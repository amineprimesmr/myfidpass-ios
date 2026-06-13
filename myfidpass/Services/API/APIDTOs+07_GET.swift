//
//  APIDTOs+07_GET.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

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
    /// `queued` | `sending` | `delivered` | `partial` | `failed` | `no_targets`
    let deliveryStatus: String?
    /// Cibles prévues tant que la livraison n’est pas confirmée (ne pas confondre avec « membres touchés »).
    let expectedDevices: Int?

    // IMPORTANT : les décodeurs APIClient / MerchantStatisticsDiskCache utilisent
    // `.convertFromSnakeCase` — les clés JSON snake_case sont converties en camelCase
    // AVANT le lookup. Les rawValues doivent donc être en camelCase (un rawValue
    // "batch_id" ne matcherait jamais). `48h`/`7d` deviennent `48H`/`7D` à la conversion.
    enum CodingKeys: String, CodingKey {
        case batchId
        case triggerName
        case createdAt
        case sentTotal
        case recipientsDistinct
        case returnedWithin48h = "returnedWithin48H"
        case returnedWithin7dLegacy = "returnedWithin7D"
        case title
        case notificationTitle
        case pushTitle
        case message
        case body
        case pushBody
        case content
        case messagePreview
        case sentPasskit
        case passkitSent
        case sentWebPush
        case sentWeb
        case deliveryStatus
        case expectedDevices
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
        deliveryStatus = try c.decodeIfPresent(String.self, forKey: .deliveryStatus)
        expectedDevices = try c.decodeIfPresent(Int.self, forKey: .expectedDevices)
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
        sentWebPush: Int? = nil,
        deliveryStatus: String? = nil,
        expectedDevices: Int? = nil
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
        self.deliveryStatus = deliveryStatus
        self.expectedDevices = expectedDevices
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
        try c.encodeIfPresent(deliveryStatus, forKey: .deliveryStatus)
        try c.encodeIfPresent(expectedDevices, forKey: .expectedDevices)
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
            sentTotal: Self.mergeCount(sentTotal, other.sentTotal),
            recipientsDistinct: Self.mergeCount(recipientsDistinct, other.recipientsDistinct),
            returnedWithin48h: Self.mergeCount(returnedWithin48h, other.returnedWithin48h),
            notificationTitle: notificationTitle ?? other.notificationTitle,
            message: message ?? other.message,
            sentPasskit: Self.mergeCount(sentPasskit, other.sentPasskit),
            sentWebPush: Self.mergeCount(sentWebPush, other.sentWebPush),
            deliveryStatus: deliveryStatus ?? other.deliveryStatus,
            expectedDevices: Self.mergeCount(expectedDevices, other.expectedDevices)
        )
    }

    var isDeliveryPending: Bool {
        let s = deliveryStatus?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return s == "queued" || s == "sending" || s == "pending"
    }

    var confirmedRecipientsCount: Int {
        if isDeliveryPending { return 0 }
        return max(recipientsDistinct ?? 0, sentTotal ?? 0)
    }

    /// Garde le plus grand compteur — un `0` explicite côté API ne doit pas écraser une valeur correcte de l’autre source.
    private static func mergeCount(_ a: Int?, _ b: Int?) -> Int? {
        switch (a, b) {
        case let (x?, y?): return max(x, y)
        case let (x?, nil): return x
        case let (nil, y?): return y
        default: return nil
        }
    }
}

