//
//  APIDTOs+20_Rseauxfidlit.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

// MARK: - Réseaux fidélité (multi-adresses, carte unique)
// `APIClient` applique `convertFromSnakeCase` : pas de CodingKeys snake_case explicites (sinon décodage impossible).

struct LoyaltyGroupSummaryDTO: Decodable, Identifiable, Sendable {
    let id: String
    let name: String
    let createdAt: String?
    let updatedAt: String?
    let businessCount: Int?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
        businessCount = Self.decodeFlexibleInt(c, forKey: .businessCount)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, createdAt, updatedAt, businessCount
    }

    private static func decodeFlexibleInt(
        _ c: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Int? {
        if let n = try? c.decodeIfPresent(Int.self, forKey: key) { return n }
        if let s = try? c.decodeIfPresent(String.self, forKey: key),
           let n = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) { return n }
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return Int(d) }
        return nil
    }
}

struct LoyaltyGroupsListResponse: Decodable, Sendable {
    let loyaltyGroups: [LoyaltyGroupSummaryDTO]
}

struct LoyaltyGroupDTO: Decodable, Identifiable, Sendable {
    let id: String
    let name: String
    let ownerUserId: String?
    let createdAt: String?
    let updatedAt: String?
}

struct LoyaltyGroupBusinessLinkDTO: Decodable, Identifiable, Sendable {
    let id: String
    let name: String
    let slug: String
    let organizationName: String?
    let loyaltyGroupId: String?
    let programType: String?
    let requiredStamps: Int?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        var slugValue = (try c.decodeIfPresent(String.self, forKey: .slug) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if slugValue.isEmpty { slugValue = id }
        slug = slugValue
        organizationName = try c.decodeIfPresent(String.self, forKey: .organizationName)
        loyaltyGroupId = try c.decodeIfPresent(String.self, forKey: .loyaltyGroupId)
        programType = try c.decodeIfPresent(String.self, forKey: .programType)
        requiredStamps = Self.decodeFlexibleInt(c, forKey: .requiredStamps)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, slug, organizationName, loyaltyGroupId, programType, requiredStamps
    }

    private static func decodeFlexibleInt(
        _ c: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Int? {
        if let n = try? c.decodeIfPresent(Int.self, forKey: key) { return n }
        if let s = try? c.decodeIfPresent(String.self, forKey: key),
           let n = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) { return n }
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return Int(d) }
        return nil
    }
}

struct LoyaltyGroupDetailResponse: Decodable, Sendable {
    let loyaltyGroup: LoyaltyGroupDTO
    let businesses: [LoyaltyGroupBusinessLinkDTO]
}

struct LoyaltyGroupCreateResponse: Decodable, Sendable {
    let loyaltyGroup: LoyaltyGroupDTO
    let businesses: [LoyaltyGroupBusinessLinkDTO]
}

struct LoyaltyGroupLinkBusinessResponse: Decodable, Sendable {
    let loyaltyGroup: LoyaltyGroupDTO
    let business: LoyaltyGroupBusinessLinkDTO
}

struct LoyaltyGroupOkResponse: Decodable, Sendable {
    let ok: Bool?
}

struct LoyaltyGroupCreateBody: Encodable, Sendable {
    let name: String
    let businessIds: [String]?
}

struct LoyaltyGroupPatchBody: Encodable, Sendable {
    let name: String
}

struct LoyaltyGroupLinkBusinessBody: Encodable, Sendable {
    let businessId: String?
    let slug: String?
}

