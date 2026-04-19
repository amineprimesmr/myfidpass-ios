//
//  CampaignNotificationImageCache.swift
//  myfidpass
//
//  Icône **uniquement** pour l’aperçu campagne / push (`GET .../notification-icon`).
//  Ne doit pas être mélangé aux caches `MerchantLogoAssetCache` (carte & fiche).
//

import Foundation

enum CampaignNotificationImageCache {
    /// Cache-bust pour `GET …/notification-icon` — **uniquement** `notification_icon` (indépendant des logos Ma Carte).
    static let previewCompositeServerBustKey = "myfidpass.campaignNotificationPreviewCompositeBust"

    static func applyPreviewTimestamps(from settings: BusinessSettingsResponse) {
        let dates = [parseISO8601(settings.notificationIconUpdatedAt)].compactMap { $0 }
        if let maxDate = dates.max() {
            UserDefaults.standard.set(maxDate, forKey: previewCompositeServerBustKey)
        } else if settings.notificationIconUrl != nil, !(settings.notificationIconUrl ?? "").isEmpty {
            // Au moins un ?v= pour invalider URLCache si le serveur renvoie une date non ISO parseable.
            UserDefaults.standard.set(Date(), forKey: previewCompositeServerBustKey)
        }
    }

    private static func parseISO8601(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }
}
