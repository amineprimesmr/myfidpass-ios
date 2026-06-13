//
//  APIDTOs+17_FlyergnrationdimageIA.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

// MARK: - Flyer — génération d’image IA (OpenAI, serveur)

struct FlyerAIGenerateRequestDTO: Encodable {
    var brandName: String
    /// Secteur + produits / visuels à mettre en avant (un seul champ côté UX).
    var cuisineOrConcept: String
    var accentColorHex: String
    var secondaryColorHex: String?
    var extraContext: String?
    /// 1 à 3 couleurs `#RRGGBB`, ordre = priorité pour le prompt IA (aligné `palette_colors_hex` API).
    var paletteColorsHex: [String]
    /// Data URL ou base64 — logo affiché en tête d’affiche dans l’image générée (optionnel).
    var logoBase64: String?
    /// Jusqu’à 3 images d’inspiration (DA / ambiance) — data URL ou base64.
    var styleReferenceImagesBase64: [String]?
}

struct FlyerAIGenerateResponseDTO: Decodable {
    let imageBase64: String
    let revisedPrompt: String?
    let flyerAiGenerationsUsed: Int?
    let flyerAiGenerationsRemaining: Int?
    let flyerAiUnlimited: Bool?
}

/// Réponse `202 Accepted` après `POST .../flyer/ai-generate` (génération asynchrone).
struct FlyerAIGenerateEnqueueResponseDTO: Decodable {
    let jobId: String
    let status: String
}

/// Corps `GET .../flyer/ai-generate/jobs/:jobId` (polling jusqu’à `done` ou `failed`).
struct FlyerAIGenerateJobStatusResponseDTO: Decodable {
    let status: String
    let jobId: String
    let error: String?
    let imageBase64: String?
    let revisedPrompt: String?
    let flyerAiGenerationsUsed: Int?
    let flyerAiGenerationsRemaining: Int?
    let flyerAiUnlimited: Bool?
    let fidelityPageBackgroundSaved: Bool?
    let fidelityPageBackgroundError: String?
}

enum FlyerRemoteImagePayload: Equatable {
    case leaveUnchanged
    case clear
    case dataURL(String)
}

struct FlyerPutPayload: Encodable {
    var state: FlyerStateDTO
    var logo: FlyerRemoteImagePayload
    var background: FlyerRemoteImagePayload

    enum CK: String, CodingKey {
        case state
        case customLogoDataUrl = "custom_logo_data_url"
        case customBgDataUrl = "custom_bg_data_url"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CK.self)
        try c.encode(state, forKey: .state)
        switch logo {
        case .leaveUnchanged:
            break
        case .clear:
            try c.encodeNil(forKey: .customLogoDataUrl)
        case .dataURL(let s):
            try c.encode(s, forKey: .customLogoDataUrl)
        }
        switch background {
        case .leaveUnchanged:
            break
        case .clear:
            try c.encodeNil(forKey: .customBgDataUrl)
        case .dataURL(let s):
            try c.encode(s, forKey: .customBgDataUrl)
        }
    }

    func encodedJSON() throws -> Data {
        let enc = JSONEncoder()
        /// **camelCase** pour le corps `state` (aligné aperçu `/assets/app-flyer-qr-draw*.js` : `r.wheelRenderMode`).
        /// Le `JSONEncoder` de `APIClient` utilise le snake, mais ici l’API flyer attend les mêmes clés que l’éditeur.
        enc.keyEncodingStrategy = .useDefaultKeys
        return try enc.encode(self)
    }
}

