//
//  NotificationsService.swift
//  myfidpass
//
//  Gestion des notifications push : permission, enregistrement, envoi du token au backend.
//
//  CORRECTIONS APPORTÉES :
//  1. sendTokenToBackend() : 3 tentatives avec backoff exponentiel (2s → 4s → 8s) au lieu
//     d'une seule tentative silencieuse. En production, les échecs sont loggés en WARNING.
//  2. Persistance locale : le token est sauvegardé dans UserDefaults avant tout envoi réseau.
//     Si le réseau est coupé au moment de l'enregistrement, retryPendingTokenIfNeeded() est
//     appelé à chaque connexion réussie (via .myfidpassAuthTokensUpdated) pour réessayer.
//  3. Sans ces corrections, un réseau coupé à la première ouverture de l'app empêchait
//     définitivement le commerçant de recevoir les pushes silencieux et les accusés de campagne.
//

import Foundation
import UserNotifications
import UIKit
import Combine

@MainActor
final class NotificationsService: NSObject, ObservableObject {
    static let shared = NotificationsService()
    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var deviceToken: String?

    /// Clé UserDefaults pour le token en attente d'envoi au backend.
    private static let pendingTokenKey = "myfidpass.pendingDeviceToken"
    /// Relances onboarding commerçant (local notifications).
    private static let merchantCardReminderRequestId = "myfidpass.merchant.cardSetup.reminder.v1"
    private static let merchantFlyerReminderRequestId = "myfidpass.merchant.flyerSetup.reminder.v1"
    private static let merchantCardReminderScheduledAtBySlugKey = "myfidpass.merchant.cardSetup.reminder.scheduledAtBySlug.v1"
    private static let merchantFlyerReminderScheduledAtBySlugKey = "myfidpass.merchant.flyerSetup.reminder.scheduledAtBySlug.v1"
    private static let merchantCardReminderDelay: TimeInterval = 3 * 60 * 60
    private static let merchantFlyerReminderDelay: TimeInterval = 8 * 60 * 60
    /// Ancienne notif fin d’essai — retirée du produit, conservée pour annuler les rappels déjà planifiés.
    private static let legacyTrialReminderRequestId = "myfidpass.merchant.trialEnding.reminder.v1"

    override private init() {
        super.init()
        NotificationCenter.default.addObserver(
            forName: .myfidpassAuthTokensUpdated,
            object: nil,
            queue: .main
        ) { _ in
            // Closure `@Sendable` non isolée : hop explicite vers le MainActor (Swift 6).
            Task { @MainActor in
                NotificationsService.shared.syncPushTokenAfterLogin()
                await NotificationsService.shared.refreshMerchantCardSetupReminder()
            }
        }
    }

    /// Après connexion ou refresh JWT : enregistre le token APNs côté API si disponible.
    /// Réessaie aussi tout token en attente (échec réseau précédent).
    func syncPushTokenAfterLogin() {
        guard AuthStorage.isLoggedIn, APIClient.shared.authToken != nil else { return }

        // Tenter l'envoi du token courant (s'il est disponible).
        if let token = deviceToken, !token.isEmpty {
            Task { await NotificationsService.shared.sendTokenToBackend(token) }
        }

        // Réessayer un token persisté mais jamais envoyé (crash ou réseau coupé).
        retryPendingTokenIfNeeded()

        // Re-demander le token à iOS (déclenche didRegisterForRemoteNotifications si token a changé).
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Met à jour `isAuthorized` selon les réglages système (à rappeler à l'ouverture des Paramètres).
    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let authorized: Bool = {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral: return true
                default: return false
                }
            }()
            Task { @MainActor in
                NotificationsService.shared.isAuthorized = authorized
                NotificationsService.shared.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    /// Demande la permission et enregistre pour les notifications à distance.
    func requestPermissionAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            Task { @MainActor in
                NotificationsService.shared.isAuthorized = granted
                NotificationsService.shared.authorizationStatus = granted ? .authorized : .denied
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    await NotificationsService.shared.refreshMerchantCardSetupReminder()
                }
            }
        }
    }

    /// Appelé par AppDelegate quand le device token est reçu d'Apple.
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = token

        // Persiste immédiatement en local : si l'envoi réseau échoue,
        // le token sera réessayé à la prochaine connexion.
        UserDefaults.standard.set(token, forKey: Self.pendingTokenKey)

        Task { await NotificationsService.shared.sendTokenToBackend(token) }
    }

    /// Envoie le token au backend avec jusqu'à 3 tentatives et backoff exponentiel.
    ///
    /// - Tentative 1 : immédiate
    /// - Tentative 2 : après 2 secondes
    /// - Tentative 3 : après 4 secondes supplémentaires (6s total)
    ///
    /// En cas de succès : supprime le token de UserDefaults (plus besoin de retry).
    /// En cas d'échec total : le token reste dans UserDefaults pour être réessayé
    /// à la prochaine connexion via retryPendingTokenIfNeeded().
    fileprivate func sendTokenToBackend(_ token: String) async {
        guard AuthStorage.isLoggedIn, APIClient.shared.authToken != nil else {
            // Non connecté : on garde le token en attente, sera envoyé après login.
            UserDefaults.standard.set(token, forKey: Self.pendingTokenKey)
            return
        }

        let maxAttempts = 3
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                _ = try await APIClient.shared.request(APIEndpoint.deviceRegister(token: token)) as EmptyResponse
                // Succès : le token est enregistré côté serveur, on nettoie UserDefaults.
                UserDefaults.standard.removeObject(forKey: Self.pendingTokenKey)
                return
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    // Backoff exponentiel : 2s, puis 4s.
                    let delaySeconds = pow(2.0, Double(attempt))
                    try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                }
            }
        }

        // Toutes les tentatives ont échoué.
        // Le token reste dans UserDefaults — retryPendingTokenIfNeeded() le renverra
        // à la prochaine connexion ou ouverture de l'app.
        NSLog(
            "[NotificationsService] deviceRegister échoué après %d tentatives : %@",
            maxAttempts,
            lastError?.localizedDescription ?? "inconnu"
        )
    }

    /// Vérifie si un token était en attente d'envoi (ex: crash ou réseau coupé lors
    /// du précédent enregistrement) et le réenvoie si c'est le cas.
    private func retryPendingTokenIfNeeded() {
        guard let pending = UserDefaults.standard.string(forKey: Self.pendingTokenKey),
              !pending.isEmpty else { return }

        // Éviter de réenvoyer le token actuel (déjà en cours d'envoi via didRegisterForRemoteNotifications).
        if let current = deviceToken, current == pending { return }

        Task { await NotificationsService.shared.sendTokenToBackend(pending) }
    }

    // MARK: - Onboarding commerçant (relance création carte)

    /// Campagne locale onboarding commerçant (carte + flyer + fin d'offre 1€).
    func refreshMerchantCardSetupReminder() async {
        guard AuthStorage.isLoggedIn else {
            await cancelMerchantOnboardingReminders()
            return
        }
        // Jamais pour les comptes staff.
        if let staff = AuthStorage.userStaffLogin?.trimmingCharacters(in: .whitespacesAndNewlines), !staff.isEmpty {
            await cancelMerchantOnboardingReminders()
            return
        }
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            await cancelMerchantOnboardingReminders()
            return
        }

        let settings = await notificationSettings()
        let authorized = {
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: return true
            default: return false
            }
        }()
        guard authorized else { return }

        let pending = await pendingNotificationRequests()
        await refreshCardReminder(slug: slug, pending: pending)
        await refreshFlyerReminder(slug: slug, pending: pending)
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.legacyTrialReminderRequestId]
        )
    }

    private func refreshCardReminder(slug: String, pending: [UNNotificationRequest]) async {
        if isMerchantCardConfigured(slug: slug) {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.merchantCardReminderRequestId])
            clearScheduleStamp(for: slug, key: Self.merchantCardReminderScheduledAtBySlugKey)
            return
        }

        if let existing = pending.first(where: { $0.identifier == Self.merchantCardReminderRequestId }) {
            let existingSlug = existing.content.userInfo["business_slug"] as? String
            if existingSlug == slug { return }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.merchantCardReminderRequestId])
        }
        if isReminderRecentlyScheduled(for: slug, key: Self.merchantCardReminderScheduledAtBySlugKey, delay: Self.merchantCardReminderDelay) {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Créez votre carte fidélité"
        content.body = "Vous n'avez pas encore finalisé votre carte. Configurez-la maintenant pour commencer à fidéliser vos clients."
        content.sound = .default
        content.userInfo = ["business_slug": slug, "campaign": "merchant_card_setup_reminder"]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: Self.merchantCardReminderDelay,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.merchantCardReminderRequestId,
            content: content,
            trigger: trigger
        )

        await addNotificationRequest(request)
        markReminderScheduledNow(for: slug, key: Self.merchantCardReminderScheduledAtBySlugKey)
    }

    private func refreshFlyerReminder(slug: String, pending: [UNNotificationRequest]) async {
        if isMerchantFlyerConfigured(slug: slug) {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.merchantFlyerReminderRequestId])
            clearScheduleStamp(for: slug, key: Self.merchantFlyerReminderScheduledAtBySlugKey)
            return
        }

        if let existing = pending.first(where: { $0.identifier == Self.merchantFlyerReminderRequestId }) {
            let existingSlug = existing.content.userInfo["business_slug"] as? String
            if existingSlug == slug { return }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.merchantFlyerReminderRequestId])
        }
        if isReminderRecentlyScheduled(for: slug, key: Self.merchantFlyerReminderScheduledAtBySlugKey, delay: Self.merchantFlyerReminderDelay) {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Activez votre flyer en boutique"
        content.body = "Votre flyer n'est pas encore prêt. Imprimez-le et affichez-le en commerce pour accélérer les scans clients."
        content.sound = .default
        content.userInfo = ["business_slug": slug, "campaign": "merchant_flyer_setup_reminder"]
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: Self.merchantFlyerReminderDelay,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.merchantFlyerReminderRequestId,
            content: content,
            trigger: trigger
        )
        await addNotificationRequest(request)
        markReminderScheduledNow(for: slug, key: Self.merchantFlyerReminderScheduledAtBySlugKey)
    }

    private func cancelMerchantOnboardingReminders() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [
                Self.merchantCardReminderRequestId,
                Self.merchantFlyerReminderRequestId,
                Self.legacyTrialReminderRequestId,
            ]
        )
    }

    private func isMerchantCardConfigured(slug: String) -> Bool {
        guard let snapshot = CardPreviewDisplaySnapshotStore.load(slug: slug) else { return false }
        let missing = MyCardCompletionRequirements.missingRequirements(
            primaryHex: snapshot.primaryHex,
            accentHex: snapshot.accentHex,
            labelHex: snapshot.labelHex,
            stripDisplayMode: snapshot.stripDisplayMode,
            stripText: snapshot.stripText,
            displayName: snapshot.displayName,
            logoURL: snapshot.logoURL,
            programType: snapshot.programType,
            cardBackgroundImagePath: snapshot.hasLocalCardBackground == true ? CardLogoStorage.relativeCardBackgroundPath : nil,
            cardBackgroundRemoteURL: snapshot.cardBackgroundRemoteURL,
            cardBackgroundWasRemoved: false,
            stampEmoji: snapshot.stampEmoji,
            stampIconPendingBase64: snapshot.stampIconPendingBase64,
            stampIconWasRemoved: snapshot.stampIconWasRemoved ?? false,
            serverHasStampIcon: snapshot.hasServerStampIcon ?? false,
            tierPoints: snapshot.tierPoints ?? [],
            tierLabels: snapshot.tierLabels ?? [],
            requiredStamps: snapshot.requiredStamps,
            stampRewardLabel: snapshot.stampRewardLabel,
            stampMidRewardLabel: snapshot.stampMidRewardLabel ?? "",
            startGameRewardLabel: snapshot.startGameRewardLabel ?? ""
        )
        return missing.isEmpty
    }

    private func isMerchantFlyerConfigured(slug: String) -> Bool {
        guard let cached = CommerceFlyerStateCache.load(slug: slug) else { return false }
        let hasBootstrap = !(cached.bootstrapPreviewB64 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasCustomBg = !(cached.customBgDataURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return cached.flyerRegistered || hasBootstrap || hasCustomBg
    }

    private func isReminderRecentlyScheduled(for slug: String, key: String, delay: TimeInterval) -> Bool {
        guard let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: TimeInterval],
              let ts = dict[slug] else { return false }
        let age = Date().timeIntervalSince1970 - ts
        return age < delay
    }

    private func markReminderScheduledNow(for slug: String, key: String) {
        var dict = UserDefaults.standard.dictionary(forKey: key) as? [String: TimeInterval] ?? [:]
        dict[slug] = Date().timeIntervalSince1970
        UserDefaults.standard.set(dict, forKey: key)
    }

    private func clearScheduleStamp(for slug: String, key: String) {
        var dict = UserDefaults.standard.dictionary(forKey: key) as? [String: TimeInterval] ?? [:]
        dict.removeValue(forKey: slug)
        UserDefaults.standard.set(dict, forKey: key)
    }

    private func parseISO8601(_ raw: String?) -> Date? {
        guard var iso = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !iso.isEmpty else { return nil }
        if !iso.contains("T") { iso = iso.replacingOccurrences(of: " ", with: "T") }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: iso) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private func addNotificationRequest(_ request: UNNotificationRequest) async {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().add(request) { _ in
                continuation.resume(returning: ())
            }
        }
    }
}
