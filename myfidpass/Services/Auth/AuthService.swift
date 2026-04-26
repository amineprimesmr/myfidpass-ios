//
//  AuthService.swift
//  myfidpass
//
//  Connexion via l’API MyFidpass (login, Apple, Google). Inscription native dans l’app.
//

import Foundation
import Combine
import AuthenticationServices
import UIKit
import CoreData

enum AuthScreen: Equatable {
    case welcome
    case authenticated
}

private enum AuthLoadingBootstrapTimeout: Error {
    case exceeded
}

/// Cache local de la fin d’essai (ISO) : au cold start, `merchantTrialEndsAt` peut rester nil tant que `GET /me` n’a pas réussi — la pastille ne s’affichait pas.
private let merchantTrialEndIsoUserDefaultsKey = "myfidpass.merchantTrialEndsAtIso"

@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published private(set) var currentScreen: AuthScreen = .welcome
    @Published private(set) var currentUserEmail: String?

    /// Identifiant employé (sans e-mail), si connexion par compte créé par le commerçant.
    var currentUserStaffLogin: String? { AuthStorage.userStaffLogin }
    @Published private(set) var currentUserPhone: String?
    @Published private(set) var businesses: [BusinessDTO] = []
    /// Incrémenté après suppression de compte pour que `myfidpassApp` réaffiche l’onboarding premier lancement.
    @Published private(set) var firstLaunchOnboardingRestartEpoch: Int = 0
    /// `true` après au moins un `GET /api/auth/me` (ou login avec champs abonnement) post-restauration session.
    @Published private(set) var merchantSubscriptionEligibilityResolved = false
    /// Abonnement Stripe : actif, essai ou `past_due` (aligné sur `hasActiveSubscription` API).
    @Published private(set) var hasActiveMerchantSubscription = false
    /// Verrou local post-inscription pour forcer l’ouverture du paywall.
    @Published private(set) var pendingMandatoryPaywallAfterSignup = false
    /// Doit relancer le tutoriel commerçant une fois le paywall post-inscription quitté.
    @Published private(set) var pendingHomeTutorialAfterSignup = false
    /// Dernière ligne d’abonnement renvoyée par `/me` (pour distinguer paiement Stripe de l’essai gratuit 24 h).
    @Published private(set) var merchantSubscription: SubscriptionDTO?
    /// Fin de la fenêtre d’essai gratuit commerçant (sans abonnement Stripe payant), si applicable.
    @Published private(set) var merchantTrialEndsAt: Date?
    /// Compte `is_admin` : pilotage de tous les commerces via l’API (même slug hors liste « mes » commerces).
    @Published private(set) var isPlatformAdmin = false
    /// `false` = interface **Administration** (liste plateforme) ; `true` = interface commerçant classique (pilotage d’un commerce).
    @Published var adminShowsMerchantWorkspace = false
    /// Rôle dans le commerce actif (`user.workspace_role` sur login / `GET /me`). Défaut `owner` si absent.
    @Published private(set) var merchantWorkspaceRole: MerchantWorkspaceRole = .owner

    private var cancellables = Set<AnyCancellable>()

    /// Employé (caisse) : interface réduite (pas d’onglet Commerce / Notifs marketing).
    /// S’appuie sur le rôle **et** sur `userStaffLogin` persistant (l’API omet parfois `workspace_role` / `staff_login`).
    var isMerchantStaffUser: Bool {
        if merchantWorkspaceRole == .staff { return true }
        if let s = AuthStorage.userStaffLogin?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { return true }
        return false
    }

    /// Pour l’UI freemium : abonnement Stripe actif **ou** compte admin plateforme (accès pilotage).
    var effectiveMerchantSubscriptionActive: Bool {
        if isPlatformAdmin { return true }
        return hasActiveMerchantSubscription
    }

    var canManageMerchantTeam: Bool { merchantWorkspaceRole.canManageTeam }

    /// Abonnement encaissé côté Stripe (hors seule période d’essai **application**).
    var hasPaidStripeSubscription: Bool {
        let s = merchantSubscription?.status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return s == "active" || s == "trialing" || s == "past_due"
    }

    /// Verrou post-inscription : tant que ce flag n’est pas consommé par le paywall,
    /// l’accès doit rester bloqué pour forcer l’étape paiement.
    var mustOpenMandatoryPaywallAfterSignup: Bool {
        pendingMandatoryPaywallAfterSignup
    }

    /// Essai gratuit 3 j **en cours** : la source de vérité est `merchant_trial_ends_at` (non nul côté API tant que pas d’abo Stripe / IAP payant).
    /// On ne combine pas avec `hasPaidStripeSubscription` : une ligne locale parasite pourrait masquer la pastille à tort.
    var isMerchantTrialPeriodActive: Bool {
        guard !isPlatformAdmin else { return false }
        guard let end = merchantTrialEndsAt else { return false }
        return Date() < end
    }

    private static func parseMerchantTrialEnd(_ iso: String?) -> Date? {
        guard var iso, !iso.isEmpty else { return nil }
        iso = iso.trimmingCharacters(in: .whitespacesAndNewlines)
        if !iso.contains("T") { iso = iso.replacingOccurrences(of: " ", with: "T") }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: iso) { return d }
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: iso) { return d }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        if let d = df.date(from: iso) { return d }
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return df.date(from: iso)
    }

    override init() {
        super.init()
        loadFromStorage()
        // Ne pas figer « non abonné » sur un 403 : réconcilier avec GET /me (ex. paiement Stripe tout juste actif, requête en retard).
        NotificationCenter.default.publisher(for: .myfidpassSubscriptionRequiredByAPI)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refreshBusinessesIfNeeded() }
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .myfidpassMerchantSubscriptionFromRefresh)
            .compactMap { Self.subscriptionActiveFromRefreshNotification($0) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] has in
                guard let self else { return }
                // Ne pas appliquer `false` depuis le seul POST /refresh : source de vérité = GET /me
                // (évite bannière « mode découverte » si la réponse refresh est transitoirement fausse / désalignée).
                if has {
                    self.applySubscriptionGateState(active: true, markResolved: true)
                } else {
                    Task { await self.refreshBusinessesIfNeeded() }
                }
            }
            .store(in: &cancellables)
    }

    private func applySubscriptionGateState(active: Bool, markResolved: Bool) {
        hasActiveMerchantSubscription = active
        if markResolved {
            merchantSubscriptionEligibilityResolved = true
        }
    }

    private func loadFromStorage() {
        FirstLaunchOnboarding.bootstrapInstallAndMigrateMerchantPhaseIfNeeded()
        pendingMandatoryPaywallAfterSignup = AuthStorage.pendingOpenMerchantSubscriptionSheetAfterSignup
        pendingHomeTutorialAfterSignup = AuthStorage.pendingShowMerchantHomeTutorialAfterSignup
        if AuthStorage.isLoggedIn {
            currentUserPhone = AuthStorage.userPhone
            currentScreen = .authenticated
            merchantSubscriptionEligibilityResolved = false
            if
                let sl = AuthStorage.userStaffLogin?.trimmingCharacters(in: .whitespacesAndNewlines), !sl.isEmpty
            {
                merchantWorkspaceRole = .staff
            } else if let raw = AuthStorage.merchantWorkspaceRoleRaw, let r = MerchantWorkspaceRole(rawValue: raw) {
                merchantWorkspaceRole = r
            } else {
                merchantWorkspaceRole = .owner
            }
            syncAccountDisplayLineForSession()
            if merchantTrialEndsAt == nil,
               let iso = UserDefaults.standard.string(forKey: merchantTrialEndIsoUserDefaultsKey),
               !iso.isEmpty,
               let cached = Self.parseMerchantTrialEnd(iso) {
                merchantTrialEndsAt = cached
            }
        } else {
            currentScreen = .welcome
            merchantSubscriptionEligibilityResolved = false
            hasActiveMerchantSubscription = false
            isPlatformAdmin = false
            adminShowsMerchantWorkspace = false
            merchantWorkspaceRole = .owner
            pendingMandatoryPaywallAfterSignup = false
            pendingHomeTutorialAfterSignup = false
            UserDefaults.standard.removeObject(forKey: merchantTrialEndIsoUserDefaultsKey)
        }
    }

    func markMandatoryPaywallAfterSignupPending() {
        AuthStorage.pendingOpenMerchantSubscriptionSheetAfterSignup = true
        AuthStorage.pendingShowMerchantHomeTutorialAfterSignup = true
        pendingMandatoryPaywallAfterSignup = true
        pendingHomeTutorialAfterSignup = true
    }

    func clearMandatoryPaywallAfterSignupPending() {
        AuthStorage.pendingOpenMerchantSubscriptionSheetAfterSignup = false
        pendingMandatoryPaywallAfterSignup = false
    }

    func consumePendingHomeTutorialAfterSignup() -> Bool {
        guard pendingHomeTutorialAfterSignup else { return false }
        pendingHomeTutorialAfterSignup = false
        AuthStorage.pendingShowMerchantHomeTutorialAfterSignup = false
        return true
    }

    private static func persistMerchantTrialEndIsoFromServer(_ iso: String?) {
        if let iso, !iso.isEmpty {
            UserDefaults.standard.set(iso, forKey: merchantTrialEndIsoUserDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: merchantTrialEndIsoUserDefaultsKey)
        }
    }

    func showLogin() {
        currentScreen = .welcome
    }

    func showSignUp() {
        currentScreen = .welcome
    }

    func showWelcome() {
        currentScreen = .welcome
    }

    /// Recharge la liste des commerces (ex. au retour de l’app).
    /// Important : si on ne peut pas appeler `/me`, il faut quand même marquer l’état abonnement comme « résolu »,
    /// sinon `RootView` reste bloquée sur « Chargement du compte… » (ex. `isLoggedIn` vrai mais JWT absent).
    func refreshBusinessesIfNeeded() async {
        guard AuthStorage.isLoggedIn else { return }

        let accessEmpty = APIClient.shared.authToken?.isEmpty != false
        if accessEmpty {
            _ = await APIClient.shared.tryRefreshToken()
        }

        guard APIClient.shared.authToken != nil, !(APIClient.shared.authToken ?? "").isEmpty else {
            applySubscriptionGateState(active: false, markResolved: true)
            return
        }

        do {
            let me: AuthMeResponse = try await withLoadingBootstrapTimeout(seconds: 35) {
                try await APIClient.shared.request(.authMe)
            }
            applyAuthMeResponse(me)
        } catch {
            // Ne pas remettre l’abonnement à « inactif » sur erreur réseau, timeout ou échec de décodage :
            // cela affichait la bannière « mode découverte » alors que l’utilisateur avait déjà payé.
            merchantSubscriptionEligibilityResolved = true
        }
    }

    private static let stripeReconcileThrottleKey = "myfidpass.stripeReconcileLastSuccessAt"
    private static let stripeReconcileMinInterval: TimeInterval = 90

    /// Le serveur interroge Stripe (client avec l’email du compte) et met à jour `subscriptions` si un abo actif existe.
    /// Utile quand le webhook n’a pas lié le paiement au bon `user_id`.
    func reconcileStripeSubscriptionFromServer(force: Bool = false) async {
        guard AuthStorage.isLoggedIn else { return }
        guard APIClient.shared.authToken != nil, !(APIClient.shared.authToken ?? "").isEmpty else { return }
        if hasActiveMerchantSubscription { return }
        if !force {
            if let last = UserDefaults.standard.object(forKey: Self.stripeReconcileThrottleKey) as? Date,
               Date().timeIntervalSince(last) < Self.stripeReconcileMinInterval {
                return
            }
        }
        do {
            let r: PaymentReconcileSubscriptionResponse = try await APIClient.shared.request(.paymentReconcileSubscription)
            if r.hasActiveSubscription == true {
                applySubscriptionGateState(active: true, markResolved: true)
            }
            if r.ok == true {
                UserDefaults.standard.set(Date(), forKey: Self.stripeReconcileThrottleKey)
            }
            // Toujours relire `/me` après reconcile : même si `ok` est false, la base peut avoir été mise à jour ailleurs.
            await refreshBusinessesIfNeeded()
        } catch {
            // réseau / Stripe : on ne bloque pas l’UI
        }
    }

    /// Après achat / restore in-app (RevenueCat) : pousse l’état côté API pour que le JWT / `has_active_subscription` suive l’IAP, sans n’attendre que le webhook.
    @MainActor
    func syncRevenueCatSubscriptionWithServerAfterPurchase() async {
        guard AuthStorage.isLoggedIn else { return }
        guard APIClient.shared.authToken != nil, !(APIClient.shared.authToken ?? "").isEmpty else { return }
        do {
            let _: AuthRevenueCatSyncResponse = try await APIClient.shared.request(.authRevenueCatSync)
        } catch {
            // rétro-réseau : on tente quand même `/me`
        }
        await refreshBusinessesIfNeeded()
    }

    /// Évite un spinner infini si `GET /api/auth/me` reste suspendu (réseau / proxy).
    private func withLoadingBootstrapTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw AuthLoadingBootstrapTimeout.exceeded
            }
            guard let first = try await group.next() else {
                group.cancelAll()
                throw AuthLoadingBootstrapTimeout.exceeded
            }
            group.cancelAll()
            return first
        }
    }

    /// Applique la réponse `GET /api/auth/me` (écran Compte, pull-to-refresh).
    func applyAuthMeResponse(_ me: AuthMeResponse) {
        AuthStorage.mergeDashboardTokens(from: me.businesses)
        businesses = me.businesses
        if let saved = AuthStorage.currentBusinessSlug,
           businesses.contains(where: { $0.slug == saved }) {
            // conserve le slug actif
        } else {
            AuthStorage.currentBusinessSlug = businesses.first?.slug
        }
        if let uid = me.user.id?.trimmingCharacters(in: .whitespacesAndNewlines), !uid.isEmpty {
            AuthStorage.userId = uid
        }
        if let sl = me.user.staffLogin?.trimmingCharacters(in: .whitespacesAndNewlines), !sl.isEmpty {
            AuthStorage.userStaffLogin = sl
        }
        let hasStaffId = !(AuthStorage.userStaffLogin?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
        if !hasStaffId, let em = me.user.email?.trimmingCharacters(in: .whitespacesAndNewlines), !em.isEmpty {
            AuthStorage.userEmail = em
        } else if hasStaffId {
            AuthStorage.userEmail = nil
        }
        if let ph = me.user.phone?.trimmingCharacters(in: .whitespacesAndNewlines), !ph.isEmpty {
            AuthStorage.userPhone = ph
            currentUserPhone = ph
        } else {
            AuthStorage.userPhone = nil
            currentUserPhone = nil
        }
        hasActiveMerchantSubscription = Self.isMerchantSubscriptionActive(me)
        merchantSubscription = me.subscription
        merchantTrialEndsAt = Self.parseMerchantTrialEnd(me.merchantTrialEndsAt)
        Self.persistMerchantTrialEndIsoFromServer(me.merchantTrialEndsAt)
        merchantSubscriptionEligibilityResolved = true
        isPlatformAdmin = me.user.isAdmin == true
        if !isPlatformAdmin {
            adminShowsMerchantWorkspace = false
        }
        applyWorkspaceRole(from: me.user)
        alignMerchantRoleWithPersistedStaffSession()
        syncAccountDisplayLineForSession()
    }

    /// Aligné sur le backend : `has_active_subscription` ou statut Stripe `subscription.status`.
    /// Aligné sur le backend (`hasActiveSubscription`) : actif, essai, ou période de grâce Stripe (`past_due`).
    private static func isMerchantSubscriptionActive(hasExplicit: Bool?, subscription: SubscriptionDTO?) -> Bool {
        if hasExplicit == true { return true }
        let s = subscription?.status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return s == "active" || s == "trialing" || s == "past_due"
    }

    private static func subscriptionActiveFromRefreshNotification(_ note: Notification) -> Bool? {
        guard let raw = note.userInfo?["hasActive"] else { return nil }
        if let b = raw as? Bool { return b }
        if let n = raw as? NSNumber { return n.boolValue }
        return nil
    }

    private static func isMerchantSubscriptionActive(_ me: AuthMeResponse) -> Bool {
        isMerchantSubscriptionActive(hasExplicit: me.hasActiveSubscription, subscription: me.subscription)
    }

    private func applyWorkspaceRole(from user: AuthUser) {
        var role = MerchantWorkspaceRole.resolve(fromAPIValue: user.workspaceRole)
        /// Comptes identifiants employés : `GET /me` ou login peuvent omettre `workspace_role` ; `staff_login` est la source fiable.
        if let sl = user.staffLogin?.trimmingCharacters(in: .whitespacesAndNewlines), !sl.isEmpty {
            role = .staff
        }
        /// Session employé reconnue localement (identifiant sans « @ ») même si l’API ne renvoie pas les champs ci‑dessus.
        if let s = AuthStorage.userStaffLogin?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            role = .staff
        }
        merchantWorkspaceRole = role
        if AuthStorage.isLoggedIn {
            AuthStorage.merchantWorkspaceRoleRaw = role.rawValue
        }
    }

    /// Après `GET /me` : l’API peut renvoyer `workspace_role` absent / erroné ; l’identifiant employé persistant prime.
    private func alignMerchantRoleWithPersistedStaffSession() {
        guard AuthStorage.isLoggedIn else { return }
        if let s = AuthStorage.userStaffLogin?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            merchantWorkspaceRole = .staff
            AuthStorage.merchantWorkspaceRoleRaw = MerchantWorkspaceRole.staff.rawValue
        }
    }

    /// Comptes employé : on ne stocke pas d’e-mail local ; le libellé de session reprend l’identifiant caisse.
    private func syncAccountDisplayLineForSession() {
        if isMerchantStaffUser {
            AuthStorage.userEmail = nil
            currentUserEmail = AuthStorage.userStaffLogin
        } else {
            currentUserEmail = AuthStorage.userEmail
        }
    }

    /// - Parameter passwordLoginFieldNormalized: valeur normalisée du champ « e-mail ou identifiant » pour `POST /auth/login` (obligatoire pour détecter l’employé quand l’API omet `staff_login`).
    private func applyAuthSuccess(
        _ response: AuthLoginResponse,
        passwordLoginFieldNormalized: String? = nil
    ) {
        AuthStorage.isLoggedIn = true
        if let uid = response.user.id?.trimmingCharacters(in: .whitespacesAndNewlines), !uid.isEmpty {
            AuthStorage.userId = uid
        }
        let pl = passwordLoginFieldNormalized.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        } ?? ""
        let loginByIdentifierNotEmail = !pl.isEmpty && !pl.contains("@")
        if let sl = response.user.staffLogin?.trimmingCharacters(in: .whitespacesAndNewlines), !sl.isEmpty {
            AuthStorage.userStaffLogin = sl
            AuthStorage.userEmail = nil
        } else if loginByIdentifierNotEmail {
            /// L’app envoie `login` (sans @) : c’est un employé, même si la réponse JSON n’a ni `staff_login` ni `workspace_role`.
            AuthStorage.userStaffLogin = pl
            AuthStorage.userEmail = nil
        } else {
            AuthStorage.userStaffLogin = nil
            AuthStorage.userEmail = response.user.email
        }
        if let ph = response.user.phone?.trimmingCharacters(in: .whitespacesAndNewlines), !ph.isEmpty {
            AuthStorage.userPhone = ph
        } else {
            AuthStorage.userPhone = nil
        }
        AuthStorage.authToken = response.token
        if let rt = response.refreshToken { AuthStorage.refreshToken = rt }
        AuthStorage.mergeDashboardTokens(from: response.businesses)
        businesses = response.businesses
        if let saved = AuthStorage.currentBusinessSlug,
           response.businesses.contains(where: { $0.slug == saved }) {
            // conserve le commerce déjà choisi
        } else if let first = response.businesses.first {
            AuthStorage.currentBusinessSlug = first.slug
        } else {
            AuthStorage.currentBusinessSlug = nil
        }
        DataService.seedBusinessesFromAuth(response.businesses, context: PersistenceController.shared.container.viewContext)
        currentUserPhone = AuthStorage.userPhone
        hasActiveMerchantSubscription = Self.isMerchantSubscriptionActive(
            hasExplicit: response.hasActiveSubscription,
            subscription: response.subscription
        )
        merchantSubscription = response.subscription
        merchantTrialEndsAt = Self.parseMerchantTrialEnd(response.merchantTrialEndsAt)
        Self.persistMerchantTrialEndIsoFromServer(response.merchantTrialEndsAt)
        merchantSubscriptionEligibilityResolved = true
        isPlatformAdmin = response.user.isAdmin == true
        if !isPlatformAdmin {
            adminShowsMerchantWorkspace = false
        }
        applyWorkspaceRole(from: response.user)
        alignMerchantRoleWithPersistedStaffSession()
        syncAccountDisplayLineForSession()
        currentScreen = .authenticated
        NotificationsService.shared.syncPushTokenAfterLogin()
    }

    /// Change le commerce actif (multi-cartes). En admin plateforme, tout slug valide côté API est accepté.
    func selectBusiness(slug: String) {
        let trimmed = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !isPlatformAdmin {
            guard businesses.contains(where: { $0.slug == trimmed }) else { return }
        }
        ScanFlowSettingsCache.clearAll()
        AuthStorage.currentBusinessSlug = trimmed
    }

    /// Indique si un compte existe : e-mail (`POST /api/auth/check-email`) ou identifiant employé (`POST /api/auth/check-identifier`).
    func checkAccountExists(identifier: String) async throws -> Bool {
        struct CheckEmailResponse: Decodable {
            let accountExists: Bool
        }
        let norm = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !norm.isEmpty else { throw AuthError.invalidCredentials }
        do {
            if norm.contains("@") {
                let r: CheckEmailResponse = try await APIClient.shared.request(
                    .authCheckEmail(email: norm),
                    responseType: CheckEmailResponse.self
                )
                return r.accountExists
            }
            let r: CheckEmailResponse = try await APIClient.shared.request(
                .authCheckIdentifier(identifier: norm),
                responseType: CheckEmailResponse.self
            )
            return r.accountExists
        } catch {
            throw AuthError.networkError
        }
    }

    /// Inscription native — alignée sur POST /api/auth/register (optionnel : lieu Google → 1er commerce créé côté API).
    func register(
        email: String,
        password: String,
        name: String?,
        googlePlaceId: String? = nil,
        establishmentName: String? = nil
    ) async throws {
        guard !email.isEmpty, password.count >= 8 else { throw AuthError.invalidCredentials }
        let pending = FirstLaunchOnboarding.readPendingEstablishment()
        let trimmedPlaceId = googlePlaceId?.trimmingCharacters(in: .whitespacesAndNewlines)
        var placeIdForAPI = (trimmedPlaceId?.isEmpty == false) ? trimmedPlaceId : nil
        if placeIdForAPI == nil, let p = pending.placeId { placeIdForAPI = p }
        let establishmentForAPI: String? = {
            let fromParam = establishmentName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let raw = (fromParam?.isEmpty == false ? fromParam : nil)
                ?? pending.description?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let r = raw, !r.isEmpty else { return nil }
            return r.count > 100 ? String(r.prefix(100)) : r
        }()
        do {
            let response: AuthLoginResponse = try await APIClient.shared.request(
                .authRegister(
                    email: email,
                    password: password,
                    name: name,
                    googlePlaceId: placeIdForAPI,
                    establishmentName: establishmentForAPI
                )
            )
            MerchantLinkedPlaceCache.snapshotFromPendingOnboarding()
            FirstLaunchOnboarding.clearPendingEstablishmentFromOnboarding()
            markMandatoryPaywallAfterSignupPending()
            applyAuthSuccess(response)
        } catch let e as APIError {
            if case .server(let code, _) = e, code == 409 {
                throw AuthError.emailAlreadyUsed
            }
            if case .unauthorized = e {
                throw AuthError.invalidCredentials
            }
            throw AuthError.networkError
        } catch {
            throw AuthError.networkError
        }
    }

    /// Demande de lien de réinitialisation (email transactionnel).
    func forgotPassword(email: String) async throws {
        let emailNorm = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !emailNorm.isEmpty else { throw AuthError.invalidCredentials }
        _ = try await APIClient.shared.request(.authForgotPassword(email: emailNorm)) as ForgotPasswordAPIResponse
    }

    /// Connexion e-mail **ou** identifiant employé. POST /api/auth/login (body : `login` + `password`).
    func login(email: String, password: String) async throws {
        let idNorm = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !idNorm.isEmpty else { throw AuthError.invalidCredentials }
        do {
            let response: AuthLoginResponse = try await APIClient.shared.request(.authLogin(login: idNorm, password: password))
            applyAuthSuccess(response, passwordLoginFieldNormalized: idNorm)
        } catch APIError.noAccountInLogiciel {
            throw AuthError.noAccountInLogiciel
        } catch APIError.unauthorized {
            throw AuthError.invalidCredentials
        } catch APIError.network {
            throw AuthError.networkError
        } catch {
            throw AuthError.networkError
        }
    }

    /// Demande un code SMS (connexion / inscription). POST /api/auth/phone/send-code.
    func sendPhoneOtp(phone: String) async throws {
        struct SendOk: Decodable { let ok: Bool? }
        _ = try await APIClient.shared.request(.authPhoneSendCode(phone: phone), responseType: SendOk.self)
    }

    /// Vérifie le code reçu par SMS et ouvre la session. Nouveau compte : même sélection d’établissement que pour Apple / Google.
    func verifyPhoneAndSignIn(phone: String, code: String) async throws {
        let pending = FirstLaunchOnboarding.readPendingEstablishment()
        let placeId = pending.placeId
        let estName = pending.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? pending.description : nil
        let response: AuthLoginResponse = try await APIClient.shared.request(
            .authPhoneVerify(phone: phone, code: code, googlePlaceId: placeId, establishmentName: estName)
        )
        AuthStorage.authProvider = .phone
        let isNewPhoneSignup = (placeId != nil || estName != nil)
        if isNewPhoneSignup {
            MerchantLinkedPlaceCache.snapshotFromPendingOnboarding()
            FirstLaunchOnboarding.clearPendingEstablishmentFromOnboarding()
            markMandatoryPaywallAfterSignupPending()
        }
        applyAuthSuccess(response)
    }

    /// Connexion Apple. POST /api/auth/apple avec idToken (JWT). L’app envoie credential.identityToken.
    func loginWithApple(idToken: String, name: String?, email: String?, appleUserIdentifier: String? = nil) async throws {
        let pending = FirstLaunchOnboarding.readPendingEstablishment()
        let placeId = pending.placeId
        let estName = pending.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? pending.description : nil
        do {
            let response: AuthLoginResponse = try await APIClient.shared.request(
                .authApple(idToken: idToken, name: name, email: email, googlePlaceId: placeId, establishmentName: estName)
            )
            AuthStorage.authProvider = .apple
            if let uid = appleUserIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines), !uid.isEmpty {
                AuthStorage.appleUserIdentifier = uid
            }
            let isNewAppleSignup = (placeId != nil || estName != nil)
            if isNewAppleSignup {
                MerchantLinkedPlaceCache.snapshotFromPendingOnboarding()
                FirstLaunchOnboarding.clearPendingEstablishmentFromOnboarding()
                markMandatoryPaywallAfterSignupPending()
            }
            applyAuthSuccess(response)
            currentUserEmail = response.user.email ?? email ?? "Compte Apple"
        } catch let e as APIError {
            switch e {
            case .noAccountInLogiciel:
                throw AuthError.noAccountInLogiciel
            case .server(_, let message):
                if let m = message?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty {
                    throw AuthError.apiMessage(m)
                }
                throw AuthError.networkError
            case .unauthorized, .network:
                throw AuthError.networkError
            default:
                throw AuthError.networkError
            }
        } catch {
            throw AuthError.networkError
        }
    }

    /// Connexion Google. POST /api/auth/google avec idToken.
    func loginWithGoogle(idToken: String) async throws {
        let pending = FirstLaunchOnboarding.readPendingEstablishment()
        let placeId = pending.placeId
        let estName = pending.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? pending.description : nil
        let response: AuthLoginResponse = try await APIClient.shared.request(
            .authGoogle(idToken: idToken, googlePlaceId: placeId, establishmentName: estName)
        )
        AuthStorage.authProvider = .google
        let isNewGoogleSignup = (placeId != nil || estName != nil)
        if isNewGoogleSignup {
            MerchantLinkedPlaceCache.snapshotFromPendingOnboarding()
            FirstLaunchOnboarding.clearPendingEstablishmentFromOnboarding()
            markMandatoryPaywallAfterSignupPending()
        }
        applyAuthSuccess(response)
    }

    /// Applique le JWT reçu après le redirect OAuth Google (myfidpass://auth?token=xxx&refreshToken=yyy), appelle /me puis met à jour la session.
    func applyTokenFromGoogleOAuthCallback(token: String, refreshToken: String?) async throws {
        // Effacer d’abord toute session locale (ex. compte supprimé côté serveur) pour ne pas mélanger refresh / access avec les jetons OAuth neufs.
        AuthStorage.authToken = nil
        AuthStorage.refreshToken = nil
        AuthStorage.authToken = token
        if let rt = refreshToken, !rt.isEmpty { AuthStorage.refreshToken = rt }
        AuthStorage.authProvider = .google
        let me: AuthMeResponse = try await APIClient.shared.request(.authMe)
        // L'établissement a été transmis via `state` dans l'URL OAuth et traité côté serveur — on nettoie le UserDefaults.
        MerchantLinkedPlaceCache.snapshotFromPendingOnboarding()
        FirstLaunchOnboarding.clearPendingEstablishmentFromOnboarding()
        let response = AuthLoginResponse(
            user: me.user,
            token: token,
            refreshToken: refreshToken,
            businesses: me.businesses,
            subscription: me.subscription,
            hasActiveSubscription: me.hasActiveSubscription,
            merchantTrialEndsAt: me.merchantTrialEndsAt
        )
        markMandatoryPaywallAfterSignupPending()
        applyAuthSuccess(response)
    }

    /// Lance le flux OAuth Google (ouverture navigateur → redirect myfidpass://auth?token=…). En cas d’erreur ou d’annulation, throw.
    func startGoogleOAuthFlow() async throws {
        let config: AuthConfigResponse = try await APIClient.shared.request(.authConfig)
        guard let clientId = config.googleClientId, !clientId.isEmpty else {
            throw AuthError.notImplemented
        }
        let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let redirectUri = "\(base)/api/auth/google-oauth-callback"
        let scope = "openid email profile"
        var comp = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        // `prompt=select_account` : toujours afficher le sélecteur de compte Google (choisir un compte / « Autre compte »),
        // au lieu de reprendre silencieusement la session Safari par défaut.
        // `state` : établissement sélectionné dans l'onboarding, transmis au callback pour créer le 1er commerce.
        let pending = FirstLaunchOnboarding.readPendingEstablishment()
        var stateObj: [String: String] = [:]
        if let pid = pending.placeId { stateObj["place_id"] = pid }
        if let desc = pending.description?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
            stateObj["establishment_name"] = desc
        }
        let stateParam: String? = stateObj.isEmpty ? nil : {
            let data = try? JSONSerialization.data(withJSONObject: stateObj)
            return data?.base64EncodedString()
        }()
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        if let state = stateParam {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }
        comp.queryItems = queryItems
        guard let authURL = comp.url else { throw AuthError.networkError }
        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let lock = NSLock()
            var didResume = false
            func finish(_ action: () -> Void) {
                lock.lock()
                defer { lock.unlock() }
                guard !didResume else { return }
                didResume = true
                action()
            }
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "myfidpass"
            ) { callbackURL, error in
                if let error = error {
                    finish { continuation.resume(throwing: Self.mapGoogleOAuthSessionError(error)) }
                    return
                }
                guard let url = callbackURL else {
                    finish { continuation.resume(throwing: AuthError.networkError) }
                    return
                }
                finish { continuation.resume(returning: url) }
            }
            session.presentationContextProvider = self
            // false : cookies Google / session plus stables (évite des échecs silencieux du flux OAuth).
            session.prefersEphemeralWebBrowserSession = false
            guard session.start() else {
                finish { continuation.resume(throwing: AuthError.networkError) }
                return
            }
        }
        let (token, refreshToken) = try parseGoogleOAuthCallbackURL(callbackURL)
        try await applyTokenFromGoogleOAuthCallback(token: token, refreshToken: refreshToken)
    }

    /// Erreurs système ASWebAuthenticationSession (ex. « Application failed to respond ») → message exploitable.
    private static func mapGoogleOAuthSessionError(_ error: Error) -> Error {
        let ns = error as NSError
        if ns.domain.contains("AuthenticationServices"), ns.code == 1 {
            return error
        }
        let desc = error.localizedDescription
        if desc.localizedCaseInsensitiveContains("failed to respond") {
            return AuthError.apiMessage(
                "Connexion Google interrompue : le serveur n’a pas renvoyé la redirection attendue. C’est souvent corrigé côté API (variable API_URL=https://api.myfidpass.fr sur Railway, identique à l’URL de l’app). Réessayez dans un instant."
            )
        }
        return error
    }

    /// Lit `myfidpass://auth?token=&refreshToken=` ou `?error=` renvoyés par `/api/auth/google-oauth-callback`.
    private func parseGoogleOAuthCallbackURL(_ url: URL) throws -> (token: String, refreshToken: String?) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        var dict: [String: String] = [:]
        for item in items {
            dict[item.name] = item.value ?? ""
        }
        if let err = dict["error"], !err.isEmpty {
            switch err {
            case "no_account":
                throw AuthError.noAccountInLogiciel
            case "invalid":
                throw AuthError.apiMessage(
                    "Google a refusé l’échange du code (redirect_uri ou secrets). Vérifiez API_URL et les identifiants OAuth sur le serveur."
                )
            case "config":
                throw AuthError.apiMessage("Connexion Google non configurée sur le serveur.")
            case "no_token":
                throw AuthError.apiMessage("Réponse Google incomplète. Réessayez.")
            case "no_email":
                throw AuthError.apiMessage("Google n’a pas partagé votre e-mail. Réessayez en autorisant l’accès à l’e-mail.")
            case "no_code":
                throw AuthError.apiMessage("Connexion Google interrompue. Réessayez.")
            default:
                throw AuthError.apiMessage("Connexion Google impossible (erreur \(err)).")
            }
        }
        guard let token = dict["token"], !token.isEmpty else {
            throw AuthError.apiMessage("Réponse de connexion Google invalide. Réessayez.")
        }
        let refreshToken = dict["refreshToken"].flatMap { $0.isEmpty ? nil : $0 }
        return (token, refreshToken)
    }

    /// Interface commerçant pour l’admin : si aucun slug actif, prend le **premier** commerce listé par l’API admin.
    func openMerchantWorkspaceFromAdmin() async {
        guard isPlatformAdmin else {
            adminShowsMerchantWorkspace = true
            return
        }
        let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if slug.isEmpty {
            do {
                let r: AdminBusinessesListResponse = try await APIClient.shared.request(
                    .adminBusinesses(q: nil, limit: 1, offset: 0)
                )
                if let first = r.businesses.first {
                    selectBusiness(slug: first.slug)
                }
            } catch {
                // ignore — l’utilisateur pourra choisir un commerce dans l’onglet Commerces.
            }
        }
        adminShowsMerchantWorkspace = true
    }

    func logout() {
        // Révoquer le refresh token côté serveur (fire-and-forget)
        if let rt = AuthStorage.refreshToken, !rt.isEmpty {
            Task {
                _ = try? await APIClient.shared.request(.authLogout(refreshToken: rt)) as EmptyResponse
            }
        }
        AuthenticatedMediaLoader.clearAllCaches()
        CardLogoStorage.removeAllLocalCardAssets()
        CardPreviewDisplaySnapshotStore.clearAllSnapshots()
        // Conserver l’historique local d’envois (UserDefaults) + cache stats disque par slug : mêmes données
        // qu’avant reconnexion — la purge est réservée à `deleteAccount()`.
        // Vider le cache CoreData pour éviter qu'un ancien commerce réapparaisse sur un nouveau compte
        DataService.clearAllLocalData(context: PersistenceController.shared.container.viewContext)
        // Effacer l'établissement pour forcer la re-sélection au prochain lancement (WelcomeFlow)
        FirstLaunchOnboarding.clearPendingEstablishmentFromOnboarding()
        MerchantLinkedPlaceCache.clear()
        AuthStorage.clearSession()
        currentUserEmail = nil
        currentUserPhone = nil
        businesses = []
        merchantSubscriptionEligibilityResolved = false
        hasActiveMerchantSubscription = false
        merchantSubscription = nil
        merchantTrialEndsAt = nil
        UserDefaults.standard.removeObject(forKey: merchantTrialEndIsoUserDefaultsKey)
        isPlatformAdmin = false
        adminShowsMerchantWorkspace = false
        merchantWorkspaceRole = .owner
        pendingMandatoryPaywallAfterSignup = false
        pendingHomeTutorialAfterSignup = false
        currentScreen = .welcome
    }

    /// Supprime définitivement le compte (appel API + déconnexion).
    func deleteAccount() async throws {
        _ = try await APIClient.shared.request(APIEndpoint.authDeleteAccount) as EmptyResponse
        if let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty {
            MerchantStatisticsDiskCache.clear(slug: slug)
        }
        NotificationSendLocalHistoryStore.clearForAllSlugs()
        NotificationStatsEndpointCache.clearAll()
        logout()
        FirstLaunchOnboarding.resetAfterAccountDeletion()
        firstLaunchOnboardingRestartEpoch += 1
    }
}

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        func anchor() -> ASPresentationAnchor {
            MainActor.assumeIsolated {
                let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                func activationRank(_ state: UIScene.ActivationState) -> Int {
                    switch state {
                    case .foregroundActive: return 0
                    case .foregroundInactive: return 1
                    case .background: return 2
                    case .unattached: return 3
                    @unknown default: return 4
                    }
                }
                let ordered = scenes.sorted { activationRank($0.activationState) < activationRank($1.activationState) }
                for scene in ordered {
                    if let w = scene.windows.first(where: { $0.isKeyWindow }) { return w }
                }
                for scene in ordered {
                    if let w = scene.windows.first(where: { !$0.isHidden && $0.alpha > 0.01 }) { return w }
                }
                if let w = ordered.first?.windows.first { return w }
                assertionFailure("MyFidpass: aucune UIWindow pour ASWebAuthenticationSession")
                if let w = scenes.flatMap(\.windows).first(where: { !$0.isHidden }) { return w }
                preconditionFailure("MyFidpass: aucune fenêtre pour la connexion Google.")
            }
        }
        if Thread.isMainThread {
            return anchor()
        }
        return DispatchQueue.main.sync(execute: anchor)
    }
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case networkError
    case notImplemented
    case noAccountInLogiciel
    case emailAlreadyUsed
    /// Message renvoyé par l’API (ex. validation Apple JWT).
    case apiMessage(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "E-mail ou mot de passe incorrect. Utilisez « Continuer avec Apple » ou « Continuer avec Google » si votre compte a été créé ainsi, ou réinitialisez votre mot de passe (Paramètres → Tableau de bord web, page ouverte dans l’app)."
        case .networkError: return "Erreur réseau. Réessayez."
        case .notImplemented: return "Connexion Google bientôt disponible."
        case .noAccountInLogiciel:
            return "Aucun compte associé à cet identifiant. Utilisez l’onglet « Inscription » dans l’app pour créer un compte."
        case .emailAlreadyUsed: return "Un compte existe déjà avec cet email."
        case .apiMessage(let s): return s
        }
    }
}
