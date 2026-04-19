//
//  SecureTokenStore.swift
//  myfidpass
//
//  Stockage du JWT dans le Keychain (migration depuis UserDefaults au premier accès).
//

import Foundation
import Security

enum SecureTokenStore {
    private static let service = "fr.myfidpass.auth"
    private static let account = "jwt"
    private static let refreshAccount = "jwt_refresh"

    static func save(_ token: String) {
        saveItem(token, account: account)
    }

    static func read() -> String? {
        readItem(account: account)
    }

    static func delete() {
        deleteItem(account: account)
    }

    static func saveRefresh(_ token: String) {
        saveItem(token, account: refreshAccount)
    }

    static func readRefresh() -> String? {
        readItem(account: refreshAccount)
    }

    static func deleteRefresh() {
        deleteItem(account: refreshAccount)
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
        SecItemAdd(query as CFDictionary, nil)
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
