//
//  MerchantLinkedPlaceCache.swift
//  myfidpass
//
//  Conserve le lieu Google (Place ID + libellé) choisi à l’onboarding pour préremplir les avis Google
//  sans resaisie — les clés `myfidpass.ob.*` sont effacées après auth.
//

import Foundation

enum MerchantLinkedPlaceCache {
    private static let placeIdKey = "myfidpass.merchant.linkedGooglePlaceId"
    private static let descriptionKey = "myfidpass.merchant.linkedGooglePlaceDescription"

    static func save(placeId: String, description: String?) {
        let pid = placeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty else { return }
        let d = UserDefaults.standard
        d.set(pid, forKey: placeIdKey)
        if let desc = description?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
            d.set(desc, forKey: descriptionKey)
        }
    }

    static func read() -> (placeId: String?, description: String?) {
        let d = UserDefaults.standard
        let rawId = d.string(forKey: placeIdKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let pid = rawId.isEmpty ? nil : rawId
        let desc = d.string(forKey: descriptionKey)
        return (pid, desc)
    }

    static func clear() {
        let d = UserDefaults.standard
        d.removeObject(forKey: placeIdKey)
        d.removeObject(forKey: descriptionKey)
    }

    /// Copie le lieu encore en attente d’inscription avant `clearPendingEstablishmentFromOnboarding()`.
    static func snapshotFromPendingOnboarding() {
        let p = FirstLaunchOnboarding.readPendingEstablishment()
        if let pid = p.placeId?.trimmingCharacters(in: .whitespacesAndNewlines), !pid.isEmpty {
            save(placeId: pid, description: p.description)
        }
    }
}
