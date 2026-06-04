//
//  AuthStorage.swift
//  myfidpass
//
//  Persistance locale (UserDefaults) + JWT dans le Keychain.
//

import Foundation

enum AuthProvider: String, Codable {
    case email
    case apple
    case google
    case phone
}

enum AuthStorage {
    private static let defaults = UserDefaults.standard

    enum Key {
        static let isLoggedIn = "myfidpass.auth.isLoggedIn"
        static let userEmail = "myfidpass.auth.userEmail"
        static let userStaffLogin = "myfidpass.auth.userStaffLogin"
        static let userPhone = "myfidpass.auth.userPhone"
        static let authProvider = "myfidpass.auth.authProvider"
        static let appleUserIdentifier = "myfidpass.auth.appleUserIdentifier"
        static let authToken = "myfidpass.auth.authToken"
        static let currentBusinessSlug = "myfidpass.auth.currentBusinessSlug"
        /// `slug` → `dashboard_token` (GET login/me) pour l’en-tête `X-Dashboard-Token` sur les routes dashboard.
        static let dashboardTokensBySlug = "myfidpass.auth.dashboardTokensBySlug"
        /// Legacy : toujours `false` (paywall post-inscription supprimé). Conservé pour migration UserDefaults.
        static let pendingOpenMerchantSubscriptionSheetAfterSignup = "myfidpass.auth.pendingOpenMerchantSubscriptionSheetAfterSignup"
        /// Après inscription : lancer le tutoriel commerçant à l’accueil.
        static let pendingShowMerchantHomeTutorialAfterSignup = "myfidpass.auth.pendingShowMerchantHomeTutorialAfterSignup"
        /// Identifiant utilisateur API (`GET /me` → `user.id`).
        static let userId = "myfidpass.auth.userId"
        /// Dernier `MerchantWorkspaceRole` connu (affichage au cold start avant `GET /me`).
        static let merchantWorkspaceRole = "myfidpass.auth.merchantWorkspaceRole"
        /// Compte administrateur plateforme (`is_admin`) — évite d’afficher l’UI commerçant au cold start avant `/me`.
        static let isPlatformAdmin = "myfidpass.auth.isPlatformAdmin"
        /// Abonnement payant actif (Apple/Stripe) — relances onboarding locales (`NotificationsService`).
        static let merchantHasEncashedSubscription = "myfidpass.auth.merchantHasEncashedSubscription"
        /// Accès bench commerçant (combinaison plafonds scan) — app uniquement.
        static let merchantScanBenchAccessActive = "myfidpass.auth.merchantScanBenchAccessActive"
    }

    static var isLoggedIn: Bool {
        get { defaults.bool(forKey: Key.isLoggedIn) }
        set { defaults.set(newValue, forKey: Key.isLoggedIn) }
    }

    static var userEmail: String? {
        get { defaults.string(forKey: Key.userEmail) }
        set { defaults.set(newValue, forKey: Key.userEmail) }
    }

    /// Compte employé (connexion par identifiant sans e-mail).
    static var userStaffLogin: String? {
        get { defaults.string(forKey: Key.userStaffLogin) }
        set { defaults.set(newValue, forKey: Key.userStaffLogin) }
    }

    static var userPhone: String? {
        get { defaults.string(forKey: Key.userPhone) }
        set { defaults.set(newValue, forKey: Key.userPhone) }
    }

    /// Id utilisateur renvoyé par l’API (`GET /me`).
    static var userId: String? {
        get {
            let s = defaults.string(forKey: Key.userId)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return s.isEmpty ? nil : s
        }
        set {
            if let v = newValue?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty {
                defaults.set(v, forKey: Key.userId)
            } else {
                defaults.removeObject(forKey: Key.userId)
            }
        }
    }

    static var authProvider: AuthProvider {
        get {
            guard let raw = defaults.string(forKey: Key.authProvider),
                  let p = AuthProvider(rawValue: raw) else { return .email }
            return p
        }
        set { defaults.set(newValue.rawValue, forKey: Key.authProvider) }
    }

    static var appleUserIdentifier: String? {
        get { defaults.string(forKey: Key.appleUserIdentifier) }
        set { defaults.set(newValue, forKey: Key.appleUserIdentifier) }
    }

    /// Token JWT (Keychain ; migration automatique depuis UserDefaults).
    static var authToken: String? {
        get {
            if let k = SecureTokenStore.read(), !k.isEmpty { return k }
            if let legacy = defaults.string(forKey: Key.authToken), !legacy.isEmpty {
                SecureTokenStore.save(legacy)
                defaults.removeObject(forKey: Key.authToken)
                return legacy
            }
            return nil
        }
        set {
            if let v = newValue, !v.isEmpty {
                SecureTokenStore.save(v)
                defaults.removeObject(forKey: Key.authToken)
            } else {
                SecureTokenStore.delete()
                defaults.removeObject(forKey: Key.authToken)
            }
        }
    }

    /// Refresh token opaque (Keychain — rotation côté serveur à chaque usage).
    static var refreshToken: String? {
        get { SecureTokenStore.readRefresh() }
        set {
            if let v = newValue, !v.isEmpty {
                SecureTokenStore.saveRefresh(v)
            } else {
                SecureTokenStore.deleteRefresh()
            }
        }
    }

    /// Slug du commerce courant (pour les appels /api/businesses/:slug/...).
    static var currentBusinessSlug: String? {
        get { defaults.string(forKey: Key.currentBusinessSlug) }
        set { defaults.set(newValue, forKey: Key.currentBusinessSlug) }
    }

    /// Enregistre les jetons dashboard renvoyés par l’API (même contrôle d’accès que le JWT sur `.../dashboard/*`).
    static func mergeDashboardTokens(from businesses: [BusinessDTO]) {
        var dict = (defaults.dictionary(forKey: Key.dashboardTokensBySlug) as? [String: String]) ?? [:]
        for b in businesses {
            let slug = b.slug.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !slug.isEmpty else { continue }
            if let t = b.dashboardToken?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                dict[slug] = t
            }
        }
        defaults.set(dict, forKey: Key.dashboardTokensBySlug)
    }

    static func dashboardToken(forSlug slug: String) -> String? {
        let k = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return nil }
        return (defaults.dictionary(forKey: Key.dashboardTokensBySlug) as? [String: String])?[k]
    }

    /// Une fois à `true` après inscription réussie ; consommé par `ContentView` (paywall racine ou feuille).
    static var pendingOpenMerchantSubscriptionSheetAfterSignup: Bool {
        get { defaults.bool(forKey: Key.pendingOpenMerchantSubscriptionSheetAfterSignup) }
        set { defaults.set(newValue, forKey: Key.pendingOpenMerchantSubscriptionSheetAfterSignup) }
    }

    static var pendingShowMerchantHomeTutorialAfterSignup: Bool {
        get { defaults.bool(forKey: Key.pendingShowMerchantHomeTutorialAfterSignup) }
        set { defaults.set(newValue, forKey: Key.pendingShowMerchantHomeTutorialAfterSignup) }
    }

    static var merchantWorkspaceRoleRaw: String? {
        get { defaults.string(forKey: Key.merchantWorkspaceRole) }
        set {
            if let v = newValue, !v.isEmpty { defaults.set(v, forKey: Key.merchantWorkspaceRole) }
            else { defaults.removeObject(forKey: Key.merchantWorkspaceRole) }
        }
    }

    /// Reprise au tap sur une notif (AppDelegate) avant chargement d’`AuthService`.
    static var isCachedWorkspaceStaff: Bool { merchantWorkspaceRoleRaw == "staff" }

    static var isPlatformAdminFlag: Bool {
        get { defaults.bool(forKey: Key.isPlatformAdmin) }
        set { defaults.set(newValue, forKey: Key.isPlatformAdmin) }
    }

    /// Dernier état connu : commerçant a un abo payant encaissé (pas staff, pas essai gratuit seul).
    static var merchantHasEncashedSubscription: Bool {
        get { defaults.bool(forKey: Key.merchantHasEncashedSubscription) }
        set { defaults.set(newValue, forKey: Key.merchantHasEncashedSubscription) }
    }

    static var merchantScanBenchAccessActive: Bool {
        get { defaults.bool(forKey: Key.merchantScanBenchAccessActive) }
        set { defaults.set(newValue, forKey: Key.merchantScanBenchAccessActive) }
    }

    static func clearSession() {
        defaults.removeObject(forKey: Key.isLoggedIn)
        defaults.removeObject(forKey: Key.userEmail)
        defaults.removeObject(forKey: Key.userStaffLogin)
        defaults.removeObject(forKey: Key.userPhone)
        defaults.removeObject(forKey: Key.userId)
        defaults.removeObject(forKey: Key.authProvider)
        defaults.removeObject(forKey: Key.appleUserIdentifier)
        SecureTokenStore.delete()
        SecureTokenStore.deleteRefresh()
        defaults.removeObject(forKey: Key.authToken)
        defaults.removeObject(forKey: Key.currentBusinessSlug)
        defaults.removeObject(forKey: Key.dashboardTokensBySlug)
        defaults.removeObject(forKey: Key.pendingOpenMerchantSubscriptionSheetAfterSignup)
        defaults.removeObject(forKey: Key.pendingShowMerchantHomeTutorialAfterSignup)
        defaults.removeObject(forKey: Key.merchantWorkspaceRole)
        defaults.removeObject(forKey: Key.isPlatformAdmin)
        defaults.removeObject(forKey: Key.merchantHasEncashedSubscription)
        defaults.removeObject(forKey: Key.merchantScanBenchAccessActive)
        defaults.removeObject(forKey: "myfidpass.merchantHomeTutorial.v2")
        defaults.removeObject(forKey: "myfidpass.merchantHomeTutorial.v1")
    }
}
