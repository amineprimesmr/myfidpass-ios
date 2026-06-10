//
//  WalletCardPreview.swift
//  myfidpass
//
//  Aperçu calqué sur le pass Apple Wallet : logo seul en haut, pas de texte, fond vert, bandeau blanc avec vrai QR.
//

import SwiftUI
import UIKit
import CoreImage

/// Ratio et proportions du pass Wallet (largeur / hauteur). Un peu plus « haut » que 375/460 pour de l’air au-dessus du QR en aperçu Ma carte.
private let walletCardAspectRatio: CGFloat = 375 / 478
/// Bandeau image de fond : aligné sur le SaaS (`app-wallet-preview-card-bg-banner`, 750×246).
private let walletCardBackgroundBannerAspect: CGFloat = 750 / 246

/// Repère Apple Wallet (Creating a pass) : zone logo **160 × 50 pt** @largeur pass ~375 ; on scale avec la largeur réelle de l’aperçu.
private func walletLogoSlotSize(cardWidth: CGFloat, compact: Bool) -> (maxWidth: CGFloat, maxHeight: CGFloat) {
    let ref: CGFloat = 375
    let scale = max(0.55, cardWidth / ref)
    let slotW = 160 * scale
    let slotH = 50 * scale
    if compact {
        return (min(slotW * 0.88, cardWidth * 0.46), min(slotH * 0.95, 40))
    }
    // Légère marge au-dessus du slot Apple pour les wordmarks (ex. PRINTEMPS) tout en gardant le même ordre de grandeur que le Wallet.
    return (min(slotW * 1.05, cardWidth * 0.52), min(slotH * 1.12, 58))
}

/// Tailles proches du Wallet : champs secondaires (label + valeur sous le bandeau).
private enum PassFontSize {
    static let fieldLabel: CGFloat = 12
    static let fieldValue: CGFloat = 17
    static let fieldLabelCompact: CGFloat = 10
    static let fieldValueCompact: CGFloat = 13
}

struct WalletCardPreview: View {
    var displayName: String
    var requiredStamps: Int32
    var stampsCount: Int32
    var primaryColorHex: String
    var accentColorHex: String
    /// Couleur du bandeau (grande section sans image). Si nil, utilise primaryColorHex.
    var stripColorHex: String? = nil
    var logoURL: String?
    /// "logo" = image, "text" = afficher stripText à la place du logo.
    var stripDisplayMode: String? = nil
    /// Texte affiché dans le bandeau quand stripDisplayMode == "text".
    var stripText: String? = nil
    var stampEmoji: String? = nil
    /// Chemin local de l’image de fond de carte (bandeau pleine largeur sous l’en-tête, comme le SaaS).
    var cardBackgroundImagePath: String? = nil
    /// URL API authentifiée (ex. …/api/businesses/{slug}/card-background) quand le fond est défini sur le SaaS.
    var cardBackgroundRemoteURL: String? = nil
    /// Couleur des libellés (RÉCOMPENSE, MEMBRE, "Points"). Si nil, blanc/opacité par défaut.
    var labelColorHex: String? = nil
    /// Texte à droite dans l’en-tête (ex. « Récompenses ↗ »), comme `header_right_text` côté SaaS.
    var headerRightText: String? = nil
    /// Nom membre à droite (aperçu).
    var memberPreviewText: String? = nil
    /// Libellé colonne membre (`label_member` API, défaut Membre).
    var memberColumnTitle: String = "MEMBRE"
    var compact: Bool = false
    /// Tap sur une zone → édition ciblée (Ma Carte). `nil` = aperçu passif.
    var onEditZoneTap: ((CardPreviewEditZone) -> Void)? = nil
    /// Pastilles « Touchez » (complétion) — ouvre l’éditeur sans déclencher le zoom logo.
    var onCompletionPillTap: ((CardPreviewEditZone) -> Void)? = nil
    /// URL encodée dans le QR (page carte fidélité). Si `nil`, QR de démonstration.
    var fidelityQRPayloadURL: String? = nil
    var completionHighlightZones: Set<CardPreviewEditZone> = []
    private var primaryColor: Color { Color(hex: primaryColorHex) }
    /// Couleur effective du bandeau (section points / infos).
    private var bandeauColor: Color { stripColorHex.flatMap { Color(hex: $0) } ?? primaryColor }

    /// PassKit `foregroundColor` — hex tel que sur le .pkpass (pas de recalcul de contraste).
    private var passForegroundExact: Color { Color(hex: accentColorHex) }
    /// PassKit `labelColor` — hex explicite ou défaut type Wallet sur fond clair/sombre.
    private var passLabelExact: Color {
        let t = labelColorHex?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !t.isEmpty { return Color(hex: t) }
        return primaryColor.isDark ? Color.white.opacity(0.78) : Color.black.opacity(0.78)
    }

    /// Avec image promo : en-tête aligné sur le fond carte (pas un bandeau strip figé, ex. vert template).
    private var headerBarColor: Color {
        hasCardBackground ? primaryColor : bandeauColor
    }

    /// Avec image de fond : pas de gros chiffre POINTS sur le bandeau (ligne « Points : n » dans le corps, comme Wallet).
    private var hasCardBackground: Bool {
        let local = cardBackgroundImagePath.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false
        let rem = cardBackgroundRemoteURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let remoteOk = rem.isEmpty ? false : (APIResourceURL.resolved(from: rem).map { Self.isAPICardBackgroundURL($0) } ?? false)
        return local || remoteOk
    }

    private var headerRightDisplay: String {
        let t = headerRightText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? "Récompenses ↗" : t
    }

    private var memberDisplay: String {
        let t = memberPreviewText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? "Prévisualisation" : t
    }

    var body: some View {
        let corner: CGFloat = compact ? 9 : 14

        Color.clear
            .aspectRatio(walletCardAspectRatio, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let w = max(1, geo.size.width.isFinite ? geo.size.width : 1)
                    let h = max(1, geo.size.height.isFinite ? geo.size.height : 1)

                    cardContent(cardWidth: w)
                        .transaction { $0.disablesAnimations = true }
                        .frame(width: w, height: h)
                        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                        .overlay {
                            if !completionHighlightZones.isEmpty, let onTap = onCompletionPillTap ?? onEditZoneTap {
                                CardPreviewCompletionPillsOverlay(
                                    cardWidth: w,
                                    totalHeight: h,
                                    compact: compact,
                                    zones: completionHighlightZones,
                                    onTapZone: onTap
                                )
                                .allowsHitTesting(true)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: corner, style: .continuous)
                                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.32), radius: compact ? 12 : 20, x: 0, y: compact ? 6 : 10)
                        .frame(width: w, height: h, alignment: .topLeading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
    }

    private func cardContent(cardWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            headerSection(cardWidth: cardWidth)
                .zIndex(2)
            cardBackgroundBannerSection(cardWidth: cardWidth)
                .zIndex(1)
            bodySection(cardWidth: cardWidth)
                .zIndex(0)
        }
    }

    private func walletBannerHeight(cardWidth: CGFloat) -> CGFloat {
        max(1, cardWidth / walletCardBackgroundBannerAspect)
    }

    /// En-tête : fond couleur strip (comme le SaaS) ; logo à gauche ; lien à droite. L’image promo est dans `cardBackgroundBannerSection`.
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
                        accessibilityLabel: "Agrandir le logo",
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

    /// Bandeau `750×246` : image commerce, ou visuel par défaut (`banner`) **sans** texte par-dessus — le solde est dans le corps (comme le pass Wallet sans primary sur le strip).
    @ViewBuilder
    private func cardBackgroundBannerSection(cardWidth: CGFloat) -> some View {
        let bannerHeight = walletBannerHeight(cardWidth: cardWidth)
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
            cardBackgroundBannerPointsOnly(cardWidth: cardWidth, bannerHeight: bannerHeight)
        }
    }

    /// Sans image personnalisée : uniquement le visuel `banner` (pas de solde superposé — les points sont sous le bandeau, comme sans image perso sur le Wallet).
    private func cardBackgroundBannerPointsOnly(cardWidth: CGFloat, bannerHeight: CGFloat) -> some View {
        CardPreviewTappableZone(
            zone: .backgroundImage,
            accessibilityLabel: "Ajouter une image de fond (optionnel)",
            onEditZoneTap: onEditZoneTap
        ) {
            ZStack {
                // Ressource Xcode uniquement pour l’aperçu in-app. Le vrai pass Wallet utilise
                // `card_background` (upload) ou `backend/src/pass/assets/default-points-strip.png` (sync `npm run sync:wallet-strip`).
                Image("banner")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                LinearGradient(
                    colors: [Color.black.opacity(0.35), Color.black.opacity(0.08)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity)
            .frame(height: bannerHeight)
            .clipped()
        }
    }

    /// Logo ou texte dans le bandeau selon stripDisplayMode (taille calquée sur le slot Wallet).
    @ViewBuilder
    private func logoInStrip(maxWidth: CGFloat, maxHeight: CGFloat, cardWidth: CGFloat) -> some View {
        Group {
            if let urlString = logoURL?.trimmingCharacters(in: .whitespaces), !urlString.isEmpty {
                logoImage(from: urlString)
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: .topLeading)
                    .clipped()
            } else {
                stripLogoPlaceholder(maxWidth: maxWidth, maxHeight: maxHeight)
            }
        }
    }

    /// Corps : Points (gauche) + Membre (droite), sous le bandeau — avec ou sans image de fond (même mise en page que le Wallet).
    private func bodySection(cardWidth: CGFloat) -> some View {
        let insetH: CGFloat = compact ? 12 : 16
        return VStack(spacing: 0) {
            // Fond coloré : tap hors champs → couleurs ; zone points → règles du programme.
            ZStack(alignment: .topLeading) {
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
                    HStack(alignment: .top, spacing: compact ? 4 : 8) {
                        CardPreviewTappableZone(
                            zone: .mainMetrics,
                            accessibilityLabel: "Système de carte",
                            onEditZoneTap: onEditZoneTap
                        ) {
                            fieldBlock(
                                label: "POINTS",
                                value: "\(stampsCount)",
                                align: .leading,
                                cardWidth: cardWidth
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        CardPreviewTappableZone(
                            zone: .memberColumn,
                            accessibilityLabel: "Modifier les libellés colonne membre",
                            onEditZoneTap: onEditZoneTap
                        ) {
                            fieldBlock(label: memberColumnTitle, value: memberDisplay, align: .trailing, cardWidth: cardWidth)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, insetH)
                    .padding(.top, compact ? 14 : 20)

                    Spacer(minLength: compact ? 18 : 44)
                }
            }
            .frame(maxWidth: .infinity)
            .background(primaryColor)

            // QR : zone limitée au carré ; le fond vert autour → couleurs de la carte.
            ZStack {
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
                        walletQrCodeBlock(cardWidth: cardWidth)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, insetH)
                .padding(.top, compact ? 18 : 28)
                .padding(.bottom, compact ? 8 : 10)
            }
            .frame(maxWidth: .infinity)
            .background(primaryColor)
        }
        .frame(maxWidth: .infinity)
        .id("body-\(cardBackgroundRemoteURL ?? "")-\(cardBackgroundImagePath ?? "")-\(primaryColorHex)-\(hasCardBackground)")
    }

    @ViewBuilder
    private func walletQrCodeBlock(cardWidth: CGFloat) -> some View {
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

    private func fieldBlock(label: String, value: String, align: HorizontalAlignment = .leading, cardWidth: CGFloat) -> some View {
        let labelPx = AppTheme.CardPreviewLayout.scaledFont(base: compact ? PassFontSize.fieldLabelCompact : PassFontSize.fieldLabel, cardWidth: cardWidth)
        let valuePx = AppTheme.CardPreviewLayout.scaledFont(base: compact ? PassFontSize.fieldValueCompact : PassFontSize.fieldValue, cardWidth: cardWidth, minSize: 10)
        return VStack(alignment: align, spacing: compact ? 3 : 4) {
            Text(label)
                .font(.system(size: labelPx, weight: .medium))
                .foregroundStyle(passLabelExact)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
            Text(value)
                .font(.system(size: valuePx, weight: .regular))
                .foregroundStyle(passForegroundExact)
                .lineLimit(3)
                .minimumScaleFactor(0.68)
                .multilineTextAlignment(align == .leading ? .leading : .trailing)
        }
        .frame(maxWidth: .infinity, alignment: align == .leading ? .leading : .trailing)
    }

    @ViewBuilder
    private func logoImage(from urlString: String) -> some View {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
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
            logoPlaceholder
        }
    }

    /// Logo bandeau Wallet / SaaS : `…/logo` exactement (pas `logo-icon`, pas notification).
    private func isAPIStripLogoURL(_ url: URL) -> Bool {
        guard url.scheme == "http" || url.scheme == "https" else { return false }
        guard url.host() == APIConfig.baseURL.host() else { return false }
        return url.path.hasSuffix("/logo")
    }

    private static func isAPICardBackgroundURL(_ url: URL) -> Bool {
        guard url.scheme == "http" || url.scheme == "https" else { return false }
        return url.host() == APIConfig.baseURL.host() && url.path.contains("card-background")
    }

    private var logoPlaceholder: some View {
        Image("votrelogo")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityLabel("Logo du commerce, à personnaliser")
    }

    private func stripLogoPlaceholder(maxWidth: CGFloat, maxHeight: CGFloat) -> some View {
        Image("votrelogo")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: .topLeading)
            .accessibilityLabel("Logo du commerce, à personnaliser")
    }
}

// MARK: - Génération QR (comme le vrai pass) — partagé avec CafeDesArtsCardPreview

enum QRCodeGenerator {
    /// QR standard (noir sur blanc) — pour usage avec fond blanc.
    static func generateQR(from string: String, size: CGFloat = 120) -> UIImage? {
        let data = Data(string.utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// QR en « template » : modules noirs sur fond transparent, pour teinter (blanc sur fond sombre, noir sur fond clair).
    static func generateQRTemplate(from string: String, size: CGFloat = 120) -> UIImage? {
        guard let opaque = generateQR(from: string, size: size),
              let cgImage = opaque.cgImage else { return nil }
        let w = cgImage.width
        let h = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * w
        let bitsPerComponent = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = context.data else { return nil }
        let buffer = data.bindMemory(to: UInt8.self, capacity: w * h * bytesPerPixel)
        for y in 0..<h {
            for x in 0..<w {
                let offset = (y * w + x) * bytesPerPixel
                let r = buffer[offset], g = buffer[offset + 1], b = buffer[offset + 2]
                if r > 250 && g > 250 && b > 250 { buffer[offset + 3] = 0 }
            }
        }
        guard let resultCg = context.makeImage() else { return nil }
        return UIImage(cgImage: resultCg)
    }
}

// MARK: - Logo API (Bearer)

struct AuthenticatedLogoView: View {
    let url: URL
    /// `true` : fond du bandeau (remplissage type bannière SaaS).
    var stripBackgroundFill: Bool = false
    @State private var image: UIImage?
    @State private var failed = false

    private var urlKey: String { url.absoluteString }

    var body: some View {
        Group {
            if let image {
                if stripBackgroundFill {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            } else if failed {
                Image("votrelogo")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .accessibilityLabel("Logo du commerce, à personnaliser")
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: urlKey) { _, _ in
            image = nil
            failed = false
        }
        .task(id: urlKey) {
            let loadKey = urlKey
            let maxDim: CGFloat = url.path.contains("card-background") ? 1800 : 1000
            if let instant = AuthenticatedMediaLoader.memoryCachedImage(for: url, maxPixelDimension: maxDim) {
                await MainActor.run {
                    guard loadKey == urlKey else { return }
                    image = instant
                }
            }
            guard let token = AuthStorage.authToken, !token.isEmpty else {
                await MainActor.run {
                    guard loadKey == urlKey else { return }
                    failed = true
                }
                return
            }
            do {
                let img = try await AuthenticatedMediaLoader.loadAuthenticatedImage(from: url, maxPixelDimension: maxDim)
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
    VStack(spacing: 24) {
        WalletCardPreview(
            displayName: "test",
            requiredStamps: 10,
            stampsCount: 3,
            primaryColorHex: AppTheme.WalletCardAppearanceDefaults.backgroundHex,
            accentColorHex: AppTheme.WalletCardAppearanceDefaults.accentHex,
            logoURL: nil
        )
        .padding(.horizontal, 24)

        WalletCardPreview(
            displayName: "Ma Carte",
            requiredStamps: 10,
            stampsCount: 0,
            primaryColorHex: AppTheme.WalletCardAppearanceDefaults.backgroundHex,
            accentColorHex: AppTheme.WalletCardAppearanceDefaults.accentHex,
            logoURL: nil,
            compact: true
        )
        .frame(height: 140)
        .padding(.horizontal, 24)
    }
    .padding()
}
