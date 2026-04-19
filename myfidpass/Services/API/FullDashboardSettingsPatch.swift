//
//  FullDashboardSettingsPatch.swift
//  myfidpass
//
//  PATCH .../dashboard/settings : n’encode que les champs non-nil (évite d’écraser le serveur avec des null).
//

import Foundation

/// Payload PATCH dashboard / settings (snake_case JSON, aligné `fidelity/backend/.../dashboard.js`).
struct FullDashboardSettingsPatch: Encodable {
    var organizationName: String?
    var backgroundColor: String?
    var foregroundColor: String?
    var labelColor: String?
    var backTerms: String?
    var backContact: String?
    var locationAddress: String?
    var locationLat: Double?
    var locationLng: Double?
    var locationRadiusMeters: Int?
    var locationRelevantText: String?
    var requiredStamps: Int?
    var stampEmoji: String?
    var stampRewardLabel: String?
    var stampMidRewardLabel: String?
    /// Si true, envoie `stamp_mid_reward_label: null` (équivalent case « pas de récompense 5ᵉ » sur le web).
    var stampMidRewardLabelIsExplicitNull: Bool = false
    var programType: String?
    var loyaltyMode: String?
    var pointsPerTicket: Int?
    var pointsPerEuro: Int?
    var pointsPerVisit: Int?
    var pointsMinAmountEur: Double?
    var pointsRewardTiers: [PointsRewardTierPayload]?
    var sector: String?
    var logoBase64: String?
    var logoIconBase64: String?
    /// Icône campagnes / push uniquement (ne modifie pas `logo` / `logo_icon`).
    var notificationIconBase64: String?
    var logoUrl: String?
    var cardBackgroundBase64: String?
    var stampIconBase64: String?
    var stripColor: String?
    var stripDisplayMode: String?
    var stripText: String?
    var labelRestants: String?
    var labelMember: String?
    var headerRightText: String?
    var notificationTitleOverride: String?
    var notificationChangeMessage: String?
    /// Règles campagnes automatiques (remplace l’objet côté serveur).
    var campaignAutomation: CampaignAutomationConfigDTO?
    /// À n’envoyer que si vous avez chargé l’état complet depuis le GET (sinon risque d’écraser la config web).
    var engagementRewards: EngagementRewardsFullPatch?
    /// 0 = illimité (persisté NULL côté serveur).
    var scanMaxPassesPerMemberPerDay: Int?
    /// 0 = illimité.
    var scanMaxPointsPerTransaction: Int?
    var requireReceiptQrValidation: Bool?
    var receiptQrToleranceCents: Int?

    private enum CK: String, CodingKey {
        case organizationName = "organization_name"
        case backgroundColor = "background_color"
        case foregroundColor = "foreground_color"
        case labelColor = "label_color"
        case backTerms = "back_terms"
        case backContact = "back_contact"
        case locationAddress = "location_address"
        case locationLat = "location_lat"
        case locationLng = "location_lng"
        case locationRadiusMeters = "location_radius_meters"
        case locationRelevantText = "location_relevant_text"
        case requiredStamps = "required_stamps"
        case stampEmoji = "stamp_emoji"
        case stampRewardLabel = "stamp_reward_label"
        case stampMidRewardLabel = "stamp_mid_reward_label"
        case programType = "program_type"
        case loyaltyMode = "loyalty_mode"
        case pointsPerTicket = "points_per_ticket"
        case pointsPerEuro = "points_per_euro"
        case pointsPerVisit = "points_per_visit"
        case pointsMinAmountEur = "points_min_amount_eur"
        case pointsRewardTiers = "points_reward_tiers"
        case sector
        case logoBase64 = "logo_base64"
        case logoIconBase64 = "logo_icon_base64"
        case notificationIconBase64 = "notification_icon_base64"
        case logoUrl = "logo_url"
        case cardBackgroundBase64 = "card_background_base64"
        case stampIconBase64 = "stamp_icon_base64"
        case stripColor = "strip_color"
        case stripDisplayMode = "strip_display_mode"
        case stripText = "strip_text"
        case labelRestants = "label_restants"
        case labelMember = "label_member"
        case headerRightText = "header_right_text"
        case notificationTitleOverride = "notification_title_override"
        case notificationChangeMessage = "notification_change_message"
        case campaignAutomation = "campaign_automation"
        case engagementRewards = "engagement_rewards"
        case scanMaxPassesPerMemberPerDay = "scan_max_passes_per_member_per_day"
        case scanMaxPointsPerTransaction = "scan_max_points_per_transaction"
        case requireReceiptQrValidation = "require_receipt_qr_validation"
        case receiptQrToleranceCents = "receipt_qr_tolerance_cents"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CK.self)
        if let v = organizationName { try c.encode(v, forKey: .organizationName) }
        if let v = backgroundColor { try c.encode(v, forKey: .backgroundColor) }
        if let v = foregroundColor { try c.encode(v, forKey: .foregroundColor) }
        if let v = labelColor { try c.encode(v, forKey: .labelColor) }
        if let v = backTerms { try c.encode(v, forKey: .backTerms) }
        if let v = backContact { try c.encode(v, forKey: .backContact) }
        if let v = locationAddress { try c.encode(v, forKey: .locationAddress) }
        if let v = locationLat { try c.encode(v, forKey: .locationLat) }
        if let v = locationLng { try c.encode(v, forKey: .locationLng) }
        if let v = locationRadiusMeters { try c.encode(v, forKey: .locationRadiusMeters) }
        if let v = locationRelevantText { try c.encode(v, forKey: .locationRelevantText) }
        if let v = requiredStamps { try c.encode(v, forKey: .requiredStamps) }
        if let v = stampEmoji { try c.encode(v, forKey: .stampEmoji) }
        if let v = stampRewardLabel { try c.encode(v, forKey: .stampRewardLabel) }
        if stampMidRewardLabelIsExplicitNull {
            try c.encodeNil(forKey: .stampMidRewardLabel)
        } else if let v = stampMidRewardLabel {
            try c.encode(v, forKey: .stampMidRewardLabel)
        }
        if let v = programType { try c.encode(v, forKey: .programType) }
        if let v = loyaltyMode { try c.encode(v, forKey: .loyaltyMode) }
        if let v = pointsPerTicket { try c.encode(v, forKey: .pointsPerTicket) }
        if let v = pointsPerEuro { try c.encode(v, forKey: .pointsPerEuro) }
        if let v = pointsPerVisit { try c.encode(v, forKey: .pointsPerVisit) }
        if let v = pointsMinAmountEur { try c.encode(v, forKey: .pointsMinAmountEur) }
        if let v = pointsRewardTiers { try c.encode(v, forKey: .pointsRewardTiers) }
        if let v = sector { try c.encode(v, forKey: .sector) }
        if let v = logoBase64 { try c.encode(v, forKey: .logoBase64) }
        if let v = logoIconBase64 { try c.encode(v, forKey: .logoIconBase64) }
        if let v = notificationIconBase64 { try c.encode(v, forKey: .notificationIconBase64) }
        if let v = logoUrl { try c.encode(v, forKey: .logoUrl) }
        if let v = cardBackgroundBase64 { try c.encode(v, forKey: .cardBackgroundBase64) }
        if let v = stampIconBase64 { try c.encode(v, forKey: .stampIconBase64) }
        if let v = stripColor { try c.encode(v, forKey: .stripColor) }
        if let v = stripDisplayMode { try c.encode(v, forKey: .stripDisplayMode) }
        if let v = stripText { try c.encode(v, forKey: .stripText) }
        if let v = labelRestants { try c.encode(v, forKey: .labelRestants) }
        if let v = labelMember { try c.encode(v, forKey: .labelMember) }
        if let v = headerRightText { try c.encode(v, forKey: .headerRightText) }
        if let v = notificationTitleOverride { try c.encode(v, forKey: .notificationTitleOverride) }
        if let v = notificationChangeMessage { try c.encode(v, forKey: .notificationChangeMessage) }
        if let v = campaignAutomation { try c.encode(v, forKey: .campaignAutomation) }
        if let v = engagementRewards { try c.encode(v, forKey: .engagementRewards) }
        if let v = scanMaxPassesPerMemberPerDay { try c.encode(v, forKey: .scanMaxPassesPerMemberPerDay) }
        if let v = scanMaxPointsPerTransaction { try c.encode(v, forKey: .scanMaxPointsPerTransaction) }
        if let v = requireReceiptQrValidation { try c.encode(v ? 1 : 0, forKey: .requireReceiptQrValidation) }
        if let v = receiptQrToleranceCents { try c.encode(v, forKey: .receiptQrToleranceCents) }
    }
}

/// Objet complet pour `engagement_rewards` (remplace la colonne côté serveur — utiliser seulement si issu du GET fusionné).
struct EngagementRewardsFullPatch: Encodable {
    let googleReview: GoogleReviewPatch
    let instagramFollow: SimpleUrlPatch
    let tiktokFollow: SimpleUrlPatch
    let facebookFollow: SimpleUrlPatch
    let twitterFollow: SimpleUrlPatch
    let snapchatFollow: SimpleUrlPatch
    let linkedinFollow: SimpleUrlPatch
    let youtubeFollow: SimpleUrlPatch
    let trustpilotReview: SimpleUrlPatch
    let tripadvisorReview: SimpleUrlPatch

    struct GoogleReviewPatch: Encodable {
        let enabled: Bool
        let points: Int
        let placeId: String
        let autoVerifyEnabled: Bool

        enum CK: String, CodingKey {
            case enabled, points
            case placeId = "place_id"
            case requireApproval = "require_approval"
            case autoVerifyEnabled = "auto_verify_enabled"
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CK.self)
            try c.encode(enabled, forKey: .enabled)
            try c.encode(points, forKey: .points)
            try c.encode(placeId, forKey: .placeId)
            try c.encode(false, forKey: .requireApproval)
            try c.encode(autoVerifyEnabled, forKey: .autoVerifyEnabled)
        }
    }

    struct SimpleUrlPatch: Encodable {
        let enabled: Bool
        let points: Int
        let url: String
    }

    private enum CK: String, CodingKey {
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

    init(from dto: EngagementRewardsDTO?) {
        let d = dto
        self.init(
            googleReview: .init(
                enabled: d?.googleReview?.enabled ?? false,
                points: d?.googleReview?.points ?? 50,
                placeId: d?.googleReview?.placeId ?? "",
                autoVerifyEnabled: d?.googleReview?.autoVerifyEnabled ?? true
            ),
            instagramFollow: .init(enabled: d?.instagramFollow?.enabled ?? false, points: d?.instagramFollow?.points ?? 10, url: d?.instagramFollow?.url ?? ""),
            tiktokFollow: .init(enabled: d?.tiktokFollow?.enabled ?? false, points: d?.tiktokFollow?.points ?? 10, url: d?.tiktokFollow?.url ?? ""),
            facebookFollow: .init(enabled: d?.facebookFollow?.enabled ?? false, points: d?.facebookFollow?.points ?? 10, url: d?.facebookFollow?.url ?? ""),
            twitterFollow: .init(enabled: d?.twitterFollow?.enabled ?? false, points: d?.twitterFollow?.points ?? 10, url: d?.twitterFollow?.url ?? ""),
            snapchatFollow: .init(enabled: d?.snapchatFollow?.enabled ?? false, points: d?.snapchatFollow?.points ?? 10, url: d?.snapchatFollow?.url ?? ""),
            linkedinFollow: .init(enabled: d?.linkedinFollow?.enabled ?? false, points: d?.linkedinFollow?.points ?? 10, url: d?.linkedinFollow?.url ?? ""),
            youtubeFollow: .init(enabled: d?.youtubeFollow?.enabled ?? false, points: d?.youtubeFollow?.points ?? 10, url: d?.youtubeFollow?.url ?? ""),
            trustpilotReview: .init(enabled: d?.trustpilotReview?.enabled ?? false, points: d?.trustpilotReview?.points ?? 10, url: d?.trustpilotReview?.url ?? ""),
            tripadvisorReview: .init(enabled: d?.tripadvisorReview?.enabled ?? false, points: d?.tripadvisorReview?.points ?? 10, url: d?.tripadvisorReview?.url ?? "")
        )
    }

    /// Formulaire profil / SaaS : toutes les missions sont envoyées en un bloc JSON serveur.
    init(
        googleReview: GoogleReviewPatch,
        instagramFollow: SimpleUrlPatch,
        tiktokFollow: SimpleUrlPatch,
        facebookFollow: SimpleUrlPatch,
        twitterFollow: SimpleUrlPatch,
        snapchatFollow: SimpleUrlPatch,
        linkedinFollow: SimpleUrlPatch,
        youtubeFollow: SimpleUrlPatch,
        trustpilotReview: SimpleUrlPatch,
        tripadvisorReview: SimpleUrlPatch
    ) {
        self.googleReview = googleReview
        self.instagramFollow = instagramFollow
        self.tiktokFollow = tiktokFollow
        self.facebookFollow = facebookFollow
        self.twitterFollow = twitterFollow
        self.snapchatFollow = snapchatFollow
        self.linkedinFollow = linkedinFollow
        self.youtubeFollow = youtubeFollow
        self.trustpilotReview = trustpilotReview
        self.tripadvisorReview = tripadvisorReview
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CK.self)
        try c.encode(googleReview, forKey: .googleReview)
        try c.encode(instagramFollow, forKey: .instagramFollow)
        try c.encode(tiktokFollow, forKey: .tiktokFollow)
        try c.encode(facebookFollow, forKey: .facebookFollow)
        try c.encode(twitterFollow, forKey: .twitterFollow)
        try c.encode(snapchatFollow, forKey: .snapchatFollow)
        try c.encode(linkedinFollow, forKey: .linkedinFollow)
        try c.encode(youtubeFollow, forKey: .youtubeFollow)
        try c.encode(trustpilotReview, forKey: .trustpilotReview)
        try c.encode(tripadvisorReview, forKey: .tripadvisorReview)
    }
}
