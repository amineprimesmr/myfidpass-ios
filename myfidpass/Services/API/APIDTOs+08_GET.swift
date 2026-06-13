//
//  APIDTOs+08_GET.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

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
    private let deliveryStatus: String?
    private let expectedDevices: Int?

    // RawValues camelCase — voir note sur `.convertFromSnakeCase` plus haut.
    enum CodingKeys: String, CodingKey {
        case id
        case batchId
        case triggerName
        case createdAt
        case sentTotal
        case sent
        case recipientsDistinct
        case distinctRecipients
        case returnedWithin48h = "returnedWithin48H"
        case returnedWithin7dLegacy = "returnedWithin7D"
        case title
        case notificationTitle
        case message
        case body
        case sentPasskit
        case sentWeb
        case sentWebPush
        case deliveryStatus
        case expectedDevices
        case summary
    }

    private struct SummaryBox: Decodable {
        let sent: Int?
        let sentTotal: Int?
        let recipientsDistinct: Int?
        let distinctRecipients: Int?
        let title: String?
        let notificationTitle: String?
        let message: String?
        let body: String?
        let sentPasskit: Int?
        let sentWebPush: Int?
        let deliveryStatus: String?
        let expectedDevices: Int?

        // Le summary serveur écrit `sentPassKit` (K majuscule) — clé sans underscore,
        // laissée telle quelle par `.convertFromSnakeCase`.
        enum CodingKeys: String, CodingKey {
            case sent
            case sentTotal
            case recipientsDistinct
            case distinctRecipients
            case title
            case notificationTitle
            case message
            case body
            case sentPasskit = "sentPassKit"
            case sentWebPush
            case deliveryStatus
            case expectedDevices
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let topId = try c.decodeIfPresent(String.self, forKey: .id)
        let topBatch = try c.decodeIfPresent(String.self, forKey: .batchId)
        let resolvedBatchId = (topBatch?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? topBatch
            : topId

        var resolvedSentTotal = try c.decodeIfPresent(Int.self, forKey: .sentTotal)
        if resolvedSentTotal == nil { resolvedSentTotal = try c.decodeIfPresent(Int.self, forKey: .sent) }

        var resolvedRecipients = try c.decodeIfPresent(Int.self, forKey: .recipientsDistinct)
        if resolvedRecipients == nil {
            resolvedRecipients = try c.decodeIfPresent(Int.self, forKey: .distinctRecipients)
        }

        let resolvedReturned48h: Int?
        if let v = try c.decodeIfPresent(Int.self, forKey: .returnedWithin48h) {
            resolvedReturned48h = v
        } else {
            resolvedReturned48h = try c.decodeIfPresent(Int.self, forKey: .returnedWithin7dLegacy)
        }

        var resolvedTitle = try c.decodeIfPresent(String.self, forKey: .title)
            ?? (try? c.decodeIfPresent(String.self, forKey: .notificationTitle))
        var resolvedMessage = try c.decodeIfPresent(String.self, forKey: .message)
        var resolvedBody = try c.decodeIfPresent(String.self, forKey: .body)
        var resolvedSentPasskit = try c.decodeIfPresent(Int.self, forKey: .sentPasskit)
        let resolvedSentWeb = try c.decodeIfPresent(Int.self, forKey: .sentWeb)
        var resolvedSentWebPush = try c.decodeIfPresent(Int.self, forKey: .sentWebPush)
        var resolvedDeliveryStatus = try c.decodeIfPresent(String.self, forKey: .deliveryStatus)
        var resolvedExpectedDevices = try c.decodeIfPresent(Int.self, forKey: .expectedDevices)

        if let summary = try c.decodeIfPresent(SummaryBox.self, forKey: .summary) {
            if resolvedSentTotal == nil { resolvedSentTotal = summary.sentTotal ?? summary.sent }
            if resolvedRecipients == nil {
                resolvedRecipients = summary.recipientsDistinct ?? summary.distinctRecipients
            }
            if resolvedTitle == nil { resolvedTitle = summary.notificationTitle ?? summary.title }
            if resolvedMessage == nil { resolvedMessage = summary.message }
            if resolvedBody == nil { resolvedBody = summary.body }
            if resolvedSentPasskit == nil { resolvedSentPasskit = summary.sentPasskit }
            if resolvedSentWebPush == nil { resolvedSentWebPush = summary.sentWebPush }
            if resolvedDeliveryStatus == nil { resolvedDeliveryStatus = summary.deliveryStatus }
            if resolvedExpectedDevices == nil { resolvedExpectedDevices = summary.expectedDevices }
        }

        batchId = resolvedBatchId
        triggerName = try c.decodeIfPresent(String.self, forKey: .triggerName)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        sentTotal = resolvedSentTotal
        recipientsDistinct = resolvedRecipients
        returnedWithin48h = resolvedReturned48h
        title = resolvedTitle
        message = resolvedMessage
        body = resolvedBody
        sentPasskit = resolvedSentPasskit
        sentWeb = resolvedSentWeb
        sentWebPush = resolvedSentWebPush
        deliveryStatus = resolvedDeliveryStatus
        expectedDevices = resolvedExpectedDevices
    }

    func asCampaignInsight() -> NotificationCampaignInsightDTO? {
        let mergedMessage: String? = {
            let candidates: [String?] = [self.message, self.body]
            for raw in candidates {
                guard let raw else { continue }
                let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { return t }
            }
            return nil
        }()
        let mergedTitle: String? = {
            guard let t = self.title else { return nil }
            let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }()
        // N’invente pas une « campagne » si le JSON n’a qu’une date (compteurs & texte vides) — sinon une ligne 0/0/0 inutile.
        let hasSignal = (batchId?.isEmpty == false)
            || (triggerName?.isEmpty == false)
            || (sentTotal ?? 0) > 0
            || (recipientsDistinct ?? 0) > 0
            || (expectedDevices ?? 0) > 0
            || mergedTitle != nil
            || mergedMessage != nil
            || !(deliveryStatus?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        guard hasSignal else { return nil }
        let web = sentWebPush ?? sentWeb
        let pending = ["queued", "sending", "pending"].contains(
            deliveryStatus?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        )
        let confirmedRecipients = pending ? 0 : max(recipientsDistinct ?? 0, sentTotal ?? 0)
        return NotificationCampaignInsightDTO(
            batchId: (batchId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? (batchId ?? "batch")
                : "last-batch-\(createdAt ?? "unknown")",
            triggerName: triggerName,
            createdAt: createdAt,
            sentTotal: pending ? nil : sentTotal,
            recipientsDistinct: confirmedRecipients > 0 ? confirmedRecipients : (pending ? 0 : recipientsDistinct),
            returnedWithin48h: returnedWithin48h,
            notificationTitle: mergedTitle,
            message: mergedMessage,
            sentPasskit: sentPasskit,
            sentWebPush: web,
            deliveryStatus: deliveryStatus,
            expectedDevices: expectedDevices
        )
    }
}

/// Agrège les listes d’envois retournées par le dashboard notif. (certaines clés sont optionnelles côté SaaS).
struct NotificationStatsEndpointPayload: Decodable {
    let campaigns: [NotificationCampaignInsightDTO]

    // RawValues en camelCase : le décodeur `.convertFromSnakeCase` convertit les clés JSON
    // snake_case AVANT le lookup (un rawValue "notification_campaigns" ne matcherait jamais).
    private enum K: String, CodingKey {
        case notificationCampaigns
        case campaigns
        case batches
        case recentBatches
        case history
        case notificationHistory
        case sendHistory
        case lastBatch
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

struct RewardRedeemedBreakdownRowDTO: Codable, Sendable, Hashable {
    let label: String
    let count: Int
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
    /// Repère panier moyen saisi par le commerce (comparaison dans l’app).
    let baselineAvgBasketEur: Double?
    let rewardsRedeemedCount: Int?
    let rewardsRedeemedBreakdown: [RewardRedeemedBreakdownRowDTO]?
    let pointsRedeemedInPeriod: Int?
    let googleReviewsNewInPeriod: Int?
    let socialFollowsClaimed: SocialFollowsClaimedDTO?
    let notificationCampaigns: [NotificationCampaignInsightDTO]?
    let businessName: String?
}

struct SocialFollowsClaimedDTO: Codable, Sendable {
    let instagram: Int?
    let tiktok: Int?
    let facebook: Int?
    let twitter: Int?

    var total: Int {
        (instagram ?? 0) + (tiktok ?? 0) + (facebook ?? 0) + (twitter ?? 0)
    }
}

