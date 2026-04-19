//
//  ScanFlowSettingsCache.swift
//  myfidpass
//
//  Cache léger des réglages commerce pour le flux scan : 2ᵉ scan+ ne refait pas GET settings (lookup seul).
//  TTL de 5 minutes : si le commerçant modifie ses règles côté API, l'app voit les nouvelles valeurs
//  au prochain cycle de 5 min plutôt qu'au prochain redémarrage.
//

import Foundation

enum ScanFlowSettingsCache {

    /// Durée de validité d'une entrée en cache.
    private static let ttl: TimeInterval = 5 * 60 // 5 minutes

    private struct CachedEntry {
        let value: BusinessSettingsResponse
        let expiresAt: Date
    }

    private static var storage: [String: CachedEntry] = [:]
    private static let lock = NSLock()

    /// Retourne les settings en cache si présents ET non expirés, sinon `nil`.
    static func cached(for slug: String) -> BusinessSettingsResponse? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = storage[slug] else { return nil }
        if Date() > entry.expiresAt {
            // Expirée : on nettoie immédiatement
            storage.removeValue(forKey: slug)
            return nil
        }
        return entry.value
    }

    /// Stocke les settings avec un TTL de 5 minutes.
    static func store(_ settings: BusinessSettingsResponse, for slug: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[slug] = CachedEntry(value: settings, expiresAt: Date().addingTimeInterval(ttl))
    }

    /// Invalide immédiatement le cache d'un commerce (ex. changement de commerce actif).
    static func clear(for slug: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: slug)
    }

    /// Invalide tout le cache (ex. déconnexion, switch de compte).
    static func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll(keepingCapacity: false)
    }
}
