//
//  CommerceFlyerRasterCache.swift
//  myfidpass
//
//  Cache mémoire du fond flyer (data URL → UIImage) pour éviter un décodage base64
//  à chaque apparition de l’onglet Commerce / chaque sync.
//

import Foundation
import UIKit

private actor CommerceFlyerRasterInFlightCoordinator {
    private var customBgTasks: [String: Task<UIImage?, Never>] = [:]
    private var publicBgTasks: [String: Task<UIImage?, Never>] = [:]

    func customBgImage(
        key: String,
        loader: @escaping @Sendable () async -> UIImage?
    ) async -> UIImage? {
        if let existing = customBgTasks[key] { return await existing.value }
        let task = Task { await loader() }
        customBgTasks[key] = task
        let value = await task.value
        customBgTasks.removeValue(forKey: key)
        return value
    }

    func publicBgImage(
        slug: String,
        loader: @escaping @Sendable () async -> UIImage?
    ) async -> UIImage? {
        if let existing = publicBgTasks[slug] { return await existing.value }
        let task = Task { await loader() }
        publicBgTasks[slug] = task
        let value = await task.value
        publicBgTasks.removeValue(forKey: slug)
        return value
    }
}

/// Empreinte courte (longueurs + hash d’échantillons) : évite de mettre des Mo de base64 dans `.task(id:)`
/// et reste stable tant que le fond + le bootstrap ne changent pas (contrairement à `updated_at` dans le JSON).
enum CommerceFlyerHydrationFingerprint {
    static func token(slug: String?, customBg: String?, bootstrapB64: String?) -> String {
        let s = slug ?? ""
        let b = customBg ?? ""
        let b64 = bootstrapB64 ?? ""
        let sample = "\(String(b.prefix(2_000)))\(String(b.suffix(2_000)))\(String(b64.prefix(4_000)))\(String(b64.suffix(4_000)))"
        var h: UInt64 = 5381
        for u in sample.utf8 {
            h = h &* 33 &+ UInt64(u)
        }
        return "\(s)|\(b.count)|\(b64.count)|\(h)"
    }
}

enum CommerceFlyerRasterCache {
    private static let decodedBg = NSCache<NSString, UIImage>()
    private static let publicBgBySlug = NSCache<NSString, UIImage>()
    private static let compositeByToken = NSCache<NSString, UIImage>()
    private static let inFlight = CommerceFlyerRasterInFlightCoordinator()

    static func image(forCustomBgDataURL key: String) -> UIImage? {
        decodedBg.object(forKey: key as NSString)
    }

    static func setImage(_ image: UIImage, forCustomBgDataURL key: String) {
        decodedBg.setObject(image, forKey: key as NSString)
    }

    /// GET `…/public/flyer-custom-bg` (même slug) — évite un aller-retour réseau à chaque affichage Commerce.
    private static func publicBgCacheKey(slug: String, revisionKey: String?) -> String {
        let r = revisionKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if r.isEmpty { return slug }
        return "\(slug)|\(r)"
    }

    static func image(forPublicFlyerBgSlug slug: String, revisionKey: String? = nil) -> UIImage? {
        let t = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let key = publicBgCacheKey(slug: t, revisionKey: revisionKey)
        return publicBgBySlug.object(forKey: key as NSString)
    }

    static func setPublicFlyerBgImage(_ image: UIImage, slug: String, revisionKey: String? = nil) {
        let t = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let key = publicBgCacheKey(slug: t, revisionKey: revisionKey)
        publicBgBySlug.setObject(image, forKey: key as NSString)
    }

    static func compositeSnapshotToken(slug: String?, bootstrapB64: String?) -> String? {
        let s = slug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let b = bootstrapB64?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !s.isEmpty, !b.isEmpty else { return nil }
        return CommerceFlyerHydrationFingerprint.token(slug: s, customBg: nil, bootstrapB64: b)
    }

    static func image(forCompositeToken token: String) -> UIImage? {
        if let mem = compositeByToken.object(forKey: token as NSString) {
            if isLikelyInvalidCompositeSnapshot(mem) {
                compositeByToken.removeObject(forKey: token as NSString)
                if let url = compositeSnapshotDiskURL(token: token) { try? FileManager.default.removeItem(at: url) }
                return nil
            }
            return mem
        }
        guard let url = compositeSnapshotDiskURL(token: token),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        if isLikelyInvalidCompositeSnapshot(image) {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        compositeByToken.setObject(image, forKey: token as NSString)
        return image
    }

    static func setCompositeImage(_ image: UIImage, token: String) {
        guard !isLikelyInvalidCompositeSnapshot(image) else { return }
        compositeByToken.setObject(image, forKey: token as NSString)
        guard let url = compositeSnapshotDiskURL(token: token),
              let data = image.jpegData(compressionQuality: 0.9) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func coalescedCustomBgImage(
        key: String,
        loader: @escaping @Sendable () async -> UIImage?
    ) async -> UIImage? {
        if let cached = image(forCustomBgDataURL: key) { return cached }
        let loaded = await inFlight.customBgImage(key: key, loader: loader)
        if let loaded { setImage(loaded, forCustomBgDataURL: key) }
        return loaded
    }

    static func coalescedPublicBgImage(
        slug: String,
        revisionKey: String? = nil,
        loader: @escaping @Sendable () async -> UIImage?
    ) async -> UIImage? {
        let t = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if let cached = image(forPublicFlyerBgSlug: t, revisionKey: revisionKey) { return cached }
        let inflightKey = publicBgCacheKey(slug: t, revisionKey: revisionKey)
        let loaded = await inFlight.publicBgImage(slug: inflightKey, loader: loader)
        if let loaded { setPublicFlyerBgImage(loaded, slug: t, revisionKey: revisionKey) }
        return loaded
    }

    /// Purge mémoire globale des rendus flyer (changement de session / suppression de compte).
    static func clearAll() {
        decodedBg.removeAllObjects()
        publicBgBySlug.removeAllObjects()
        compositeByToken.removeAllObjects()
        purgeCompositeSnapshotsDisk()
        purgeFlyerTransientCacheFilesInCachesDirectory()
    }

    private static func purgeCompositeSnapshotsDisk() {
        guard let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let dir = root.appendingPathComponent("CommerceFlyerCompositeSnapshots", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
    }

    /// Fichiers hors `CommerceFlyerStateCache` (Caches/) — voir `FlyerPendingBgStorage` / `FlyerRecreatePreviousBackupStorage` dans le hub flyer.
    private static func purgeFlyerTransientCacheFilesInCachesDirectory() {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: caches.path) else { return }
        for name in names where name.hasPrefix("flyerPendingBg_") || name.hasPrefix("flyerRecreatePrevious_") {
            try? fm.removeItem(at: caches.appendingPathComponent(name))
        }
    }

    private static func compositeSnapshotDiskURL(token: String) -> URL? {
        guard !token.isEmpty else { return nil }
        guard let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let dir = root.appendingPathComponent("CommerceFlyerCompositeSnapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let safe = token.replacingOccurrences(of: "/", with: "_")
        return dir.appendingPathComponent("\(safe).jpg")
    }

    /// Évite de persister un snapshot WebView vide/noir (race de rendu) qui masquerait le vrai flyer.
    private static func isLikelyInvalidCompositeSnapshot(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return true }
        let width = 24
        let height = 24
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var buffer = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let ctx = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return true }

        ctx.interpolationQuality = .low
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        var luminances: [Double] = []
        luminances.reserveCapacity(width * height)

        for y in 0..<height {
            for x in 0..<width {
                let i = y * bytesPerRow + x * bytesPerPixel
                let r = Double(buffer[i]) / 255.0
                let g = Double(buffer[i + 1]) / 255.0
                let b = Double(buffer[i + 2]) / 255.0
                let a = Double(buffer[i + 3]) / 255.0
                let lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) * a
                luminances.append(lum)
            }
        }

        guard !luminances.isEmpty else { return true }
        let mean = luminances.reduce(0, +) / Double(luminances.count)
        let variance = luminances.reduce(0) { $0 + (($1 - mean) * ($1 - mean)) } / Double(luminances.count)
        let std = sqrt(variance)

        // Noir/uni très sombre => snapshot invalide typique.
        return mean < 0.06 || (mean < 0.10 && std < 0.015)
    }
}
