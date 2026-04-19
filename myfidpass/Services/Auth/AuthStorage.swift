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
        static let userPhone = "myfidpass.auth.userPhone"
        static let authProvider = "myfidpass.auth.authProvider"
        static let appleUserIdentifier = "myfidpass.auth.appleUserIdentifier"
        static let authToken = "myfidpass.auth.authToken"
        static let currentBusinessSlug = "myfidpass.auth.currentBusinessSlug"
        /// `slug` → `dashboard_token` (GET login/me) pour l’en-tête `X-Dashboard-Token` sur les routes dashboard.
        static let dashboardTokensBySlug = "myfidpass.auth.dashboardTokensBySlug"
        /// Après `POST /api/auth/register` : ouvrir une fois la feuille d’abonnement à l’entrée dans l’app.
        static let pendingOpenMerchantSubscriptionSheetAfterSignup = "myfidpass.auth.pendingOpenMerchantSubscriptionSheetAfterSignup"
        /// Après `POST /api/auth/register` : autoriser le tutoriel d’accueil (spotlight) lorsque l’utilisateur arrive sur l’onglet Accueil.
        static let pendingShowMerchantHomeTutorialAfterSignup = "myfidpass.auth.pendingShowMerchantHomeTutorialAfterSignup"
        /// Identifiant utilisateur API (`GET /me` → `user.id`) — RevenueCat `logIn` (stable par compte).
        static let userId = "myfidpass.auth.userId"
    }

    static var isLoggedIn: Bool {
        get { defaults.bool(forKey: Key.isLoggedIn) }
        set { defaults.set(newValue, forKey: Key.isLoggedIn) }
    }

    static var userEmail: String? {
        get { defaults.string(forKey: Key.userEmail) }
        set { defaults.set(newValue, forKey: Key.userEmail) }
    }

    static var userPhone: String? {
        get { defaults.string(forKey: Key.userPhone) }
        set { defaults.set(newValue, forKey: Key.userPhone) }
    }

    /// Id utilisateur renvoyé par l’API (préféré pour RevenueCat `Purchases.logIn`).
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

    /// Identifiant stable pour RevenueCat : `userId` API sinon email en minuscules.
    static var revenueCatAppUserID: String? {
        if let id = userId { return id }
        if let em = userEmail?.trimmingCharacters(in: .whitespacesAndNewlines), !em.isEmpty {
            return em.lowercased()
        }
        return nil
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

    /// Une fois à `true` après inscription réussie ; consommé par `ContentView` à l’ouverture de la feuille Stripe.
    static var pendingOpenMerchantSubscriptionSheetAfterSignup: Bool {
        get { defaults.bool(forKey: Key.pendingOpenMerchantSubscriptionSheetAfterSignup) }
        set { defaults.set(newValue, forKey: Key.pendingOpenMerchantSubscriptionSheetAfterSignup) }
    }

    /// Une fois à `true` après inscription réussie ; consommé par `DashboardView` à la fin du tutoriel
    /// (spotlight « User-Tutorial-Screen »). Jamais activé pour un compte existant.
    static var pendingShowMerchantHomeTutorialAfterSignup: Bool {
        get { defaults.bool(forKey: Key.pendingShowMerchantHomeTutorialAfterSignup) }
        set { defaults.set(newValue, forKey: Key.pendingShowMerchantHomeTutorialAfterSignup) }
    }

    /// Clé `@AppStorage` partagée avec `DashboardView` et `OneTimeOnBoarding` — booléen « tutoriel vu ? ».
    /// Bumpée à `v2` pour re-déclencher le tutoriel sur tous les devices où la `v1` était coincée à `true`.
    static let merchantHomeTutorialCompletedKey = "myfidpass.merchantHomeTutorial.v2"

    /// Arme le tutoriel d’accueil pour la prochaine apparition (signup réussi) :
    /// - pose le flag « pending » consommé côté `DashboardView` ;
    /// - **remet à `false`** la clé AppStorage `merchantHomeTutorial.v2` pour qu’un compte déjà marqué
    ///   comme onboardé voie quand même le tutoriel sur un nouveau signup (sinon une seule complétion
    ///   historique désactive tout tutoriel futur, y compris après réinstallation si UserDefaults survit).
    static func armMerchantHomeTutorialAfterSignup() {
        defaults.set(true, forKey: Key.pendingShowMerchantHomeTutorialAfterSignup)
        defaults.set(false, forKey: merchantHomeTutorialCompletedKey)
    }

    static func clearSession() {
        defaults.removeObject(forKey: Key.isLoggedIn)
        defaults.removeObject(forKey: Key.userEmail)
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
        // Déconnexion : ré-autoriser le tutoriel pour un futur signup/connexion depuis ce device.
        defaults.removeObject(forKey: merchantHomeTutorialCompletedKey)
        // On nettoie aussi l'ancienne clé v1 au cas où pour éviter toute confusion.
        defaults.removeObject(forKey: "myfidpass.merchantHomeTutorial.v1")
    }
}
