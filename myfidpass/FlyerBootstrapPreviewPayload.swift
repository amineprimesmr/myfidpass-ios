//
//  FlyerBootstrapPreviewPayload.swift
//  myfidpass
//
//  JSON d’aperçu flyer (embed) partagé entre l’éditeur et la checklist Commerce.
//

import Foundation

/// Même JSON que l’aperçu studio (`flyer-embed`), clé `flyer_prefs` alignée sur le GET dashboard.
struct FlyerBootstrapPreviewPayload: Encodable {
    let flyerPrefs: Inner
    let updatedAt: String?
    let shareUrl: String

    struct Inner: Encodable {
        let state: FlyerStateDTO
        let customLogoDataUrl: String?
        let customBgDataUrl: String?
        let businessSlug: String

        enum CodingKeys: String, CodingKey {
            case state
            case customLogoDataUrl = "custom_logo_data_url"
            case customBgDataUrl = "custom_bg_data_url"
            case businessSlug = "business_slug"
        }
    }

    enum CodingKeys: String, CodingKey {
        case flyerPrefs = "flyer_prefs"
        case updatedAt = "updated_at"
        case shareUrl = "share_url"
    }
}

enum FlyerBootstrapPreviewPayloadBuilder {
    /// Bootstrap base64 pour `FlyerPreviewWebView` (composite : roue, QR, textes — pas seulement le fond IA).
    static func base64(from response: DashboardFlyerGetResponse, businessSlug: String) -> String? {
        guard let fp = response.flyerPrefs else { return nil }
        /// Anciens comptes / JSON partiel : sans `state` explicite on reprend le défaut (sinon checklist Commerce sans aperçu composite).
        var state = fp.state ?? FlyerStateDTO.default
        state.normalizeClamps()
        let slug = businessSlug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slug.isEmpty else { return nil }
        let share = (response.shareUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        /// `updated_at` exclu : sinon chaque sync change le base64 → la checklist Commerce relance WebView + décodage fond (flash / rechargement).
        let payload = FlyerBootstrapPreviewPayload(
            flyerPrefs: .init(
                state: state,
                customLogoDataUrl: fp.customLogoDataUrl,
                customBgDataUrl: fp.customBgDataUrl,
                businessSlug: slug
            ),
            updatedAt: nil,
            shareUrl: share
        )
        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .useDefaultKeys
        guard let data = try? enc.encode(payload) else { return nil }
        return data.base64EncodedString()
    }
}
