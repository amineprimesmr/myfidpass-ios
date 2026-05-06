//
//  CardPreviewConfiguratorPill.swift
//  myfidpass
//
//  Pastilles « Configurer » sur l’aperçu carte (Ma carte) — boutons par zone.
//

import SwiftUI

/// Pastille sur l’aperçu : indique où taper pour compléter un élément obligatoire.
struct CardPreviewConfiguratorPill: View {
    @State private var isBlinking = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 10, weight: .bold))
            Text("Touchez")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.82))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.34), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 8, y: 4)
        .opacity(isBlinking ? 1 : 0.45)
        .scaleEffect(isBlinking ? 1 : 0.96)
        .animation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true), value: isBlinking)
        .onAppear { isBlinking = true }
        .onDisappear { isBlinking = false }
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
