//
//  SaaSAPIDTOs.swift
//  myfidpass
//
//  Modèles alignés sur l’API fidelity (dashboard, jeux, engagement, notifications avancées).
//

import Foundation

// MARK: - Évolution

struct DashboardEvolutionResponse: Decodable, Sendable {
    let evolution: [EvolutionWeekDTO]
}

struct EvolutionWeekDTO: Decodable, Sendable {
    let weekIndex: Int?
    let operationsCount: Int?
    let membersCount: Int?
}

// MARK: - Jeux

struct DashboardGamesResponse: Decodable {
    let games: [BusinessGameDTO]
}

struct BusinessGameDTO: Decodable, Identifiable {
    let rowId: String?
    let gameCode: String?
    let gameName: String?
    let enabled: Bool?
    let ticketCost: Int?
    let dailySpinLimit: Int?
    let cooldownSeconds: Int?

    var id: String { rowId ?? gameCode ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case rowId = "id"
        case gameCode = "game_code"
        case gameName = "game_name"
        case enabled
        case ticketCost = "ticket_cost"
        case dailySpinLimit = "daily_spin_limit"
        case cooldownSeconds = "cooldown_seconds"
    }
}

struct GameRewardsResponse: Decodable {
    let rewards: [GameRewardDTO]
}

struct GameRewardDTO: Decodable, Identifiable {
    let rawId: String?
    let code: String?
    let label: String?
    let kind: String?
    let value: GameRewardValueDTO?
    let stock: Int?
    let active: Bool?
    let weight: Int?

    var id: String { rawId ?? code ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case rawId = "id"
        case code, label, kind, value, stock, active, weight
    }
}

struct GameRewardValueDTO: Decodable {
    let points: Int?
    let stamps: Int?
}

struct PutGameRewardsBody: Encodable {
    let rewards: [GameRewardInput]
}

struct GameRewardInput: Encodable {
    let code: String
    let label: String
    let kind: String
    let weight: Int
    let active: Bool
    let stock: Int?
    let value: GameRewardValueInput?

    struct GameRewardValueInput: Encodable {
        let points: Int?
        let stamps: Int?
    }
}

struct PatchGameBody: Encodable {
    var enabled: Bool?
    var ticketCost: Int?
    var dailySpinLimit: Int?
    var cooldownSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case enabled
        case ticketCost = "ticket_cost"
        case dailySpinLimit = "daily_spin_limit"
        case cooldownSeconds = "cooldown_seconds"
    }
}

// MARK: - Notifications dashboard

struct NotificationSendPayload: Encodable {
    let title: String?
    let message: String
    let categoryIds: [String]?
    let segment: String?

    enum CodingKeys: String, CodingKey {
        case title, message, segment
        case categoryIds = "category_ids"
    }
}

struct NotificationSendResponse: Decodable {
    let ok: Bool?
    let sent: Int?
    let sentWebPush: Int?
    let sentPassKit: Int?
    let message: String?
}

struct CampaignSegmentsResponse: Decodable {
    let inactive30: Int?
    let inactive90: Int?
    let new30: Int?
    let recurrent: Int?
    let points50: Int?
}

struct NotificationChannelStatsResponse: Decodable {
    let subscriptionsCount: Int?
    let membersCount: Int?
    let webPushCount: Int?
    let passKitCount: Int?
    let passKitWithTokenCount: Int?
    let membersWithNotifications: Int?
    let passKitUrlConfigured: Bool?
    let diagnostic: String?
    let helpWhenNoDevice: String?
    let paradoxExplanation: String?
    let dataDirHint: String?
    let membersVsDevicesExplanation: String?
}

struct TestPasskitResponse: Decodable {
    let ok: Bool?
    let message: String?
    let curl: String?
    let memberId: String?
}

struct RemoveTestDeviceResponse: Decodable {
    let ok: Bool?
    let removed: Int?
    let message: String?
}

// MARK: - Notify (alias iOS)

struct NotifyClientsResult: Decodable {
    let ok: Bool?
    let sent: Int?
    let sentWebPush: Int?
    let sentPassKit: Int?
}

// MARK: - Import / création membre

struct MembersImportPayload: Encodable {
    let members: [MemberImportRow]
    let onDuplicate: String

    enum CodingKeys: String, CodingKey {
        case members
        case onDuplicate = "onDuplicate"
    }

    struct MemberImportRow: Encodable {
        let email: String
        let name: String
        let points: Int?
    }
}

struct MembersImportResponse: Decodable {
    let created: Int?
    let updated: Int?
    let skipped: Int?
    let errors: Int?
}

struct CreateMemberPayload: Encodable {
    let email: String
    let name: String
}

struct CreateMemberResponse: Decodable {
    let memberId: String?
    let member: ScanMemberDTO?
}

// MARK: - Fiche membre API publique

struct MemberPublicDetailResponse: Decodable {
    let id: String?
    let email: String?
    let name: String?
    let points: Int?
    let lastVisitAt: String?
    let phone: String?
    let city: String?
    let birthDate: String?
}

// MARK: - Tickets / récompenses jeu

struct MemberTicketsResponse: Decodable {
    let ticketBalance: Int?
    let points: Int?
    let loyaltyMode: String?
    let pointsPerTicket: Int?

    enum CodingKeys: String, CodingKey {
        case ticketBalance = "ticket_balance"
        case points
        case loyaltyMode = "loyalty_mode"
        case pointsPerTicket = "points_per_ticket"
    }
}

struct MemberRewardsListResponse: Decodable {
    let rewards: [MemberGameRewardDTO]
}

struct MemberGameRewardDTO: Decodable, Identifiable {
    var id: String { grantId ?? UUID().uuidString }
    let grantId: String?
    let status: String?
    let reward: MemberRewardNestedDTO?

    enum CodingKeys: String, CodingKey {
        case grantId = "id"
        case status
        case reward
    }

    var displayLabel: String { reward?.label ?? reward?.code ?? "Récompense" }
}

struct MemberRewardNestedDTO: Decodable {
    let code: String?
    let label: String?
    let kind: String?
}

struct ClaimRewardResponse: Decodable {
    let ok: Bool?
}

struct GoogleWalletUrlResponse: Decodable {
    let url: String?
}

// MARK: - Paiement Stripe

struct CheckoutSessionResponse: Decodable {
    let url: String?
}

struct CheckoutSessionPayload: Encodable {
    let planId: String?
}

// MARK: - Inscription / mot de passe

struct AuthRegisterPayload: Encodable {
    let email: String
    let password: String
    let name: String?
}

struct ForgotPasswordPayload: Encodable {
    let email: String
}

struct ResetPasswordPayload: Encodable {
    let token: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case token
        case newPassword = "newPassword"
    }
}

// MARK: - Création commerce

struct CreateBusinessPayload: Encodable {
    let name: String
    let slug: String
    let organizationName: String?

    enum CodingKeys: String, CodingKey {
        case name, slug
        case organizationName = "organizationName"
    }
}

struct CreateBusinessResponse: Decodable {
    let id: String?
    let name: String?
    let slug: String?
    let organizationName: String?
    let dashboardToken: String?
}

struct SimpleAPIOKResponse: Decodable {
    let ok: Bool?
}

struct ForgotPasswordAPIResponse: Decodable {
    let message: String?
}
