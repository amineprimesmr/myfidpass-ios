//
//  APIDTOs+16_GET.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

// MARK: - GET/PUT .../dashboard/flyer (flyer QR, sync SaaS)

struct DashboardFlyerGetResponse: Decodable {
    let flyerPrefs: FlyerPrefsStored?
    let updatedAt: String?
    let shareUrl: String?
    /// Challenge pronostics activé — bandeau flyer Coupe du monde côté canvas.
    let matchPredictionsEnabled: Bool?
    /// Générations flyer IA déjà consommées sur le mois UTC courant.
    let flyerAiGenerationsUsed: Int?
    /// `nil` si créations illimitées côté API.
    let flyerAiGenerationsRemaining: Int?
    let flyerAiUnlimited: Bool?
    let flyerAiBillingMonth: String?

    init(
        flyerPrefs: FlyerPrefsStored?,
        updatedAt: String?,
        shareUrl: String?,
        matchPredictionsEnabled: Bool?,
        flyerAiGenerationsUsed: Int?,
        flyerAiGenerationsRemaining: Int?,
        flyerAiUnlimited: Bool?,
        flyerAiBillingMonth: String?
    ) {
        self.flyerPrefs = flyerPrefs
        self.updatedAt = updatedAt
        self.shareUrl = shareUrl
        self.matchPredictionsEnabled = matchPredictionsEnabled
        self.flyerAiGenerationsUsed = flyerAiGenerationsUsed
        self.flyerAiGenerationsRemaining = flyerAiGenerationsRemaining
        self.flyerAiUnlimited = flyerAiUnlimited
        self.flyerAiBillingMonth = flyerAiBillingMonth
    }

    /// Conformité `Decodable` pour `APIClient.request` ; le décodage réel passe par `decodeFromJSON` (état flyer camelCase).
    init(from decoder: Decoder) throws {
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "DashboardFlyerGetResponse : utiliser APIClient.request (decodeFromJSON)."
            )
        )
    }

    /// GET dashboard flyer : `state` est toujours en **camelCase** (canvas web / PUT app).
    /// `JSONDecoder.convertFromSnakeCase` (APIClient global) ne peut pas décoder `wheelColorOdd` → défauts gris/noir.
    static func decodeFromJSON(_ data: Data) throws -> DashboardFlyerGetResponse {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Réponse flyer invalide.")
            )
        }
        let flyerPrefs: FlyerPrefsStored?
        if let fp = root["flyer_prefs"] as? [String: Any] {
            let state: FlyerStateDTO?
            if let stObj = fp["state"] {
                state = FlyerStateDTO.decodeFromJSONObject(stObj)
            } else {
                state = nil
            }
            flyerPrefs = FlyerPrefsStored(
                state: state,
                customLogoDataUrl: fp["custom_logo_data_url"] as? String,
                customBgDataUrl: fp["custom_bg_data_url"] as? String
            )
        } else {
            flyerPrefs = nil
        }
        func intVal(_ key: String) -> Int? {
            let v = root[key]
            if let i = v as? Int { return i }
            if let d = v as? Double { return Int(d) }
            if let s = v as? String, let i = Int(s) { return i }
            return nil
        }
        func boolVal(_ key: String) -> Bool? {
            let v = root[key]
            if let b = v as? Bool { return b }
            if let i = v as? Int { return i != 0 }
            if let s = v as? String {
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if t == "true" || t == "1" { return true }
                if t == "false" || t == "0" { return false }
            }
            return nil
        }
        return DashboardFlyerGetResponse(
            flyerPrefs: flyerPrefs,
            updatedAt: root["updated_at"] as? String,
            shareUrl: root["share_url"] as? String,
            matchPredictionsEnabled: boolVal("match_predictions_enabled"),
            flyerAiGenerationsUsed: intVal("flyer_ai_generations_used"),
            flyerAiGenerationsRemaining: intVal("flyer_ai_generations_remaining"),
            flyerAiUnlimited: boolVal("flyer_ai_unlimited"),
            flyerAiBillingMonth: root["flyer_ai_billing_month"] as? String
        )
    }
}

/// Objet stocké en base (`flyer_prefs_json`) : `state` + images data URL optionnelles.
struct FlyerPrefsStored {
    let state: FlyerStateDTO?
    let customLogoDataUrl: String?
    let customBgDataUrl: String?
}

struct FlyerPutAPIResponse: Decodable {
    let ok: Bool?
    let updatedAt: String?
}

struct FlyerRemoveLogoBgRequestBody: Encodable {
    let imageDataUrl: String

    enum CodingKeys: String, CodingKey {
        case imageDataUrl = "image_data_url"
    }
}

/// Réponse `POST …/dashboard/flyer/remove-logo-background` (rembg / secours remove.bg — `ok` peut être false sans erreur HTTP).
struct FlyerRemoveLogoBgResponse: Decodable {
    let ok: Bool
    let pngDataUrl: String?
    let code: String?
    let message: String?
}

/// État canvas flyer (mêmes clés que `app-flyer-qr-presets.js` / mergeFlyerState).
struct FlyerStateDTO: Codable, Equatable {
    var templateId: String
    var headline: String
    var ctaBanner: String
    /// Fond de la pastille « Scanne pour jouer » (#RRGGBB).
    var ctaBannerBgColor: String
    /// Texte de la pastille CTA (contraste sur `ctaBannerBgColor`).
    var ctaTextColor: String
    var step1: String
    var step2: String
    var step3: String
    var social1: String
    var socialUrl1: String
    var social2: String
    var socialUrl2: String
    var social3: String
    var socialUrl3: String
    var colorPrimary: String
    var colorSecondary: String
    var colorAccent: String
    var colorBgTop: String
    var colorBgBottom: String
    var wheelRenderMode: String
    var wheelColorOdd: String
    var wheelColorEven: String
    var wheelSegmentOffsetDeg: Double
    var headlineFontId: String
    var headlineTextColor: String
    var headlineStrokeColor: String
    /// Contour du mot « CADEAU » (remplissage = `ctaBannerBgColor` côté canvas web).
    var headlineGiftStrokeColor: String
    var headlineStrokeWidth: Double
    var headlineLogoGapPct: Double
    var headlineLetterSpacing: Double
    var headlineSizePct: Double
    var flyerFooterTextScalePct: Double
    var flyerWheelLabelScalePct: Double
    var flyerBgOverlayPct: Double
    var flyerQrOutlineWidth: Double
    /// Centre vertical du logo (fraction de la hauteur du flyer, ~0.04–0.22).
    var flyerLogoCenterYFrac: Double
    /// Largeur max du logo / largeur canvas (~0.28–0.88).
    var flyerLogoMaxWFrac: Double
    /// Hauteur max du logo / hauteur canvas (~0.06–0.36).
    var flyerLogoMaxHFrac: Double
    /// Détourage auto désactivé : envoi du logo avec fond d’origine (lisibilité sur dégradé clair).
    var flyerLogoKeepSourceBackground: Bool

    static let templateIdFixed = "noir-or-roue"

    static var `default`: FlyerStateDTO {
        FlyerStateDTO(
            templateId: templateIdFixed,
            headline: "SCANNEZ & GAGNEZ VOTRE CADEAU !",
            ctaBanner: "SCANNER POUR JOUER",
            ctaBannerBgColor: "#ec4899",
            ctaTextColor: "#ffffff",
            step1: "Scannez le QR code",
            step2: "Ajoutez la carte au Wallet",
            step3: "Cumulez points & avantages",
            social1: "",
            socialUrl1: "",
            social2: "",
            socialUrl2: "",
            social3: "",
            socialUrl3: "",
            colorPrimary: "#fbbf24",
            colorSecondary: "#f97316",
            colorAccent: "#ffffff",
            /// Fond clair, vif (dégradé) — cohérent avec le texte titre foncé.
            colorBgTop: "#FEF3C7",
            colorBgBottom: "#FED7AA",
            /// Legacy : `wheelRenderMode` ignoré côté canvas (roue vectorielle + `flyergame.png`).
            wheelRenderMode: "png",
            wheelColorOdd: "#fbbf24",
            wheelColorEven: "#ffffff",
            wheelSegmentOffsetDeg: 0,
            headlineFontId: "fraunces",
            headlineTextColor: "#0f172a",
            headlineStrokeColor: "#F8FAFC",
            headlineGiftStrokeColor: "#be185d",
            headlineStrokeWidth: 18,
            headlineLogoGapPct: 4,
            headlineLetterSpacing: 0,
            headlineSizePct: 7,
            flyerFooterTextScalePct: 100,
            flyerWheelLabelScalePct: 100,
            flyerBgOverlayPct: 0,
            flyerQrOutlineWidth: 5,
            flyerLogoCenterYFrac: 0.092,
            flyerLogoMaxWFrac: 0.62,
            flyerLogoMaxHFrac: 0.15,
            /// Détourage auto du logo (fond retiré) par défaut — l’app exporte en PNG transparence.
            flyerLogoKeepSourceBackground: false
        )
    }

    init(
        templateId: String,
        headline: String,
        ctaBanner: String,
        ctaBannerBgColor: String,
        ctaTextColor: String,
        step1: String,
        step2: String,
        step3: String,
        social1: String,
        socialUrl1: String,
        social2: String,
        socialUrl2: String,
        social3: String,
        socialUrl3: String,
        colorPrimary: String,
        colorSecondary: String,
        colorAccent: String,
        colorBgTop: String,
        colorBgBottom: String,
        wheelRenderMode: String,
        wheelColorOdd: String,
        wheelColorEven: String,
        wheelSegmentOffsetDeg: Double,
        headlineFontId: String,
        headlineTextColor: String,
        headlineStrokeColor: String,
        headlineGiftStrokeColor: String,
        headlineStrokeWidth: Double,
        headlineLogoGapPct: Double,
        headlineLetterSpacing: Double,
        headlineSizePct: Double,
        flyerFooterTextScalePct: Double,
        flyerWheelLabelScalePct: Double,
        flyerBgOverlayPct: Double,
        flyerQrOutlineWidth: Double,
        flyerLogoCenterYFrac: Double,
        flyerLogoMaxWFrac: Double,
        flyerLogoMaxHFrac: Double,
        flyerLogoKeepSourceBackground: Bool
    ) {
        self.templateId = templateId
        self.headline = headline
        self.ctaBanner = ctaBanner
        self.ctaBannerBgColor = ctaBannerBgColor
        self.ctaTextColor = ctaTextColor
        self.step1 = step1
        self.step2 = step2
        self.step3 = step3
        self.social1 = social1
        self.socialUrl1 = socialUrl1
        self.social2 = social2
        self.socialUrl2 = socialUrl2
        self.social3 = social3
        self.socialUrl3 = socialUrl3
        self.colorPrimary = colorPrimary
        self.colorSecondary = colorSecondary
        self.colorAccent = colorAccent
        self.colorBgTop = colorBgTop
        self.colorBgBottom = colorBgBottom
        self.wheelRenderMode = wheelRenderMode
        self.wheelColorOdd = wheelColorOdd
        self.wheelColorEven = wheelColorEven
        self.wheelSegmentOffsetDeg = wheelSegmentOffsetDeg
        self.headlineFontId = headlineFontId
        self.headlineTextColor = headlineTextColor
        self.headlineStrokeColor = headlineStrokeColor
        self.headlineGiftStrokeColor = headlineGiftStrokeColor
        self.headlineStrokeWidth = headlineStrokeWidth
        self.headlineLogoGapPct = headlineLogoGapPct
        self.headlineLetterSpacing = headlineLetterSpacing
        self.headlineSizePct = headlineSizePct
        self.flyerFooterTextScalePct = flyerFooterTextScalePct
        self.flyerWheelLabelScalePct = flyerWheelLabelScalePct
        self.flyerBgOverlayPct = flyerBgOverlayPct
        self.flyerQrOutlineWidth = flyerQrOutlineWidth
        self.flyerLogoCenterYFrac = flyerLogoCenterYFrac
        self.flyerLogoMaxWFrac = flyerLogoMaxWFrac
        self.flyerLogoMaxHFrac = flyerLogoMaxHFrac
        self.flyerLogoKeepSourceBackground = flyerLogoKeepSourceBackground
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = Self.default
        templateId = Self.templateIdFixed
        headline = try c.decodeIfPresent(String.self, forKey: .headline) ?? base.headline
        ctaBanner = try c.decodeIfPresent(String.self, forKey: .ctaBanner) ?? base.ctaBanner
        ctaBannerBgColor = Self.safeHex(try c.decodeIfPresent(String.self, forKey: .ctaBannerBgColor), base.ctaBannerBgColor)
        ctaTextColor = Self.safeHex(try c.decodeIfPresent(String.self, forKey: .ctaTextColor), base.ctaTextColor)
        step1 = try c.decodeIfPresent(String.self, forKey: .step1) ?? base.step1
        step2 = try c.decodeIfPresent(String.self, forKey: .step2) ?? base.step2
        step3 = try c.decodeIfPresent(String.self, forKey: .step3) ?? base.step3
        social1 = try c.decodeIfPresent(String.self, forKey: .social1) ?? base.social1
        socialUrl1 = try c.decodeIfPresent(String.self, forKey: .socialUrl1) ?? base.socialUrl1
        social2 = try c.decodeIfPresent(String.self, forKey: .social2) ?? base.social2
        socialUrl2 = try c.decodeIfPresent(String.self, forKey: .socialUrl2) ?? base.socialUrl2
        social3 = try c.decodeIfPresent(String.self, forKey: .social3) ?? base.social3
        socialUrl3 = try c.decodeIfPresent(String.self, forKey: .socialUrl3) ?? base.socialUrl3
        let oddRaw = try c.decodeIfPresent(String.self, forKey: .wheelColorOdd)
        let evenRaw = try c.decodeIfPresent(String.self, forKey: .wheelColorEven)
        colorPrimary = Self.safeHex(try c.decodeIfPresent(String.self, forKey: .colorPrimary), base.colorPrimary)
        colorSecondary = Self.safeHex(try c.decodeIfPresent(String.self, forKey: .colorSecondary), base.colorSecondary)
        colorAccent = Self.safeHex(try c.decodeIfPresent(String.self, forKey: .colorAccent), base.colorAccent)
        colorBgTop = Self.safeHex(try c.decodeIfPresent(String.self, forKey: .colorBgTop), base.colorBgTop)
        colorBgBottom = Self.safeHex(try c.decodeIfPresent(String.self, forKey: .colorBgBottom), base.colorBgBottom)
        let wr = try c.decodeIfPresent(String.self, forKey: .wheelRenderMode) ?? base.wheelRenderMode
        var wm = Self.normalizeWheelRenderMode(wr)
        if wm == "segments" { wm = "png" }
        wheelRenderMode = wm
        wheelColorOdd = Self.safeHex(oddRaw, base.wheelColorOdd)
        wheelColorEven = Self.safeHex(evenRaw, base.wheelColorEven)
        wheelSegmentOffsetDeg = Self.clampWheelOffset(try c.decodeIfPresent(Double.self, forKey: .wheelSegmentOffsetDeg) ?? base.wheelSegmentOffsetDeg)
        headlineFontId = FlyerHeadlineFontCatalog.normalize(try c.decodeIfPresent(String.self, forKey: .headlineFontId))
        headlineTextColor = Self.safeHex(try c.decodeIfPresent(String.self, forKey: .headlineTextColor), base.headlineTextColor)
        headlineStrokeColor = Self.safeHex(try c.decodeIfPresent(String.self, forKey: .headlineStrokeColor), base.headlineStrokeColor)
        headlineGiftStrokeColor = Self.safeHex(
            try c.decodeIfPresent(String.self, forKey: .headlineGiftStrokeColor),
            base.headlineGiftStrokeColor
        )
        headlineStrokeWidth = Self.clampStrokeW(try c.decodeIfPresent(Double.self, forKey: .headlineStrokeWidth) ?? base.headlineStrokeWidth)
        headlineLogoGapPct = Self.clampGapPct(try c.decodeIfPresent(Double.self, forKey: .headlineLogoGapPct) ?? base.headlineLogoGapPct)
        headlineLetterSpacing = Self.clampLetterSpacing(try c.decodeIfPresent(Double.self, forKey: .headlineLetterSpacing) ?? base.headlineLetterSpacing)
        headlineSizePct = Self.clampHeadlineSize(try c.decodeIfPresent(Double.self, forKey: .headlineSizePct) ?? base.headlineSizePct)
        flyerFooterTextScalePct = Self.clampTextScale(try c.decodeIfPresent(Double.self, forKey: .flyerFooterTextScalePct) ?? base.flyerFooterTextScalePct)
        flyerWheelLabelScalePct = Self.clampTextScale(try c.decodeIfPresent(Double.self, forKey: .flyerWheelLabelScalePct) ?? base.flyerWheelLabelScalePct)
        flyerBgOverlayPct = Self.clampOverlay(try c.decodeIfPresent(Double.self, forKey: .flyerBgOverlayPct) ?? base.flyerBgOverlayPct)
        flyerQrOutlineWidth = Self.clampQrOutline(try c.decodeIfPresent(Double.self, forKey: .flyerQrOutlineWidth) ?? base.flyerQrOutlineWidth)
        flyerLogoCenterYFrac = Self.clampLogoCenterYFrac(
            try c.decodeIfPresent(Double.self, forKey: .flyerLogoCenterYFrac) ?? base.flyerLogoCenterYFrac
        )
        flyerLogoMaxWFrac = Self.clampLogoMaxWFrac(
            try c.decodeIfPresent(Double.self, forKey: .flyerLogoMaxWFrac) ?? base.flyerLogoMaxWFrac
        )
        flyerLogoMaxHFrac = Self.clampLogoMaxHFrac(
            try c.decodeIfPresent(Double.self, forKey: .flyerLogoMaxHFrac) ?? base.flyerLogoMaxHFrac
        )
        flyerLogoKeepSourceBackground = try c.decodeIfPresent(Bool.self, forKey: .flyerLogoKeepSourceBackground)
            ?? base.flyerLogoKeepSourceBackground
    }

    mutating func normalizeClamps() {
        /// `JSONEncoder` n’encode pas les `Double` non finis → échec silencieux de `encodedPreviewBootstrapBase64`
        /// et l’aperçu retombe sur le PNG IA seul (pas de roue / QR canvas).
        Self.coerceFiniteNumericFields(&self)
        templateId = Self.templateIdFixed
        wheelRenderMode = Self.normalizeWheelRenderMode(wheelRenderMode)
        /// Legacy : `wheelRenderMode` conservé pour compat API ; le canvas utilise roue vectorielle + `flyergame.png`.
        if wheelRenderMode == "segments" {
            wheelRenderMode = "png"
        }
        wheelSegmentOffsetDeg = Self.clampWheelOffset(wheelSegmentOffsetDeg)
        colorPrimary = Self.safeHex(colorPrimary, Self.default.colorPrimary)
        colorSecondary = Self.safeHex(colorSecondary, Self.default.colorSecondary)
        colorAccent = Self.safeHex(colorAccent, Self.default.colorAccent)
        colorBgTop = Self.safeHex(colorBgTop, Self.default.colorBgTop)
        colorBgBottom = Self.safeHex(colorBgBottom, Self.default.colorBgBottom)
        wheelColorOdd = Self.safeHex(wheelColorOdd, Self.default.wheelColorOdd)
        wheelColorEven = Self.safeHex(wheelColorEven, Self.default.wheelColorEven)
        headlineFontId = FlyerHeadlineFontCatalog.normalize(headlineFontId)
        headlineTextColor = Self.safeHex(headlineTextColor, Self.default.headlineTextColor)
        headlineStrokeColor = Self.safeHex(headlineStrokeColor, Self.default.headlineStrokeColor)
        headlineGiftStrokeColor = Self.safeHex(headlineGiftStrokeColor, Self.default.headlineGiftStrokeColor)
        ctaBannerBgColor = Self.safeHex(ctaBannerBgColor, Self.default.ctaBannerBgColor)
        ctaTextColor = Self.safeHex(ctaTextColor, Self.default.ctaTextColor)
        headlineStrokeWidth = Self.clampStrokeW(headlineStrokeWidth)
        headlineLogoGapPct = Self.clampGapPct(headlineLogoGapPct)
        headlineLetterSpacing = Self.clampLetterSpacing(headlineLetterSpacing)
        headlineSizePct = Self.clampHeadlineSize(headlineSizePct)
        flyerFooterTextScalePct = Self.clampTextScale(flyerFooterTextScalePct)
        flyerWheelLabelScalePct = Self.clampTextScale(flyerWheelLabelScalePct)
        flyerBgOverlayPct = Self.clampOverlay(flyerBgOverlayPct)
        flyerQrOutlineWidth = Self.clampQrOutline(flyerQrOutlineWidth)
        flyerLogoCenterYFrac = Self.clampLogoCenterYFrac(flyerLogoCenterYFrac)
        flyerLogoMaxWFrac = Self.clampLogoMaxWFrac(flyerLogoMaxWFrac)
        flyerLogoMaxHFrac = Self.clampLogoMaxHFrac(flyerLogoMaxHFrac)
    }

    private static func coerceFiniteNumericFields(_ st: inout FlyerStateDTO) {
        let d = Self.default
        if !st.wheelSegmentOffsetDeg.isFinite { st.wheelSegmentOffsetDeg = d.wheelSegmentOffsetDeg }
        if !st.headlineStrokeWidth.isFinite { st.headlineStrokeWidth = d.headlineStrokeWidth }
        if !st.headlineLogoGapPct.isFinite { st.headlineLogoGapPct = d.headlineLogoGapPct }
        if !st.headlineLetterSpacing.isFinite { st.headlineLetterSpacing = d.headlineLetterSpacing }
        if !st.headlineSizePct.isFinite { st.headlineSizePct = d.headlineSizePct }
        if !st.flyerFooterTextScalePct.isFinite { st.flyerFooterTextScalePct = d.flyerFooterTextScalePct }
        if !st.flyerWheelLabelScalePct.isFinite { st.flyerWheelLabelScalePct = d.flyerWheelLabelScalePct }
        if !st.flyerBgOverlayPct.isFinite { st.flyerBgOverlayPct = d.flyerBgOverlayPct }
        if !st.flyerQrOutlineWidth.isFinite { st.flyerQrOutlineWidth = d.flyerQrOutlineWidth }
        if !st.flyerLogoCenterYFrac.isFinite { st.flyerLogoCenterYFrac = d.flyerLogoCenterYFrac }
        if !st.flyerLogoMaxWFrac.isFinite { st.flyerLogoMaxWFrac = d.flyerLogoMaxWFrac }
        if !st.flyerLogoMaxHFrac.isFinite { st.flyerLogoMaxHFrac = d.flyerLogoMaxHFrac }
    }

    /// Décodage depuis l’objet `flyer_prefs.state` brut (clés **camelCase** ; secours snake_case legacy).
    static func decodeFromJSONObject(_ object: Any) -> FlyerStateDTO? {
        guard JSONSerialization.isValidJSONObject(object),
              var dict = object as? [String: Any]
        else { return nil }
        dict = migrateLegacySnakeCaseFlyerStateKeys(dict)
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .useDefaultKeys
        guard var st = try? dec.decode(FlyerStateDTO.self, from: data) else { return nil }
        st.normalizeClamps()
        return st
    }

    /// Anciennes lignes SQLite / clients : `wheel_color_odd` au lieu de `wheelColorOdd`.
    private static func migrateLegacySnakeCaseFlyerStateKeys(_ raw: [String: Any]) -> [String: Any] {
        var d = raw
        let pairs: [(String, String)] = [
            ("wheel_color_odd", "wheelColorOdd"),
            ("wheel_color_even", "wheelColorEven"),
            ("wheel_render_mode", "wheelRenderMode"),
            ("color_primary", "colorPrimary"),
            ("color_secondary", "colorSecondary"),
            ("color_accent", "colorAccent"),
            ("color_bg_top", "colorBgTop"),
            ("color_bg_bottom", "colorBgBottom"),
            ("cta_banner_bg_color", "ctaBannerBgColor"),
            ("cta_text_color", "ctaTextColor"),
            ("headline_text_color", "headlineTextColor"),
            ("headline_stroke_color", "headlineStrokeColor"),
            ("headline_gift_stroke_color", "headlineGiftStrokeColor"),
        ]
        for (snake, camel) in pairs {
            if d[camel] == nil, let v = d[snake] { d[camel] = v }
        }
        return d
    }

    /// Au moins une teinte « élément » présente dans le JSON (évite d’ignorer un `state` serveur valide).
    var hasExplicitFlyerColorFields: Bool {
        var st = self
        st.normalizeClamps()
        let d = Self.default
        return st.wheelColorOdd != d.wheelColorOdd
            || st.wheelColorEven != d.wheelColorEven
            || st.ctaBannerBgColor != d.ctaBannerBgColor
            || st.ctaTextColor != d.ctaTextColor
            || st.headlineTextColor != d.headlineTextColor
            || st.headlineStrokeColor != d.headlineStrokeColor
            || st.headlineGiftStrokeColor != d.headlineGiftStrokeColor
            || st.colorBgTop != d.colorBgTop
            || st.colorBgBottom != d.colorBgBottom
            || st.colorPrimary != d.colorPrimary
    }

    /// Après `normalizeClamps()`, diffère du gabarit app (textes, teintes roue / fond / bandeau, etc.).
    var isCustomizedComparedToAppDefault: Bool {
        var lhs = self
        lhs.normalizeClamps()
        var rhs = Self.default
        rhs.normalizeClamps()
        return lhs != rhs
    }

    /// Ancien bootstrap iOS : `colorBgTop` / `colorBgBottom` avaient été écrasés par `colorPrimary` pour le mode fond natif.
    /// Rétablit un dégradé lisible pour l’underlay Swift et l’embed web après réouverture depuis le cache.
    mutating func repairLegacyNativeBgFlattenedGradientIfNeeded(hasNativeBackground: Bool) {
        guard hasNativeBackground else { return }
        normalizeClamps()
        let primary = colorPrimary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !primary.isEmpty else { return }
        let top = colorBgTop.trimmingCharacters(in: .whitespacesAndNewlines)
        let bottom = colorBgBottom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard top.uppercased() == primary.uppercased(),
              bottom.uppercased() == primary.uppercased()
        else { return }
        let secondary = colorSecondary.trimmingCharacters(in: .whitespacesAndNewlines)
        let sec = secondary.isEmpty ? Self.default.colorSecondary : secondary
        colorBgTop = Self.lightenHexTowardWhite(primary, mix: 0.36)
        colorBgBottom = Self.darkenHex(sec, amount: 0.17)
    }

    private static func lightenHexTowardWhite(_ hex: String, mix: Double) -> String {
        guard let (r, g, b) = rgbFractions(fromHex: hex) else { return hex }
        let t = min(1, max(0, mix))
        return rgbHex(
            r: r * t + (1 - t),
            g: g * t + (1 - t),
            b: b * t + (1 - t)
        )
    }

    private static func darkenHex(_ hex: String, amount: Double) -> String {
        guard let (r, g, b) = rgbFractions(fromHex: hex) else { return hex }
        let d = min(1, max(0, amount))
        return rgbHex(r: r * (1 - d), g: g * (1 - d), b: b * (1 - d))
    }

    private static func rgbFractions(fromHex raw: String) -> (Double, Double, Double)? {
        let h = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard h.range(of: #"^#[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil else { return nil }
        let r = Double(Int(h.dropFirst().prefix(2), radix: 16) ?? 0) / 255
        let g = Double(Int(h.dropFirst(3).prefix(2), radix: 16) ?? 0) / 255
        let b = Double(Int(h.dropFirst(5).prefix(2), radix: 16) ?? 0) / 255
        return (r, g, b)
    }

    private static func rgbHex(r: Double, g: Double, b: Double) -> String {
        func c(_ x: Double) -> Int { min(255, max(0, Int((x * 255).rounded()))) }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }

    private enum CodingKeys: String, CodingKey {
        case templateId, headline, ctaBanner, ctaBannerBgColor, ctaTextColor, step1, step2, step3
        case social1, socialUrl1, social2, socialUrl2, social3, socialUrl3
        case colorPrimary, colorSecondary, colorAccent, colorBgTop, colorBgBottom
        case wheelRenderMode, wheelColorOdd, wheelColorEven, wheelSegmentOffsetDeg
        case headlineFontId, headlineTextColor, headlineStrokeColor, headlineGiftStrokeColor, headlineStrokeWidth
        case headlineLogoGapPct, headlineLetterSpacing, headlineSizePct
        case flyerFooterTextScalePct, flyerWheelLabelScalePct, flyerBgOverlayPct, flyerQrOutlineWidth
        case flyerLogoCenterYFrac, flyerLogoMaxWFrac, flyerLogoMaxHFrac, flyerLogoKeepSourceBackground
    }

    private static func safeHex(_ v: String?, _ fallback: String) -> String {
        let t = (v ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if t.range(of: #"^#[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil { return t }
        return fallback
    }

    private static func normalizeWheelRenderMode(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t == "segments" { return "segments" }
        return "png"
    }

    private static func clampWheelOffset(_ v: Double) -> Double {
        let x = v.isFinite ? v : 0
        return min(180, max(-180, (x * 20).rounded() / 20))
    }

    private static func clampStrokeW(_ v: Double) -> Double {
        let x = v.isFinite ? v : Self.default.headlineStrokeWidth
        return min(32, max(0, x.rounded()))
    }

    private static func clampGapPct(_ v: Double) -> Double {
        let x = v.isFinite ? v : Self.default.headlineLogoGapPct
        return min(14, max(0, (x * 10).rounded() / 10))
    }

    private static func clampLetterSpacing(_ v: Double) -> Double {
        let x = v.isFinite ? v : 0
        return min(8, max(0, (x * 2).rounded() / 2))
    }

    private static func clampHeadlineSize(_ v: Double) -> Double {
        let x = v.isFinite ? v : Self.default.headlineSizePct
        return min(16, max(5, (x * 10).rounded() / 10))
    }

    private static func clampTextScale(_ v: Double) -> Double {
        let x = v.isFinite ? v : 100
        let r = (x / 5).rounded() * 5
        return min(130, max(70, r))
    }

    private static func clampOverlay(_ v: Double) -> Double {
        let x = v.isFinite ? v : 0
        return min(90, max(0, x.rounded()))
    }

    private static func clampQrOutline(_ v: Double) -> Double {
        let x = v.isFinite ? v : 0
        return min(12, max(0, x.rounded()))
    }

    private static func clampLogoCenterYFrac(_ v: Double) -> Double {
        let x = v.isFinite ? v : Self.default.flyerLogoCenterYFrac
        return min(0.22, max(0.06, (x * 1000).rounded() / 1000))
    }

    private static func clampLogoMaxWFrac(_ v: Double) -> Double {
        let x = v.isFinite ? v : Self.default.flyerLogoMaxWFrac
        return min(0.88, max(0.28, (x * 1000).rounded() / 1000))
    }

    private static func clampLogoMaxHFrac(_ v: Double) -> Double {
        let x = v.isFinite ? v : Self.default.flyerLogoMaxHFrac
        return min(0.36, max(0.06, (x * 1000).rounded() / 1000))
    }
}

extension DashboardFlyerGetResponse {
    /// Flyer réellement personnalisé / enregistré : visuels ou textes-couleurs ≠ gabarit par défaut.
    /// Ne **pas** se baser sur `updated_at` seul : une ligne créée côté serveur peut avoir un horodatage sans aucune action commerçant (sinon « Créer » / hub se confondent avec « Modifier »).
    var commerceIndicatesFlyerRegistered: Bool {
        let bg = (flyerPrefs?.customBgDataUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let lg = (flyerPrefs?.customLogoDataUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !bg.isEmpty || !lg.isEmpty { return true }
        guard let fp = flyerPrefs else { return false }
        if let st = fp.state {
            var lhs = st
            lhs.normalizeClamps()
            var rhs = FlyerStateDTO.default
            rhs.normalizeClamps()
            if lhs != rhs { return true }
        }
        return false
    }
}

enum FlyerHeadlineFontCatalog {
    static let idsOrdered: [String] = [
        "fraunces", "abril-fatface", "playfair", "dm-serif-display", "bodoni-moda", "yeseva-one", "cinzel",
        "bebas", "anton", "archivo-black", "oswald", "saira-extra-condensed", "teko", "alfa-slab", "ultra",
        "bungee", "righteous", "paytone-one", "russo-one", "shrikhand", "titan-one", "unbounded"
    ]

    static let displayNames: [String: String] = [
        "fraunces": "Fraunces",
        "abril-fatface": "Abril Fatface",
        "playfair": "Playfair Display",
        "dm-serif-display": "DM Serif Display",
        "bodoni-moda": "Bodoni Moda",
        "yeseva-one": "Yeseva One",
        "cinzel": "Cinzel",
        "bebas": "Bebas Neue",
        "anton": "Anton",
        "archivo-black": "Archivo Black",
        "oswald": "Oswald",
        "saira-extra-condensed": "Saira Extra Condensed",
        "teko": "Teko",
        "alfa-slab": "Alfa Slab One",
        "ultra": "Ultra",
        "bungee": "Bungee",
        "righteous": "Righteous",
        "paytone-one": "Paytone One",
        "russo-one": "Russo One",
        "shrikhand": "Shrikhand",
        "titan-one": "Titan One",
        "unbounded": "Unbounded"
    ]

    static func normalize(_ id: String?) -> String {
        let t = (id ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if idsOrdered.contains(t) { return t }
        return idsOrdered[0]
    }
}

