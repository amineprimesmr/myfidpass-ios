//
//  SecureTokenStore.swift
//  myfidpass
//
//  Stockage du JWT dans le Keychain (migration depuis UserDefaults au premier accès).
//
//  PERF : cache mémoire des tokens pour éviter un `SecItemCopyMatching` à CHAQUE requête API.
//         Sur un sync iOS standard (~15 requêtes), c'était ~30-50 ms perdus en Keychain.
//         Le cache reste cohérent car toutes les écritures passent par `save*` / `delete*`.
//

import Foundation
import Security
import os.lock

enum SecureTokenStore {
    private static let service = "fr.myfidpass.auth"
    private static let account = "jwt"
    private static let refreshAccount = "jwt_refresh"

    /// Verrou de cache (lock léger plutôt qu'un actor : on est appelé depuis n'importe quel thread sync).
    private static var cacheLock = os_unfair_lock_s()
    /// `nil` = pas encore chargé depuis le Keychain ; `Optional.some(nil)` = chargé et absent.
    private static var cachedAccess: String?? = nil
    private static var cachedRefresh: String?? = nil

    static func save(_ token: String) {
        saveItem(token, account: account)
        os_unfair_lock_lock(&cacheLock)
        cachedAccess = .some(token)
        os_unfair_lock_unlock(&cacheLock)
    }

    static func read() -> String? {
        os_unfair_lock_lock(&cacheLock)
        if let cached = cachedAccess {
            os_unfair_lock_unlock(&cacheLock)
            return cached
        }
        os_unfair_lock_unlock(&cacheLock)
        let fresh = readItem(account: account)
        os_unfair_lock_lock(&cacheLock)
        cachedAccess = .some(fresh)
        os_unfair_lock_unlock(&cacheLock)
        return fresh
    }

    static func delete() {
        deleteItem(account: account)
        os_unfair_lock_lock(&cacheLock)
        cachedAccess = .some(nil)
        os_unfair_lock_unlock(&cacheLock)
    }

    static func saveRefresh(_ token: String) {
        saveItem(token, account: refreshAccount)
        os_unfair_lock_lock(&cacheLock)
        cachedRefresh = .some(token)
        os_unfair_lock_unlock(&cacheLock)
    }

    static func readRefresh() -> String? {
        os_unfair_lock_lock(&cacheLock)
        if let cached = cachedRefresh {
            os_unfair_lock_unlock(&cacheLock)
            return cached
        }
        os_unfair_lock_unlock(&cacheLock)
        let fresh = readItem(account: refreshAccount)
        os_unfair_lock_lock(&cacheLock)
        cachedRefresh = .some(fresh)
        os_unfair_lock_unlock(&cacheLock)
        return fresh
    }

    static func deleteRefresh() {
        deleteItem(account: refreshAccount)
        os_unfair_lock_lock(&cacheLock)
        cachedRefresh = .some(nil)
        os_unfair_lock_unlock(&cacheLock)
    }

    /// À appeler en cas de doute (ex. import depuis UserDefaults legacy, restauration backup) :
    /// force la prochaine lecture à rejoindre le Keychain.
    static func invalidateCache() {
        os_unfair_lock_lock(&cacheLock)
        cachedAccess = nil
        cachedRefresh = nil
        os_unfair_lock_unlock(&cacheLock)
    }

    private static func saveItem(_ token: String, account: String) {
        deleteItem(account: account)
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            assertionFailure("Keychain write failed: \(status)")
        }
    }

    private static func readItem(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (s?.isEmpty == false) ? s : nil
    }

    private static func deleteItem(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
