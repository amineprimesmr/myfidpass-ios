//
//  SocialMetricsModels.swift
//  myfidpass
//
//  Réponses GET /dashboard/social-metrics — aligné sur `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`
//  (ne pas redéfinir des CodingKeys en snake_case : double application = échec du décodage).
//

import Foundation

struct SocialMetricsSummaryResponse: Decodable {
    let channels: [SocialMetricsChannelRow]
    let googlePlacesConfigured: Bool
    let generatedAt: String?
    /// Jetons OAuth OK mais résolution lieu reportée (quota API) — finalisation au prochain rafraîchissement.
    let googleBusinessLocationPending: Bool?
    /// OAuth Google Business Profile (avis propriétaire).
    let googleBusinessOauthAvailable: Bool?
    /// OAuth Meta (Instagram + Page Facebook).
    let metaOauthAvailable: Bool?
    /// OAuth Google (chaîne YouTube).
    let youtubeOauthAvailable: Bool?
    /// OAuth TikTok.
    let tiktokOauthAvailable: Bool?
}

/// Aperçu d’un avis (API Google Business Profile), renvoyé dans le canal `google_review`.
struct GoogleReviewSampleItem: Decodable, Identifiable {
    let author: String?
    let text: String?
    let rating: Double?
    let updateTime: String?

    var id: String {
        let a = author ?? ""
        let t = updateTime ?? ""
        let h = text.map { String($0.prefix(40)) } ?? ""
        return "\(t)|\(a)|\(h.hashValue)"
    }

    enum CodingKeys: String, CodingKey {
        case author, text, rating
        case updateTime = "update_time"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        author = try c.decodeIfPresent(String.self, forKey: .author)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        updateTime = try c.decodeIfPresent(String.self, forKey: .updateTime)
        if let d = try? c.decodeIfPresent(Double.self, forKey: .rating) {
            rating = d
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .rating) {
            rating = Double(i)
        } else {
            rating = nil
        }
    }
}

struct SocialMetricsChannelRow: Decodable, Identifiable {
    var id: String { channel }

    let channel: String
    let label: String
    let enabled: Bool
    let configured: Bool
    let latest: SocialMetricsLatest?
    let baselineCapturedAt: String?
    let deltaSinceBaseline: [String: Double]?
    let deltaSincePrevious: [String: Double]?
    let history: [SocialMetricsHistoryPoint]
    let googleAutoAvailable: Bool
    /// Instagram : connexion Meta enregistrée côté API.
    let oauthConnected: Bool?
    /// Avis récents (OAuth Google Business uniquement).
    let reviewsSample: [GoogleReviewSampleItem]?
}

/// GET …/dashboard/social-oauth/meta/start
struct MetaOAuthStartResponse: Decodable {
    let authUrl: String
    let metaOauthAvailable: Bool?
}

struct SocialMetricsLatest: Decodable {
    let capturedAt: String
    let source: String
    let metrics: [String: Double]

    enum CodingKeys: String, CodingKey {
        case capturedAt
        case source
        case metrics
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        capturedAt = try c.decode(String.self, forKey: .capturedAt)
        source = try c.decode(String.self, forKey: .source)
        let raw = try c.decode([String: SocialMetricNumber].self, forKey: .metrics)
        metrics = raw.mapValues(\.value)
    }
}

/// Décodage souple (Int ou Double dans le JSON).
private struct SocialMetricNumber: Decodable {
    let value: Double

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) {
            value = Double(i)
        } else if let d = try? c.decode(Double.self) {
            value = d
        } else {
            value = 0
        }
    }
}

struct SocialMetricsHistoryPoint: Decodable {
    let capturedAt: String
    let source: String
    let metrics: [String: Double]

    enum CodingKeys: String, CodingKey {
        case capturedAt
        case source
        case metrics
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        capturedAt = try c.decode(String.self, forKey: .capturedAt)
        source = try c.decode(String.self, forKey: .source)
        let raw = try c.decode([String: SocialMetricNumber].self, forKey: .metrics)
        metrics = raw.mapValues(\.value)
    }
}

struct SocialMetricsManualPayload: Encodable {
    let channel: String
    let followers: Int?
    let reviewsCount: Int?
    let rating: Double?
}
