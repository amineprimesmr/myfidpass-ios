//
//  CommerceFlyerStateCache.swift
//  myfidpass
//
//  Cache local (Application Support) pour affichage instantané de la checklist Commerce
//  avant la fin des GET réseau (évite le flash « Créer le flyer » + recharge la miniature).
//

import Foundation

enum CommerceFlyerStateCache {
    struct Loaded {
        var flyerRegistered: Bool
        var shareURL: String
        var bootstrapPreviewB64: String?
        var customBgDataURL: String?
        var engagementStepDone: Bool
    }

    private struct Meta: Codable {
        var flyerRegistered: Bool
        var shareURL: String
        var engagementStepDone: Bool
    }

    private static func sanitizedSlug(_ slug: String) -> String {
        slug.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
    }

    private static func directoryURL(slug: String) throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = root
            .appendingPathComponent("CommerceFlyerStateCache", isDirectory: true)
            .appendingPathComponent(sanitizedSlug(slug), isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Lecture synchrone (léger bloc disque) — appeler sur le main thread au `onAppear`.
    static func load(slug: String) -> Loaded? {
        guard !slug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let dir = try? directoryURL(slug: slug) else { return nil }
        let metaURL = dir.appendingPathComponent("meta.json")
        guard let data = try? Data(contentsOf: metaURL),
              let meta = try? JSONDecoder().decode(Meta.self, from: data) else { return nil }

        let bootURL = dir.appendingPathComponent("bootstrap.b64")
        let bootstrap: String? = {
            guard let s = try? String(contentsOf: bootURL, encoding: .utf8) else { return nil }
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }()

        let customURL = dir.appendingPathComponent("custom_bg.txt")
        let customBg: String? = {
            guard let s = try? String(contentsOf: customURL, encoding: .utf8) else { return nil }
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }()

        return Loaded(
            flyerRegistered: meta.flyerRegistered,
            shareURL: meta.shareURL,
            bootstrapPreviewB64: bootstrap,
            customBgDataURL: customBg,
            engagementStepDone: meta.engagementStepDone
        )
    }

    /// Plafond pour éviter d’écrire des data URL énormes ; aligné sur le backend (~6 Mo) avec marge UTF-8.
    private static let maxCustomBgChars = 6_500_000

    static func save(
        slug: String,
        flyerRegistered: Bool,
        shareURL: String,
        bootstrapB64: String?,
        engagementStepDone: Bool,
        customBgDataURL: String?
    ) {
        guard !slug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let dir = try? directoryURL(slug: slug) else { return }

        let meta = Meta(
            flyerRegistered: flyerRegistered,
            shareURL: shareURL,
            engagementStepDone: engagementStepDone
        )
        if let data = try? JSONEncoder().encode(meta) {
            try? data.write(to: dir.appendingPathComponent("meta.json"), options: .atomic)
        }

        let bootURL = dir.appendingPathComponent("bootstrap.b64")
        if let b64 = bootstrapB64, !b64.isEmpty {
            try? b64.data(using: .utf8)?.write(to: bootURL, options: .atomic)
        } else if !flyerRegistered {
            // Pas de flyer enregistré : on nettoie. Si `nil` à cause d’un GET partiel, on garde l’ancien fichier.
            try? FileManager.default.removeItem(at: bootURL)
        }

        let customURL = dir.appendingPathComponent("custom_bg.txt")
        if let c = customBgDataURL, c.count <= maxCustomBgChars {
            try? c.data(using: .utf8)?.write(to: customURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: customURL)
        }
    }
}
