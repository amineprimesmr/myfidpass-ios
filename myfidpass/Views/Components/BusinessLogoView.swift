//
//  BusinessLogoView.swift
//  myfidpass
//
//  Affiche le logo du commerce (fichier local, URL API authentifiée, ou URL externe).
//

import SwiftUI

/// Quel média authentifié est affiché : permet des caches `?v=` **indépendants** (carte / fiche / campagne).
enum LogoAssetContext: Equatable {
    case automatic
    case merchantStripeLogo
    case merchantLogoIcon
    case campaignNotificationIcon
}

struct BusinessLogoView: View {
    var logoURL: String?
    /// Par défaut `automatic` : déduit le type depuis le chemin d’URL (`/logo`, `/logo-icon`, `/notification-icon`).
    var logoAssetContext: LogoAssetContext = .automatic
    var size: CGFloat = 80
    var cornerRadius: CGFloat = 20

    var body: some View {
        Group {
            if let urlString = logoURL?.trimmingCharacters(in: .whitespaces), !urlString.isEmpty {
                logoImage(from: urlString)
            } else {
                Image(systemName: "building.2.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(AppTheme.Colors.primary.opacity(0.8))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func logoImage(from urlString: String) -> some View {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        if let path = APIResourceURL.localImageFilePathIfPresent(trimmed) {
            AsyncLocalFileImage(filePath: path, contentMode: .fill)
                .id(path)
        } else if let url = APIResourceURL.resolved(from: trimmed), shouldLoadNotificationIconWithAsyncImage(url) {
            // GET …/notification-icon est public côté API; on passe par le loader maison
            // pour bénéficier du cache mémoire/disque et éviter le flash au ré-affichage.
            let displayURL = authenticatedLogoURLWithCacheBust(url)
            ProfileAuthenticatedLogoView(url: displayURL, size: size)
            .id(displayURL.absoluteString)
        } else if let url = APIResourceURL.resolved(from: trimmed), isAPILogoURL(url) {
            let displayURL = authenticatedLogoURLWithCacheBust(url)
            ProfileAuthenticatedLogoView(url: displayURL, size: size)
                .id(displayURL.absoluteString)
        } else if let url = APIResourceURL.resolved(from: trimmed) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    logoPlaceholder
                @unknown default:
                    logoPlaceholder
                }
            }
            .id(url.absoluteString)
        } else {
            logoPlaceholder
        }
    }

    /// `notification-icon` est géré à part (`AsyncImage` public) — ne pas l’inclure ici.
    private func isAPILogoURL(_ url: URL) -> Bool {
        guard url.scheme == "http" || url.scheme == "https" else { return false }
        guard hostsMatchAPIBase(url) else { return false }
        let p = url.path
        if p.contains("/notification-icon") { return false }
        return p.hasSuffix("/logo") || p.contains("/logo-icon")
    }

    private func shouldLoadNotificationIconWithAsyncImage(_ url: URL) -> Bool {
        guard url.scheme == "http" || url.scheme == "https" else { return false }
        guard hostsMatchAPIBase(url) else { return false }
        return url.path.contains("/notification-icon")
    }

    private func hostsMatchAPIBase(_ url: URL) -> Bool {
        let h1 = url.host()?.lowercased()
        let h2 = APIConfig.baseURL.host()?.lowercased()
        guard let h1, let h2 else { return false }
        return h1 == h2
    }

    private func resolvedAssetContext(for url: URL) -> LogoAssetContext {
        if logoAssetContext != .automatic { return logoAssetContext }
        let p = url.path
        if p.contains("/notification-icon") { return .campaignNotificationIcon }
        if p.contains("/logo-icon") { return .merchantLogoIcon }
        if p.hasSuffix("/logo") { return .merchantStripeLogo }
        return .merchantStripeLogo
    }

    private func businessSlug(from url: URL) -> String? {
        let parts = url.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard let businessesIndex = parts.firstIndex(of: "businesses"),
              businessesIndex + 1 < parts.count else { return nil }
        let slug = parts[businessesIndex + 1].trimmingCharacters(in: .whitespacesAndNewlines)
        return slug.isEmpty ? nil : slug
    }

    /// Cache HTTP / mémoire : `v` selon le **type** de média (commerce vs campagne).
    private func authenticatedLogoURLWithCacheBust(_ url: URL) -> URL {
        let ctx = resolvedAssetContext(for: url)
        switch ctx {
        case .campaignNotificationIcon:
            var c = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let slug = businessSlug(from: url),
               let d = CampaignNotificationImageCache.bestBustDate(for: slug) {
                c?.queryItems = [URLQueryItem(name: "v", value: Self.cacheBustQueryValue(from: d))]
            }
            return c?.url ?? url
        case .merchantLogoIcon:
            if let slug = businessSlug(from: url) {
                return MerchantLogoAssetCache.logoIconDisplayURL(url, slug: slug)
            }
            return MerchantLogoAssetCache.logoIconDisplayURL(url)
        case .merchantStripeLogo:
            if let slug = businessSlug(from: url) {
                return MerchantLogoAssetCache.stripeLogoDisplayURL(url, slug: slug)
            }
            return MerchantLogoAssetCache.stripeLogoDisplayURL(url)
        case .automatic:
            return url
        }
    }

    /// `Int(secondes)` pour `?v=` faisait coller deux URLs dans la même seconde → `URLCache` / `AsyncImage` pouvaient réutiliser l’ancienne image.
    private static func cacheBustQueryValue(from date: Date) -> String {
        String(Int64((date.timeIntervalSince1970 * 1000.0).rounded()))
    }

    private var logoPlaceholder: some View {
        Image(systemName: "photo.circle.fill")
            .font(.system(size: size * 0.5))
            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.6))
    }
}

// Chargement du logo depuis l’API (Bearer).
private struct ProfileAuthenticatedLogoView: View {
    let url: URL
    let size: CGFloat
    @State private var image: UIImage?
    @State private var failed = false

    private var urlKey: String { url.absoluteString }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if failed {
                Image(systemName: "photo.circle.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.6))
            } else {
                Image(systemName: "photo.circle.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.45))
            }
        }
        .onChange(of: urlKey) { _, _ in
            image = nil
            failed = false
        }
        .task(id: urlKey) {
            let loadKey = urlKey
            if let instant = AuthenticatedMediaLoader.memoryCachedImage(for: url, maxPixelDimension: 720) {
                await MainActor.run {
                    guard loadKey == urlKey else { return }
                    image = instant
                }
            }
            guard AuthStorage.authToken != nil, !(AuthStorage.authToken ?? "").isEmpty else {
                await MainActor.run {
                    guard loadKey == urlKey else { return }
                    failed = true
                }
                return
            }
            do {
                let img = try await AuthenticatedMediaLoader.loadAuthenticatedImage(from: url, maxPixelDimension: 720)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard loadKey == urlKey else { return }
                    image = img
                    failed = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard loadKey == urlKey else { return }
                    if image == nil { failed = true }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        BusinessLogoView(logoURL: nil)
        BusinessLogoView(logoURL: "https://via.placeholder.com/100", size: 60)
    }
    .padding()
}
