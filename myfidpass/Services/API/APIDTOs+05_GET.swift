//
//  APIDTOs+05_GET.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

// MARK: - GET .../dashboard/accounting-pack

struct MerchantAccountingPackResponse: Decodable, Sendable {
    let businessSlug: String
    let businessName: String
    let generatedAt: String
    let periodLabel: String
    let filters: MerchantAccountingPackFiltersDTO?
    let programSnapshot: MerchantAccountingProgramSnapshotDTO?
    let accountingPrefs: MerchantAccountingPrefsDTO?
    let summary: MerchantAccountingPackSummaryDTO?
    let files: [MerchantAccountingPackFileDTO]

    enum CodingKeys: String, CodingKey {
        case businessSlug = "business_slug"
        case businessName = "business_name"
        case generatedAt = "generated_at"
        case periodLabel = "period_label"
        case filters
        case programSnapshot = "program_snapshot"
        case accountingPrefs = "accounting_prefs"
        case summary
        case files
    }
}

struct MerchantAccountingPackFiltersDTO: Decodable, Sendable {
    let days: Int?
    let dateFrom: String?
    let dateTo: String?
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case days
        case dateFrom = "date_from"
        case dateTo = "date_to"
        case limit
    }
}

struct MerchantAccountingProgramSnapshotDTO: Decodable, Sendable {
    let programType: String?
    let loyaltyMode: String?
    let pointsPerEuro: Int?
    let pointsPerVisit: Int?
    let pointsMinAmountEur: Double?
    let pointsRewardTiers: [PointsRewardTierDTO]?
    let requiredStamps: Int?
    let stampRewardLabel: String?
    let stampMidRewardLabel: String?
    let stampEmoji: String?
    let pointsPerTicket: Int?
    let expiryMonths: Int?
    let sector: String?
    let baselineAvgBasketEur: Double?

    enum CodingKeys: String, CodingKey {
        case programType = "program_type"
        case loyaltyMode = "loyalty_mode"
        case pointsPerEuro = "points_per_euro"
        case pointsPerVisit = "points_per_visit"
        case pointsMinAmountEur = "points_min_amount_eur"
        case pointsRewardTiers = "points_reward_tiers"
        case requiredStamps = "required_stamps"
        case stampRewardLabel = "stamp_reward_label"
        case stampMidRewardLabel = "stamp_mid_reward_label"
        case stampEmoji = "stamp_emoji"
        case pointsPerTicket = "points_per_ticket"
        case expiryMonths = "expiry_months"
        case sector
        case baselineAvgBasketEur = "baseline_avg_basket_eur"
    }
}

struct MerchantAccountingPackSummaryDTO: Decodable, Sendable {
    let rowCount: Int?
    let byType: [String: Int]?
    let pointsCreditedTotal: Int?
    let pointsDebitedTotal: Int?
    let membersCount: Int?
    let engagementRows: Int?
    let ticketLedgerRows: Int?
    let rewardGrantRows: Int?
    let gameRewardDefinitions: Int?
    let deliveryClaimRows: Int?
    /// Somme indicative passif (clé API `passif_estime_sum_eur` ou ancienne `passif_estime_sum_eur_implied_points`).
    let passifEstimeSumEurImpliedPoints: Double?
    let valuationMode: String?

    enum CodingKeys: String, CodingKey {
        case rowCount = "row_count"
        case byType = "by_type"
        case pointsCreditedTotal = "points_credited_total"
        case pointsDebitedTotal = "points_debited_total"
        case membersCount = "members_count"
        case engagementRows = "engagement_rows"
        case ticketLedgerRows = "ticket_ledger_rows"
        case rewardGrantRows = "reward_grant_rows"
        case gameRewardDefinitions = "game_reward_definitions"
        case deliveryClaimRows = "delivery_claim_rows"
        case passifEstimeSumEur = "passif_estime_sum_eur"
        case passifEstimeSumEurImpliedPointsLegacy = "passif_estime_sum_eur_implied_points"
        case valuationMode = "valuation_mode"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rowCount = try c.decodeIfPresent(Int.self, forKey: .rowCount)
        byType = try c.decodeIfPresent([String: Int].self, forKey: .byType)
        pointsCreditedTotal = try c.decodeIfPresent(Int.self, forKey: .pointsCreditedTotal)
        pointsDebitedTotal = try c.decodeIfPresent(Int.self, forKey: .pointsDebitedTotal)
        membersCount = try c.decodeIfPresent(Int.self, forKey: .membersCount)
        engagementRows = try c.decodeIfPresent(Int.self, forKey: .engagementRows)
        ticketLedgerRows = try c.decodeIfPresent(Int.self, forKey: .ticketLedgerRows)
        rewardGrantRows = try c.decodeIfPresent(Int.self, forKey: .rewardGrantRows)
        gameRewardDefinitions = try c.decodeIfPresent(Int.self, forKey: .gameRewardDefinitions)
        deliveryClaimRows = try c.decodeIfPresent(Int.self, forKey: .deliveryClaimRows)
        passifEstimeSumEurImpliedPoints =
            try c.decodeIfPresent(Double.self, forKey: .passifEstimeSumEur)
            ?? c.decodeIfPresent(Double.self, forKey: .passifEstimeSumEurImpliedPointsLegacy)
        valuationMode = try c.decodeIfPresent(String.self, forKey: .valuationMode)
    }
}

struct MerchantAccountingPackFileDTO: Decodable, Sendable, Identifiable {
    var id: String { filename }
    let filename: String
    let mimeType: String?
    let contentUtf8: String?

    enum CodingKeys: String, CodingKey {
        case filename
        case mimeType = "mime_type"
        case contentUtf8 = "content_utf8"
    }
}

