//
//  CafeDesArtsCardPreview.swift
//  myfidpass
//
//  Aperçu mode tampons : même structure que la carte points (WalletCardPreview),
//  avec le bandeau logo identique et la zone points remplacée par la grille de tampons.
//

import SwiftUI
import UIKit

/// Même ratio que WalletCardPreview pour une carte identique en proportions.
private let walletCardAspectRatio: CGFloat = 375 / 478
private let walletCardBackgroundBannerAspect: CGFloat = 750 / 246

/// Aligné sur `WalletCardPreview` : slot logo Apple ~160×50 pt @375.
private func walletLogoSlotSize(cardWidth: CGFloat, compact: Bool) -> (maxWidth: CGFloat, maxHeight: CGFloat) {
    let ref: CGFloat = 375
    let scale = max(0.55, cardWidth / ref)
    let slotW = 160 * scale
    let slotH = 50 * scale
    if compact {
        return (min(slotW * 0.88, cardWidth * 0.46), min(slotH * 0.95, 40))
    }
    return (min(slotW * 1.05, cardWidth * 0.52), min(slotH * 1.12, 58))
}

private enum CafePassFieldFont {
    static let label: CGFloat = 12
    static let value: CGFloat = 17
    static let labelCompact: CGFloat = 10
    static let valueCompact: CGFloat = 13
}

struct CafeDesArtsCardPreview: View {
    var displayName: String
    var requiredStamps: Int32
    var stampsCount: Int32
    var primaryColorHex: String
    var accentColorHex: String
    /// Couleur du bandeau (logo). Si nil, utilise primaryColorHex.
    var stripColorHex: String? = nil
    var logoURL: String?
    var stripDisplayMode: String? = nil
    var stripText: String? = nil
    var stampEmoji: String? = nil
    var cardBackgroundImagePath: String? = nil
    var cardBackgroundRemoteURL: String? = nil
    var labelColorHex: String? = nil
    var headerRightText: String? = nil
    var rewardPreviewText: String? = nil
    var memberPreviewText: String? = nil
    var rewardColumnTitle: String = "RÉCOMPENSE"
    var memberColumnTitle: String = "MEMBRE"
    /// Libellé « Restants » (face avant pass tampons), ex. pour la ligne `Restants = N` avec image de fond.
    var restantsCaption: String = "Restants"
    var compact: Bool = false
    var onEditZoneTap: ((CardPreviewEditZone) -> Void)? = nil
    /// URL encodée dans le QR (page carte fidélité). Si `nil`, QR de démonstration.
    var fidelityQRPayloadURL: String? = nil

    private var primaryColor: Color { Color(hex: primaryColorHex) }
    private var accentColor: Color { Color(hex: accentColorHex) }
    private var labelColor: Color? { labelColorHex.flatMap { Color(hex: $0) } }
    private var bandeauColor: Color { stripColorHex.flatMap { Color(hex: $0) } ?? primaryColor }

    private var headerBarColor: Color {
        hasCardBackground ? primaryColor : bandeauColor
    }

    private var hasCardBackground: Bool {
        let local = cardBackgroundImagePath.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false
        let rem = cardBackgroundRemoteURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return local || (!rem.isEmpty && URL(string: rem).map { Self.isAPICardBackgroundURL($0) } ?? false)
    }

    private var headerRightDisplay: String {
        let t = headerRightText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? "Récompenses ↗" : t
    }

    private var rewardDisplay: String {
        let t = rewardPreviewText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? "Paliers en magasin" : t
    }

    private var memberDisplay: String {
        let t = memberPreviewText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? "Prévisualisation" : t
    }

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width.isFinite ? geo.size.width : 1)
            let h = max(1, w / walletCardAspectRatio)
            let corner: CGFloat = compact ? 9 : 14

            cardContent(cardWidth: w)
                .frame(width: w, height: h)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: compact ? 10 : 14, x: 0, y: 6)
                .frame(maxWidth: .infinity)
        }
        .aspectRatio(walletCardAspectRatio, contentMode: .fit)
        .animation(.easeOut(duration: 0.25), value: primaryColorHex)
        .animation(.easeOut(duration: 0.2), value: stampsCount)
        .animation(.easeOut(duration: 0.2), value: requiredStamps)
        .animation(.easeOut(duration: 0.2), value: logoURL)
        .animation(.easeOut(duration: 0.2), value: stampEmoji)
        .animation(.easeOut(duration: 0.25), value: cardBackgroundRemoteURL)
    }

    private func cardContent(cardWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            headerSection(cardWidth: cardWidth)
                .zIndex(1)
            cardBackgroundBannerSection(cardWidth: cardWidth)
                .zIndex(0)
            stampsBodySection(cardWidth: cardWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .zIndex(0)
            qrSection()
                .zIndex(0)
        }
    }

    private func headerSection(cardWidth: CGFloat) -> some View {
        let logoSlot = walletLogoSlotSize(cardWidth: cardWidth, compact: compact)
        let headerTopInset: CGFloat = compact ? 6 : 11
        let headerBottomInset: CGFloat = compact ? 6 : 8
        let headerH: CGFloat = compact ? 64 : 92
        return ZStack(alignment: .topLeading) {
            headerBarColor
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: headerTopInset)
                HStack(alignment: .center, spacing: 0) {
                    CardPreviewTappableZone(
                        zone: .logoBand,
                        accessibilityLabel: "Modifier le logo ou le texte du bandeau",
                        onEditZoneTap: onEditZoneTap
                    ) {
                        logoInStrip(maxWidth: logoSlot.maxWidth, maxHeight: logoSlot.maxHeight)
                            .frame(maxWidth: logoSlot.maxWidth, maxHeight: logoSlot.maxHeight, alignment: .topLeading)
                            .clipped()
                    }
                    Spacer(minLength: compact ? 4 : 8)
                    CardPreviewTappableZone(
                        zone: .headerRight,
                        accessibilityLabel: "Modifier le texte en haut à droite",
                        onEditZoneTap: onEditZoneTap
                    ) {
                        Text(headerRightDisplay)
                            .font(.system(size: compact ? 11 : 16, weight: .semibold))
                            .foregroundStyle(labelColor ?? .white.opacity(0.95))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .offset(y: compact ? -2 : -4)
                .frame(maxWidth: .infinity)
                .padding(.leading, compact ? 12 : 16)
                .padding(.trailing, compact ? 10 : 12)
                Spacer(minLength: headerBottomInset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .frame(height: headerH)
        .clipped()
    }

    @ViewBuilder
    private func cardBackgroundBannerSection(cardWidth: CGFloat) -> some View {
        if hasCardBackground {
            let bannerHeight = max(1, cardWidth / walletCardBackgroundBannerAspect)
            let banner = Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: bannerHeight)
                .overlay {
                    Group {
                        if let path = cardBackgroundImagePath, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                        } else if let remote = cardBackgroundRemoteURL?.trimmingCharacters(in: .whitespacesAndNewlines), !remote.isEmpty,
                                  let url = URL(string: remote), Self.isAPICardBackgroundURL(url) {
                            AuthenticatedLogoView(url: url, stripBackgroundFill: true)
                                .id(remote)
                        } else {
                            bandeauColor
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipped()
            CardPreviewTappableZone(
                zone: .backgroundImage,
                accessibilityLabel: "Modifier l’image de fond",
                onEditZoneTap: onEditZoneTap
            ) {
                banner
            }
        }
    }

    @ViewBuilder
    private func logoInStrip(maxWidth: CGFloat, maxHeight: CGFloat) -> some View {
        Group {
            if stripDisplayMode == "text" {
                Text(stripText?.trimmingCharacters(in: .whitespaces).isEmpty == false ? (stripText ?? displayName) : (displayName.isEmpty ? "Ma Carte" : displayName))
                    .font(.system(size: compact ? 18 : 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: .topLeading)
            } else if let urlString = logoURL?.trimmingCharacters(in: .whitespaces), !urlString.isEmpty {
                stampLogoImage(from: urlString)
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: .topLeading)
                    .clipped()
            } else {
                Image(systemName: "building.2.fill")
                    .font(.system(size: compact ? 21 : 30))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(width: min(maxHeight * 0.85, 44), height: min(maxHeight * 0.85, 44))
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: .topLeading)
            }
        }
    }

    // MARK: - Corps : grille d’icônes tampons + RÉCOMPENSE / MEMBRE (comme en mode points)

    private func stampsBodySection(cardWidth: CGFloat) -> some View {
        let total = Int(requiredStamps)
        let filled = min(max(0, Int(stampsCount)), total)
        let cols = 5
        let rows = (total + cols - 1) / cols
        let cellSize: CGFloat = compact ? 36 : 44
        let gap: CGFloat = compact ? 6 : 8
        let insetH: CGFloat = compact ? 12 : 16

        let restants = max(0, total - filled)
        let restantsLine = "\(restantsCaption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Restants" : restantsCaption) = \(restants)"

        return ZStack(alignment: .topLeading) {
            if let onEditZoneTap {
                Button {
                    onEditZoneTap(.cardAppearance)
                } label: {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.borderless)
            }
            VStack(alignment: .leading, spacing: 0) {
                if hasCardBackground {
                    HStack(alignment: .top, spacing: compact ? 4 : 8) {
                        CardPreviewTappableZone(
                            zone: .mainMetrics,
                            accessibilityLabel: "Règles du programme et emoji des tampons",
                            onEditZoneTap: onEditZoneTap
                        ) {
                            restantsSummaryBlock(text: restantsLine)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        CardPreviewTappableZone(
                            zone: .rewardColumn,
                            accessibilityLabel: "Modifier la récompense ou les paliers",
                            onEditZoneTap: onEditZoneTap
                        ) {
                            stampFieldBlock(label: rewardColumnTitle, value: rewardDisplay, align: .leading)
                                .frame(maxWidth: .infinity)
                        }
                        CardPreviewTappableZone(
                            zone: .memberColumn,
                            accessibilityLabel: "Modifier les libellés colonne membre",
                            onEditZoneTap: onEditZoneTap
                        ) {
                            stampFieldBlock(label: memberColumnTitle, value: memberDisplay, align: .trailing)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, insetH)
                    .padding(.top, compact ? 14 : 20)
                    .padding(.bottom, compact ? 18 : 26)
                } else {
                    CardPreviewTappableZone(
                        zone: .mainMetrics,
                        accessibilityLabel: "Règles du programme et emoji des tampons",
                        onEditZoneTap: onEditZoneTap
                    ) {
                        VStack(spacing: gap) {
                            ForEach(0..<rows, id: \.self) { row in
                                HStack(spacing: gap) {
                                    ForEach(0..<cols, id: \.self) { col in
                                        let index = row * cols + col
                                        if index < total {
                                            stampIconCell(filled: index < filled, size: cellSize, tint: accentColor)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, insetH)
                        .padding(.top, compact ? 14 : 22)
                    }

                    HStack(alignment: .top, spacing: 0) {
                        CardPreviewTappableZone(
                            zone: .rewardColumn,
                            accessibilityLabel: "Modifier la récompense ou les paliers",
                            onEditZoneTap: onEditZoneTap
                        ) {
                            stampFieldBlock(label: rewardColumnTitle, value: rewardDisplay, align: .leading)
                                .frame(maxWidth: .infinity)
                        }
                        CardPreviewTappableZone(
                            zone: .memberColumn,
                            accessibilityLabel: "Modifier les libellés colonne membre",
                            onEditZoneTap: onEditZoneTap
                        ) {
                            stampFieldBlock(label: memberColumnTitle, value: memberDisplay, align: .trailing)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, insetH)
                    .padding(.top, compact ? 20 : 28)
                    .padding(.bottom, compact ? 20 : 30)
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
        .background(primaryColor)
        .id("stamps-\(cardBackgroundRemoteURL ?? "")-\(cardBackgroundImagePath ?? "")-\(primaryColorHex)")
    }

    private func stampIconCell(filled: Bool, size: CGFloat, tint: Color) -> some View {
        StampIconView(stampEmoji: stampEmoji, size: size, tint: tint)
            .opacity(filled ? 1 : 0.4)
            .frame(width: size, height: size)
    }

    private func restantsSummaryBlock(text: String) -> some View {
        Text(text)
            .font(.system(size: compact ? CafePassFieldFont.valueCompact : CafePassFieldFont.value, weight: .regular))
            .foregroundStyle(accentColor)
            .lineLimit(2)
            .minimumScaleFactor(0.78)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stampFieldBlock(label: String, value: String, align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: compact ? 3 : 4) {
            Text(label)
                .font(.system(size: compact ? CafePassFieldFont.labelCompact : CafePassFieldFont.label, weight: .medium))
                .foregroundStyle(labelColor ?? .white.opacity(0.88))
            Text(value)
                .font(.system(size: compact ? CafePassFieldFont.valueCompact : CafePassFieldFont.value, weight: .regular))
                .foregroundStyle(accentColor)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .multilineTextAlignment(align == .leading ? .leading : .trailing)
        }
        .frame(maxWidth: .infinity, alignment: align == .leading ? .leading : .trailing)
    }

    // MARK: - Zone QR (identique à WalletCardPreview : fond blanc, QR noir)

    private func qrSection() -> some View {
        let insetH: CGFloat = compact ? 12 : 16
        return ZStack {
            if let onEditZoneTap {
                Button {
                    onEditZoneTap(.cardAppearance)
                } label: {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }
            HStack {
                Spacer(minLength: 0)
                CardPreviewTappableZone(
                    zone: .qrCode,
                    accessibilityLabel: "Lien et QR code pour vos clients",
                    onEditZoneTap: onEditZoneTap
                ) {
                    cafeQrCodeBlock()
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, insetH)
            .padding(.top, compact ? 18 : 28)
            .padding(.bottom, compact ? 8 : 10)
        }
        .frame(maxWidth: .infinity)
        .background(primaryColor)
        .id("qr-\(primaryColorHex)")
    }

    @ViewBuilder
    private func cafeQrCodeBlock() -> some View {
        let payload = fidelityQRPayloadURL?.trimmingCharacters(in: .whitespacesAndNewlines).flatMap { $0.isEmpty ? nil : $0 }
            ?? "5b34fc46-19d4-46db-95d3-dc2ffbc0"
        if let qrImage = QRCodeGenerator.generateQR(from: payload, size: compact ? 80 : 120) {
            Image(uiImage: qrImage)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: compact ? 80 : 120, height: compact ? 80 : 120)
                .padding(4)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    // MARK: - Logo (même logique que WalletCardPreview, .fit pour pas de crop)

    @ViewBuilder
    private func stampLogoImage(from urlString: String) -> some View {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        let filePath: String? = if trimmed.hasPrefix("/") || trimmed.hasPrefix("file:") {
            trimmed.hasPrefix("file:") ? URL(string: trimmed)?.path : trimmed
        } else if trimmed.contains("CardLogos"), let full = CardLogoStorage.fullPath(forRelative: trimmed) {
            full
        } else {
            nil
        }
        if let path = filePath {
            let url = URL(fileURLWithPath: path)
            if let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        } else if let url = URL(string: trimmed), isAPILogoURL(url) {
            AuthenticatedLogoView(url: url, stripBackgroundFill: false)
                .id(trimmed)
        } else if let url = URL(string: trimmed) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fit)
                case .failure, .empty:
                    Image(systemName: "photo.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.7))
                @unknown default:
                    Image(systemName: "photo.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        } else {
            Image(systemName: "photo.circle.fill")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func isAPILogoURL(_ url: URL) -> Bool {
        guard url.scheme == "http" || url.scheme == "https" else { return false }
        return url.host() == APIConfig.baseURL.host() && url.path.contains("/logo")
    }

    private static func isAPICardBackgroundURL(_ url: URL) -> Bool {
        guard url.scheme == "http" || url.scheme == "https" else { return false }
        return url.host() == APIConfig.baseURL.host() && url.path.contains("card-background")
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        CafeDesArtsCardPreview(
            displayName: "O'CALI CROUSTY",
            requiredStamps: 10,
            stampsCount: 3,
            primaryColorHex: "8B2942",
            accentColorHex: "ffd54f",
            logoURL: nil,
            stampEmoji: "☕"
        )
        .padding(.horizontal, 24)

        CafeDesArtsCardPreview(
            displayName: "Café des Arts",
            requiredStamps: 10,
            stampsCount: 8,
            primaryColorHex: "5d4e37",
            accentColorHex: "d7ccc8",
            logoURL: nil,
            stampEmoji: "☕",
            compact: true
        )
        .padding(.horizontal, 24)
    }
    .padding()
}
