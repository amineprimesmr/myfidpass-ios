//
//  MerchantLogoAssetCache.swift
//  myfidpass
//
//  Cache-bust (`?v=`) pour les logos **commerce** : bandeau carte (`/logo`) et logo carré fiche (`/logo-icon`).
//  Indépendant de l’icône campagnes / notification (`CampaignNotificationImageCache`).
//

import Foundation

enum MerchantLogoAssetCache {
    static let logoServerDateKey = "myfidpass.merchantLogoStripeServerCacheDate"
    static let logoIconServerDateKey = "myfidpass.merchantLogoIconServerCacheDate"
    /// Même clé que `SyncService.lastLogoUploadAtKey` (évite une référence à une propriété `@MainActor` depuis ce type non isolé).
    private static let lastLogoUploadAtDefaultsKey = "myfidpass.lastLogoUploadAt"

    /// Après GET `dashboard/settings` ou sync : met à jour les timestamps pour invalider URLCache / mémoire.
    static func applyMerchantLogoTimestamps(from settings: BusinessSettingsResponse) {
        if let d = parseISO8601(settings.logoIconUpdatedAt) {
            UserDefaults.standard.set(d, forKey: logoIconServerDateKey)
        }
        if let d = parseISO8601(settings.logoUpdatedAt) {
            UserDefaults.standard.set(d, forKey: logoServerDateKey)
        }
    }

    private static func parseISO8601(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }

    /// URL d’affichage pour le bandeau carte (`GET …/logo`) : même `?v=` que `BusinessLogoView` / profil.
    static func stripeLogoDisplayURL(_ url: URL) -> URL {
        var c = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let serverAt = UserDefaults.standard.object(forKey: logoServerDateKey) as? Date
        let localAt = UserDefaults.standard.object(forKey: lastLogoUploadAtDefaultsKey) as? Date
        if let d = [serverAt, localAt].compactMap({ $0 }).max() {
            c?.queryItems = [URLQueryItem(name: "v", value: String(Int(d.timeIntervalSince1970)))]
        }
        return c?.url ?? url
    }
}
