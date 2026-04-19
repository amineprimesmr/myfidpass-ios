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
    var memberPreviewText: String? = nil
    var memberColumnTitle: String = "MEMBRE"
    /// Libellés récompenses (SaaS / Ma carte) — valeur affichée sous « Dans x passages ».
    var stampMidRewardLabel: String = ""
    var stampRewardLabel: String = ""
    /// Libellé colonne gauche (face avant pass tampons avec image) — affiché en capitales comme « MEMBRE » ; valeur = tampons obtenus.
    var restantsCaption: String = "Restants"
    var compact: Bool = false
    var onEditZoneTap: ((CardPreviewEditZone) -> Void)? = nil
    /// URL encodée dans le QR (page carte fidélité). Si `nil`, QR de démonstration.
    var fidelityQRPayloadURL: String? = nil
    /// Pastilles « Configurer » (complétion Ma carte).
    var completionHighlightZones: Set<CardPreviewEditZone> = []

    private var primaryColor: Color { Color(hex: primaryColorHex) }
    private var bandeauColor: Color { stripColorHex.flatMap { Color(hex: $0) } ?? primaryColor }

    /// PassKit `foregroundColor` — identique au .pkpass.
    private var passForegroundExact: Color { Color(hex: accentColorHex) }
    /// PassKit `labelColor`.
    private var passLabelExact: Color {
        let t = labelColorHex?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !t.isEmpty { return Color(hex: t) }
        return primaryColor.isDark ? Color.white.opacity(0.78) : Color.black.opacity(0.78)
    }

    private var headerBarColor: Color {
        hasCardBackground ? primaryColor : bandeauColor
    }

    /// L’image de fond carte est réservée au mode **points** ; l’aperçu tampons n’affiche jamais ce bandeau photo.
    private var hasCardBackground: Bool { false }

    private var headerRightDisplay: String {
        let t = headerRightText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? "Récompenses ↗" : t
    }

    private var memberDisplay: String {
        let t = memberPreviewText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? "Prévisualisation" : t
    }

    /// Colonne gauche (avec image de fond) : libellé type PassKit + **tampons obtenus** (comme « TAMPONS » / « 0 » sur le pass), pas une seule ligne « Restants = n ».
    private var stampsMetricColumnLabel: String {
        let t = restantsCaption.trimmingCharacters(in: .whitespacesAndNewlines)
        let base: String
        if t.isEmpty {
            base = "Tampons"
        } else if t.compare("Restants", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
            // Défaut API / feuille Ma carte : « Restants » décrivait l’ancien libellé une ligne ; la colonne affiche le compte obtenu → libellé « Tampons ».
            base = "Tampons"
        } else {
            base = t
        }
        return base.uppercased(with: Locale(identifier: "fr_FR"))
    }

    private var stampsMetricColumnValue: String {
        let total = max(0, Int(requiredStamps))
        let filled = min(max(0, Int(stampsCount)), total)
        return "\(filled)"
    }

    /// Libellé type PassKit (petites capitales) : « DANS X PASSAGES » — aligné sur le pass Wallet généré côté serveur.
    private var nextRewardDansPassagesLabel: String {
        let total = max(1, Int(requiredStamps))
        let filled = min(max(0, Int(stampsCount)), total)
        if filled >= total {
            return "OBJECTIF ATTEINT"
        }
        if total <= 5 {
            return Self.upperDansPassages(need: total - filled)
        }
        if filled < 5 {
            return Self.upperDansPassages(need: 5 - filled)
        }
        return Self.upperDansPassages(need: total - filled)
    }

    /// Seule la récompense marchand (ex. « -50 % »), comme sur le Wallet.
    private var nextRewardMerchantValueOnly: String {
        let mid = stampMidRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let fin = stampRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let total = max(1, Int(requiredStamps))
        let filled = min(max(0, Int(stampsCount)), total)
        if filled >= total {
            return fin.isEmpty ? "—" : fin
        }
        if total <= 5 {
            return fin.isEmpty ? "Récompense" : fin
        }
        if filled < 5 {
            return mid.isEmpty ? "Récompense au 5ᵉ passage" : mid
        }
        return fin.isEmpty ? "Récompense à la carte complète" : fin
    }

    private static func upperDansPassages(need: Int) -> String {
        if need <= 0 { return "OBJECTIF ATTEINT" }
        if need == 1 { return "DANS 1 PASSAGE" }
        return "DANS \(need) PASSAGES"
    }

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width.isFinite ? geo.size.width : 1)
            let h = max(1, w / walletCardAspectRatio)
            let corner: CGFloat = compact ? 9 : 14

            cardContent(cardWidth: w)
                .frame(width: w, height: h)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                .overlay {
                    if !completionHighlightZones.isEmpty, let onTap = onEditZoneTap {
                        CardPreviewCompletionPillsOverlay(
                            cardWidth: w,
                            totalHeight: h,
                            compact: compact,
                            zones: completionHighlightZones,
                            layoutStyle: .stampsBannerMetrics,
                            onTapZone: onTap
                        )
                    }
                }
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
        .animation(.easeOut(duration: 0.2), value: stampMidRewardLabel)
        .animation(.easeOut(duration: 0.2), value: stampRewardLabel)
        .animation(.easeOut(duration: 0.2), value: logoURL)
        .animation(.easeOut(duration: 0.2), value: stampEmoji)
        .animation(.easeOut(duration: 0.25), value: cardBackgroundRemoteURL)
        .animation(.easeOut(duration: 0.2), value: completionHighlightZones.count)
    }

    private func cardContent(cardWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            // zIndex : bandeau image au-dessus du corps si le layout chevauche (évite tampons / texte « par-dessus » la photo).
            headerSection(cardWidth: cardWidth)
                .zIndex(2)
            cardBackgroundBannerSection(cardWidth: cardWidth)
                .zIndex(1)
            stampsBodySection(cardWidth: cardWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .zIndex(0)
            qrSection(cardWidth: cardWidth)
                .zIndex(0)
        }
    }

    private func cafeBannerHeight(cardWidth: CGFloat) -> CGFloat {
        max(1, cardWidth / walletCardBackgroundBannerAspect)
    }

    private func headerSection(cardWidth: CGFloat) -> some View {
        let logoSlot = walletLogoSlotSize(cardWidth: cardWidth, compact: compact)
        let scale = AppTheme.CardPreviewLayout.widthScale(cardWidth: cardWidth)
        let headerTopInset: CGFloat = compact ? 7 : 12
        let headerBottomInset: CGFloat = compact ? 6 : 8
        let headerH: CGFloat = compact ? 70 : 100
        return ZStack(alignment: .topLeading) {
            headerBarColor
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: headerTopInset)
                HStack(alignment: .top, spacing: 0) {
                    CardPreviewTappableZone(
                        zone: .logoBand,
                        accessibilityLabel: "Modifier le logo ou le texte du bandeau",
                        onEditZoneTap: onEditZoneTap
                    ) {
                        logoInStrip(maxWidth: logoSlot.maxWidth, maxHeight: logoSlot.maxHeight, cardWidth: cardWidth)
                            .frame(maxWidth: logoSlot.maxWidth, maxHeight: logoSlot.maxHeight, alignment: .topLeading)
                            .clipped()
                    }
                    Spacer(minLength: compact ? 4 : 8)
                    CardPreviewTappableZone(
                        zone: .headerRight,
                        accessibilityLabel: "Modifier les récompenses",
                        onEditZoneTap: onEditZoneTap
                    ) {
                        Text(headerRightDisplay)
                            .font(.system(size: AppTheme.CardPreviewLayout.scaledFont(base: compact ? 10 : 13, cardWidth: cardWidth), weight: .semibold))
                            .foregroundStyle(passForegroundExact)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                            .minimumScaleFactor(0.62 * scale)
                    }
                }
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

    /// Avec image : bandeau photo ; sans image (mode tampons) : **grille de tampons** dans la zone 750×246 — pas l’aperçu photo « banner » du mode points.
    @ViewBuilder
    private func cardBackgroundBannerSection(cardWidth: CGFloat) -> some View {
        let bannerHeight = cafeBannerHeight(cardWidth: cardWidth)
        if hasCardBackground {
            let banner = Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: bannerHeight)
                .overlay {
                    Group {
                        if let path = cardBackgroundImagePath, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            AsyncLocalFileImage(filePath: path, contentMode: .fill)
                                .id(path)
                        } else if let remote = cardBackgroundRemoteURL?.trimmingCharacters(in: .whitespacesAndNewlines), !remote.isEmpty,
                                  let url = APIResourceURL.resolved(from: remote), Self.isAPICardBackgroundURL(url) {
                            AuthenticatedLogoView(url: url, stripBackgroundFill: true)
                                .id(url.absoluteString)
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
        } else {
            cardBackgroundBannerStampsOnly(cardWidth: cardWidth, bannerHeight: bannerHeight)
        }
    }

    /// Sans image de fond : grille de tampons dans le bandeau (comme le pass Wallet tampons — pas la photo « banner » du mode points).
    private func cardBackgroundBannerStampsOnly(cardWidth: CGFloat, bannerHeight: CGFloat) -> some View {
        let insetH: CGFloat = compact ? 12 : 16
        return ZStack {
            primaryColor
            CardPreviewTappableZone(
                zone: .mainMetrics,
                accessibilityLabel: "Système de carte",
                onEditZoneTap: onEditZoneTap
            ) {
                stampGridBannerFitted(cardWidth: cardWidth, bannerHeight: bannerHeight, horizontalInset: insetH)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: bannerHeight)
    }

    /// Tampons calés dans la hauteur du bandeau (750×246), sans déborder.
    private func stampGridBannerFitted(cardWidth: CGFloat, bannerHeight: CGFloat, horizontalInset: CGFloat) -> some View {
        let total = Int(requiredStamps)
        let filled = min(max(0, Int(stampsCount)), total)
        let cols = 5
        let rows = max(1, (total + cols - 1) / cols)
        /// Marges un peu resserrées pour laisser plus de place aux pictos (rendu plus proche du pass Wallet).
        let verticalPad: CGFloat = compact ? 8 : 12
        let gap: CGFloat = compact ? 4 : 5
        let innerW = max(1, cardWidth - horizontalInset * 2)
        let innerH = max(1, bannerHeight - verticalPad * 2)
        let cellW = (innerW - CGFloat(max(0, cols - 1)) * gap) / CGFloat(cols)
        let cellH = (innerH - CGFloat(max(0, rows - 1)) * gap) / CGFloat(rows)
        /// Plafond relevé : les tampons paraissaient petits vs la grille réelle.
        let cellSize = max(10, min(cellW, cellH, compact ? 48 : 58))

        return VStack(spacing: gap) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<cols, id: \.self) { col in
                        let index = row * cols + col
                        Group {
                            if index < total {
                                stampIconCell(
                                    index: index,
                                    total: total,
                                    filledStampCount: filled,
                                    size: cellSize,
                                    tint: passForegroundExact
                                )
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, horizontalInset)
        .padding(.vertical, verticalPad)
    }

    private func rewardIconKey(for index: Int, total: Int) -> String? {
        if total >= 10 && index == 9 { return "giftgold" }
        if total >= 5 && index == 4 { return "giftsilver" }
        return nil
    }

    /// Prochain palier cadeau : argent avant le 5e tampon, or entre le 5e et le 10e — affiché en couleur même vide.
    private func isNextGiftTeaser(index: Int, total: Int, filledStampCount: Int) -> Bool {
        if total >= 5 && index == 4 && filledStampCount < 5 { return true }
        if total >= 10 && index == 9 && filledStampCount >= 5 && filledStampCount < 10 { return true }
        return false
    }

    @ViewBuilder
    private func stampIconCell(index: Int, total: Int, filledStampCount: Int, size: CGFloat, tint: Color) -> some View {
        let slotFilled = index < filledStampCount
        let rewardKey = rewardIconKey(for: index, total: total)
        let giftInColor = slotFilled || isNextGiftTeaser(index: index, total: total, filledStampCount: filledStampCount)
        if let rewardKey {
            StampIconView(stampEmoji: rewardKey, size: size, tint: tint)
                .frame(width: size, height: size)
                .grayscale(giftInColor ? 0 : 1)
                .opacity(giftInColor ? 1 : 0.44)
        } else {
            let trimmed = stampEmoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                StampIconView(stampEmoji: trimmed, size: size, tint: tint)
                    .frame(width: size, height: size)
                    .grayscale(slotFilled ? 0 : 1)
                    .opacity(slotFilled ? 1 : 0.44)
            } else if slotFilled {
                RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                    .fill(tint.opacity(0.95))
                    .frame(width: size, height: size)
            } else {
                emptyStampSquare(size: size)
            }
        }
    }

    private func emptyStampSquare(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
            .fill(Color.black.opacity(0.38))
            .frame(width: size, height: size)
    }

    @ViewBuilder
    private func logoInStrip(maxWidth: CGFloat, maxHeight: CGFloat, cardWidth: CGFloat) -> some View {
        let textPrimary = AppTheme.CardPreviewLayout.scaledFont(base: compact ? 18 : 26, cardWidth: cardWidth)
        Group {
            if stripDisplayMode == "text" {
                Text(stripText?.trimmingCharacters(in: .whitespaces).isEmpty == false ? (stripText ?? displayName) : (displayName.isEmpty ? "Ma Carte" : displayName))
                    .font(.system(size: textPrimary, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: .topLeading)
            } else if let urlString = logoURL?.trimmingCharacters(in: .whitespaces), !urlString.isEmpty {
                stampLogoImage(from: urlString)
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: .topLeading)
                    .clipped()
            } else {
                Image("votrelogo")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: .topLeading)
                    .accessibilityLabel("Logo du commerce, à personnaliser")
            }
        }
    }

    // MARK: - Corps : avec fond → tampons + prochaine récompense + membre ; sinon prochaine récompense + membre (grille tampons dans le bandeau)

    private func stampsBodySection(cardWidth: CGFloat) -> some View {
        let insetH: CGFloat = compact ? 12 : 16

        return ZStack(alignment: .topLeading) {
            if let onEditZoneTap {
                Button {
                    onEditZoneTap(.cardAppearance)
                } label: {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(PassPreviewZoneButtonStyle())
            }
            VStack(alignment: .leading, spacing: 0) {
                if hasCardBackground {
                    HStack(alignment: .top, spacing: compact ? 4 : 8) {
                        CardPreviewTappableZone(
                            zone: .mainMetrics,
                            accessibilityLabel: "Système de carte",
                            onEditZoneTap: onEditZoneTap
                        ) {
                            stampFieldBlock(
                                label: stampsMetricColumnLabel,
                                value: stampsMetricColumnValue,
                                align: .leading,
                                cardWidth: cardWidth
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        CardPreviewTappableZone(
                            zone: .headerRight,
                            accessibilityLabel: "Prochaine récompense, modifier dans Récompenses",
                            onEditZoneTap: onEditZoneTap
                        ) {
                            stampFieldBlock(
                                label: nextRewardDansPassagesLabel,
                                value: nextRewardMerchantValueOnly,
                                align: .leading,
                                cardWidth: cardWidth,
                                valueLineLimit: 4
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        CardPreviewTappableZone(
                            zone: .memberColumn,
                            accessibilityLabel: "Modifier les libellés colonne membre",
                            onEditZoneTap: onEditZoneTap
                        ) {
                            stampFieldBlock(label: memberColumnTitle, value: memberDisplay, align: .trailing, cardWidth: cardWidth)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, insetH)
                    .padding(.top, compact ? 14 : 20)
                    .padding(.bottom, compact ? 18 : 26)
                } else {
                    HStack(alignment: .top, spacing: compact ? 6 : 10) {
                        CardPreviewTappableZone(
                            zone: .headerRight,
                            accessibilityLabel: "Prochaine récompense, modifier dans Récompenses",
                            onEditZoneTap: onEditZoneTap
                        ) {
                            stampFieldBlock(
                                label: nextRewardDansPassagesLabel,
                                value: nextRewardMerchantValueOnly,
                                align: .leading,
                                cardWidth: cardWidth,
                                valueLineLimit: 4
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        CardPreviewTappableZone(
                            zone: .memberColumn,
                            accessibilityLabel: "Modifier les libellés colonne membre",
                            onEditZoneTap: onEditZoneTap
                        ) {
                            stampFieldBlock(label: memberColumnTitle, value: memberDisplay, align: .trailing, cardWidth: cardWidth)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, insetH)
                    .padding(.top, compact ? 14 : 20)
                    .padding(.bottom, compact ? 20 : 26)
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
        .background(primaryColor)
        .id("stamps-\(cardBackgroundRemoteURL ?? "")-\(cardBackgroundImagePath ?? "")-\(primaryColorHex)")
    }

    private func stampFieldBlock(label: String, value: String, align: HorizontalAlignment, cardWidth: CGFloat, valueLineLimit: Int = 3) -> some View {
        let labelPx = AppTheme.CardPreviewLayout.scaledFont(base: compact ? CafePassFieldFont.labelCompact : CafePassFieldFont.label, cardWidth: cardWidth)
        let valuePx = AppTheme.CardPreviewLayout.scaledFont(base: compact ? CafePassFieldFont.valueCompact : CafePassFieldFont.value, cardWidth: cardWidth, minSize: 10)
        return VStack(alignment: align, spacing: compact ? 3 : 4) {
            Text(label)
                .font(.system(size: labelPx, weight: .medium))
                .foregroundStyle(passLabelExact)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
            Text(value)
                .font(.system(size: valuePx, weight: .regular))
                .foregroundStyle(passForegroundExact)
                .lineLimit(valueLineLimit)
                .minimumScaleFactor(0.68)
                .multilineTextAlignment(align == .leading ? .leading : .trailing)
        }
        .frame(maxWidth: .infinity, alignment: align == .leading ? .leading : .trailing)
    }

    // MARK: - Zone QR (identique à WalletCardPreview : fond blanc, QR noir)

    private func qrSection(cardWidth: CGFloat) -> some View {
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
                .buttonStyle(PassPreviewZoneButtonStyle())
            }
            HStack {
                Spacer(minLength: 0)
                CardPreviewTappableZone(
                    zone: .qrCode,
                    accessibilityLabel: "Ouvrir la page où vos clients ajoutent la carte",
                    onEditZoneTap: onEditZoneTap
                ) {
                    cafeQrCodeBlock(cardWidth: cardWidth)
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
    private func cafeQrCodeBlock(cardWidth: CGFloat) -> some View {
        let trimmed = fidelityQRPayloadURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let payload = trimmed.isEmpty ? "5b34fc46-19d4-46db-95d3-dc2ffbc0" : trimmed
        let side = AppTheme.CardPreviewLayout.qrDisplaySide(cardWidth: cardWidth, compact: compact)
        let renderPx = max(128, ceil(side * AppTheme.DisplayMetrics.displayScale))
        if let qrImage = QRCodeGenerator.generateQR(from: payload, size: renderPx) {
            Image(uiImage: qrImage)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: side, height: side)
                .padding(4)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    // MARK: - Logo (même logique que WalletCardPreview, .fit pour pas de crop)

    private func stampLogoImage(from urlString: String) -> some View {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        return Group {
            if let path = APIResourceURL.localImageFilePathIfPresent(trimmed) {
                AsyncLocalFileImage(filePath: path, contentMode: .fit)
                    .id(path)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if let url = APIResourceURL.resolved(from: trimmed), isAPIStripLogoURL(url) {
                let displayURL = MerchantLogoAssetCache.stripeLogoDisplayURL(url)
                AuthenticatedLogoView(url: displayURL, stripBackgroundFill: false)
                    .id(displayURL.absoluteString)
            } else if let url = APIResourceURL.resolved(from: trimmed) {
                DecodedURLImage(url: url, contentMode: .fit, maxPixelDimension: 1000)
                    .id(url.absoluteString)
            } else {
                Image("votrelogo")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
            }
        }
        .accessibilityLabel("Logo du commerce, à personnaliser")
    }

    private func isAPIStripLogoURL(_ url: URL) -> Bool {
        guard url.scheme == "http" || url.scheme == "https" else { return false }
        guard url.host() == APIConfig.baseURL.host() else { return false }
        return url.path.hasSuffix("/logo")
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
            displayName: "Commerce démo",
            requiredStamps: 10,
            stampsCount: 3,
            primaryColorHex: AppTheme.WalletCardAppearanceDefaults.backgroundHex,
            accentColorHex: AppTheme.WalletCardAppearanceDefaults.bodyTextHex,
            logoURL: nil,
            stampEmoji: "☕",
            stampMidRewardLabel: "−50 % sur un dessert",
            stampRewardLabel: "Boisson offerte"
        )
        .padding(.horizontal, 24)

        CafeDesArtsCardPreview(
            displayName: "Ma Carte",
            requiredStamps: 10,
            stampsCount: 8,
            primaryColorHex: AppTheme.WalletCardAppearanceDefaults.backgroundHex,
            accentColorHex: AppTheme.WalletCardAppearanceDefaults.bodyTextHex,
            logoURL: nil,
            stampEmoji: "☕",
            compact: true
        )
        .padding(.horizontal, 24)
    }
    .padding()
}
