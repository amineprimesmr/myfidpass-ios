//
//  CommerceFlyerEditorDraftStore.swift
//  myfidpass
//
//  Brouillon de session « Modifier le flyer » : survit à un passage en arrière-plan / kill
//  pour que l’utilisateur retrouve le design en cours à la réouverture.
//

import Foundation

/// Encodage stable de `FlyerRemoteImagePayload` (hors de la cible `Codable` API).
struct FlyerEditorImagePayloadSnapshot: Codable, Equatable {
    enum Mode: String, Codable { case leaveUnchanged, clear, dataURL }
    var mode: Mode
    var data: String?

    static func from(_ p: FlyerRemoteImagePayload) -> FlyerEditorImagePayloadSnapshot {
        switch p {
        case .leaveUnchanged: return .init(mode: .leaveUnchanged, data: nil)
        case .clear: return .init(mode: .clear, data: nil)
        case .dataURL(let s): return .init(mode: .dataURL, data: s)
        }
    }

    func toPayload() -> FlyerRemoteImagePayload {
        switch mode {
        case .leaveUnchanged: return .leaveUnchanged
        case .clear: return .clear
        case .dataURL: return .dataURL(data ?? "")
        }
    }
}

struct FlyerEditorSessionDraftMeta: Codable, Equatable {
    var shareURL: String
    var customBgDataURL: String?
    var serverLogoDataUrl: String?
    var serverBgDataUrl: String?
    var logoPayload: FlyerEditorImagePayloadSnapshot
    var bgPayload: FlyerEditorImagePayloadSnapshot
    var suppressDashboardCustomLogoForPreview: Bool
    var cachedPublicLogoDataUrl: String?
    var serverUpdatedAt: String?
    var savedAt: Date
}

enum CommerceFlyerEditorDraftStore {
    private static let metaFilename = "editor_draft_meta.json"
    private static let bootstrapFilename = "editor_draft_bootstrap.b64"

    private static let maxCustomBgChars = 6_500_000
    private static let maxResumeAge: TimeInterval = 60 * 60 * 24 * 30

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

    static func load(slug: String) -> (meta: FlyerEditorSessionDraftMeta, bootstrapB64: String)? {
        guard !slug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let dir = try? directoryURL(slug: slug) else { return nil }
        let metaURL = dir.appendingPathComponent(metaFilename)
        let bootURL = dir.appendingPathComponent(bootstrapFilename)
        guard let metaData = try? Data(contentsOf: metaURL),
              let meta = try? JSONDecoder().decode(FlyerEditorSessionDraftMeta.self, from: metaData)
        else { return nil }
        guard let s = try? String(contentsOf: bootURL, encoding: .utf8) else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if Date().timeIntervalSince(meta.savedAt) >= maxResumeAge {
            clear(slug: slug)
            return nil
        }
        return (meta: meta, bootstrapB64: t)
    }

    static func save(
        slug: String,
        bootstrapB64: String,
        meta: FlyerEditorSessionDraftMeta
    ) {
        let b = bootstrapB64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !b.isEmpty else { return }
        var m = meta
        if let c = m.customBgDataURL, c.count > maxCustomBgChars {
            m.customBgDataURL = nil
        }
        guard let dir = try? directoryURL(slug: slug) else { return }
        let metaURL = dir.appendingPathComponent(metaFilename)
        let bootURL = dir.appendingPathComponent(bootstrapFilename)
        if let j = try? JSONEncoder().encode(m) {
            try? j.write(to: metaURL, options: .atomic)
        }
        try? b.data(using: .utf8)?.write(to: bootURL, options: .atomic)
    }

    static func clear(slug: String) {
        guard !slug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let dir = try? directoryURL(slug: slug) else { return }
        let metaURL = dir.appendingPathComponent(metaFilename)
        let bootURL = dir.appendingPathComponent(bootstrapFilename)
        try? FileManager.default.removeItem(at: metaURL)
        try? FileManager.default.removeItem(at: bootURL)
    }
}
