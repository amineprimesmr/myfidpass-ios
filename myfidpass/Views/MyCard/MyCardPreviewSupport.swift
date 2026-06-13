//
//  MyCardPreviewSupport.swift
//  myfidpass — types et vues d’aperçu carte (extrait de MyCardView.swift)
//

import SwiftUI
import UIKit

enum CardPreviewFormat: String, CaseIterable {
    case wallet
    case creditCard
    case stampGrid
    /// Design dédié avec grille de tampons visible (Café des Arts).
    case cafeDesArts
}

/// Modifier pour adopter le style Liquid Glass natif des sheets sur iOS 26 (coins système, pas de fond opaque).
struct LiquidGlassSheetModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.presentationCornerRadius(nil)
        } else {
            content
        }
    }
}

/// Aperçu d’une image depuis une URL (http) ou un chemin local (logo ou image de fond).
struct CardImagePreviewView: View {
    let urlOrPath: String
    var body: some View {
        let trimmed = urlOrPath.trimmingCharacters(in: .whitespaces)
        Group {
            if trimmed.isEmpty {
                EmptyView()
            } else if let filePath = resolvedFilePath(trimmed) {
                LocalImagePreviewView(path: filePath)
            } else if let url = resolvedHTTPURL(trimmed), isAPILogoURL(url) {
                AuthenticatedLogoView(url: MerchantLogoAssetCache.stripeLogoDisplayURL(url), stripBackgroundFill: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if let url = resolvedHTTPURL(trimmed), isAPICardBackgroundURL(url) {
                AuthenticatedLogoView(url: url, stripBackgroundFill: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if let url = resolvedHTTPURL(trimmed) {
                DecodedURLImage(url: url, contentMode: .fit, maxPixelDimension: 1200)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                LocalImagePreviewView(path: urlOrPath)
            }
        }
        .id(trimmed)
    }

    private func resolvedHTTPURL(_ s: String) -> URL? {
        if let u = URL(string: s), u.scheme == "http" || u.scheme == "https" { return u }
        if s.hasPrefix("/"), let u = URL(string: s, relativeTo: APIConfig.baseURL)?.absoluteURL,
           u.scheme == "http" || u.scheme == "https" {
            return u
        }
        return nil
    }

    private func resolvedFilePath(_ path: String) -> String? {
        APIResourceURL.localImageFilePathIfPresent(path)
            ?? CardLogoStorage.fullPath(forRelative: path)
    }

    private func isAPILogoURL(_ url: URL) -> Bool {
        guard url.scheme == "http" || url.scheme == "https" else { return false }
        guard url.host() == APIConfig.baseURL.host() else { return false }
        return url.path.hasSuffix("/logo")
    }

    private func isAPICardBackgroundURL(_ url: URL) -> Bool {
        (url.scheme == "http" || url.scheme == "https") && url.host() == APIConfig.baseURL.host() && url.path.contains("card-background")
    }
}

private struct LocalImagePreviewView: View {
    let path: String
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .onAppear { loadImage() }
        .onChange(of: path) { _, _ in loadImage() }
    }

    private func loadImage() {
        let fullPath = path.hasPrefix("/") || path.hasPrefix("file:") ? (path.hasPrefix("file:") ? (URL(string: path)?.path ?? path) : path) : (CardLogoStorage.fullPath(forRelative: path) ?? path)
        Task {
            let fp = fullPath
            let img = await Task.detached(priority: .userInitiated) {
                ImageIODownsampling.imageFromFile(at: fp, maxPixelDimension: 1400)
            }.value
            await MainActor.run { image = img }
        }
    }
}

/// Paliers points éditables dans « Récompenses » (10 pts inclus en 1ʳᵉ ligne).
enum MyCardPointsRewardTiers {
    static let slotCount = 8
    static let minVisibleCount = 5
}

/// État comparé pour savoir si « Enregistrer » doit apparaître (aligné sur ce que `saveTemplate` envoie).
struct MyCardPersistedSnapshot: Equatable {
    var displayName: String
    var requiredStamps: Int
    var primaryHex: String
    var accentHex: String
    var labelHex: String
    var stripDisplayMode: String
    var stripText: String
    var logoURL: String
    var localLogoFileModification: Date?
    var stampEmoji: String
    var cardBackgroundImagePath: String?
    var localCardBackgroundFileModification: Date?
    var cardBackgroundRemoteURL: String?
    var cardBackgroundWasRemoved: Bool
    var programType: String
    var pointsPerEuro: Int
    var pointsPerVisit: Int
    var pointsMinAmountEur: String
    var tierPoints: [String]
    var tierLabels: [String]
    var stampRewardLabel: String
    var expiryMonths: String
    var sector: String
    var stampMidRewardLabel: String
    var stampMidRewardEnabled: Bool
    var startGameRewardLabel: String
    var backTerms: String
    var backContact: String
    var labelRestants: String
    var labelMember: String
    var notificationTitleOverride: String
    var notificationChangeMessage: String
    var stampIconWasRemoved: Bool
    var stampIconPendingBase64: String?
}
