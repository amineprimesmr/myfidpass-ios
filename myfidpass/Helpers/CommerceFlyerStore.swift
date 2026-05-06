//
//  CommerceFlyerStore.swift
//  myfidpass
//
//  Source de vérité unifiée (mémoire) pour l’état flyer cross-écrans.
//

import Foundation

final class CommerceFlyerStore {
    static let shared = CommerceFlyerStore()

    struct Snapshot: Equatable {
        var flyerRegistered: Bool
        var shareURL: String
        var bootstrapPreviewB64: String?
        var customBgDataURL: String?
        var revisionKey: String?
    }

    private var snapshotsBySlug: [String: Snapshot] = [:]

    private init() {}

    func snapshot(for slug: String) -> Snapshot? {
        let key = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        return snapshotsBySlug[key]
    }

    func hydrateFromDiskIfNeeded(slug: String) {
        let key = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        guard snapshotsBySlug[key] == nil else { return }
        guard let cached = CommerceFlyerStateCache.load(slug: key) else { return }
        snapshotsBySlug[key] = Snapshot(
            flyerRegistered: cached.flyerRegistered,
            shareURL: cached.shareURL,
            bootstrapPreviewB64: cached.bootstrapPreviewB64,
            customBgDataURL: cached.customBgDataURL,
            revisionKey: cached.revisionKey
        )
    }

    func upsert(slug: String, snapshot: Snapshot) {
        let key = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        snapshotsBySlug[key] = snapshot
    }

    func clear(slug: String) {
        let key = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        snapshotsBySlug.removeValue(forKey: key)
    }

    func clearAll() {
        snapshotsBySlug.removeAll()
    }
}
