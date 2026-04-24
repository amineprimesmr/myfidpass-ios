//
//  APIDTOs.swift
//  myfidpass
//
//  Modèles de réponse alignés sur l’API MyFidpass (api.myfidpass.fr).
//

import Foundation

/// Décode `has_active_subscription` même si l’API envoie 0/1 ou une chaîne (certains proxys / JSON atypiques).
private func decodeFlexibleOptionalBool<Key: CodingKey>(container: KeyedDecodingContainer<Key>, key: Key) -> Bool? {
    guard container.contains(key) else { return nil }
    if let b = try? container.decode(Bool.self, forKey: key) { return b }
    if let i = try? container.decode(Int.self, forKey: key) { return i != 0 }
    if let s = try? container.decode(String.self, forKey: key) {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t == "1" || t == "true" || t == "yes"
    }
    return nil
}

// MARK: - Auth (login, google, apple)

struct AuthLoginResponse: Decodable {
    let user: AuthUser
    let token: String
    let refreshToken: String?
    let businesses: [BusinessDTO]
    let subscription: SubscriptionDTO?
    let hasActiveSubscription: Bool?
    /// Fin d’essai gratuit commerçant (ISO 8601), si compte sans abonnement Stripe payant.
    let merchantTrialEndsAt: String?

    enum CodingKeys: String, CodingKey {
        case user
        case token
        case refreshToken
        case businesses
        case subscription
        case hasActiveSubscription
        case merchantTrialEndsAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        user = try c.decode(AuthUser.self, forKey: .user)
        token = try c.decode(String.self, forKey: .token)
        refreshToken = try c.decodeIfPresent(String.self, forKey: .refreshToken)
        businesses = try c.decodeIfPresent([BusinessDTO].self, forKey: .businesses) ?? []
        subscription = try c.decodeIfPresent(SubscriptionDTO.self, forKey: .subscription)
        hasActiveSubscription = decodeFlexibleOptionalBool(container: c, key: .hasActiveSubscription)
        merchantTrialEndsAt = try c.decodeIfPresent(String.self, forKey: .merchantTrialEndsAt)
    }

    /// Assemblage après OAuth Google (callback) quand `/me` a déjà été décodé.
    init(
        user: AuthUser,
        token: String,
        refreshToken: String?,
        businesses: [BusinessDTO],
        subscription: SubscriptionDTO? = nil,
        hasActiveSubscription: Bool? = nil,
        merchantTrialEndsAt: String? = nil
    ) {
        self.user = user
        self.token = token
        self.refreshToken = refreshToken
        self.businesses = businesses
        self.subscription = subscription
        self.hasActiveSubscription = hasActiveSubscription
        self.merchantTrialEndsAt = merchantTrialEndsAt
    }
}

struct AuthUser: Decodable {
    let id: String?
    let email: String?
    let name: String?
    /// Présent si le compte est lié à un numéro (connexion par SMS).
    let phone: String?
    /// Compte administrateur plateforme (`is_admin` côté API).
    let isAdmin: Bool?
    /// Rôle dans l’espace commerçant : `owner` | `manager` | `staff` (`workspace_role` API).
    let workspaceRole: String?

    enum CodingKeys: String, CodingKey {
        case id, email, name, phone
        case isAdmin = "is_admin"
        case workspaceRole = "workspace_role"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        phone = try c.decodeIfPresent(String.self, forKey: .phone)
        isAdmin = try c.decodeIfPresent(Bool.self, forKey: .isAdmin)
        workspaceRole = try c.decodeIfPresent(String.self, forKey: .workspaceRole)
    }
}

struct BusinessDTO: Decodable {
    let id: String
    let name: String
    let slug: String
    let organizationName: String?
    let createdAt: String?
    let dashboardToken: String?

    /// Tolère champs manquants / vides côté API (sinon toute la synchro échoue sur `GET /me`).
    private enum CodingKeys: String, CodingKey {
        case id, name, slug, organizationName, createdAt, dashboardToken
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var rawId = (try c.decodeIfPresent(String.self, forKey: .id) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if rawId.isEmpty { rawId = "legacy-\(UUID().uuidString)" }
        id = rawId
        var n = (try c.decodeIfPresent(String.self, forKey: .name) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if n.isEmpty { n = "Commerce" }
        name = n
        var s = (try c.decodeIfPresent(String.self, forKey: .slug) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { s = id }
        slug = s
        organizationName = try c.decodeIfPresent(String.self, forKey: .organizationName)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        dashboardToken = try c.decodeIfPresent(String.self, forKey: .dashboardToken)
    }
}

// MARK: - GET /api/auth/config

struct AuthConfigResponse: Decodable {
    let googleClientId: String?
}

// MARK: - POST /api/auth/refresh

struct AuthRefreshResponse: Decodable {
    let token: String
    let refreshToken: String?
    let subscription: SubscriptionDTO?
    let hasActiveSubscription: Bool?
    let merchantTrialEndsAt: String?

    enum CodingKeys: String, CodingKey {
        case token
        case refreshToken
        case subscription
        case hasActiveSubscription
        case merchantTrialEndsAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        token = try c.decode(String.self, forKey: .token)
        refreshToken = try c.decodeIfPresent(String.self, forKey: .refreshToken)
        subscription = try c.decodeIfPresent(SubscriptionDTO.self, forKey: .subscription)
        hasActiveSubscription = decodeFlexibleOptionalBool(container: c, key: .hasActiveSubscription)
        merchantTrialEndsAt = try c.decodeIfPresent(String.self, forKey: .merchantTrialEndsAt)
    }
}

// MARK: - GET /api/auth/me

struct AuthMeResponse: Decodable {
    let user: AuthUser
    let businesses: [BusinessDTO]
    let subscription: SubscriptionDTO?
    let hasActiveSubscription: Bool?
    let merchantTrialEndsAt: String?

    enum CodingKeys: String, CodingKey {
        case user
        case businesses
        case subscription
        case hasActiveSubscription
        case merchantTrialEndsAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        user = try c.decode(AuthUser.self, forKey: .user)
        businesses = try c.decodeIfPresent([BusinessDTO].self, forKey: .businesses) ?? []
        subscription = try c.decodeIfPresent(SubscriptionDTO.self, forKey: .subscription)
        hasActiveSubscription = decodeFlexibleOptionalBool(container: c, key: .hasActiveSubscription)
        merchantTrialEndsAt = try c.decodeIfPresent(String.self, forKey: .merchantTrialEndsAt)
    }
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
    /// Rayon en mètres pour la pertinence à proximité (Apple Wallet ~100 m max pour carte magasin / fidélité).
    let locationRadiusMeters: Int?
    /// Message affiché / envoyé aux clients qui entrent dans le périmètre.
    let locationRelevantText: String?
    let locationAddress: String?
    /// 1 si le périmètre est embarqué dans le pass Wallet (géofence) ; 0 sinon (recommandé pour les campagnes visibles partout).
    let walletPassIncludeLocations: Int?
    let requiredStamps: Int?
    let stampEmoji: String?
    let stampRewardLabel: String?
    let stampMidRewardLabel: String?
    let programType: String?
    let loyaltyMode: String?
    let pointsPerTicket: Int?
    let pointsPerEuro: Int?
    let pointsPerVisit: Int?
    let pointsMinAmountEur: Double?
    let pointsRewardTiers: [PointsRewardTierDTO]?
    let expiryMonths: Int?
    let sector: String?
    let stripColor: String?
    let stripDisplayMode: String?
    let stripText: String?
    let labelRestants: String?
    let labelMember: String?
    let headerRightText: String?
    let notificationTitleOverride: String?
    let notificationChangeMessage: String?
    let logoUrl: String?
    /// Logo carré fiche / bandeau (URL `.../logo-icon`) — **pas** l’icône campagne.
    let logoIconUrl: String?
    /// Icône **campagnes / push** uniquement (`.../notification-icon`) lorsqu’un média dédié existe.
    let notificationIconUrl: String?
    let notificationIconUpdatedAt: String?
    let hasCardBackground: Bool?
    /// Invalide le cache HTTP / URLCache quand le fond change (query `?v=` côté app).
    let cardBackgroundUpdatedAt: String?
    let hasStampIcon: Bool?
    let stampIconUrl: String?
    let engagementRewards: EngagementRewardsDTO?
    /// Règles campagnes Wallet (automatisation + messages).
    let campaignAutomation: CampaignAutomationConfigDTO?
    /// Date ISO8601 de la dernière mise à jour du logo côté serveur (pour last-write-wins avec l’app).
    let logoUpdatedAt: String?
    let logoIconUpdatedAt: String?
    /// 0 ou absent côté app = illimité — crédits max par client / jour (UTC, serveur).
    let scanMaxPassesPerMemberPerDay: Int?
    /// Plafond de points par opération de crédit (scan ou fiche membre). 0 ou absent = illimité.
    let scanMaxPointsPerTransaction: Int?
    /// 1 = exiger un QR ticket (JWT) pour les crédits basés sur un montant €.
    let requireReceiptQrValidation: Int?
    /// Tolérance en centimes entre montant saisi et JWT (défaut 5).
    let receiptQrToleranceCents: Int?
}

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

    enum CodingKeys: String, CodingKey {
        case points
        case label
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
    }
}

// MARK: - GET .../dashboard/stats

struct NotificationCampaignInsightDTO: Codable, Sendable, Identifiable {
    var id: String { batchId }
    let batchId: String
    let triggerName: String?
    let createdAt: String?
    let sentTotal: Int?
    let recipientsDistinct: Int?
    /// Passages en caisse distincts (`points_add`) dans les 48 h après l’envoi de la campagne.
    let returnedWithin48h: Int?
    let notificationTitle: String?
    let message: String?
    let sentPasskit: Int?
    let sentWebPush: Int?

    enum CodingKeys: String, CodingKey {
        case batchId = "batch_id"
        case triggerName = "trigger_name"
        case createdAt = "created_at"
        case sentTotal = "sent_total"
        case recipientsDistinct = "recipients_distinct"
        case returnedWithin48h = "returned_within_48h"
        case returnedWithin7dLegacy = "returned_within_7d"
        case title
        case notificationTitle = "notification_title"
        case pushTitle = "push_title"
        case message
        case body
        case pushBody = "push_body"
        case content
        case messagePreview = "message_preview"
        case sentPasskit = "sent_passkit"
        case passkitSent = "passkit_sent"
        case sentWebPush = "sent_web_push"
        case sentWeb = "sent_web"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawBatch = (try c.decodeIfPresent(String.self, forKey: .batchId) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !rawBatch.isEmpty {
            batchId = rawBatch
        } else {
            // L’API peut renvoyer des entrées d’historique sans `batch_id` — ne pas bloquer
            // toute la synchro (`GET .../dashboard/stats`).
            let created = (try? c.decodeIfPresent(String.self, forKey: .createdAt)) ?? ""
            let trig = (try? c.decodeIfPresent(String.self, forKey: .triggerName)) ?? ""
            let st = (try? c.decodeIfPresent(Int.self, forKey: .sentTotal))
            var synthetic = "legacy"
            if !created.isEmpty { synthetic += ":\(created)" }
            if !trig.isEmpty { synthetic += ":\(trig)" }
            if let st { synthetic += ":\(st)" }
            if synthetic == "legacy" { synthetic = "legacy:\(UUID().uuidString)" }
            batchId = synthetic
        }
        triggerName = try c.decodeIfPresent(String.self, forKey: .triggerName)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        sentTotal = try c.decodeIfPresent(Int.self, forKey: .sentTotal)
        recipientsDistinct = try c.decodeIfPresent(Int.self, forKey: .recipientsDistinct)
        if let v = try c.decodeIfPresent(Int.self, forKey: .returnedWithin48h) {
            returnedWithin48h = v
        } else {
            returnedWithin48h = try c.decodeIfPresent(Int.self, forKey: .returnedWithin7dLegacy)
        }
        notificationTitle = Self.firstNonEmptyString(
            c,
            keys: [.title, .notificationTitle, .pushTitle]
        )
        message = Self.firstNonEmptyString(
            c,
            keys: [.message, .body, .pushBody, .content, .messagePreview]
        )
        sentPasskit = Self.firstInt(
            c,
            keys: [.sentPasskit, .passkitSent]
        )
        sentWebPush = Self.firstInt(
            c,
            keys: [.sentWebPush, .sentWeb]
        )
    }

    init(
        batchId: String,
        triggerName: String?,
        createdAt: String?,
        sentTotal: Int?,
        recipientsDistinct: Int?,
        returnedWithin48h: Int?,
        notificationTitle: String? = nil,
        message: String? = nil,
        sentPasskit: Int? = nil,
        sentWebPush: Int? = nil
    ) {
        self.batchId = batchId
        self.triggerName = triggerName
        self.createdAt = createdAt
        self.sentTotal = sentTotal
        self.recipientsDistinct = recipientsDistinct
        self.returnedWithin48h = returnedWithin48h
        self.notificationTitle = notificationTitle
        self.message = message
        self.sentPasskit = sentPasskit
        self.sentWebPush = sentWebPush
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(batchId, forKey: .batchId)
        try c.encodeIfPresent(triggerName, forKey: .triggerName)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(sentTotal, forKey: .sentTotal)
        try c.encodeIfPresent(recipientsDistinct, forKey: .recipientsDistinct)
        try c.encodeIfPresent(returnedWithin48h, forKey: .returnedWithin48h)
        try c.encodeIfPresent(notificationTitle, forKey: .title)
        try c.encodeIfPresent(message, forKey: .message)
        try c.encodeIfPresent(sentPasskit, forKey: .sentPasskit)
        try c.encodeIfPresent(sentWebPush, forKey: .sentWebPush)
    }

    private static func firstNonEmptyString(
        _ c: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> String? {
        for k in keys {
            guard let s = try? c.decodeIfPresent(String.self, forKey: k) else { continue }
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        return nil
    }

    private static func firstInt(
        _ c: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Int? {
        for k in keys {
            if let i = try? c.decodeIfPresent(Int.self, forKey: k) { return i }
        }
        return nil
    }
}

extension NotificationCampaignInsightDTO {
    /// Combine deux entrées même `batch_id` (ex. `dashboard/stats` + `.../notifications/stats`) en complétant les champs manquants.
    func mergedWith(_ other: NotificationCampaignInsightDTO) -> NotificationCampaignInsightDTO {
        NotificationCampaignInsightDTO(
            batchId: batchId,
            triggerName: triggerName ?? other.triggerName,
            createdAt: createdAt ?? other.createdAt,
            sentTotal: sentTotal ?? other.sentTotal,
            recipientsDistinct: recipientsDistinct ?? other.recipientsDistinct,
            returnedWithin48h: returnedWithin48h ?? other.returnedWithin48h,
            notificationTitle: notificationTitle ?? other.notificationTitle,
            message: message ?? other.message,
            sentPasskit: sentPasskit ?? other.sentPasskit,
            sentWebPush: sentWebPush ?? other.sentWebPush
        )
    }
}

// MARK: - GET .../notifications/stats (enrichit l’historique des campagnes côté stats)

/// Clé d’objet `last_batch` (compteurs variables selon version API).
private struct LastBatchStatsDecodable: Decodable {
    private let batchId: String?
    private let triggerName: String?
    private let createdAt: String?
    private let sentTotal: Int?
    private let recipientsDistinct: Int?
    private let returnedWithin48h: Int?
    private let title: String?
    private let message: String?
    private let body: String?
    private let sentPasskit: Int?
    private let sentWeb: Int?
    private let sentWebPush: Int?

    enum CodingKeys: String, CodingKey {
        case batchId = "batch_id"
        case triggerName = "trigger_name"
        case createdAt = "created_at"
        case sentTotal = "sent_total"
        case recipientsDistinct = "recipients_distinct"
        case returnedWithin48h = "returned_within_48h"
        case returnedWithin7dLegacy = "returned_within_7d"
        case title
        case message
        case body
        case sentPasskit = "sent_passkit"
        case sentWeb = "sent_web"
        case sentWebPush = "sent_web_push"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        batchId = try c.decodeIfPresent(String.self, forKey: .batchId)
        triggerName = try c.decodeIfPresent(String.self, forKey: .triggerName)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        sentTotal = try c.decodeIfPresent(Int.self, forKey: .sentTotal)
        recipientsDistinct = try c.decodeIfPresent(Int.self, forKey: .recipientsDistinct)
        if let v = try c.decodeIfPresent(Int.self, forKey: .returnedWithin48h) {
            returnedWithin48h = v
        } else {
            returnedWithin48h = try c.decodeIfPresent(Int.self, forKey: .returnedWithin7dLegacy)
        }
        title = try c.decodeIfPresent(String.self, forKey: .title)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        body = try c.decodeIfPresent(String.self, forKey: .body)
        sentPasskit = try c.decodeIfPresent(Int.self, forKey: .sentPasskit)
        sentWeb = try c.decodeIfPresent(Int.self, forKey: .sentWeb)
        sentWebPush = try c.decodeIfPresent(Int.self, forKey: .sentWebPush)
    }

    func asCampaignInsight() -> NotificationCampaignInsightDTO? {
        let mergedMessage = [message, body]
            .compactMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        let mergedTitle = title
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }
        // N’invente pas une « campagne » si le JSON n’a qu’une date (compteurs & texte vides) — sinon une ligne 0/0/0 inutile.
        let hasSignal = (batchId?.isEmpty == false)
            || (triggerName?.isEmpty == false)
            || (sentTotal ?? 0) > 0
            || (recipientsDistinct ?? 0) > 0
            || mergedTitle != nil
            || mergedMessage != nil
        guard hasSignal else { return nil }
        let web = sentWebPush ?? sentWeb
        return NotificationCampaignInsightDTO(
            batchId: (batchId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? (batchId ?? "batch")
                : "last-batch-\(createdAt ?? "unknown")",
            triggerName: triggerName,
            createdAt: createdAt,
            sentTotal: sentTotal,
            recipientsDistinct: recipientsDistinct,
            returnedWithin48h: returnedWithin48h,
            notificationTitle: mergedTitle,
            message: mergedMessage,
            sentPasskit: sentPasskit,
            sentWebPush: web
        )
    }
}

/// Agrège les listes d’envois retournées par le dashboard notif. (certaines clés sont optionnelles côté SaaS).
struct NotificationStatsEndpointPayload: Decodable {
    let campaigns: [NotificationCampaignInsightDTO]

    private enum K: String, CodingKey {
        case notificationCampaigns = "notification_campaigns"
        case campaigns
        case batches
        case recentBatches = "recent_batches"
        case history
        case notificationHistory = "notification_history"
        case sendHistory = "send_history"
        case lastBatch = "last_batch"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        var buf: [NotificationCampaignInsightDTO] = []
        let arrayKeys: [K] = [
            .notificationCampaigns, .campaigns, .batches, .recentBatches, .history, .notificationHistory, .sendHistory,
        ]
        for k in arrayKeys {
            if let more = try c.decodeIfPresent([NotificationCampaignInsightDTO].self, forKey: k) {
                buf.append(contentsOf: more)
            }
        }
        if let many = try? c.decodeIfPresent([LastBatchStatsDecodable].self, forKey: .lastBatch) {
            for one in many {
                if let insight = one.asCampaignInsight() { buf.append(insight) }
            }
        } else if let one = try c.decodeIfPresent(LastBatchStatsDecodable.self, forKey: .lastBatch),
                  let insight = one.asCampaignInsight() {
            buf.append(insight)
        }
        var seen = Set<String>()
        var out: [NotificationCampaignInsightDTO] = []
        for row in buf where seen.insert(row.batchId).inserted {
            out.append(row)
        }
        campaigns = out
    }
}

struct BusinessStatsResponse: Codable, Sendable {
    let period: String?
    let periodKey: String?
    let membersCount: Int?
    let pointsThisMonth: Int?
    let transactionsThisMonth: Int?
    let newMembersLast7Days: Int?
    let newMembersLast30Days: Int?
    let newMembersInPeriod: Int?
    let inactiveMembers30Days: Int?
    let inactiveMembers90Days: Int?
    let pointsAveragePerMember: Double?
    let activeMembersInPeriod: Int?
    let retentionPct: Double?
    let recurrentMembersInPeriod: Int?
    let visitsInPeriod: Int?
    let avgVisitsPerActiveMember: Double?
    /// Uniquement si des montants € sont enregistrés sur les transactions (`amount_eur`), jamais dérivé des points.
    let avgBasketEur: Double?
    let rewardsRedeemedCount: Int?
    let pointsRedeemedInPeriod: Int?
    let googleReviewsNewInPeriod: Int?
    let notificationCampaigns: [NotificationCampaignInsightDTO]?
    let businessName: String?
}

// MARK: - GET .../dashboard/stats/traffic

struct DashboardTrafficHourBucketDTO: Codable, Sendable {
    let hour: Int
    let count: Int
}

struct DashboardTrafficWeekdayBucketDTO: Codable, Sendable {
    let weekday: Int
    let label: String?
    let count: Int
}

struct DashboardTrafficPeakHourDTO: Codable, Sendable {
    let hour: Int
    let count: Int
    let pctOfTotal: Double?
}

struct DashboardTrafficPeakWeekdayDTO: Codable, Sendable {
    let weekday: Int
    let label: String?
    let count: Int
    let pctOfTotal: Double?
}

struct DashboardTrafficPatternsResponse: Codable, Sendable {
    let period: String?
    let periodKey: String?
    let timezoneNote: String?
    /// Ex. `points_add_and_reward_redeem` — crédits caisse + utilisations récompense.
    let basis: String?
    let totalEvents: Int?
    let byHour: [DashboardTrafficHourBucketDTO]?
    let byWeekday: [DashboardTrafficWeekdayBucketDTO]?
    let peakHour: DashboardTrafficPeakHourDTO?
    let peakWeekday: DashboardTrafficPeakWeekdayDTO?
}

// MARK: - GET .../dashboard/members

struct BusinessMembersResponse: Decodable {
    let members: [MemberDTO]
    let total: Int?

    private enum CodingKeys: String, CodingKey { case members, total }

    /// 1ʳᵉ phase sync / tests : conteneur vide (pas fourni par le membre `init(from:)` seul).
    init(members: [MemberDTO], total: Int?) {
        self.members = members
        self.total = total
    }

    /// Décodage large : ignore les entrées sans `id` (au lieu de faire échouer toute la page).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rows = try c.decodeIfPresent([MemberAPIRow].self, forKey: .members) ?? []
        members = rows.compactMap { $0.toMemberDTO() }
        total = try c.decodeIfPresent(Int.self, forKey: .total)
    }
}

/// Décodage intermédiaire : id optionnel côté fil, transformé en `MemberDTO?`.
private struct MemberAPIRow: Decodable {
    let id: String?
    let name: String?
    let email: String?
    let points: Int?
    let createdAt: String?
    let lastVisitAt: String?
    let categoryIds: [String]?

    func toMemberDTO() -> MemberDTO? {
        let trimmed = (id ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return MemberDTO(
            id: trimmed,
            name: name,
            email: email,
            points: points,
            createdAt: createdAt,
            lastVisitAt: lastVisitAt,
            categoryIds: categoryIds
        )
    }
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

    /// Utilisé par le décodage large des listes ; le décodage JSON direct d’un seul `MemberDTO` reste le synthétiseur.
    fileprivate init(
        id: String,
        name: String?,
        email: String?,
        points: Int?,
        createdAt: String?,
        lastVisitAt: String?,
        categoryIds: [String]?
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.points = points
        self.createdAt = createdAt
        self.lastVisitAt = lastVisitAt
        self.categoryIds = categoryIds
    }
}

// MARK: - GET .../dashboard/transactions

struct BusinessTransactionsResponse: Decodable {
    let transactions: [TransactionDTO]
    let total: Int?

    /// 1ʳᵉ phase sync : liste vide (le synthétiseur `init(from:)` seul n’expose pas d’init membre public).
    init(transactions: [TransactionDTO], total: Int?) {
        self.transactions = transactions
        self.total = total
    }
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
    /// Optionnel : certaines réponses d’erreur partielles ou évolutions API peuvent omettre `member` ; le solde peut venir de `new_balance` / `points_added`.
    let member: ScanMemberDTO?
    let pointsAdded: Int?
    let newBalance: Int?
    /// `true` si le plafond `scan_max_points_per_transaction` a réduit le crédit.
    let pointsCapped: Bool?
    let pointsRequested: Int?
    /// Programme tampons : la carte était complète sur ce crédit → récompense max, compteur remis à zéro côté serveur.
    let stampCycleCompleted: Bool?
    let stampCyclesCompleted: Int?
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

// MARK: - GET/PUT .../dashboard/flyer (flyer QR, sync SaaS)

struct DashboardFlyerGetResponse: Decodable {
    let flyerPrefs: FlyerPrefsStored?
    let updatedAt: String?
    let shareUrl: String?
    /// Générations flyer IA déjà consommées sur le mois UTC courant.
    let flyerAiGenerationsUsed: Int?
    /// `nil` si créations illimitées côté API.
    let flyerAiGenerationsRemaining: Int?
    let flyerAiUnlimited: Bool?
    let flyerAiBillingMonth: String?
}

/// Objet stocké en base (`flyer_prefs_json`) : `state` + images data URL optionnelles.
struct FlyerPrefsStored: Decodable {
    let state: FlyerStateDTO?
    let customLogoDataUrl: String?
    let customBgDataUrl: String?

    enum CodingKeys: String, CodingKey {
        case state
        case customLogoDataUrl = "custom_logo_data_url"
        case customBgDataUrl = "custom_bg_data_url"
    }
}

struct FlyerPutAPIResponse: Decodable {
    let ok: Bool?
    let updatedAt: String?
}

/// État canvas flyer (mêmes clés que `app-flyer-qr-presets.js` / mergeFlyerState).
struct FlyerStateDTO: Codable, Equatable {
    var templateId: String
    var headline: String
    var ctaBanner: String
    /// Fond de la pastille « Scanne pour jouer » (#RRGGBB).
    var ctaBannerBgColor: String
    /// Texte de la pastille CTA (contraste sur `ctaBannerBgColor`).
    var ctaTextColor: String
    var step1: String
    var step2: String
    var step3: String
    var social1: String
    var socialUrl1: String
    var social2: String
    var socialUrl2: String
    var social3: String
    var socialUrl3: String
    var colorPrimary: String
    var colorSecondary: String
    var colorAccent: String
    var colorBgTop: String
    var colorBgBottom: String
    var wheelRenderMode: String
    var wheelColorOdd: String
    var wheelColorEven: String
    var wheelSegmentOffsetDeg: Double
    var headlineFontId: String
    var headlineTextColor: String
    var headlineStrokeColor: String
    /// Contour du mot « CADEAU » (remplissage = `ctaBannerBgColor` côté canvas web).
    var headlineGiftStrokeColor: String
    var headlineStrokeWidth: Double
    var headlineLogoGapPct: Double
    var headlineLetterSpacing: Double
    var headlineSizePct: Double
    var flyerFooterTextScalePct: Double
    var flyerWheelLabelScalePct: Double
    var flyerBgOverlayPct: Double
    var flyerQrOutlineWidth: Double
    /// Centre vertical du logo (fraction de la hauteur du flyer, ~0.04–0.22).
    var flyerLogoCenterYFrac: Double
    /// Largeur max du logo / largeur canvas (~0.28–0.88).
    var flyerLogoMaxWFrac: Double
    /// Hauteur max du logo / hauteur canvas (~0.06–0.36).
    var flyerLogoMaxHFrac: Double
    /// Détourage auto désactivé : envoi du logo avec fond d’origine (lisibilité sur dégradé clair).
    var flyerLogoKeepSourceBackground: Bool

    static let templateIdFixed = "noir-or-roue"

    static var `default`: FlyerStateDTO {
        FlyerStateDTO(
            templateId: templateIdFixed,
            headline: "SCANNEZ & GAGNEZ VOTRE CADEAU !",
            ctaBanner: "SCANNER POUR JOUER",
            ctaBannerBgColor: "#ec4899",
            ctaTextColor: "#ffffff",
            step1: "Scannez le QR code",
            step2: "Ajoutez la carte au Wallet",
            step3: "Cumulez points & avantages",
            social1: "",
            socialUrl1: "",
            social2: "",
            socialUrl2: "",
            social3: "",
            socialUrl3: "",
            colorPrimary: "#fbbf24",
            colorSecondary: "#f97316",
            colorAccent: "#ffffff",
            colorBgTop: "#0f172a",
            colorBgBottom: "#020617",
            /// `png` = texture web `spinflyer` ; `segments` = secteurs aplats (sans image).
            wheelRenderMode: "png",
            wheelColorOdd: "#fbbf24",
            wheelColorEven: "#f97316",
            wheelSegmentOffsetDeg: 0,
            headlineFontId: "fraunces",
            headlineTextColor: "#ffffff",
            headlineStrokeColor: "#020617",
            headlineGiftStrokeColor: "#020617",
            headlineStrokeWidth: 18,
            headlineLogoGapPct: 4,
            headlineLetterSpacing: 0,
            headlineSizePct: 7,
            flyerFooterTextScalePct: 100,
            flyerWheelLabelScalePct: 100,
            flyerBgOverlayPct: 0,
            flyerQrOutlineWidth: 5,
            flyerLogoCenterYFrac: 0.092,
            flyerLogoMaxWFrac: 0.62,
            flyerLogoMaxHFrac: 0.15,
            flyerLogoKeepSourceBackground: false
        )
    }

    init(
        templateId: String,
        headline: String,
        ctaBanner: String,
        ctaBannerBgColor: String,
        ctaTextColor: String,
        step1: String,
        step2: String,
        step3: String,
        social1: String,
        socialUrl1: String,
        social2: String,
        socialUrl2: String,
        social3: String,
        socialUrl3: String,
        colorPrimary: String,
        colorSecondary: String,
        colorAccent: String,
        colorBgTop: String,
        colorBgBottom: String,
        wheelRenderMode: String,
        wheelColorOdd: String,
        wheelColorEven: String,
        wheelSegmentOffsetDeg: Double,
        headlineFontId: String,
        headlineTextColor: String,
        headlineStrokeColor: String,
        headlineGiftStrokeColor: String,
        headlineStrokeWidth: Double,
        headlineLogoGapPct: Double,
        headlineLetterSpacing: Double,
        headlineSizePct: Double,
        flyerFooterTextScalePct: Double,
        flyerWheelLabelScalePct: Double,
        flyerBgOverlayPct: Double,
        flyerQrOutlineWidth: Double,
        flyerLogoCenterYFrac: Double,
        flyerLogoMaxWFrac: Double,
        flyerLogoMaxHFrac: Double,
        flyerLogoKeepSourceBackground: Bool
    ) {
        self.templateId = templateId
        self.headline = headline
        self.ctaBanner = ctaBanner
        self.ctaBannerBgColor = ctaBannerBgColor
        self.ctaTextColor = ctaTextColor
        self.step1 = step1
        self.step2 = step2
        self.step3 = step3
        self.social1 = social1
        self.socialUrl1 = socialUrl1
        self.social2 = social2
        self.socialUrl2 = socialUrl2
        self.social3 = social3
        self.socialUrl3 = socialUrl3
        self.colorPrimary = colorPrimary
        self.colorSecondary = colorSecondary
        self.colorAccent = colorAccent
        self.colorBgTop = colorBgTop
        self.colorBgBottom = colorBgBottom
        self.wheelRenderMode = wheelRenderMode
        self.wheelColorOdd = wheelColorOdd
        self.wheelColorEven = wheelColorEven
        self.wheelSegmentOffsetDeg = wheelSegmentOffsetDeg
        self.headlineFontId = headlineFontId
        self.headlineTextColor = headlineTextColor
        self.headlineStrokeColor = headlineStrokeColor
        self.headlineGiftStrokeColor = headlineGiftStrokeColor
        self.headlineStrokeWidth = headlineStrokeWidth
        self.headlineLogoGapPct = headlineLogoGapPct
        self.headlineLetterSpacing = headlineLetterSpacing
        self.headlineSizePct = headlineSizePct
        self.flyerFooterTextScalePct = flyerFooterTextScalePct
        self.flyerWheelLabelScalePct = flyerWheelLabelScalePct
        self.flyerBgOverlayPct = flyerBgOverlayPct
        self.flyerQrOutlineWidth = flyerQrOutlineWidth
        self.flyerLogoCenterYFrac = flyerLogoCenterYFrac
        self.flyerLogoMaxWFrac = flyerLogoMaxWFrac
        self.flyerLogoMaxHFrac = flyerLogoMaxHFrac
        self.flyerLogoKeepSourceBackground = flyerLogoKeepSourceBackground
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = Self.default
        templateId = Self.templateIdFixed
        headline = try c.decodeIfPresent(String.self, forKey: .headline) ?? base.headline
        ctaBanner = try c.decodeIfPresent(String.self, forKey: .ctaBanner) ?? base.ctaBanner
        ctaBannerBgColor = Self.safeHex(try c.decodeIfPresent(String.self, forKey: .ctaBannerBgColor), base.ctaBannerBgColor)
        ctaTextColor = Self.safeHex(try c.decodeIfPresent(String.self, forKey: .ctaTextColor), base.ctaTextColor)
        step1 = try c.decodeIfPresent(String.self, forKey: .step1) ?? base.step1
        step2 = try c.decodeIfPresent(String.self, forKey: .step2) ?? base.step2
        step3 = try c.decodeIfPresent(String.self, forKey: .step3) ?? base.step3
        social1 = try c.decodeIfPresent(String.self, forKey: .social1) ?? base.social1
        socialUrl1 = try c.decodeIfPresent(String.self, forKey: .socialUrl1) ?? base.socialUrl1
        social2 = try c.decodeIfPresent(String.self, forKey: .social2) ?? base.social2
        socialUrl2 = try c.decodeIfPresent(String.self, forKey: .socialUrl2) ?? base.socialUrl2
        social3 = try c.decodeIfPresent(String.self, forKey: .social3) ?? base.social3
        socialUrl3 = try c.decodeIfPresent(String.self, forKey: .socialUrl3) ?? base.socialUrl3
        let oddRaw = try c.decodeIfPresent(String.self, forKey: .wheelColorOdd)
        let evenRaw = try c.decodeIfPresent(String.self, forKey: .wheelColorEven)
        colorPrimary = Self.safeHex(try c.decodeIfPresent(String.self, forKey: .colorPrimary), base.colorPrimary)
        colorSecondary = Self.safeHex(try c.decodeIfPresent(String.self, forKey: .colorSecondary), base.colorSecondary)
        colorAccent = Self.safeHex(try c.decodeIfPresent(String.self, forKey: .colorAccent), base.colorAccent)
        colorBgTop = Self.safeHex(try c.decodeIfPresent(String.self, forKey: .colorBgTop), base.colorBgTop)
        colorBgBottom = Self.safeHex(try c.decodeIfPresent(String.self, forKey: .colorBgBottom), base.colorBgBottom)
        let wr = try c.decodeIfPresent(String.self, forKey: .wheelRenderMode) ?? base.wheelRenderMode
        wheelRenderMode = Self.normalizeWheelRenderMode(wr)
        wheelColorOdd = Self.safeHex(oddRaw, base.wheelColorOdd)
        wheelColorEven = Self.safeHex(evenRaw, base.wheelColorEven)
        wheelSegmentOffsetDeg = Self.clampWheelOffset(try c.decodeIfPresent(Double.self, forKey: .wheelSegmentOffsetDeg) ?? base.wheelSegmentOffsetDeg)
        headlineFontId = FlyerHeadlineFontCatalog.normalize(try c.decodeIfPresent(String.self, forKey: .headlineFontId))
        headlineTextColor = Self.safeHex(try c.decodeIfPresent(String.self, forKey: .headlineTextColor), base.headlineTextColor)
        headlineStrokeColor = Self.safeHex(try c.decodeIfPresent(String.self, forKey: .headlineStrokeColor), base.headlineStrokeColor)
        headlineGiftStrokeColor = Self.safeHex(
            try c.decodeIfPresent(String.self, forKey: .headlineGiftStrokeColor),
            base.headlineGiftStrokeColor
        )
        headlineStrokeWidth = Self.clampStrokeW(try c.decodeIfPresent(Double.self, forKey: .headlineStrokeWidth) ?? base.headlineStrokeWidth)
        headlineLogoGapPct = Self.clampGapPct(try c.decodeIfPresent(Double.self, forKey: .headlineLogoGapPct) ?? base.headlineLogoGapPct)
        headlineLetterSpacing = Self.clampLetterSpacing(try c.decodeIfPresent(Double.self, forKey: .headlineLetterSpacing) ?? base.headlineLetterSpacing)
        headlineSizePct = Self.clampHeadlineSize(try c.decodeIfPresent(Double.self, forKey: .headlineSizePct) ?? base.headlineSizePct)
        flyerFooterTextScalePct = Self.clampTextScale(try c.decodeIfPresent(Double.self, forKey: .flyerFooterTextScalePct) ?? base.flyerFooterTextScalePct)
        flyerWheelLabelScalePct = Self.clampTextScale(try c.decodeIfPresent(Double.self, forKey: .flyerWheelLabelScalePct) ?? base.flyerWheelLabelScalePct)
        flyerBgOverlayPct = Self.clampOverlay(try c.decodeIfPresent(Double.self, forKey: .flyerBgOverlayPct) ?? base.flyerBgOverlayPct)
        flyerQrOutlineWidth = Self.clampQrOutline(try c.decodeIfPresent(Double.self, forKey: .flyerQrOutlineWidth) ?? base.flyerQrOutlineWidth)
        flyerLogoCenterYFrac = Self.clampLogoCenterYFrac(
            try c.decodeIfPresent(Double.self, forKey: .flyerLogoCenterYFrac) ?? base.flyerLogoCenterYFrac
        )
        flyerLogoMaxWFrac = Self.clampLogoMaxWFrac(
            try c.decodeIfPresent(Double.self, forKey: .flyerLogoMaxWFrac) ?? base.flyerLogoMaxWFrac
        )
        flyerLogoMaxHFrac = Self.clampLogoMaxHFrac(
            try c.decodeIfPresent(Double.self, forKey: .flyerLogoMaxHFrac) ?? base.flyerLogoMaxHFrac
        )
        flyerLogoKeepSourceBackground = try c.decodeIfPresent(Bool.self, forKey: .flyerLogoKeepSourceBackground)
            ?? base.flyerLogoKeepSourceBackground
    }

    mutating func normalizeClamps() {
        /// `JSONEncoder` n’encode pas les `Double` non finis → échec silencieux de `encodedPreviewBootstrapBase64`
        /// et l’aperçu retombe sur le PNG IA seul (pas de roue / QR canvas).
        Self.coerceFiniteNumericFields(&self)
        templateId = Self.templateIdFixed
        wheelRenderMode = Self.normalizeWheelRenderMode(wheelRenderMode)
        wheelSegmentOffsetDeg = Self.clampWheelOffset(wheelSegmentOffsetDeg)
        colorPrimary = Self.safeHex(colorPrimary, Self.default.colorPrimary)
        colorSecondary = Self.safeHex(colorSecondary, Self.default.colorSecondary)
        colorAccent = Self.safeHex(colorAccent, Self.default.colorAccent)
        colorBgTop = Self.safeHex(colorBgTop, Self.default.colorBgTop)
        colorBgBottom = Self.safeHex(colorBgBottom, Self.default.colorBgBottom)
        wheelColorOdd = Self.safeHex(wheelColorOdd, Self.default.wheelColorOdd)
        wheelColorEven = Self.safeHex(wheelColorEven, Self.default.wheelColorEven)
        headlineFontId = FlyerHeadlineFontCatalog.normalize(headlineFontId)
        headlineTextColor = Self.safeHex(headlineTextColor, Self.default.headlineTextColor)
        headlineStrokeColor = Self.safeHex(headlineStrokeColor, Self.default.headlineStrokeColor)
        headlineGiftStrokeColor = Self.safeHex(headlineGiftStrokeColor, Self.default.headlineGiftStrokeColor)
        ctaBannerBgColor = Self.safeHex(ctaBannerBgColor, Self.default.ctaBannerBgColor)
        ctaTextColor = Self.safeHex(ctaTextColor, Self.default.ctaTextColor)
        headlineStrokeWidth = Self.clampStrokeW(headlineStrokeWidth)
        headlineLogoGapPct = Self.clampGapPct(headlineLogoGapPct)
        headlineLetterSpacing = Self.clampLetterSpacing(headlineLetterSpacing)
        headlineSizePct = Self.clampHeadlineSize(headlineSizePct)
        flyerFooterTextScalePct = Self.clampTextScale(flyerFooterTextScalePct)
        flyerWheelLabelScalePct = Self.clampTextScale(flyerWheelLabelScalePct)
        flyerBgOverlayPct = Self.clampOverlay(flyerBgOverlayPct)
        flyerQrOutlineWidth = Self.clampQrOutline(flyerQrOutlineWidth)
        flyerLogoCenterYFrac = Self.clampLogoCenterYFrac(flyerLogoCenterYFrac)
        flyerLogoMaxWFrac = Self.clampLogoMaxWFrac(flyerLogoMaxWFrac)
        flyerLogoMaxHFrac = Self.clampLogoMaxHFrac(flyerLogoMaxHFrac)
    }

    private static func coerceFiniteNumericFields(_ st: inout FlyerStateDTO) {
        let d = Self.default
        if !st.wheelSegmentOffsetDeg.isFinite { st.wheelSegmentOffsetDeg = d.wheelSegmentOffsetDeg }
        if !st.headlineStrokeWidth.isFinite { st.headlineStrokeWidth = d.headlineStrokeWidth }
        if !st.headlineLogoGapPct.isFinite { st.headlineLogoGapPct = d.headlineLogoGapPct }
        if !st.headlineLetterSpacing.isFinite { st.headlineLetterSpacing = d.headlineLetterSpacing }
        if !st.headlineSizePct.isFinite { st.headlineSizePct = d.headlineSizePct }
        if !st.flyerFooterTextScalePct.isFinite { st.flyerFooterTextScalePct = d.flyerFooterTextScalePct }
        if !st.flyerWheelLabelScalePct.isFinite { st.flyerWheelLabelScalePct = d.flyerWheelLabelScalePct }
        if !st.flyerBgOverlayPct.isFinite { st.flyerBgOverlayPct = d.flyerBgOverlayPct }
        if !st.flyerQrOutlineWidth.isFinite { st.flyerQrOutlineWidth = d.flyerQrOutlineWidth }
        if !st.flyerLogoCenterYFrac.isFinite { st.flyerLogoCenterYFrac = d.flyerLogoCenterYFrac }
        if !st.flyerLogoMaxWFrac.isFinite { st.flyerLogoMaxWFrac = d.flyerLogoMaxWFrac }
        if !st.flyerLogoMaxHFrac.isFinite { st.flyerLogoMaxHFrac = d.flyerLogoMaxHFrac }
    }

    private enum CodingKeys: String, CodingKey {
        case templateId, headline, ctaBanner, ctaBannerBgColor, ctaTextColor, step1, step2, step3
        case social1, socialUrl1, social2, socialUrl2, social3, socialUrl3
        case colorPrimary, colorSecondary, colorAccent, colorBgTop, colorBgBottom
        case wheelRenderMode, wheelColorOdd, wheelColorEven, wheelSegmentOffsetDeg
        case headlineFontId, headlineTextColor, headlineStrokeColor, headlineGiftStrokeColor, headlineStrokeWidth
        case headlineLogoGapPct, headlineLetterSpacing, headlineSizePct
        case flyerFooterTextScalePct, flyerWheelLabelScalePct, flyerBgOverlayPct, flyerQrOutlineWidth
        case flyerLogoCenterYFrac, flyerLogoMaxWFrac, flyerLogoMaxHFrac, flyerLogoKeepSourceBackground
    }

    private static func safeHex(_ v: String?, _ fallback: String) -> String {
        let t = (v ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if t.range(of: #"^#[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil { return t }
        return fallback
    }

    private static func normalizeWheelRenderMode(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t == "segments" { return "segments" }
        return "png"
    }

    private static func clampWheelOffset(_ v: Double) -> Double {
        let x = v.isFinite ? v : 0
        return min(180, max(-180, (x * 20).rounded() / 20))
    }

    private static func clampStrokeW(_ v: Double) -> Double {
        let x = v.isFinite ? v : Self.default.headlineStrokeWidth
        return min(32, max(0, x.rounded()))
    }

    private static func clampGapPct(_ v: Double) -> Double {
        let x = v.isFinite ? v : Self.default.headlineLogoGapPct
        return min(14, max(0, (x * 10).rounded() / 10))
    }

    private static func clampLetterSpacing(_ v: Double) -> Double {
        let x = v.isFinite ? v : 0
        return min(8, max(0, (x * 2).rounded() / 2))
    }

    private static func clampHeadlineSize(_ v: Double) -> Double {
        let x = v.isFinite ? v : Self.default.headlineSizePct
        return min(16, max(5, (x * 10).rounded() / 10))
    }

    private static func clampTextScale(_ v: Double) -> Double {
        let x = v.isFinite ? v : 100
        let r = (x / 5).rounded() * 5
        return min(130, max(70, r))
    }

    private static func clampOverlay(_ v: Double) -> Double {
        let x = v.isFinite ? v : 0
        return min(90, max(0, x.rounded()))
    }

    private static func clampQrOutline(_ v: Double) -> Double {
        let x = v.isFinite ? v : 0
        return min(12, max(0, x.rounded()))
    }

    private static func clampLogoCenterYFrac(_ v: Double) -> Double {
        let x = v.isFinite ? v : Self.default.flyerLogoCenterYFrac
        return min(0.22, max(0.06, (x * 1000).rounded() / 1000))
    }

    private static func clampLogoMaxWFrac(_ v: Double) -> Double {
        let x = v.isFinite ? v : Self.default.flyerLogoMaxWFrac
        return min(0.88, max(0.28, (x * 1000).rounded() / 1000))
    }

    private static func clampLogoMaxHFrac(_ v: Double) -> Double {
        let x = v.isFinite ? v : Self.default.flyerLogoMaxHFrac
        return min(0.36, max(0.06, (x * 1000).rounded() / 1000))
    }
}

extension DashboardFlyerGetResponse {
    /// L’onglet Commerce ne doit pas se baser uniquement sur les data URL du GET : un flyer enregistré a souvent `state` + `updated_at` alors que fond/logo sont absents ou chargés autrement (hub → hydratation).
    var commerceIndicatesFlyerRegistered: Bool {
        let bg = (flyerPrefs?.customBgDataUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let lg = (flyerPrefs?.customLogoDataUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !bg.isEmpty || !lg.isEmpty { return true }
        guard let fp = flyerPrefs else { return false }
        if let st = fp.state {
            var lhs = st
            lhs.normalizeClamps()
            var rhs = FlyerStateDTO.default
            rhs.normalizeClamps()
            if lhs != rhs { return true }
        }
        let ua = (updatedAt ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !ua.isEmpty { return true }
        return false
    }
}

enum FlyerHeadlineFontCatalog {
    static let idsOrdered: [String] = [
        "fraunces", "abril-fatface", "playfair", "dm-serif-display", "bodoni-moda", "yeseva-one", "cinzel",
        "bebas", "anton", "archivo-black", "oswald", "saira-extra-condensed", "teko", "alfa-slab", "ultra",
        "bungee", "righteous", "paytone-one", "russo-one", "shrikhand", "titan-one", "unbounded"
    ]

    static let displayNames: [String: String] = [
        "fraunces": "Fraunces",
        "abril-fatface": "Abril Fatface",
        "playfair": "Playfair Display",
        "dm-serif-display": "DM Serif Display",
        "bodoni-moda": "Bodoni Moda",
        "yeseva-one": "Yeseva One",
        "cinzel": "Cinzel",
        "bebas": "Bebas Neue",
        "anton": "Anton",
        "archivo-black": "Archivo Black",
        "oswald": "Oswald",
        "saira-extra-condensed": "Saira Extra Condensed",
        "teko": "Teko",
        "alfa-slab": "Alfa Slab One",
        "ultra": "Ultra",
        "bungee": "Bungee",
        "righteous": "Righteous",
        "paytone-one": "Paytone One",
        "russo-one": "Russo One",
        "shrikhand": "Shrikhand",
        "titan-one": "Titan One",
        "unbounded": "Unbounded"
    ]

    static func normalize(_ id: String?) -> String {
        let t = (id ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if idsOrdered.contains(t) { return t }
        return idsOrdered[0]
    }
}

// MARK: - Flyer — génération d’image IA (OpenAI, serveur)

struct FlyerAIGenerateRequestDTO: Encodable {
    var brandName: String
    /// Secteur + produits / visuels à mettre en avant (un seul champ côté UX).
    var cuisineOrConcept: String
    var accentColorHex: String
    var secondaryColorHex: String?
    var extraContext: String?
    /// 1 à 3 couleurs `#RRGGBB`, ordre = priorité pour le prompt IA (aligné `palette_colors_hex` API).
    var paletteColorsHex: [String]
    /// Data URL ou base64 — logo affiché en tête d’affiche dans l’image générée (optionnel).
    var logoBase64: String?
    /// Jusqu’à 3 images d’inspiration (DA / ambiance) — data URL ou base64.
    var styleReferenceImagesBase64: [String]?
}

struct FlyerAIGenerateResponseDTO: Decodable {
    let imageBase64: String
    let revisedPrompt: String?
    let flyerAiGenerationsUsed: Int?
    let flyerAiGenerationsRemaining: Int?
    let flyerAiUnlimited: Bool?
}

/// Réponse `202 Accepted` après `POST .../flyer/ai-generate` (génération asynchrone).
struct FlyerAIGenerateEnqueueResponseDTO: Decodable {
    let jobId: String
    let status: String
}

/// Corps `GET .../flyer/ai-generate/jobs/:jobId` (polling jusqu’à `done` ou `failed`).
struct FlyerAIGenerateJobStatusResponseDTO: Decodable {
    let status: String
    let jobId: String
    let error: String?
    let imageBase64: String?
    let revisedPrompt: String?
    let flyerAiGenerationsUsed: Int?
    let flyerAiGenerationsRemaining: Int?
    let flyerAiUnlimited: Bool?
    let fidelityPageBackgroundSaved: Bool?
    let fidelityPageBackgroundError: String?
}

enum FlyerRemoteImagePayload: Equatable {
    case leaveUnchanged
    case clear
    case dataURL(String)
}

struct FlyerPutPayload: Encodable {
    var state: FlyerStateDTO
    var logo: FlyerRemoteImagePayload
    var background: FlyerRemoteImagePayload

    enum CK: String, CodingKey {
        case state
        case customLogoDataUrl = "custom_logo_data_url"
        case customBgDataUrl = "custom_bg_data_url"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CK.self)
        try c.encode(state, forKey: .state)
        switch logo {
        case .leaveUnchanged:
            break
        case .clear:
            try c.encodeNil(forKey: .customLogoDataUrl)
        case .dataURL(let s):
            try c.encode(s, forKey: .customLogoDataUrl)
        }
        switch background {
        case .leaveUnchanged:
            break
        case .clear:
            try c.encodeNil(forKey: .customBgDataUrl)
        case .dataURL(let s):
            try c.encode(s, forKey: .customBgDataUrl)
        }
    }

    func encodedJSON() throws -> Data {
        let enc = JSONEncoder()
        /// **camelCase** pour le corps `state` (aligné aperçu `/assets/app-flyer-qr-draw*.js` : `r.wheelRenderMode`).
        /// Le `JSONEncoder` de `APIClient` utilise le snake, mais ici l’API flyer attend les mêmes clés que l’éditeur.
        enc.keyEncodingStrategy = .useDefaultKeys
        return try enc.encode(self)
    }
}

// MARK: - GET /api/admin/* (plateforme)

struct AdminOverviewResponse: Decodable {
    let usersCount: Int?
    let businessesCount: Int?
    let activeSubscriptionsCount: Int?
}

struct AdminUsersListResponse: Decodable {
    let users: [AdminUserRow]
}

struct AdminUserRow: Decodable, Identifiable {
    let id: String
    let email: String?
    let name: String?
    let createdAt: String?
    /// SQLite : 0/1
    let isAdmin: Int?

    var isAdminFlag: Bool { (isAdmin ?? 0) != 0 }
}

struct AdminBusinessesListResponse: Decodable {
    let businesses: [AdminBusinessRow]
}

struct AdminBusinessRow: Decodable, Identifiable, Hashable {
    let id: String
    let slug: String
    let name: String?
    let organizationName: String?
    let userId: String?
    let createdAt: String?
    let ownerEmail: String?
    let memberCount: Int?
    let ownerSubscriptionStatus: String?
    let ownerPlanId: String?
}

struct AdminEventsListResponse: Decodable {
    let events: [AdminEventRow]
}

struct AdminEventRow: Decodable, Identifiable {
    let id: String
    let eventType: String
    let payloadJson: String?
    let stripeEventId: String?
    let createdAt: String?
}

// MARK: - GET/POST/DELETE …/dashboard/team (espace commerçant, rôles)

/// Liste des accès « équipe » pour un commerce (owner, manager, staff).
struct WorkspaceTeamListResponse: Decodable {
    let members: [WorkspaceTeamMemberDTO]

    enum CodingKeys: String, CodingKey {
        case members
        case items
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let m = try c.decodeIfPresent([WorkspaceTeamMemberDTO].self, forKey: .members) {
            members = m
        } else if let i = try c.decodeIfPresent([WorkspaceTeamMemberDTO].self, forKey: .items) {
            members = i
        } else {
            members = []
        }
    }
}

struct WorkspaceTeamMemberDTO: Decodable, Identifiable {
    let membershipId: String?
    let userId: String?
    let email: String?
    let name: String?
    let role: String?
    let status: String?
    let createdAt: String?

    var id: String {
        if let m = membershipId?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty { return "m:\(m)" }
        if let u = userId?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty { return "u:\(u)" }
        if let e = email?.trimmingCharacters(in: .whitespacesAndNewlines), !e.isEmpty { return "e:\(e)" }
        return "row:\(name ?? ""):\(status ?? ""):\(role ?? "")"
    }

    enum CodingKeys: String, CodingKey {
        case membershipId = "membership_id"
        case userId = "user_id"
        case email, name, role, status
        case createdAt = "created_at"
    }
}

struct WorkspaceTeamInviteResponse: Decodable {
    let ok: Bool?
    let message: String?
    /// Présent si le backend a tenté d’envoyer un e-mail transactionnel (Resend/SMTP).
    let emailSent: Bool?

    enum CodingKeys: String, CodingKey {
        case ok, message
        case emailSent = "email_sent"
    }
}

struct WorkspaceTeamInviteBody: Encodable {
    let email: String
    let name: String?
    let role: String?
}
