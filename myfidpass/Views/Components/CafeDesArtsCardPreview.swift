//
//  CafeDesArtsCardPreview.swift
//  myfidpass
//
//  Design dédié « Café des Arts » : carte type fidélité papier avec grille de tampons
//  visibles (remplis / vides), style café chaleureux.
//

import SwiftUI

/// Ratio carte fidélité (proche format carte de visite).
private let cafeCardAspectRatio: CGFloat = 375 / 240

struct CafeDesArtsCardPreview: View {
    var displayName: String
    var requiredStamps: Int32
    var stampsCount: Int32
    var primaryColorHex: String
    var accentColorHex: String
    var logoURL: String?
    var stampEmoji: String?
    var compact: Bool = false

    private var primaryColor: Color { Color(hex: primaryColorHex) }
    private var accentColor: Color { Color(hex: accentColorHex) }
    private let stampIcon = "cup.and.saucer.fill"

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / cafeCardAspectRatio
            let corner: CGFloat = compact ? 12 : 20

            cardContent
                .frame(width: w, height: h)
                .clipShape(RoundedRectangle(cornerRadius: corner))
                .overlay(
                    RoundedRectangle(cornerRadius: corner)
                        .strokeBorder(accentColor.opacity(0.4), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.2), radius: compact ? 8 : 12, x: 0, y: 4)
                .frame(maxWidth: .infinity)
        }
        .aspectRatio(cafeCardAspectRatio, contentMode: .fit)
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            headerSection
            stampGridSection
            footerSection
        }
    }

    // MARK: - En-tête : logo + nom + sous-titre

    private var headerSection: some View {
        HStack(alignment: .center, spacing: compact ? 10 : 14) {
            logoView
                .frame(width: compact ? 40 : 52, height: compact ? 40 : 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName.isEmpty ? "Café des Arts" : displayName)
                    .font(.system(size: compact ? 18 : 24, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Carte fidélité")
                    .font(.system(size: compact ? 11 : 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 14 : 20)
        .padding(.vertical, compact ? 12 : 18)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [primaryColor, primaryColor.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    @ViewBuilder
    private var logoView: some View {
        Group {
            if let urlString = logoURL?.trimmingCharacters(in: .whitespaces), !urlString.isEmpty {
                cafeLogoImage(from: urlString)
            } else {
                Image(systemName: stampIcon)
                    .font(.system(size: compact ? 20 : 26))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.2))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(0.8), lineWidth: 1)
        )
    }

    // MARK: - Grille de tampons (remplis / vides) — toujours 10 cases visibles si total = 10

    private var stampGridSection: some View {
        let total = max(1, Int(requiredStamps))
        let filled = min(max(0, Int(stampsCount)), total)
        let columns = min(5, max(2, total))
        let rows = (total + columns - 1) / columns
        let useCompactStamps = total >= 10 || compact
        let cellSize: CGFloat = useCompactStamps ? (compact ? 28 : 34) : (compact ? 32 : 42)
        let rowSpacing: CGFloat = useCompactStamps ? (compact ? 4 : 6) : (compact ? 6 : 10)
        let colSpacing: CGFloat = useCompactStamps ? (compact ? 4 : 6) : (compact ? 6 : 10)

        return VStack(spacing: compact ? 8 : 10) {
            Text("\(total) café\(total > 1 ? "s" : "") acheté\(total > 1 ? "s" : "") = 1 offert")
                .font(.system(size: compact ? 11 : 13, weight: .medium))
                .foregroundStyle(primaryColor.opacity(0.9))

            VStack(spacing: rowSpacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: colSpacing) {
                        ForEach(0..<columns, id: \.self) { col in
                            let index = row * columns + col
                            if index < total {
                                stampCell(filled: index < filled, index: index, size: cellSize)
                            }
                        }
                    }
                }
            }

            HStack {
                Text("\(filled) / \(total)")
                    .font(.system(size: compact ? 14 : 17, weight: .bold))
                    .foregroundStyle(primaryColor)
                Text("tampons")
                    .font(.system(size: compact ? 12 : 14, weight: .regular))
                    .foregroundStyle(primaryColor.opacity(0.8))
                Spacer()
                let rest = max(0, total - filled)
                Text(rest == 0 ? "Récompense disponible !" : "\(rest) restant\(rest > 1 ? "s" : "")")
                    .font(.system(size: compact ? 11 : 13, weight: .medium))
                    .foregroundStyle(rest == 0 ? Color(hex: "2e7d32") : primaryColor.opacity(0.7))
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, compact ? 16 : 24)
        .padding(.vertical, compact ? 14 : 20)
        .frame(maxWidth: .infinity)
        .background(accentColor.opacity(0.5))
    }

    private func stampCell(filled: Bool, index: Int, size: CGFloat? = nil) -> some View {
        let cellSize = size ?? (compact ? 32 : 42)
        return ZStack {
            Circle()
                .fill(filled ? primaryColor : Color.white)
                .overlay(
                    Circle()
                        .strokeBorder(filled ? primaryColor : primaryColor.opacity(0.35), lineWidth: filled ? 0 : 2)
                )
            if filled {
                if let emoji = stampEmoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.system(size: cellSize * 0.5))
                } else {
                    Image(systemName: stampIcon)
                        .font(.system(size: cellSize * 0.45))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: cellSize, height: cellSize)
    }

    // MARK: - Pied de carte

    private var footerSection: some View {
        Text("Présentez cette carte à chaque passage")
            .font(.system(size: compact ? 10 : 12, weight: .medium))
            .foregroundStyle(primaryColor.opacity(0.75))
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 8 : 12)
            .background(accentColor.opacity(0.3))
    }

    // MARK: - Logo (réutilisation logique WalletCardPreview)

    @ViewBuilder
    private func cafeLogoImage(from urlString: String) -> some View {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        let filePath: String? = if trimmed.hasPrefix("file:") {
            URL(string: trimmed)?.path
        } else if trimmed.hasPrefix("/") {
            trimmed
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
                Image(systemName: stampIcon)
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        } else if let url = URL(string: trimmed) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                default: Image(systemName: stampIcon).font(.title2).foregroundStyle(.white)
                }
            }
        } else {
            Image(systemName: stampIcon)
                .font(.title2)
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        CafeDesArtsCardPreview(
            displayName: "Café des Arts",
            requiredStamps: 10,
            stampsCount: 3,
            primaryColorHex: "5d4e37",
            accentColorHex: "d7ccc8",
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
        .frame(height: 160)
        .padding(.horizontal, 24)
    }
    .padding()
}
