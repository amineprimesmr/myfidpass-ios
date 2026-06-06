//
//  RewardGiftImageCatalog.swift
//  myfidpass
//
//  Icônes récompense `gift1`…`gift5` — aligné page client fidelity (`/assets/gift/giftN.png`).
//

import SwiftUI
import UIKit

enum RewardGiftImageCatalog {
    static let defaultGiftCount = 5

    /// Rotation par index de palier (comme `defaultGiftImageUrl` côté web).
    static func defaultAssetName(tierIndex: Int) -> String {
        let n = (max(0, tierIndex) % defaultGiftCount) + 1
        return resolvedAssetName("gift/gift\(n)")
    }

    /// Résout l’image à afficher pour la validation caisse.
    static func assetName(
        tierIndex: Int?,
        mode: String,
        pointsRequired: Int,
        qrTierIndex: Int? = nil,
        customImageURL: String? = nil
    ) -> String {
        if let custom = normalizedCustomImageAsset(customImageURL) {
            return custom
        }
        let idx = resolvedTierIndex(
            tierIndex: tierIndex,
            mode: mode,
            pointsRequired: pointsRequired,
            qrTierIndex: qrTierIndex
        )
        return defaultAssetName(tierIndex: idx)
    }

    static func resolvedTierIndex(
        tierIndex: Int?,
        mode: String,
        pointsRequired: Int,
        qrTierIndex: Int? = nil
    ) -> Int {
        if let tierIndex, tierIndex >= 0 { return tierIndex }
        if let qrTierIndex, qrTierIndex >= 0 { return qrTierIndex }
        if mode == "stamps" {
            if pointsRequired <= 0 { return 0 }
            if pointsRequired == 5 { return 1 }
            return 2
        }
        return 0
    }

    private static func normalizedCustomImageAsset(_ raw: String?) -> String? {
        let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !t.isEmpty else { return nil }
        if t.hasPrefix("data:image/") { return nil }
        if t.contains("giftgold") { return resolvedAssetName("icons/giftgold") }
        if t.contains("giftsilver") { return resolvedAssetName("icons/giftsilver") }
        for n in 1...defaultGiftCount where t.contains("gift\(n)") {
            return resolvedAssetName("gift/gift\(n)")
        }
        return nil
    }

    private static func resolvedAssetName(_ base: String) -> String {
        if UIImage(named: base) != nil { return base }
        let leaf = base.split(separator: "/").last.map(String.init) ?? base
        if UIImage(named: leaf) != nil { return leaf }
        return base
    }
}

/// Visuel récompense : image palier (gift1…5) ou URL distante.
struct RewardGiftImageView: View {
    let tierIndex: Int?
    let mode: String
    let pointsRequired: Int
    var qrTierIndex: Int? = nil
    var customImageURL: String? = nil
    var size: CGFloat = 88

    var body: some View {
        let remote = customImageURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !remote.isEmpty,
           remote.lowercased().hasPrefix("http"),
           let url = URL(string: remote) {
            AuthenticatedLogoView(url: url, stripBackgroundFill: false)
                .frame(width: size, height: size)
        } else {
            let name = RewardGiftImageCatalog.assetName(
                tierIndex: tierIndex,
                mode: mode,
                pointsRequired: pointsRequired,
                qrTierIndex: qrTierIndex,
                customImageURL: customImageURL
            )
            Image(name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        }
    }
}
