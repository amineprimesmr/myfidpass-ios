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

/// Tailles de police proches du Wallet (lisibilité Ma carte).
private enum PassFontSize {
    static let primaryValue: CGFloat = 36
    static let primaryLabel: CGFloat = 14
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
    /// Libellé palier / récompense affiché sous les points (ou seul bloc si image de fond).
    var rewardPreviewText: String? = nil
    /// Nom membre à droite (aperçu).
    var memberPreviewText: String? = nil
    /// Libellé colonne gauche (SaaS : « Récompense »).
    var rewardColumnTitle: String = "RÉCOMPENSE"
    /// Libellé colonne droite (`label_member` API, défaut Membre).
    var memberColumnTitle: String = "MEMBRE"
    var compact: Bool = false
    /// Tap sur une zone → édition ciblée (Ma Carte). `nil` = aperçu passif.
    var onEditZoneTap: ((CardPreviewEditZone) -> Void)? = nil
    /// URL encodée dans le QR (page carte fidélité). Si `nil`, QR de démonstration.
    var fidelityQRPayloadURL: String? = nil

    private var primaryColor: Color { Color(hex: primaryColorHex) }
    private var accentColor: Color { Color(hex: accentColorHex) }
    private var labelColor: Color? { labelColorHex.flatMap { Color(hex: $0) } }
    /// Couleur effective du bandeau (section points / infos).
    private var bandeauColor: Color { stripColorHex.flatMap { Color(hex: $0) } ?? primaryColor }

    /// Avec image promo : en-tête aligné sur le fond carte (pas un bandeau strip figé, ex. vert template).
    private var headerBarColor: Color {
        hasCardBackground ? primaryColor : bandeauColor
    }

    /// Même règle que le SaaS : avec image de fond, on masque le gros bloc points et on garde paliers + membre.
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
        .animation(.easeOut(duration: 0.25), value: accentColorHex)
        .animation(.easeOut(duration: 0.2), value: displayName)
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
            bodySection(cardWidth: cardWidth)
                .zIndex(0)
        }
    }

    /// En-tête : fond couleur strip (comme le SaaS) ; logo à gauche ; lien à droite. L’image promo est dans `cardBackgroundBannerSection`.
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

    /// Bandeau image entre en-tête et corps — ratio SaaS `750×246`, `cover`.
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

    /// Logo ou texte dans le bandeau selon stripDisplayMode (taille calquée sur le slot Wallet).
    @ViewBuilder
    private func logoInStrip(maxWidth: CGFloat, maxHeight: CGFloat) -> some View {
        Group {
            if stripDisplayMode == "text" {
                Text(stripText?.trimmingCharacters(in: .whitespaces).isEmpty == false ? (stripText ?? displayName) : displayName)
                    .font(.system(size: compact ? 18 : 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: .topLeading)
            } else if let urlString = logoURL?.trimmingCharacters(in: .whitespaces), !urlString.isEmpty {
                logoImage(from: urlString)
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

    /// Corps : points + paliers (+ avec image de fond : 3 colonnes comme sur le pass Wallet).
    private func bodySection(cardWidth: CGFloat) -> some View {
        let insetH: CGFloat = compact ? 12 : 16
        return VStack(spacing: 0) {
            // Fond coloré : tap hors champs (points, paliers, membre) → couleurs de la carte ; tap sur la zone points uniquement → règles du programme.
            ZStack(alignment: .topLeading) {
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
                        /// Avec image sur le strip : POINTS + RÉCOMPENSE + MEMBRE sur une ligne (comme la vraie carte).
                        HStack(alignment: .top, spacing: compact ? 4 : 8) {
                            CardPreviewTappableZone(
                                zone: .mainMetrics,
                                accessibilityLabel: "Règles du programme (points ou tampons)",
                                onEditZoneTap: onEditZoneTap
                            ) {
                                pointsFieldColumn(emphasized: false)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            CardPreviewTappableZone(
                                zone: .rewardColumn,
                                accessibilityLabel: "Modifier la récompense ou les paliers",
                                onEditZoneTap: onEditZoneTap
                            ) {
                                fieldBlock(label: rewardColumnTitle, value: rewardDisplay, align: .leading)
                                    .frame(maxWidth: .infinity)
                            }
                            CardPreviewTappableZone(
                                zone: .memberColumn,
                                accessibilityLabel: "Modifier les libellés colonne membre",
                                onEditZoneTap: onEditZoneTap
                            ) {
                                fieldBlock(label: memberColumnTitle, value: memberDisplay, align: .trailing)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, insetH)
                        .padding(.top, compact ? 14 : 20)
                    } else {
                        CardPreviewTappableZone(
                            zone: .mainMetrics,
                            accessibilityLabel: "Règles du programme (points ou tampons)",
                            onEditZoneTap: onEditZoneTap
                        ) {
                            pointsFieldColumn(emphasized: true)
                                .padding(.leading, insetH)
                                .padding(.top, compact ? 12 : 22)
                        }

                        HStack(alignment: .top, spacing: 0) {
                            CardPreviewTappableZone(
                                zone: .rewardColumn,
                                accessibilityLabel: "Modifier la récompense ou les paliers",
                                onEditZoneTap: onEditZoneTap
                            ) {
                                fieldBlock(label: rewardColumnTitle, value: rewardDisplay, align: .leading)
                                    .frame(maxWidth: .infinity)
                            }
                            CardPreviewTappableZone(
                                zone: .memberColumn,
                                accessibilityLabel: "Modifier les libellés colonne membre",
                                onEditZoneTap: onEditZoneTap
                            ) {
                                fieldBlock(label: memberColumnTitle, value: memberDisplay, align: .trailing)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, insetH)
                        .padding(.top, compact ? 22 : 32)
                    }

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
                    .buttonStyle(.borderless)
                }
                HStack {
                    Spacer(minLength: 0)
                    CardPreviewTappableZone(
                        zone: .qrCode,
                        accessibilityLabel: "Lien et QR code pour vos clients",
                        onEditZoneTap: onEditZoneTap
                    ) {
                        walletQrCodeBlock()
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
    private func walletQrCodeBlock() -> some View {
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

    /// Colonne « Points » : mise en avant si `emphasized` (sans image de fond), sinon taille alignée sur les autres champs.
    private func pointsFieldColumn(emphasized: Bool) -> some View {
        let valueSize: CGFloat = emphasized
            ? (compact ? 30 : PassFontSize.primaryValue)
            : (compact ? PassFontSize.fieldValueCompact : PassFontSize.fieldValue)
        let valueWeight: Font.Weight = emphasized ? .semibold : .regular
        let labelSize: CGFloat = emphasized
            ? (compact ? 13 : PassFontSize.primaryLabel)
            : (compact ? PassFontSize.fieldLabelCompact : PassFontSize.fieldLabel)
        return VStack(alignment: .leading, spacing: compact ? 3 : 4) {
            Text("POINTS")
                .font(.system(size: labelSize, weight: .medium))
                .foregroundStyle(labelColor ?? .white.opacity(0.9))
            Text("\(stampsCount)")
                .font(.system(size: valueSize, weight: valueWeight))
                .foregroundStyle(accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func fieldBlock(label: String, value: String, align: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: align, spacing: compact ? 3 : 4) {
            Text(label)
                .font(.system(size: compact ? PassFontSize.fieldLabelCompact : PassFontSize.fieldLabel, weight: .medium))
                .foregroundStyle(labelColor ?? .white.opacity(0.88))
            Text(value)
                .font(.system(size: compact ? PassFontSize.fieldValueCompact : PassFontSize.fieldValue, weight: .regular))
                .foregroundStyle(accentColor)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .multilineTextAlignment(align == .leading ? .leading : .trailing)
        }
        .frame(maxWidth: .infinity, alignment: align == .leading ? .leading : .trailing)
    }

    @ViewBuilder
    private func logoImage(from urlString: String) -> some View {
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
                logoPlaceholder
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
                    logoPlaceholder
                @unknown default:
                    logoPlaceholder
                }
            }
        } else {
            logoPlaceholder
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

    private var logoPlaceholder: some View {
        Image(systemName: "photo.circle.fill")
            .font(.title2)
            .foregroundStyle(.white.opacity(0.7))
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
                Image(systemName: "photo.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
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
            if let instant = AuthenticatedMediaLoader.memoryCachedImage(for: url) {
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
                let img = try await AuthenticatedMediaLoader.loadAuthenticatedImage(from: url)
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

// MARK: - Grille tampons (usage ailleurs)

private struct StampGridView: View {
    let total: Int
    let filled: Int
    let accentColor: Color
    let compact: Bool
    private let maxCols = 5
    var body: some View {
        let rows = (total + maxCols - 1) / maxCols
        let cols = min(total, maxCols)
        let size: CGFloat = compact ? 6 : 10
        let spacing: CGFloat = compact ? 5 : 8
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<cols, id: \.self) { col in
                        let index = row * maxCols + col
                        Group {
                            if index < total {
                                Circle()
                                    .fill(index < filled ? accentColor : Color.white.opacity(0.4))
                            } else {
                                Color.clear
                            }
                        }
                        .frame(width: size, height: size)
                    }
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
            primaryColorHex: "0a7c42",
            accentColorHex: "F59E0B",
            logoURL: nil
        )
        .padding(.horizontal, 24)

        WalletCardPreview(
            displayName: "Ma Carte",
            requiredStamps: 10,
            stampsCount: 0,
            primaryColorHex: "0a7c42",
            accentColorHex: "F59E0B",
            logoURL: nil,
            compact: true
        )
        .frame(height: 140)
        .padding(.horizontal, 24)
    }
    .padding()
}
