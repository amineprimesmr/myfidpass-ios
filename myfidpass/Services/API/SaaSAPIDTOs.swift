//
//  SaaSAPIDTOs.swift
//  myfidpass
//
//  Modèles alignés sur l’API fidelity (dashboard, jeux, engagement, notifications avancées).
//

import Foundation

// MARK: - Décodage API (Int / Bool tolérants)

private enum SaaSAPIDecodingHelpers {
    static func losslessInt<K: CodingKey>(_ c: KeyedDecodingContainer<K>, forKey key: K) -> Int? {
        if let n = try? c.decode(Int.self, forKey: key) { return n }
        if let d = try? c.decode(Double.self, forKey: key) { return Int(d) }
        if let s = try? c.decode(String.self, forKey: key), let n = Int(s) { return n }
        return nil
    }

    static func boolish<K: CodingKey>(_ c: KeyedDecodingContainer<K>, forKey key: K) -> Bool? {
        if let b = try? c.decode(Bool.self, forKey: key) { return b }
        if let n = try? c.decode(Int.self, forKey: key) { return n != 0 }
        if let s = try? c.decode(String.self, forKey: key) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if t == "true" || t == "1" { return true }
            if t == "false" || t == "0" { return false }
        }
        return nil
    }
}

// MARK: - Évolution

struct DashboardEvolutionResponse: Codable, Sendable {
    let evolution: [EvolutionWeekDTO]
}

struct EvolutionWeekDTO: Codable, Sendable {
    let weekIndex: Int?
    let dayOfMonth: Int?
    let operationsCount: Int?
    let membersCount: Int?
    /// Cumul d’inscriptions depuis le 1er du mois jusqu’au jour `dayOfMonth` (courbe Membres).
    let newMembersInMonth: Int?
    /// Panier moyen cumulé du 1er au jour `dayOfMonth` (valeur de référence).
    let avgBasketEurInMonth: Double?
    /// Panier moyen sur l’intervalle entre deux jalons (courbe KPI — varie jour par jour).
    let avgBasketEurInInterval: Double?
    /// Cumul des montants € crédités du 1er au jour `dayOfMonth` (forme de courbe KPI).
    let basketTotalEurInMonth: Double?

    init(
        weekIndex: Int? = nil,
        dayOfMonth: Int? = nil,
        operationsCount: Int? = nil,
        membersCount: Int? = nil,
        newMembersInMonth: Int? = nil,
        avgBasketEurInMonth: Double? = nil,
        avgBasketEurInInterval: Double? = nil,
        basketTotalEurInMonth: Double? = nil
    ) {
        self.weekIndex = weekIndex
        self.dayOfMonth = dayOfMonth
        self.operationsCount = operationsCount
        self.membersCount = membersCount
        self.newMembersInMonth = newMembersInMonth
        self.avgBasketEurInMonth = avgBasketEurInMonth
        self.avgBasketEurInInterval = avgBasketEurInInterval
        self.basketTotalEurInMonth = basketTotalEurInMonth
    }

    private enum K: String, CodingKey {
        case weekIndex = "week_index"
        case weekIndexLegacy = "weekIndex"
        case dayOfMonth = "day_of_month"
        case dayOfMonthLegacy = "dayOfMonth"
        case operationsCount = "operations_count"
        case operationsCountLegacy = "operationsCount"
        case membersCount = "members_count"
        case membersCountLegacy = "membersCount"
        case newMembersInMonth = "new_members_in_month"
        case newMembersInMonthLegacy = "newMembersInMonth"
        case avgBasketEurInMonth = "avg_basket_eur_in_month"
        case avgBasketEurInInterval = "avg_basket_eur_in_interval"
        case basketTotalEurInMonth = "basket_total_eur_in_month"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        weekIndex = try c.decodeIfPresent(Int.self, forKey: .weekIndex)
            ?? c.decodeIfPresent(Int.self, forKey: .weekIndexLegacy)
        dayOfMonth = try c.decodeIfPresent(Int.self, forKey: .dayOfMonth)
            ?? c.decodeIfPresent(Int.self, forKey: .dayOfMonthLegacy)
        operationsCount = try c.decodeIfPresent(Int.self, forKey: .operationsCount)
            ?? c.decodeIfPresent(Int.self, forKey: .operationsCountLegacy)
        membersCount = try c.decodeIfPresent(Int.self, forKey: .membersCount)
            ?? c.decodeIfPresent(Int.self, forKey: .membersCountLegacy)
        newMembersInMonth = try c.decodeIfPresent(Int.self, forKey: .newMembersInMonth)
            ?? c.decodeIfPresent(Int.self, forKey: .newMembersInMonthLegacy)
        avgBasketEurInMonth = try c.decodeIfPresent(Double.self, forKey: .avgBasketEurInMonth)
        avgBasketEurInInterval = try c.decodeIfPresent(Double.self, forKey: .avgBasketEurInInterval)
        basketTotalEurInMonth = try c.decodeIfPresent(Double.self, forKey: .basketTotalEurInMonth)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        try c.encodeIfPresent(weekIndex, forKey: .weekIndex)
        try c.encodeIfPresent(dayOfMonth, forKey: .dayOfMonth)
        try c.encodeIfPresent(operationsCount, forKey: .operationsCount)
        try c.encodeIfPresent(membersCount, forKey: .membersCount)
        try c.encodeIfPresent(newMembersInMonth, forKey: .newMembersInMonth)
        try c.encodeIfPresent(avgBasketEurInMonth, forKey: .avgBasketEurInMonth)
        try c.encodeIfPresent(avgBasketEurInInterval, forKey: .avgBasketEurInInterval)
        try c.encodeIfPresent(basketTotalEurInMonth, forKey: .basketTotalEurInMonth)
    }
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

// MARK: - Challenge pronostics foot

struct MatchPredictionsDashboardResponse: Decodable {
    let config: MatchPredictionConfigDTO?
    /// Prochain match visible par les clients (pronostic unique).
    let nextMatch: MatchPredictionNextMatchDTO?
    let stats: MatchPredictionStatsDTO?
    /// Conservé pour rétrocompat — toujours vide côté serveur récent.
    let matches: [MatchPredictionMatchDTO]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        config = try c.decodeIfPresent(MatchPredictionConfigDTO.self, forKey: .config)
        nextMatch = try c.decodeIfPresent(MatchPredictionNextMatchDTO.self, forKey: .nextMatch)
        stats = try c.decodeIfPresent(MatchPredictionStatsDTO.self, forKey: .stats)
        matches = try c.decodeIfPresent([MatchPredictionMatchDTO].self, forKey: .matches) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case config, nextMatch, stats, matches
    }
}

struct MatchPredictionStatsDTO: Decodable {
    let totalPredictions: Int?
    let predictionsOnNextMatch: Int?

    enum CodingKeys: String, CodingKey {
        case totalPredictions
        case predictionsOnNextMatch
    }
}

/// Aperçu commerçant du prochain match (lecture seule).
struct MatchPredictionNextMatchDTO: Decodable, Identifiable {
    let id: String
    let title: String?
    let teamHome: String
    let teamAway: String
    let teamHomeFlag: String?
    let teamAwayFlag: String?
    let startsAt: String
    let roundLabel: String?
    let entriesCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, startsAt, roundLabel, entriesCount
        case teamHome, teamAway, teamHomeFlag, teamAwayFlag
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        teamHome = try c.decodeIfPresent(String.self, forKey: .teamHome) ?? "—"
        teamAway = try c.decodeIfPresent(String.self, forKey: .teamAway) ?? "—"
        teamHomeFlag = try c.decodeIfPresent(String.self, forKey: .teamHomeFlag)
        teamAwayFlag = try c.decodeIfPresent(String.self, forKey: .teamAwayFlag)
        startsAt = try c.decodeIfPresent(String.self, forKey: .startsAt) ?? ""
        roundLabel = try c.decodeIfPresent(String.self, forKey: .roundLabel)
        entriesCount = SaaSAPIDecodingHelpers.losslessInt(c, forKey: .entriesCount)
    }
}

struct MatchPredictionConfigDTO: Decodable {
    let enabled: Bool?
    let pointsPerCorrectPrediction: Int?

    /// Clés camelCase : `APIClient` applique déjà `convertFromSnakeCase` / `convertToSnakeCase`.
    enum CodingKeys: String, CodingKey {
        case enabled
        case pointsPerCorrectPrediction
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = SaaSAPIDecodingHelpers.boolish(c, forKey: .enabled)
        pointsPerCorrectPrediction = SaaSAPIDecodingHelpers.losslessInt(c, forKey: .pointsPerCorrectPrediction)
    }
}

struct MatchPredictionMatchDTO: Decodable, Identifiable {
    let id: String
    let title: String?
    let teamHome: String
    let teamAway: String
    let startsAt: String
    let cutoffAt: String?
    let status: String?
    let resultChoice: String?
    let locked: Bool?
    let entriesCount: Int?
    let correctCount: Int?
    let pointsDistributed: Int?
    let stage: String?
    let roundLabel: String?

    enum CodingKeys: String, CodingKey {
        case id, title, status, locked, stage
        case teamHome, teamAway, startsAt, cutoffAt, resultChoice
        case entriesCount, correctCount, pointsDistributed, roundLabel
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        teamHome = try c.decodeIfPresent(String.self, forKey: .teamHome) ?? "—"
        teamAway = try c.decodeIfPresent(String.self, forKey: .teamAway) ?? "—"
        startsAt = try c.decodeIfPresent(String.self, forKey: .startsAt) ?? ""
        cutoffAt = try c.decodeIfPresent(String.self, forKey: .cutoffAt)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        resultChoice = try c.decodeIfPresent(String.self, forKey: .resultChoice)
        locked = SaaSAPIDecodingHelpers.boolish(c, forKey: .locked)
        entriesCount = SaaSAPIDecodingHelpers.losslessInt(c, forKey: .entriesCount)
        correctCount = SaaSAPIDecodingHelpers.losslessInt(c, forKey: .correctCount)
        pointsDistributed = SaaSAPIDecodingHelpers.losslessInt(c, forKey: .pointsDistributed)
        stage = try c.decodeIfPresent(String.self, forKey: .stage)
        roundLabel = try c.decodeIfPresent(String.self, forKey: .roundLabel)
    }

    var isGroupStage: Bool {
        (stage ?? "group").lowercased() == "group"
    }
}

struct MatchPredictionsConfigPatchResponse: Decodable {
    let ok: Bool?
    let config: MatchPredictionConfigDTO?
}

struct MatchPredictionsConfigPatchBody: Encodable {
    let enabled: Bool
    let pointsPerCorrectPrediction: Int

    enum CodingKeys: String, CodingKey {
        case enabled
        case pointsPerCorrectPrediction
    }
}

struct MatchPredictionsResultBody: Encodable {
    let resultChoice: String
}

struct MatchPredictionsResultResponse: Decodable {
    let ok: Bool?
    let awardedCount: Int?
    let correctCount: Int?
    let winnersCount: Int?

    enum CodingKeys: String, CodingKey {
        case ok, awardedCount, correctCount, winnersCount
    }
}

// MARK: - Notifications dashboard

struct NotificationSendPayload: Encodable {
    let title: String?
    let message: String
    let segment: String?
    /// `true` : n’envoyer le PassKit qu’au commerçant (même compte), pas aux autres membres.
    var testSelfOnly: Bool = false
    /// Multi-commerce : envoyer la même campagne vers plusieurs slugs (propriétaire / équipe).
    var businessSlugs: [String]? = nil

    enum CodingKeys: String, CodingKey {
        case title, message, segment
        case testSelfOnly = "test_self_only"
        case businessSlugs = "business_slugs"
    }
}

struct NotificationCampaignSendResultDTO: Decodable {
    let slug: String?
    let ok: Bool?
    let accepted: Bool?
    let code: String?
    let message: String?
    let jobId: String?
    let batchId: String?
    let totalDevices: Int?
    /// Vrais clients touchés par la campagne (filtre technique appliqué, = dispatch backend).
    let deliverableDevices: Int?
    /// Carte d’aperçu du commerçant (testable via auto-test, hors campagne réelle).
    let previewDevices: Int?
    let businessName: String?
    let membersCount: Int?
}

struct NotificationBusinessReadinessDTO: Decodable, Identifiable {
    var id: String { slug ?? businessId ?? UUID().uuidString }
    let slug: String?
    let businessId: String?
    let name: String?
    let organizationName: String?
    let loyaltyGroupId: String?
    let hasNotificationIcon: Bool?
    let passkitDeviceCount: Int?
    let passkitRegistrationCount: Int?
    let webPushCount: Int?
    let totalDevices: Int?
    /// Vrais clients que la campagne touchera (filtre technique appliqué côté backend, = dispatch).
    let deliverableDevices: Int?
    /// Carte d’aperçu du commerçant : testable via auto-test, hors campagne réelle.
    let previewDevices: Int?
    /// `true` : seule la carte d’aperçu est enregistrée (0 vrai client) — prêt pour le test, pas pour une campagne.
    let previewOnly: Bool?
    /// Message d’action non bloquant (ex. « aperçu seulement, utilise Tester sur mon téléphone »).
    let deliveryHint: String?
    let membersCount: Int?
    let subscriptionOk: Bool?
    let ready: Bool?
    let blockCode: String?
    let blockMessage: String?

    var displayName: String {
        let n = (name ?? organizationName ?? slug ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Commerce" : n
    }

    /// Nombre de vrais clients destinataires (priorité au champ backend réconcilié, repli sur le total).
    var realClientDeviceCount: Int {
        deliverableDevices ?? totalDevices ?? 0
    }
}

struct NotificationReadinessResponse: Decodable {
    let ok: Bool?
    let businesses: [NotificationBusinessReadinessDTO]?
}

struct NotificationSendResponse: Decodable {
    let ok: Bool?
    let sent: Int?
    let sentWebPush: Int?
    let sentPassKit: Int?
    /// Total d’appareils ciblés (réponse dashboard / fidelity).
    let total: Int?
    let failed: Int?
    let message: String?
    let testSelfOnly: Bool?
    /// `true` : réponse d’un auto-test (livraison sur la carte d’aperçu du commerçant).
    let selfTest: Bool?
    /// Code métier : `no_real_clients`, `self_test_sent`, `self_test_failed`, `no_preview_card`, `no_preview_device`…
    let code: String?
    /// `true` : HTTP 202 — l’envoi continue sur le serveur (évite timeout sur gros volumes).
    let accepted: Bool?
    let asyncDelivery: Bool?
    let multi: Bool?
    let results: [NotificationCampaignSendResultDTO]?
    let jobId: String?
    let batchId: String?
    // Pas de CodingKeys snake_case ici : APIClient décode avec `.convertFromSnakeCase`,
    // un rawValue `"job_id"` ne matcherait jamais (clé convertie en `jobId` avant lookup).
}

struct CampaignSegmentsResponse: Decodable {
    let inactive14: Int?
    let inactive30: Int?
    let inactive60: Int?
    let inactive90: Int?
    let new7: Int?
    let new30: Int?
    let welcomeNew: Int?
    let pointsNear50: Int?
    let points50: Int?
    let recurrent: Int?
    let birthdayToday: Int?

    /// Quand l’endpoint segments renvoie 404 (route absente ou commerce sans données), l’UI continue sans effectifs.
    static let empty = CampaignSegmentsResponse(
        inactive14: nil,
        inactive30: nil,
        inactive60: nil,
        inactive90: nil,
        new7: nil,
        new30: nil,
        welcomeNew: nil,
        pointsNear50: nil,
        points50: nil,
        recurrent: nil,
        birthdayToday: nil
    )
}

// MARK: - Campagnes automatiques (GET/PATCH dashboard/settings)

struct CampaignAutomationRuleDTO: Codable, Equatable {
    var enabled: Bool?
    var message: String?
    /// Segment API (`inactive14`, `new7`, …) — obligatoire pour les règles dont `id` commence par `custom_`.
    var segment: String?
    /// Libellé dans l’app (automatisations personnalisées).
    var title: String?

    /// Type d’évènement (v1). Utilisé pour les règles dont `id` commence par `event_`.
    /// Exemple v1 : `member_created`.
    var eventType: String? = nil

    /// Délai avant envoi, en minutes (v1). Utilisé pour les règles `event_`.
    var delayMinutes: Int? = nil

    enum CodingKeys: String, CodingKey {
        case enabled, message, segment, title, eventType, delayMinutes
    }
}

struct CampaignAutomationConfigDTO: Codable, Equatable {
    var version: Int?
    /// Délai minimum entre deux notifications pour un même client (tous scénarios confondus).
    var globalCooldownDays: Int?
    var rules: [String: CampaignAutomationRuleDTO]?

    enum CodingKeys: String, CodingKey {
        case version
        case globalCooldownDays = "global_cooldown_days"
        case rules
    }
}

/// Réponse `POST .../dashboard/members/delete-all`.
struct DeleteAllMembersResponse: Decodable {
    let ok: Bool?
    let deleted: Int?
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
    /// Exemple de commande documentée côté SaaS (endpoint diagnostic PassKit).
    let testPasskitCurl: String?
    /// Clé APNs optionnelle (MERCHANT_APNS_* sur le backend) ; l’ajout Apple Wallet utilise PassKit.
    let merchantAppPushConfigured: Bool?
    /// Détail diagnostic si la clé MERCHANT_APNS n’est pas configurée.
    let merchantAppPushDetail: String?
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

struct CampaignAutomationAIParseRequestDTO: Encodable {
    let instruction: String
}

struct CampaignAutomationAIParseResponseDTO: Decodable {
    let mode: String?
    let title: String?
    let message: String?
    let eventType: String?
    let delayMinutes: Int?
    let confidence: Double?
    let source: String?
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

    init(grantId: String?, status: String?, reward: MemberRewardNestedDTO?) {
        self.grantId = grantId
        self.status = status
        self.reward = reward
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        grantId = try c.decodeIfPresent(String.self, forKey: .grantId)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        reward = try c.decodeIfPresent(MemberRewardNestedDTO.self, forKey: .reward)
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
    /// Aligné sur `POST /api/payment/create-checkout-session` (`req.body.plan`).
    let plan: String
}

struct BusinessCheckoutSessionPayload: Encodable {
    let businessSlug: String
    let interval: String?

    enum CodingKeys: String, CodingKey {
        case businessSlug = "business_slug"
        case interval
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(businessSlug, forKey: .businessSlug)
        if let interval, !interval.isEmpty {
            try c.encode(interval, forKey: .interval)
        }
    }
}

struct PaymentReconcileEmptyBody: Encodable {}

/// POST /api/payment/reconcile-subscription — réaligne la base sur Stripe pour l’email du compte connecté.
struct PaymentReconcileSubscriptionResponse: Decodable {
    let ok: Bool?
    let hasActiveSubscription: Bool?
    let message: String?
    let subscriptionStatus: String?
}

// MARK: - Paiement App Store (StoreKit 2)

struct PaymentAppleSyncTransactionPayload: Encodable {
    let signedTransactionInfo: String?
    let transactionId: String?

    enum CodingKeys: String, CodingKey {
        case signedTransactionInfo = "signed_transaction_info"
        case transactionId = "transaction_id"
    }
}

struct PaymentAppleSyncResponse: Decodable {
    let ok: Bool?
    let hasActiveSubscription: Bool?
    let hasPaidMerchantSubscription: Bool?
    let subscriptionStatus: String?
    let entitlements: MerchantEntitlementsDTO?
    let allowedBusinesses: Int?
    let usedBusinesses: Int?
    let canCreateBusiness: Bool?

    enum CodingKeys: String, CodingKey {
        case ok
        case hasActiveSubscription = "has_active_subscription"
        case hasPaidMerchantSubscription = "has_paid_merchant_subscription"
        case subscriptionStatus = "subscription_status"
        case entitlements
        case allowedBusinesses = "allowed_businesses"
        case usedBusinesses = "used_businesses"
        case canCreateBusiness = "can_create_business"
    }
}

struct PaymentAppleReconcileResponse: Decodable {
    let ok: Bool?
    let hasActiveSubscription: Bool?
    let message: String?
}

/// POST /api/payment/apple/introductory-offer-eligibility
struct PaymentAppleIntroOfferEligibilityRequest: Encodable {
    let productId: String
    let transactionId: String

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case transactionId = "transaction_id"
    }
}

struct PaymentAppleIntroOfferEligibilityResponse: Decodable {
    let ok: Bool?
    let allowIntroductoryOffer: Bool?
    let compactJws: String?
    let offerCodeHint: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case allowIntroductoryOffer = "allow_introductory_offer"
        case compactJws = "compact_jws"
        case offerCodeHint = "offer_code_hint"
        case message
    }
}

// MARK: - Inscription / mot de passe

struct AuthRegisterPayload: Encodable {
    let email: String
    let password: String
    let name: String?
    let googlePlaceId: String?
    let establishmentName: String?
    let establishments: [AuthEstablishmentPayload]?
}

struct AuthEstablishmentPayload: Encodable {
    let googlePlaceId: String
    let establishmentName: String

    enum CodingKeys: String, CodingKey {
        case googlePlaceId = "google_place_id"
        case establishmentName = "establishment_name"
    }
}

// MARK: - Google Places (onboarding inscription, aligné SaaS)

struct PlacesAutocompleteResponse: Decodable {
    let predictions: [PlaceAutocompletePrediction]
}

struct PlaceAutocompletePrediction: Decodable {
    let placeId: String
    let description: String
    let mainText: String?
    let secondaryText: String?
}

/// GET /api/places/details — nom + adresse à partir du seul place_id (affichage sans nouvelle recherche).
struct PlacesPlaceDetailsResponse: Decodable {
    let placeId: String
    let name: String?
    let formattedAddress: String?
    /// Lien officiel Google Maps → onglet Avis (`googleMapsLinks.reviewsUri`).
    let googleMapsReviewsUri: String?

    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case name
        case formattedAddress = "formatted_address"
        case googleMapsReviewsUri = "google_maps_reviews_uri"
    }
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

struct CreateBusinessFromPlacePayload: Encodable {
    let establishmentName: String
    let googlePlaceId: String

    enum CodingKeys: String, CodingKey {
        case establishmentName = "establishment_name"
        case googlePlaceId = "google_place_id"
    }
}

struct CreateBusinessFromPlaceResponse: Decodable {
    let id: String?
    let name: String?
    let slug: String?
    let organizationName: String?
    let dashboardToken: String?
    let businesses: [BusinessDTO]?
}

struct SimpleAPIOKResponse: Decodable {
    let ok: Bool?
}

struct ForgotPasswordAPIResponse: Decodable {
    let message: String?
}
