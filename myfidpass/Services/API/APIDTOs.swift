//
//  APIDTOs.swift
//  myfidpass
//
//  Modèles de réponse alignés sur l’API MyFidpass (api.myfidpass.fr).
//

import Foundation

// MARK: - Auth (login, google, apple)

struct AuthLoginResponse: Decodable {
    let user: AuthUser
    let token: String
    let businesses: [BusinessDTO]
}

struct AuthUser: Decodable {
    let id: String?
    let email: String?
    let name: String?
}

struct BusinessDTO: Decodable {
    let id: String
    let name: String
    let slug: String
    let organizationName: String?
    let createdAt: String?
    let dashboardToken: String?
}

// MARK: - GET /api/auth/config

struct AuthConfigResponse: Decodable {
    let googleClientId: String?
}

// MARK: - GET /api/auth/me

struct AuthMeResponse: Decodable {
    let user: AuthUser
    let businesses: [BusinessDTO]
    let subscription: SubscriptionDTO?
    let hasActiveSubscription: Bool?
}

struct SubscriptionDTO: Decodable {
    let status: String?
    let planId: String?
}

// MARK: - GET .../dashboard/settings

struct BusinessSettingsResponse: Decodable {
    let organizationName: String?
    let backgroundColor: String?
    let foregroundColor: String?
    let labelColor: String?
    let backTerms: String?
    let backContact: String?
    let locationLat: Double?
    let locationLng: Double?
    let locationAddress: String?
    let requiredStamps: Int?
    let stampEmoji: String?
    let stampRewardLabel: String?
    let programType: String?
    let pointsPerEuro: Int?
    let pointsPerVisit: Int?
    let pointsMinAmountEur: Double?
    let pointsRewardTiers: [PointsRewardTierDTO]?
    let expiryMonths: Int?
    let sector: String?
    let logoUrl: String?
    /// Date ISO8601 de la dernière mise à jour du logo côté serveur (pour last-write-wins avec l’app).
    let logoUpdatedAt: String?
}

struct PointsRewardTierDTO: Decodable {
    let points: Int
    let label: String
}

// MARK: - GET .../dashboard/stats

struct BusinessStatsResponse: Decodable {
    let membersCount: Int?
    let pointsThisMonth: Int?
    let transactionsThisMonth: Int?
    let newMembersLast7Days: Int?
    let newMembersLast30Days: Int?
    let businessName: String?
}

// MARK: - GET .../dashboard/members

struct BusinessMembersResponse: Decodable {
    let members: [MemberDTO]
    let total: Int?
}

struct MemberDTO: Decodable {
    let id: String
    let name: String?
    let email: String?
    let points: Int?
    let createdAt: String?
    let lastVisitAt: String?
    /// Identifiants des catégories auxquelles le membre appartient (sync backend).
    let categoryIds: [String]?
}

// MARK: - GET .../dashboard/transactions

struct BusinessTransactionsResponse: Decodable {
    let transactions: [TransactionDTO]
    let total: Int?
}

struct TransactionDTO: Decodable {
    let id: String?
    let memberId: String?
    let memberName: String?
    let memberEmail: String?
    let type: String?
    let points: Int?
    let metadata: String?
    let createdAt: String?
}

// MARK: - GET .../integration/lookup (identifier un membre sans créditer)

struct ScanLookupResponse: Decodable {
    let member: ScanMemberDTO
}

// MARK: - POST .../integration/scan

struct ScanResponse: Decodable {
    let member: ScanMemberDTO
    let pointsAdded: Int?
    let newBalance: Int?
}

struct ScanMemberDTO: Decodable {
    let id: String?
    let name: String?
    let email: String?
    let points: Int?
    let lastVisitAt: String?
}

// MARK: - POST .../members/:memberId/redeem

struct RedeemResponse: Decodable {
    let ok: Bool?
    let type: String?
    let newPoints: Int?
    let previousPoints: Int?
    let pointsDeducted: Int?
    let message: String?
}

// MARK: - Catégories de membres (GET .../dashboard/categories)

struct BusinessCategoriesResponse: Decodable {
    let categories: [CategoryDTO]
}

struct CategoryDTO: Decodable {
    let id: String
    let name: String
    let colorHex: String?
    let sortOrder: Int?
}
