//
//  FlyerCommerceRecreateOnceGuard.swift
//  myfidpass
//
//  « Recréer » depuis l’aperçu plein écran Commerce : une seule session de formulaire vierge par commerce
//  (aligné sur le texte produit « une seule régénération gratuite »). Persistance locale.
//

import Foundation

enum FlyerCommerceRecreateOnceGuard {
    private static let prefix = "fr.myfidpass.flyerCommerceRecreateConsumed."

    private static func storageKey(slug: String) -> String {
        let s = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        return prefix + s
    }

    static func hasConsumedRegenerateSession(slug: String) -> Bool {
        let s = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return false }
        return UserDefaults.standard.bool(forKey: storageKey(slug: s))
    }

    /// Appeler une fois la session « reset formulaire » depuis Commerce a mené à une **génération IA lancée** (crédit engagé).
    static func markRegenerateSessionConsumed(slug: String) {
        let s = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        UserDefaults.standard.set(true, forKey: storageKey(slug: s))
    }

    /// Résultat d’une génération lancée depuis le parcours « Recréer » Commerce (job en file ou reprise) : sert à marquer
    /// `markRegenerateSessionConsumed` à la réception de l’image, même si l’app a été tuée (état @State perdu).
    private static let pendingResultPrefix = "fr.myfidpass.flyerCommerceRecreateResultPendingForSlug."

    private static func pendingResultKey(slug: String) -> String {
        pendingResultPrefix + slug.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isPendingResultCompletion(slug: String) -> Bool {
        let s = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return false }
        return UserDefaults.standard.bool(forKey: pendingResultKey(slug: s))
    }

    static func setPendingResultCompletion(slug: String, _ pending: Bool) {
        let s = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        UserDefaults.standard.set(pending, forKey: pendingResultKey(slug: s))
    }
}
