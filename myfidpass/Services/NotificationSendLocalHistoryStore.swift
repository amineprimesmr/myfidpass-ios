//
//  NotificationSendLocalHistoryStore.swift
//  myfidpass
//
//  Historise côté app les envois de campagne afin d’alimenter Statistiques
//  immédiatement (HTTP 202) puis met à jour les compteurs après livraison confirmée.
//

import Foundation

struct NotificationSendLocalEntry: Codable, Sendable {
    var id: String
    var createdAtISO: String
    var title: String?
    var message: String
    var recipientOrSentCount: Int
    var expectedDevices: Int?
    var deliveryStatus: String?
    var jobId: String?
}

enum NotificationSendLocalHistoryStore {
    private static let storageKey = "myfidpass.notificationSendLocalHistory.v3"
    private static let perSlugMax = 40

    private static var pendingStatuses: Set<String> { ["queued", "sending", "pending"] }

    /// Clé de partition : compte connecté + commerce — évite tout mélange entre sessions ou commerces.
    private static func scopedStorageKey(slug: String) -> String {
        notificationHistoryScopedKey(slug: slug)
    }

    static func isPendingDeliveryStatus(_ raw: String?) -> Bool {
        pendingStatuses.contains(raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "queued")
    }

    /// Enregistre une campagne **livrée** (ou état terminal) — jamais « Envoi en cours » dans l'historique.
    static func recordDelivered(
        slug: String,
        batchId: String,
        jobId: String?,
        title: String?,
        message: String,
        expectedDevices: Int,
        deliveryStatus: String,
        recipientsDistinct: Int
    ) {
        let scopeKey = scopedStorageKey(slug: slug)
        guard !scopeKey.isEmpty else { return }
        guard !isPendingDeliveryStatus(deliveryStatus) else { return }
        var map = readMap()
        var list = map[scopeKey] ?? []
        let iso = isoNow()
        let t = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !m.isEmpty else { return }
        let e = NotificationSendLocalEntry(
            id: batchId,
            createdAtISO: iso,
            title: (t?.isEmpty == false) ? t : nil,
            message: m,
            recipientOrSentCount: max(0, recipientsDistinct),
            expectedDevices: max(0, expectedDevices),
            deliveryStatus: deliveryStatus,
            jobId: jobId
        )
        if let idx = list.firstIndex(where: { $0.id == batchId }) {
            list[idx] = e
        } else if let last = list.last,
                  last.message == e.message,
                  last.title == e.title,
                  (isoDistanceSeconds(last.createdAtISO, e.createdAtISO) ?? 999) < 4 {
            return
        } else {
            list.append(e)
        }
        if list.count > perSlugMax { list = Array(list.suffix(perSlugMax)) }
        map[scopeKey] = list
        writeMap(map)
    }

    /// Suivi interne poll job → historique (mise à jour par batchId / jobId).
    static func updateDelivery(
        slug: String,
        batchId: String,
        jobId: String? = nil,
        deliveryStatus: String?,
        recipientsDistinct: Int,
        sentTotal: Int?
    ) {
        let status = deliveryStatus?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard !isPendingDeliveryStatus(status) else { return }
        let scopeKey = scopedStorageKey(slug: slug)
        guard !scopeKey.isEmpty else { return }
        var map = readMap()
        guard var list = map[scopeKey] else { return }
        let job = jobId?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let idx = list.firstIndex(where: { entry in
            if !batchId.isEmpty, entry.id == batchId { return true }
            if let job, !job.isEmpty, entry.jobId == job { return true }
            return false
        }) else { return }
        var row = list[idx]
        if !batchId.isEmpty { row.id = batchId }
        row.deliveryStatus = deliveryStatus
        let delivered = max(recipientsDistinct, sentTotal ?? 0)
        if delivered > 0 { row.recipientOrSentCount = delivered }
        list[idx] = row
        map[scopeKey] = list
        writeMap(map)
    }

    static func entries(for slug: String) -> [NotificationSendLocalEntry] {
        let scopeKey = scopedStorageKey(slug: slug)
        guard !scopeKey.isEmpty else { return [] }
        return readMap()[scopeKey] ?? []
    }

    static func clearForAllSlugs() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    // MARK: - DTOs pour l’écran statistiques

    static func asCampaignInsights(_ entries: [NotificationSendLocalEntry]) -> [NotificationCampaignInsightDTO] {
        entries
            .filter { !isPendingDeliveryStatus($0.deliveryStatus) }
            .sorted { $0.createdAtISO > $1.createdAtISO }
            .map {
                let confirmed = max($0.recipientOrSentCount, 0)
                return NotificationCampaignInsightDTO(
                    batchId: $0.id,
                    triggerName: "manual",
                    createdAt: $0.createdAtISO,
                    sentTotal: confirmed > 0 ? confirmed : nil,
                    recipientsDistinct: confirmed,
                    returnedWithin48h: nil,
                    notificationTitle: $0.title,
                    message: $0.message,
                    sentPasskit: nil,
                    sentWebPush: nil,
                    deliveryStatus: $0.deliveryStatus,
                    expectedDevices: $0.expectedDevices
                )
            }
    }

    private static func readMap() -> [String: [NotificationSendLocalEntry]] {
        guard let d = UserDefaults.standard.data(forKey: storageKey) else { return [:] }
        return (try? JSONDecoder().decode([String: [NotificationSendLocalEntry]].self, from: d)) ?? [:]
    }

    private static func writeMap(_ m: [String: [NotificationSendLocalEntry]]) {
        if let d = try? JSONEncoder().encode(m) {
            UserDefaults.standard.set(d, forKey: storageKey)
        }
    }

    private static func isoNow() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: Date())
    }

    private static func isoAgeSeconds(_ iso: String) -> TimeInterval? {
        isoDistanceSeconds(iso, isoNow())
    }

    private static func isoDistanceSeconds(_ a: String, _ b: String) -> TimeInterval? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let da = f.date(from: a), let db = f.date(from: b) { return abs(da.timeIntervalSince(db)) }
        f.formatOptions = [.withInternetDateTime]
        if let da = f.date(from: a), let db = f.date(from: b) { return abs(da.timeIntervalSince(db)) }
        return nil
    }
}

// MARK: - GET …/notifications/stats (cache disque / redémarrage)

/// Dernière réponse `campaigns` de l’endpoint stats notifs, par slug — évite une liste vide au cold start ou après échec réseau.
enum NotificationStatsEndpointCache {
    private static let key = "myfidpass.notificationStatsEndpointBySlug.v3"

    static func load(slug: String) -> [NotificationCampaignInsightDTO] {
        let scopeKey = notificationHistoryScopedKey(slug: slug)
        guard !scopeKey.isEmpty else { return [] }
        guard let d = UserDefaults.standard.data(forKey: key) else { return [] }
        guard let map = try? JSONDecoder().decode([String: [NotificationCampaignInsightDTO]].self, from: d) else { return [] }
        return (map[scopeKey] ?? []).filter { !NotificationSendLocalHistoryStore.isPendingDeliveryStatus($0.deliveryStatus) }
    }

    static func save(slug: String, campaigns: [NotificationCampaignInsightDTO]) {
        let scopeKey = notificationHistoryScopedKey(slug: slug)
        guard !scopeKey.isEmpty else { return }
        let deliveredOnly = campaigns.filter { !NotificationSendLocalHistoryStore.isPendingDeliveryStatus($0.deliveryStatus) }
        var map: [String: [NotificationCampaignInsightDTO]] = [:]
        if let d = UserDefaults.standard.data(forKey: key),
           let existing = try? JSONDecoder().decode([String: [NotificationCampaignInsightDTO]].self, from: d) {
            map = existing
        }
        map[scopeKey] = deliveredOnly
        if let out = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(out, forKey: key)
        }
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

/// Clé UserDefaults : `userId|slug` (ou `email|slug`) — jamais slug seul (fuites multi-comptes).
private func notificationHistoryScopedKey(slug: String) -> String {
    let slugKey = slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let account = AuthStorage.userId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        ?? AuthStorage.userEmail?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        ?? ""
    guard !slugKey.isEmpty else { return "" }
    return account.isEmpty ? slugKey : "\(account)|\(slugKey)"
}
