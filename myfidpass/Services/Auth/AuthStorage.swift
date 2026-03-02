//
//  AuthStorage.swift
//  myfidpass
//
//  Persistance locale du statut d’authentification (UserDefaults).
//  Prêt pour migration vers Keychain pour le token plus tard.
//

import Foundation

enum AuthProvider: String, Codable {
    case email
    case apple
    case google
}

enum AuthStorage {
    private static let defaults = UserDefaults.standard

    enum Key {
        static let isLoggedIn = "myfidpass.auth.isLoggedIn"
        static let userEmail = "myfidpass.auth.userEmail"
        static let authProvider = "myfidpass.auth.authProvider"
        static let appleUserIdentifier = "myfidpass.auth.appleUserIdentifier"
        static let authToken = "myfidpass.auth.authToken"
        static let currentBusinessSlug = "myfidpass.auth.currentBusinessSlug"
    }

    static var isLoggedIn: Bool {
        get { defaults.bool(forKey: Key.isLoggedIn) }
        set { defaults.set(newValue, forKey: Key.isLoggedIn) }
    }

    static var userEmail: String? {
        get { defaults.string(forKey: Key.userEmail) }
        set { defaults.set(newValue, forKey: Key.userEmail) }
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

    /// Token JWT ou session pour les appels API (Bearer).
    static var authToken: String? {
        get { defaults.string(forKey: Key.authToken) }
        set { defaults.set(newValue, forKey: Key.authToken) }
    }

    /// Slug du commerce courant (pour les appels /api/businesses/:slug/...).
    static var currentBusinessSlug: String? {
        get { defaults.string(forKey: Key.currentBusinessSlug) }
        set { defaults.set(newValue, forKey: Key.currentBusinessSlug) }
    }

    static func clearSession() {
        defaults.removeObject(forKey: Key.isLoggedIn)
        defaults.removeObject(forKey: Key.userEmail)
        defaults.removeObject(forKey: Key.authProvider)
        defaults.removeObject(forKey: Key.appleUserIdentifier)
        defaults.removeObject(forKey: Key.authToken)
        defaults.removeObject(forKey: Key.currentBusinessSlug)
    }
}
