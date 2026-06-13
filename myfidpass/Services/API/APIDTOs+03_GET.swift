//
//  APIDTOs+03_GET.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

// MARK: - GET /api/auth/me

struct AuthMeResponse: Decodable {
    let user: AuthUser
    let businesses: [BusinessDTO]
    let subscription: SubscriptionDTO?
    let hasActiveSubscription: Bool?
    let hasPaidMerchantSubscription: Bool?
    let merchantTrialEndsAt: String?
    let entitlements: MerchantEntitlementsDTO?

    enum CodingKeys: String, CodingKey {
        case user
        case businesses
        case subscription
        case hasActiveSubscription
        case hasPaidMerchantSubscription
        case merchantTrialEndsAt
        case entitlements
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        user = try c.decode(AuthUser.self, forKey: .user)
        businesses = try c.decodeIfPresent([BusinessDTO].self, forKey: .businesses) ?? []
        subscription = try c.decodeIfPresent(SubscriptionDTO.self, forKey: .subscription)
        hasActiveSubscription = decodeFlexibleOptionalBool(container: c, key: .hasActiveSubscription)
        hasPaidMerchantSubscription = decodeFlexibleOptionalBool(container: c, key: .hasPaidMerchantSubscription)
        merchantTrialEndsAt = try c.decodeIfPresent(String.self, forKey: .merchantTrialEndsAt)
        entitlements = try c.decodeIfPresent(MerchantEntitlementsDTO.self, forKey: .entitlements)
    }
}

struct SubscriptionDTO: Decodable {
    let status: String?
    let planId: String?

    init(status: String?, planId: String?) {
        self.status = status
        self.planId = planId
    }
}

