//
//  CardPreviewConfiguratorPill.swift
//  myfidpass
//
//  Pastilles « Configurer » sur l’aperçu carte (Ma carte) — boutons par zone.
//

import SwiftUI

/// Pastille animée : indique où cliquer sur la carte pour compléter un élément obligatoire.
struct CardPreviewConfiguratorPill: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.95, green: 0.45, blue: 0.1), Color(red: 0.85, green: 0.25, blue: 0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .orange.opacity(pulse ? 0.55 : 0.28), radius: pulse ? 6 : 3, y: 2)
        .scaleEffect(pulse ? 1.04 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

/// Placement des pastilles selon le type d’aperçu (points vs tampons).
enum CardPreviewPillsLayoutStyle {
    /// Mode points : métriques sous le bandeau image.
    case walletPoints
    /// Mode tampons : grille + icône dans le bandeau 750×246.
    case stampsBannerMetrics
}

/// Pastilles au-dessus de la carte : chaque pastille est un bouton qui ouvre la zone correspondante.
/// Le fond du calque laisse passer les touches ; seules les pastilles interceptent le tap.
struct CardPreviewCompletionPillsOverlay: View {
    let cardWidth: CGFloat
    let totalHeight: CGFloat
    var compact: Bool
    let zones: Set<CardPreviewEditZone>
    let layoutStyle: CardPreviewPillsLayoutStyle
    let onTapZone: (CardPreviewEditZone) -> Void

    private var headH: CGFloat { compact ? 70 : 100 }

    private func bannerHeight(_ w: CGFloat) -> CGFloat {
        max(1, w / (750 / 246))
    }

    private func pillButton(zone: CardPreviewEditZone, x: CGFloat, y: CGFloat) -> some View {
        Button {
            onTapZone(zone)
        } label: {
            CardPreviewConfiguratorPill()
        }
        .buttonStyle(.plain)
        .position(x: x, y: y)
    }

    var body: some View {
        let w = max(1, cardWidth)
        let h = max(1, totalHeight)
        let banH = bannerHeight(w)
        let bodyH = max(0, h - headH - banH)

        ZStack(alignment: .topLeading) {
            // Laisse passer les touches vers la carte sauf sur les pastilles (sœurs au-dessus).
            Color.clear
                .frame(width: w, height: h)
                .allowsHitTesting(false)

            if zones.contains(.logoBand) {
                pillButton(zone: .logoBand, x: w * 0.24, y: headH * 0.42)
            }
            if zones.contains(.headerRight) {
                // Aligné sur le lien « Récompenses » (trailing du bandeau).
                pillButton(zone: .headerRight, x: w * 0.84, y: headH * 0.44)
            }
            if zones.contains(.backgroundImage) {
                pillButton(zone: .backgroundImage, x: w * 0.5, y: headH + banH * 0.5)
            }
            if zones.contains(.mainMetrics) {
                switch layoutStyle {
                case .walletPoints:
                    pillButton(zone: .mainMetrics, x: w * 0.24, y: headH + banH + bodyH * 0.2)
                case .stampsBannerMetrics:
                    pillButton(zone: .mainMetrics, x: w * 0.5, y: headH + banH * 0.5)
                }
            }
            if zones.contains(.cardAppearance) {
                pillButton(zone: .cardAppearance, x: w * 0.72, y: headH + banH + bodyH * 0.55)
            }
        }
        .frame(width: w, height: h)
    }
}
