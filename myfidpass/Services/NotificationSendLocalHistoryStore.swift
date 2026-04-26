//
//  NotificationSendLocalHistoryStore.swift
//  myfidpass
//
//  Historise côté app les envois de campagne réussis afin d’alimenter Statistiques
//  même si `GET .../dashboard/stats` n’expose pas (encore) `notification_campaigns` avec détail.
//

import Foundation

struct NotificationSendLocalEntry: Codable, Sendable {
    var id: String
    var createdAtISO: String
    var title: String?
    var message: String
    var recipientOrSentCount: Int
}

enum NotificationSendLocalHistoryStore {
    private static let storageKey = "myfidpass.notificationSendLocalHistory.v1"
    private static let perSlugMax = 40

    static func recordSuccess(
        slug: String,
        title: String?,
        message: String,
        count: Int
    ) {
        let slugKey = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slugKey.isEmpty else { return }
        var map = readMap()
        var list = map[slugKey] ?? []
        let iso: String = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f.string(from: Date())
        }()
        let t = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !m.isEmpty else { return }
        let e = NotificationSendLocalEntry(
            id: "local:\(UUID().uuidString)",
            createdAtISO: iso,
            title: (t?.isEmpty == false) ? t : nil,
            message: m,
            recipientOrSentCount: max(0, count)
        )
        // Évite doublon immédiat (double tap / retour d’API dupliqué)
        if let last = list.last, last.message == e.message, last.title == e.title, last.recipientOrSentCount == e.recipientOrSentCount,
           (isoDistanceSeconds(last.createdAtISO, e.createdAtISO) ?? 999) < 4
        {
            return
        }
        list.append(e)
        if list.count > perSlugMax { list = Array(list.suffix(perSlugMax)) }
        map[slugKey] = list
        writeMap(map)
    }

    static func entries(for slug: String) -> [NotificationSendLocalEntry] {
        let slugKey = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slugKey.isEmpty else { return [] }
        return readMap()[slugKey] ?? []
    }

    static func clearForAllSlugs() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    // MARK: - DTOs pour l’écran statistiques

    static func asCampaignInsights(_ entries: [NotificationSendLocalEntry]) -> [NotificationCampaignInsightDTO] {
        entries
            .sorted { $0.createdAtISO > $1.createdAtISO }
            .map {
                NotificationCampaignInsightDTO(
                    batchId: $0.id,
                    triggerName: "manual",
                    createdAt: $0.createdAtISO,
                    sentTotal: $0.recipientOrSentCount,
                    recipientsDistinct: $0.recipientOrSentCount,
                    returnedWithin48h: nil,
                    notificationTitle: $0.title,
                    message: $0.message,
                    sentPasskit: nil,
                    sentWebPush: nil
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
    private static let key = "myfidpass.notificationStatsEndpointBySlug.v1"

    static func load(slug: String) -> [NotificationCampaignInsightDTO] {
        let slugKey = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slugKey.isEmpty else { return [] }
        guard let d = UserDefaults.standard.data(forKey: key) else { return [] }
        guard let map = try? JSONDecoder().decode([String: [NotificationCampaignInsightDTO]].self, from: d) else { return [] }
        return map[slugKey] ?? []
    }

    static func save(slug: String, campaigns: [NotificationCampaignInsightDTO]) {
        let slugKey = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slugKey.isEmpty else { return }
        var map: [String: [NotificationCampaignInsightDTO]] = [:]
        if let d = UserDefaults.standard.data(forKey: key),
           let existing = try? JSONDecoder().decode([String: [NotificationCampaignInsightDTO]].self, from: d) {
            map = existing
        }
        map[slugKey] = campaigns
        if let out = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(out, forKey: key)
        }
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
