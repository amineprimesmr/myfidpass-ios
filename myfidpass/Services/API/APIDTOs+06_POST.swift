//
//  APIDTOs+06_POST.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

// MARK: - POST .../dashboard/receipt-challenge

struct ReceiptChallengeResponse: Decodable {
    let qrPayload: String
    let expiresAt: String?
    let amountEur: Double?

    enum CodingKeys: String, CodingKey {
        case qrPayload = "qr_payload"
        case expiresAt = "expires_at"
        case amountEur = "amount_eur"
    }
}

/// Config engagement renvoyée par GET dashboard/settings (fusionnée côté serveur avec les défauts).
struct EngagementRewardsDTO: Decodable, Equatable {
    var googleReview: EngagementChannelDTO?
    var instagramFollow: EngagementChannelDTO?
    var tiktokFollow: EngagementChannelDTO?
    var facebookFollow: EngagementChannelDTO?
    var twitterFollow: EngagementChannelDTO?
    var snapchatFollow: EngagementChannelDTO?
    var linkedinFollow: EngagementChannelDTO?
    var youtubeFollow: EngagementChannelDTO?
    var trustpilotReview: EngagementChannelDTO?
    var tripadvisorReview: EngagementChannelDTO?

    enum CodingKeys: String, CodingKey {
        case googleReview = "google_review"
        case instagramFollow = "instagram_follow"
        case tiktokFollow = "tiktok_follow"
        case facebookFollow = "facebook_follow"
        case twitterFollow = "twitter_follow"
        case snapchatFollow = "snapchat_follow"
        case linkedinFollow = "linkedin_follow"
        case youtubeFollow = "youtube_follow"
        case trustpilotReview = "trustpilot_review"
        case tripadvisorReview = "tripadvisor_review"
    }
}

struct EngagementChannelDTO: Decodable, Equatable {
    let enabled: Bool?
    let points: Int?
    let url: String?
    let placeId: String?
    let requireApproval: Bool?
    let autoVerifyEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case enabled, points, url
        case placeId = "place_id"
        case requireApproval = "require_approval"
        case autoVerifyEnabled = "auto_verify_enabled"
    }
}

struct PointsRewardTierDTO: Decodable {
    let points: Int
    let label: String
    let minPurchaseEur: Double?

    enum CodingKeys: String, CodingKey {
        case points
        case label
        case minPurchaseEur = "min_purchase_eur"
    }

    /// Tolère les paliers SaaS incomplets (label manquant, points en nombre décimal / chaîne) pour ne pas faire échouer tout `GET …/settings`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let i = try? c.decode(Int.self, forKey: .points) {
            points = i
        } else if let d = try? c.decode(Double.self, forKey: .points) {
            points = Int(d)
        } else if let s = try? c.decode(String.self, forKey: .points), let i = Int(s.trimmingCharacters(in: .whitespaces)) {
            points = i
        } else {
            points = 0
        }
        label = (try? c.decode(String.self, forKey: .label))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let d = try? c.decode(Double.self, forKey: .minPurchaseEur), d > 0 {
            minPurchaseEur = d
        } else if let s = try? c.decode(String.self, forKey: .minPurchaseEur),
                  let d = Double(s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)),
                  d > 0 {
            minPurchaseEur = d
        } else {
            minPurchaseEur = nil
        }
    }
}

