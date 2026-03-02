//
//  CreditCardStylePreview.swift
//  myfidpass
//
//  Aperçu de la carte fidélité au format carte bancaire (ratio large, style horizontal).
//

import SwiftUI
import UIKit
import CoreImage

/// Ratio carte bancaire ISO (≈ 1.59) — largeur / hauteur.
private let creditCardAspectRatio: CGFloat = 375 / 236

struct CreditCardStylePreview: View {
    var displayName: String
    var requiredStamps: Int32
    var stampsCount: Int32
    var primaryColorHex: String
    var accentColorHex: String
    var logoURL: String?
    var stampEmoji: String?

    private var primaryColor: Color { Color(hex: primaryColorHex) }
    private var accentColor: Color { Color(hex: accentColorHex) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / creditCardAspectRatio
            let corner: CGFloat = 14

            cardContent
                .frame(width: w, height: h)
                .clipShape(RoundedRectangle(cornerRadius: corner))
                .overlay(
                    RoundedRectangle(cornerRadius: corner)
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 4)
                .frame(maxWidth: .infinity)
        }
        .aspectRatio(creditCardAspectRatio, contentMode: .fit)
    }

    private var cardContent: some View {
        HStack(spacing: 0) {
            // Gauche : logo + nom
            leftBlock
            // Centre-droite : points + infos
            rightBlock
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [primaryColor, primaryColor.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var leftBlock: some View {
        HStack(alignment: .center, spacing: 12) {
            logoView
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName.isEmpty ? "Ma Carte" : displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 20)
        .padding(.trailing, 12)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var logoView: some View {
        if let urlString = logoURL?.trimmingCharacters(in: .whitespaces), !urlString.isEmpty {
            logoImage(from: urlString)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.8), lineWidth: 1)
                )
        } else {
            Image(systemName: "building.2.fill")
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.95))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
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
                Image(systemName: "photo.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        } else if let url = URL(string: trimmed) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
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

    private var rightBlock: some View {
        HStack(alignment: .center, spacing: 16) {
            // Points (gros) + emoji
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let emoji = stampEmoji, !emoji.isEmpty {
                        Text(emoji)
                            .font(.system(size: 28))
                    }
                    Text("\(stampsCount)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("Points")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.9))
            }

            // QR miniature
            if let qrImage = CreditCardQRGenerator.generateQR(from: "••••••••", size: 56) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, 12)
        .padding(.trailing, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

// MARK: - QR pour la carte bancaire (réutilise la logique Core Image)

private enum CreditCardQRGenerator {
    static func generateQR(from string: String, size: CGFloat = 56) -> UIImage? {
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

// MARK: - Bandeau inférieur optionnel (NIVEAU / MEMBRE)

struct CreditCardStylePreviewWithFooter: View {
    var displayName: String
    var requiredStamps: Int32
    var stampsCount: Int32
    var primaryColorHex: String
    var accentColorHex: String
    var logoURL: String?
    var stampEmoji: String?

    var body: some View {
        VStack(spacing: 0) {
            CreditCardStylePreview(
                displayName: displayName,
                requiredStamps: requiredStamps,
                stampsCount: stampsCount,
                primaryColorHex: primaryColorHex,
                accentColorHex: accentColorHex,
                logoURL: logoURL,
                stampEmoji: stampEmoji
            )
            // Bandeau accent (optionnel)
            HStack {
                Text("NIVEAU")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text("Débutant")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("MEMBRE")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text("Prévisualisation")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(hex: accentColorHex).opacity(0.9))
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
    }
}

#Preview {
    VStack(spacing: 24) {
        CreditCardStylePreview(
            displayName: "Café des Arts",
            requiredStamps: 10,
            stampsCount: 3,
            primaryColorHex: "5d4e37",
            accentColorHex: "d7ccc8",
            logoURL: nil,
            stampEmoji: "☕"
        )
        .padding(.horizontal, 24)

        CreditCardStylePreview(
            displayName: "STELLAR HUB",
            requiredStamps: 10,
            stampsCount: 9,
            primaryColorHex: "0d0d0d",
            accentColorHex: "FFD700",
            logoURL: nil,
            stampEmoji: "⭐"
        )
        .padding(.horizontal, 24)
    }
    .padding()
}
