//
//  CampaignNotificationImageCache.swift
//  myfidpass
//
//  Icône **uniquement** pour l’aperçu campagne / push (`GET .../notification-icon`).
//  Ne doit pas être mélangé aux caches `MerchantLogoAssetCache` (carte & fiche).
//

import Foundation

enum CampaignNotificationImageCache {
    /// Clé legacy (ancienne version globale, sans slug) conservée pour compat.
    private static let legacyPreviewCompositeServerBustKey = "myfidpass.campaignNotificationPreviewCompositeBust"
    private static let previewCompositeServerBustPrefix = "myfidpass.campaignNotificationPreviewCompositeBust."
    private static let localUploadBustPrefix = "myfidpass.campaignNotificationLocalUploadBust."

    private static func normalizedSlug(_ slug: String) -> String {
        slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func serverBustKey(for slug: String) -> String {
        previewCompositeServerBustPrefix + normalizedSlug(slug)
    }

    private static func localUploadBustKey(for slug: String) -> String {
        localUploadBustPrefix + normalizedSlug(slug)
    }

    static func applyPreviewTimestamps(from settings: BusinessSettingsResponse, slug: String) {
        let scopedServerKey = serverBustKey(for: slug)
        let dates = [parseISO8601(settings.notificationIconUpdatedAt)].compactMap { $0 }
        if let maxDate = dates.max() {
            UserDefaults.standard.set(maxDate, forKey: scopedServerKey)
        } else if settings.notificationIconUrl != nil, !(settings.notificationIconUrl ?? "").isEmpty {
            // Au moins un ?v= pour invalider URLCache si le serveur renvoie une date non ISO parseable.
            UserDefaults.standard.set(Date(), forKey: scopedServerKey)
        }
    }

    static func markLocalUploadNow(slug: String) {
        UserDefaults.standard.set(Date(), forKey: localUploadBustKey(for: slug))
    }

    static func bestBustDate(for slug: String) -> Date? {
        let scopedServer = UserDefaults.standard.object(forKey: serverBustKey(for: slug)) as? Date
        let scopedLocal = UserDefaults.standard.object(forKey: localUploadBustKey(for: slug)) as? Date
        let legacyServer = UserDefaults.standard.object(forKey: legacyPreviewCompositeServerBustKey) as? Date
        return [scopedServer, scopedLocal, legacyServer].compactMap { $0 }.max()
    }

    private static func parseISO8601(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }
}
