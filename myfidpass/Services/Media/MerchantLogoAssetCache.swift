//
//  MerchantLogoAssetCache.swift
//  myfidpass
//
//  Cache-bust (`?v=`) pour les logos **commerce** : bandeau carte (`/logo`) et logo carré fiche (`/logo-icon`).
//  Indépendant de l’icône campagnes / notification (`CampaignNotificationImageCache`).
//  Horodatages **par slug** pour ne pas invalider le mauvais commerce en multi-compte.
//

import Foundation

enum MerchantLogoAssetCache {
    private static func logoServerDateKey(for slug: String) -> String {
        "myfidpass.merchantLogoStripeServerCacheDate.\(slug)"
    }

    private static func logoIconServerDateKey(for slug: String) -> String {
        "myfidpass.merchantLogoIconServerCacheDate.\(slug)"
    }

    /// Après GET `dashboard/settings` ou sync : met à jour les timestamps pour invalider URLCache / mémoire.
    static func applyMerchantLogoTimestamps(from settings: BusinessSettingsResponse, slug: String) {
        let s = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        if let d = parseISO8601(settings.logoIconUpdatedAt) {
            UserDefaults.standard.set(d, forKey: logoIconServerDateKey(for: s))
        }
        if let d = parseISO8601(settings.logoUpdatedAt) {
            UserDefaults.standard.set(d, forKey: logoServerDateKey(for: s))
        }
    }

    private static func parseISO8601(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }

    /// URL d’affichage pour le bandeau carte (`GET …/logo`) : même `?v=` que `BusinessLogoView` / profil.
    static func stripeLogoDisplayURL(_ url: URL, slug: String) -> URL {
        let s = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        var c = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let serverAt = s.isEmpty ? nil : UserDefaults.standard.object(forKey: logoServerDateKey(for: s)) as? Date
        let localAt = s.isEmpty ? nil : MerchantMediaUploadOwnership.lastLogoUploadDate(for: s)
        if let d = [serverAt, localAt].compactMap({ $0 }).max() {
            c?.queryItems = [URLQueryItem(name: "v", value: String(Int(d.timeIntervalSince1970)))]
        }
        return c?.url ?? url
    }

    /// URL d’affichage pour le logo carré fiche (`GET …/logo-icon`).
    static func logoIconDisplayURL(_ url: URL, slug: String) -> URL {
        let s = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        var c = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let serverAt = s.isEmpty ? nil : UserDefaults.standard.object(forKey: logoIconServerDateKey(for: s)) as? Date
        let localAt = s.isEmpty ? nil : MerchantMediaUploadOwnership.lastLogoIconUploadDate(for: s)
        if let d = [serverAt, localAt].compactMap({ $0 }).max() {
            c?.queryItems = [URLQueryItem(name: "v", value: String(Int(d.timeIntervalSince1970)))]
        }
        return c?.url ?? url
    }

    /// Rétrocompat : sans slug explicite, tente le commerce actif.
    static func stripeLogoDisplayURL(_ url: URL) -> URL {
        let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stripeLogoDisplayURL(url, slug: slug)
    }

    static func logoIconDisplayURL(_ url: URL) -> URL {
        let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return logoIconDisplayURL(url, slug: slug)
    }
}
