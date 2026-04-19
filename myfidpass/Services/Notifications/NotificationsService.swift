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
    @Published var deviceToken: String?

    /// Clé UserDefaults pour le token en attente d'envoi au backend.
    private static let pendingTokenKey = "myfidpass.pendingDeviceToken"

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
            }
        }
    }

    /// Demande la permission et enregistre pour les notifications à distance.
    func requestPermissionAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            Task { @MainActor in
                NotificationsService.shared.isAuthorized = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
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
}
