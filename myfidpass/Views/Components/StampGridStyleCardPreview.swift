//
//  StampGridStyleCardPreview.swift
//  myfidpass
//
//  Carte style "STELLAR HUB" : fond noir, grille de tampons (jaune + étoile / gris), UNTIL REWARD + NAME.
//

import SwiftUI

struct StampGridStyleCardPreview: View {
    var displayName: String
    var requiredStamps: Int32
    var stampsCount: Int32
    var memberName: String = "Mike"
    /// Couleur des tampons remplis (défaut or).
    var filledColorHex: String = "FFD700"

    private var filledColor: Color { Color(hex: filledColorHex) }
    private let columns = 5
    private let cornerRadius: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            stampGridSection
            infoSection
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var headerSection: some View {
        Text(displayName.isEmpty ? "STELLAR HUB" : displayName.uppercased())
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 20)
            .background(Color.black)
    }

    private var stampGridSection: some View {
        let total = Int(requiredStamps)
        let filled = min(max(0, Int(stampsCount)), total)
        let rows = (total + columns - 1) / columns
        return VStack(spacing: 10) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(0..<columns, id: \.self) { col in
                        let index = row * columns + col
                        if index < total {
                            stampCell(filled: index < filled)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func stampCell(filled: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(filled ? filledColor : Color(white: 0.35))
                .frame(width: 52, height: 52)
            if filled {
                Image(systemName: "star.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.black)
            }
        }
    }

    private var infoSection: some View {
        let remaining = max(0, Int(requiredStamps) - Int(stampsCount))
        return HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("UNTIL REWARD")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
                Text(remaining == 1 ? "1 stamp" : "\(remaining) stamps")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text("NAME")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
                Text(memberName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(Color.black)
    }
}

#Preview {
    StampGridStyleCardPreview(
        displayName: "STELLAR HUB",
        requiredStamps: 10,
        stampsCount: 8,
        memberName: "Mike"
    )
    .frame(width: 320)
    .padding()
}
