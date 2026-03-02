//
//  WalletCardPreview.swift
//  myfidpass
//
//  Aperçu calqué sur le pass Apple Wallet : logo seul en haut, pas de texte, fond vert, bandeau blanc avec vrai QR.
//

import SwiftUI
import UIKit
import CoreImage

/// Ratio et proportions du pass Wallet (carte haute, comme dans le Wallet).
private let walletCardAspectRatio: CGFloat = 375 / 460

/// Tailles de police calquées sur le pass Wallet.
private enum PassFontSize {
    static let primaryValue: CGFloat = 48   // Chiffre des points
    static let primaryLabel: CGFloat = 15   // "Points"
    static let fieldLabel: CGFloat = 11     // "NIVEAU", "MEMBRE"
    static let fieldValue: CGFloat = 18     // "Débutant", "Prévisualisation"
    static let idUnderQR: CGFloat = 10      // ID sous le QR
}

struct WalletCardPreview: View {
    var displayName: String
    var requiredStamps: Int32
    var stampsCount: Int32
    var primaryColorHex: String
    var accentColorHex: String
    var logoURL: String?
    var stampEmoji: String? = nil
    var compact: Bool = false

    private var primaryColor: Color { Color(hex: primaryColorHex) }
    private var accentColor: Color { Color(hex: accentColorHex) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / walletCardAspectRatio
            let corner: CGFloat = compact ? 14 : 22

            cardContent
                .frame(width: w, height: h)
                .clipShape(RoundedRectangle(cornerRadius: corner))
                .overlay(
                    RoundedRectangle(cornerRadius: corner)
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
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            headerSection
            bodySection
        }
    }

    /// En-tête : uniquement le logo en haut à gauche (comme le vrai pass — pas de texte "test" en haut).
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 0) {
            logoInStrip
            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 14 : 20)
        .padding(.vertical, compact ? 10 : 16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [primaryColor, primaryColor.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .frame(height: compact ? 52 : 72)
    }

    /// Logo rectangulaire avec bord blanc (comme sur le vrai pass), pas de cercle.
    @ViewBuilder
    private var logoInStrip: some View {
        Group {
            if let urlString = logoURL?.trimmingCharacters(in: .whitespaces), !urlString.isEmpty {
                logoImage(from: urlString)
                    .frame(width: compact ? 36 : 48, height: compact ? 36 : 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5)
                    )
            } else {
                Image(systemName: "building.2.fill")
                    .font(.system(size: compact ? 18 : 24))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(width: compact ? 36 : 48, height: compact ? 36 : 48)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5)
                    )
            }
        }
    }

    /// Corps : zone verte (Points, NIVEAU/MEMBRE) puis bandeau blanc pleine largeur (QR réel + ID).
    private var bodySection: some View {
        VStack(spacing: 0) {
            // Zone verte — Points à gauche, NIVEAU/MEMBRE
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: compact ? 4 : 8) {
                    HStack(alignment: .firstTextBaseline, spacing: compact ? 4 : 6) {
                        if let emoji = stampEmoji, !emoji.isEmpty {
                            Text(emoji)
                                .font(.system(size: compact ? 28 : 36))
                        }
                        Text("\(stampsCount)")
                            .font(.system(size: compact ? 32 : PassFontSize.primaryValue, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text("Points")
                        .font(.system(size: compact ? 13 : PassFontSize.primaryLabel, weight: .regular))
                        .foregroundStyle(.white.opacity(0.95))
                }
                .padding(.leading, compact ? 20 : 32)
                .padding(.top, compact ? 18 : 36)

                HStack(alignment: .top, spacing: 0) {
                    fieldBlock(label: "NIVEAU", value: "Débutant", align: .leading)
                        .frame(maxWidth: .infinity)
                    fieldBlock(label: "MEMBRE", value: "Prévisualisation", align: .trailing)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, compact ? 20 : 32)
                .padding(.top, compact ? 20 : 32)

                Spacer(minLength: compact ? 16 : 36)
            }
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [primaryColor.opacity(0.96), primaryColor.opacity(0.88)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Bandeau même couleur que la carte (comme le vrai pass Wallet), QR + ID dans un rectangle blanc
            VStack(spacing: compact ? 6 : 10) {
                if let qrImage = QRCodeGenerator.generateQR(from: "5b34fc46-19d4-46db-95d3-dc2ffbc0", size: compact ? 80 : 120) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: compact ? 80 : 120, height: compact ? 80 : 120)
                }
                Text("5b34fc46-19d4-46db-95d3-dc2ffbc0")
                    .font(.system(size: compact ? 9 : PassFontSize.idUnderQR, weight: .regular))
                    .foregroundStyle(.black.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(compact ? 14 : 20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 10 : 14))
            .padding(.horizontal, compact ? 16 : 24)
            .padding(.vertical, compact ? 14 : 20)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [primaryColor.opacity(0.96), primaryColor.opacity(0.88)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func fieldBlock(label: String, value: String, align: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: align, spacing: compact ? 3 : 6) {
            Text(label)
                .font(.system(size: compact ? 10 : PassFontSize.fieldLabel, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            Text(value)
                .font(.system(size: compact ? 15 : PassFontSize.fieldValue, weight: .medium))
                .foregroundStyle(.white)
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
                    .aspectRatio(contentMode: .fill)
            } else {
                logoPlaceholder
            }
        } else if let url = URL(string: trimmed), isAPILogoURL(url) {
            AuthenticatedLogoView(url: url)
        } else if let url = URL(string: trimmed) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
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

    private var logoPlaceholder: some View {
        Image(systemName: "photo.circle.fill")
            .font(.title2)
            .foregroundStyle(.white.opacity(0.7))
    }
}

// MARK: - Génération QR (comme le vrai pass)

private enum QRCodeGenerator {
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
}

// MARK: - Logo API (Bearer)

private struct AuthenticatedLogoView: View {
    let url: URL
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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
        .task(id: url.absoluteString) {
            guard image == nil, !failed else { return }
            guard let token = AuthStorage.authToken, !token.isEmpty else { failed = true; return }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.cachePolicy = .reloadIgnoringLocalCacheData
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
                      let img = UIImage(data: data) else {
                    await MainActor.run { failed = true }
                    return
                }
                await MainActor.run { image = img }
            } catch {
                await MainActor.run { failed = true }
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
