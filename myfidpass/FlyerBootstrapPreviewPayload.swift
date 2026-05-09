//
//  FlyerBootstrapPreviewPayload.swift
//  myfidpass
//
//  JSON d’aperçu flyer (embed) partagé entre l’éditeur et la checklist Commerce.
//

import Foundation

// MARK: - Roue : même logique d’aperçu `png` (texture) partout (éditeur, Commerce, cache disque)

/// Ajuste l’état pour l’embed web : la texture **spinflyer** n’est peinte que si `wheelRenderMode === "png"`.
/// (voir `app-flyer-qr-draw` / `t.wheelRenderMode === "png"` sur myfidpass.fr)
enum FlyerWheelWebEmbedPreviewMigration {
    static func normalizedStateForPreview(_ state: FlyerStateDTO, businessSlug: String) -> FlyerStateDTO {
        _ = businessSlug
        var s = state
        s.normalizeClamps()
        s.wheelRenderMode = "png"
        return s
    }
}

/// Même JSON que l’aperçu studio (`flyer-embed`), clé `flyer_prefs` alignée sur le GET dashboard.
struct FlyerBootstrapPreviewPayload: Encodable {
    let flyerPrefs: Inner
    let updatedAt: String?
    let shareUrl: String
    /// Marqueur local uniquement : présent (`true`) quand le fond est affiché en `UIImage` natif sous la WebView.
    /// Ignoré par le JS (`_nbg` n’est pas lu par `app-flyer-qr-draw`), mais change le base64 du bootstrap
    /// quand le fond passe de absent → présent, forçant une ré-injection complète du canvas (canvas cleared + redrawn).
    let nativeBgActive: Bool?

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

    init(flyerPrefs: Inner, updatedAt: String?, shareUrl: String, nativeBgActive: Bool? = nil) {
        self.flyerPrefs = flyerPrefs
        self.updatedAt = updatedAt
        self.shareUrl = shareUrl
        self.nativeBgActive = nativeBgActive
    }

    enum CodingKeys: String, CodingKey {
        case flyerPrefs = "flyer_prefs"
        case updatedAt = "updated_at"
        case shareUrl = "share_url"
        case nativeBgActive = "_nbg"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(flyerPrefs, forKey: .flyerPrefs)
        try c.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try c.encode(shareUrl, forKey: .shareUrl)
        try c.encodeIfPresent(nativeBgActive, forKey: .nativeBgActive)
    }
}

enum FlyerBootstrapPreviewPayloadBuilder {
    /// Découpe l’`état` flyer depuis un bootstrap base64 (calques natifs : dégradé + photo, même logique que l’embed).
    static func flyerStateFromBootstrapBase64(_ b64: String) -> FlyerStateDTO? {
        let trimmed = b64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: trimmed),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fp = root["flyer_prefs"] as? [String: Any],
              let stObj = fp["state"] else { return nil }
        do {
            let stateData = try JSONSerialization.data(withJSONObject: stObj)
            let dec = JSONDecoder()
            dec.keyDecodingStrategy = .convertFromSnakeCase
            var st = try dec.decode(FlyerStateDTO.self, from: stateData)
            st.normalizeClamps()
            return st
        } catch {
            return nil
        }
    }

    /// Extrait `custom_bg_data_url` depuis un bootstrap base64 quand le champ cache séparé est absent.
    static func customBgDataURLFromBootstrapBase64(_ b64: String) -> String? {
        let trimmed = b64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: trimmed),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fp = root["flyer_prefs"] as? [String: Any],
              let raw = fp["custom_bg_data_url"] as? String else { return nil }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    static func updatedAtFromBootstrapBase64(_ b64: String?) -> String? {
        let trimmed = b64?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty,
              let data = Data(base64Encoded: trimmed),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = root["updated_at"] as? String
        else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// Met à jour uniquement le mode de rendu roue dans un bootstrap existant (cache disque) pour matcher l’éditeur.
    static func normalizeWheelModeInBootstrapBase64(_ b64: String?, businessSlug: String) -> String? {
        let slug = businessSlug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slug.isEmpty else { return b64 }
        let t = b64?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !t.isEmpty, let data = Data(base64Encoded: t) else { return b64 }
        guard var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var fp = root["flyer_prefs"] as? [String: Any],
              let stObj = fp["state"] else { return b64 }
        var state: FlyerStateDTO
        do {
            let stateData = try JSONSerialization.data(withJSONObject: stObj)
            let dec = JSONDecoder()
            dec.keyDecodingStrategy = .convertFromSnakeCase
            state = try dec.decode(FlyerStateDTO.self, from: stateData)
        } catch {
            return b64
        }
        let before = state.wheelRenderMode
        state = FlyerWheelWebEmbedPreviewMigration.normalizedStateForPreview(state, businessSlug: slug)
        guard before != state.wheelRenderMode else { return b64 }
        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .useDefaultKeys
        guard let stData = try? enc.encode(state),
              let stNew = try? JSONSerialization.jsonObject(with: stData) else { return b64 }
        fp["state"] = stNew
        root["flyer_prefs"] = fp
        guard let out = try? JSONSerialization.data(withJSONObject: root) else { return b64 }
        return out.base64EncodedString()
    }

    /// Bootstrap base64 pour `FlyerPreviewWebView` (composite : roue, QR, textes — pas seulement le fond IA).
    /// - Parameter fallbackStateIfMissing: quand le GET omet `flyer_prefs.state` (JSON partiel / sync), réutiliser l’état
    ///   du dernier bootstrap disque au lieu de `FlyerStateDTO.default` — sinon un `loadProfileFromServer` écrase le cache
    ///   Commerce avec le gabarit par défaut (couleurs roue / bandeau / CADEAU perdues à la réouverture du flyer).
    static func base64(from response: DashboardFlyerGetResponse, businessSlug: String, fallbackStateIfMissing: FlyerStateDTO? = nil) -> String? {
        guard let fp = response.flyerPrefs else { return nil }
        let slug = businessSlug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slug.isEmpty else { return nil }
        let state: FlyerStateDTO
        if let s = fp.state {
            var merged = s
            merged.normalizeClamps()
            state = FlyerWheelWebEmbedPreviewMigration.normalizedStateForPreview(merged, businessSlug: slug)
        } else if let fb = fallbackStateIfMissing {
            var merged = fb
            merged.normalizeClamps()
            state = FlyerWheelWebEmbedPreviewMigration.normalizedStateForPreview(merged, businessSlug: slug)
        } else {
            state = FlyerWheelWebEmbedPreviewMigration.normalizedStateForPreview(FlyerStateDTO.default, businessSlug: slug)
        }
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
        /// Même règle que l’injection `WKWebView` : l’objet `state` doit rester en camelCase pour
        /// `r.wheelRenderMode` côté `app-flyer-qr-draw.js` (myfidpass.fr).
        enc.keyEncodingStrategy = .useDefaultKeys
        guard let data = try? enc.encode(payload) else { return nil }
        return data.base64EncodedString()
    }
}
