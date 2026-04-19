//
//  AuthenticatedMediaLoader.swift
//  myfidpass
//
//  Cache mémoire + cache disque (clé = URL, sans token) + URLSession pour logos et fonds API (Bearer).
//  Décodage + downscale ImageIO hors thread principal (moins de RAM / moins de blocages).
//  Les chargements réseau concurrents pour la même URL + même taille sont fusionnés (un seul GET).
//

import CryptoKit
import Foundation
import UIKit

enum AuthenticatedMediaLoader {
    private static let memoryCache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 280
        c.totalCostLimit = 96 * 1024 * 1024
        return c
    }()

    private static let diskFolder: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("AuthenticatedMediaDisk", isDirectory: true)
    }()

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 180 * 1024 * 1024
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpMaximumConnectionsPerHost = 10
        config.timeoutIntervalForResource = 90
        return URLSession(configuration: config)
    }()

    /// Fusionne les `Task` concurrents (listes, plusieurs `BusinessLogoView`, etc.).
    private actor CoalescingInFlightLoads {
        static let shared = CoalescingInFlightLoads()
        private var inflight: [String: Task<UIImage, Error>] = [:]

        func run(key: String, load: @escaping () async throws -> UIImage) async throws -> UIImage {
            if let existing = inflight[key] {
                return try await existing.value
            }
            let task = Task { try await load() }
            inflight[key] = task
            defer { inflight.removeValue(forKey: key) }
            return try await task.value
        }
    }

    private static func memoryKey(url: URL, maxPixelDimension: CGFloat) -> NSString {
        // Suffixe : invalide les entrées cacheées avant la normalisation ImageIO (miniatures à mauvais ratio).
        "\(url.absoluteString)#\(Int(maxPixelDimension))#ioNorm3" as NSString
    }

    private static func approximateCost(for image: UIImage) -> Int {
        let w = max(image.size.width * image.scale, 1)
        let h = max(image.size.height * image.scale, 1)
        return min(Int(w * h * 4), 48 * 1024 * 1024)
    }

    /// Image déjà en mémoire (affichage instantané).
    static func memoryCachedImage(for url: URL, maxPixelDimension: CGFloat = 1400) -> UIImage? {
        memoryCache.object(forKey: memoryKey(url: url, maxPixelDimension: maxPixelDimension))
    }

    static func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }

    /// Appelé à la déconnexion : vide aussi le disque (tokens Bearer exclus du cache HTTP).
    static func clearDiskCache() {
        try? FileManager.default.removeItem(at: diskFolder)
        try? FileManager.default.createDirectory(at: diskFolder, withIntermediateDirectories: true)
    }

    static func clearAllCaches() {
        clearMemoryCache()
        clearDiskCache()
    }

    private static func ensureDiskFolder() {
        try? FileManager.default.createDirectory(at: diskFolder, withIntermediateDirectories: true)
    }

    /// Aligné sur `APIClient.applyDashboardTokenHeaderIfNeeded` : le backend exige `canAccessDashboard` pour les médias
    /// (`/logo`, `/card-background`, …) — le JWT seul peut ne pas suffire si `user_id` ≠ `business.user_id` ou session dégradée.
    private static func applyDashboardTokenIfNeeded(to request: inout URLRequest, url: URL) {
        let path = url.path
        guard path.hasPrefix("/api/businesses/") else { return }
        let prefix = "/api/businesses/"
        let rest = String(path.dropFirst(prefix.count))
        guard let slash = rest.firstIndex(of: "/") else { return }
        var seg = String(rest[..<slash])
        seg = seg.removingPercentEncoding ?? seg
        guard let tok = AuthStorage.dashboardToken(forSlug: seg), !tok.isEmpty else { return }
        request.setValue(tok, forHTTPHeaderField: "X-Dashboard-Token")
    }

    private static func sha256Hex(_ string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func diskFileURL(for url: URL) -> URL {
        ensureDiskFolder()
        let name = sha256Hex(url.absoluteString) + ".bin"
        return diskFolder.appendingPathComponent(name)
    }

    /// Charge l’image (mémoire → disque → réseau). Met à jour mémoire et disque.
    /// - Parameter maxPixelDimension: côté long max après décodage (logo ~900, fond carte ~1600).
    static func loadAuthenticatedImage(from url: URL, maxPixelDimension: CGFloat = 1400) async throws -> UIImage {
        let memKey = memoryKey(url: url, maxPixelDimension: maxPixelDimension)
        if let mem = memoryCache.object(forKey: memKey) {
            return mem
        }
        let diskURL = diskFileURL(for: url)
        if let data = try? Data(contentsOf: diskURL), !data.isEmpty {
            let decoded = await Task.detached(priority: .userInitiated) {
                ImageIODownsampling.imageFromData(data, maxPixelDimension: maxPixelDimension)
            }.value
            if let img = decoded, img.size.width > 0 {
                memoryCache.setObject(img, forKey: memKey, cost: approximateCost(for: img))
                return img
            }
        }

        let coalesceKey = String(memKey)
        return try await CoalescingInFlightLoads.shared.run(key: coalesceKey) {
            try await Self.fetchNetworkDecodeAndStore(
                url: url,
                maxPixelDimension: maxPixelDimension,
                diskURL: diskURL,
                memKey: memKey
            )
        }
    }

    private static func fetchNetworkDecodeAndStore(
        url: URL,
        maxPixelDimension: CGFloat,
        diskURL: URL,
        memKey: NSString
    ) async throws -> UIImage {
        if let mem = memoryCache.object(forKey: memKey) {
            return mem
        }
        let allowsUnauthenticatedGET = url.path.contains("/notification-icon")
        if !allowsUnauthenticatedGET {
            guard let token = AuthStorage.authToken, !token.isEmpty else {
                throw URLError(.userAuthenticationRequired)
            }
        }
        var req = URLRequest(url: url)
        if let token = AuthStorage.authToken, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        Self.applyDashboardTokenIfNeeded(to: &req, url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        let payload: Data
        switch http.statusCode {
        case 200 ... 299:
            payload = data
        case 304:
            if let cached = URLCache.shared.cachedResponse(for: req), !cached.data.isEmpty {
                payload = cached.data
            } else {
                throw URLError(.badServerResponse)
            }
        default:
            throw URLError(.badServerResponse)
        }
        Task.detached(priority: .utility) {
            try? payload.write(to: diskURL, options: [.atomic])
        }
        let decoded = await Task.detached(priority: .userInitiated) {
            ImageIODownsampling.imageFromData(payload, maxPixelDimension: maxPixelDimension)
        }.value
        guard let img = decoded, img.size.width > 0 else {
            throw URLError(.badServerResponse)
        }
        memoryCache.setObject(img, forKey: memKey, cost: approximateCost(for: img))
        return img
    }

    /// Précharge en arrière-plan (remplit URLCache + mémoire).
    static func prefetch(url: URL?) async {
        guard let url else { return }
        let isBackground = url.path.contains("card-background")
        let cap: CGFloat = isBackground ? 1800 : 1000
        _ = try? await loadAuthenticatedImage(from: url, maxPixelDimension: cap)
    }
}
