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
        NotificationCenter.default.post(name: .myfidpassMerchantSetupProgressUpdated, object: nil)
    }

    /// Flyer personnalisé (cache, mémoire ou brouillon éditeur) — même critère que l’accueil / checklist.
    func isFlyerReady(for slug: String?) -> Bool {
        let key = slug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !key.isEmpty else { return false }
        Self.shared.hydrateFromDiskIfNeeded(slug: key)
        if let snap = Self.shared.snapshot(for: key) {
            if snapLooksReady(snap) { return true }
        }
        if let draft = CommerceFlyerEditorDraftStore.load(slug: key) {
            if !draft.bootstrapB64.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
            let draftBg = draft.meta.customBgDataURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !draftBg.isEmpty { return true }
        }
        guard let cached = CommerceFlyerStateCache.load(slug: key) else { return false }
        let hasBootstrap = !(cached.bootstrapPreviewB64 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasCustomBg = !(cached.customBgDataURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return cached.flyerRegistered || hasBootstrap || hasCustomBg
    }

    private func snapLooksReady(_ snap: Snapshot) -> Bool {
        let hasBootstrap = !(snap.bootstrapPreviewB64 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasCustomBg = !(snap.customBgDataURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return snap.flyerRegistered || hasBootstrap || hasCustomBg
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
