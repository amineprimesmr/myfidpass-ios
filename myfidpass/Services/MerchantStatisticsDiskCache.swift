//
//  MerchantStatisticsDiskCache.swift
//  myfidpass
//
//  Cache JSON locale des stats par mois : réouverture instantanée + carrousel sans attente réseau.
//

import Foundation

enum MerchantStatisticsDiskCache {
    private static let folderName = "MerchantStatistics_v2"
    private static let maxMonthsStored = 18

    private struct FilePayload: Codable {
        var months: [String: CachedMonth]
    }

    struct CachedMonth: Codable {
        let stats: BusinessStatsResponse
        let evolution: [EvolutionWeekDTO]
        let traffic: DashboardTrafficPatternsResponse?
    }

    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private static func sanitizedSlug(_ slug: String) -> String {
        slug.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
    }

    private static func cacheURL(slug: String) throws -> URL {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "MerchantStatisticsDiskCache", code: 1)
        }
        let dir = base.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("stats_\(sanitizedSlug(slug)).json")
    }

    static func load(slug: String, period: String) -> CachedMonth? {
        guard !slug.isEmpty, !period.isEmpty else { return nil }
        do {
            let url = try cacheURL(slug: slug)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)
            let payload = try decoder().decode(FilePayload.self, from: data)
            return payload.months[period]
        } catch {
            return nil
        }
    }

    static func save(slug: String, period: String, snapshot: CachedMonth) {
        guard !slug.isEmpty, !period.isEmpty else { return }
        do {
            let url = try cacheURL(slug: slug)
            var payload: FilePayload
            if FileManager.default.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                payload = (try? decoder().decode(FilePayload.self, from: data)) ?? FilePayload(months: [:])
            } else {
                payload = FilePayload(months: [:])
            }
            payload.months[period] = snapshot
            if payload.months.count > maxMonthsStored {
                let keys = payload.months.keys.sorted()
                let drop = keys.prefix(payload.months.count - maxMonthsStored)
                for k in drop { payload.months.removeValue(forKey: k) }
            }
            let out = try encoder().encode(payload)
            try out.write(to: url, options: [.atomic])
        } catch {}
    }

    /// Supprime le fichier cache pour un commerce (ex. changement de compte).
    static func clear(slug: String) {
        guard !slug.isEmpty else { return }
        guard let url = try? cacheURL(slug: slug) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Un mois précis (ex. après sync) : le prochain `load(period:)` ira au réseau.
    static func removePeriod(slug: String, period: String) {
        guard !slug.isEmpty, !period.isEmpty else { return }
        do {
            let url = try cacheURL(slug: slug)
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let data = try Data(contentsOf: url)
            var payload = try decoder().decode(FilePayload.self, from: data)
            payload.months.removeValue(forKey: period)
            let out = try encoder().encode(payload)
            try out.write(to: url, options: [.atomic])
        } catch {}
    }

    /// Mois civil courant `YYYY-MM` : invalide le cache disque des stats du mois affiché par défaut.
    static func invalidateCurrentCalendarMonth(slug: String, reference: Date = Date()) {
        let cal = Calendar(identifier: .gregorian)
        let d = cal.startOfDay(for: reference)
        let y = cal.component(.year, from: d)
        let m = cal.component(.month, from: d)
        let key = String(format: "%04d-%02d", y, m)
        removePeriod(slug: slug, period: key)
    }
}
