//
//  APIDTOs+12_GET.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

// MARK: - GET .../integration/lookup (identifier un membre sans créditer)

struct ScanRewardRedeemPreviewDTO: Decodable {
    let mode: String?
    let label: String?
    let tierIndex: Int?
    let tierImageURL: String?
    let pointsRequired: Int?
    let pointsBalance: Int?
    let eligible: Bool?

    enum CodingKeys: String, CodingKey {
        case mode
        case label
        case tierIndex = "tier_index"
        case tierImageURL = "tier_image_url"
        case pointsRequired = "points_required"
        case pointsBalance = "points_balance"
        case eligible
    }
}

struct ScanLookupResponse: Decodable {
    let member: ScanMemberDTO
    let rewardRedeem: ScanRewardRedeemPreviewDTO?
}

struct IntegrationRewardRedeemResponse: Decodable {
    let ok: Bool?
    let type: String?
    let rewardLabel: String?
    let pointsDeducted: Int?
    let previousPoints: Int?
    let newPoints: Int?
    let tierIndex: Int?
    let message: String?
    let member: ScanMemberDTO?

    enum CodingKeys: String, CodingKey {
        case ok, type, message, member
        case rewardLabel = "reward_label"
        case pointsDeducted = "points_deducted"
        case previousPoints = "previous_points"
        case newPoints = "new_points"
        case tierIndex = "tier_index"
    }
}

