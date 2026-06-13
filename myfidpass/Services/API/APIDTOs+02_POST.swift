//
//  APIDTOs+02_POST.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

// MARK: - POST /api/auth/refresh

struct AuthRefreshResponse: Decodable {
    let token: String
    let refreshToken: String?
    let subscription: SubscriptionDTO?
    let hasActiveSubscription: Bool?
    let merchantTrialEndsAt: String?
    let entitlements: MerchantEntitlementsDTO?

    enum CodingKeys: String, CodingKey {
        case token
        case refreshToken
        case subscription
        case hasActiveSubscription
        case merchantTrialEndsAt
        case entitlements
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        token = try c.decode(String.self, forKey: .token)
        refreshToken = try c.decodeIfPresent(String.self, forKey: .refreshToken)
        subscription = try c.decodeIfPresent(SubscriptionDTO.self, forKey: .subscription)
        hasActiveSubscription = decodeFlexibleOptionalBool(container: c, key: .hasActiveSubscription)
        merchantTrialEndsAt = try c.decodeIfPresent(String.self, forKey: .merchantTrialEndsAt)
        entitlements = try c.decodeIfPresent(MerchantEntitlementsDTO.self, forKey: .entitlements)
    }
}

