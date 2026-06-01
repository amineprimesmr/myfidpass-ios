//
//  CardPreviewConfiguratorPill.swift
//  myfidpass
//
//  Pastilles statiques "Touchez" sur l'aperçu carte (Ma carte).
//

import SwiftUI

struct CardPreviewConfiguratorPill: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

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
        .fixedSize()
        .scaleEffect(reduceMotion ? 1 : (isPulsing ? 1.08 : 0.96), anchor: .center)
        .task {
            guard !reduceMotion else { return }
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.82).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        .onDisappear {
            isPulsing = false
        }
    }
}

enum CardPreviewPillsLayoutStyle {
    /// Mode points (ou tampons avec image de fond : colonne TAMPONS dans le corps).
    case walletPoints
    /// Tampons sans image : grille dans le bandeau 750×246 (zone `.mainMetrics`).
    case stampGridInBanner
}

struct CardPreviewCompletionPillsOverlay: View {
    let cardWidth: CGFloat
    let totalHeight: CGFloat
    var compact: Bool
    let zones: Set<CardPreviewEditZone>
    var layoutStyle: CardPreviewPillsLayoutStyle = .walletPoints
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
        .fixedSize()
        .position(x: x, y: y)
    }

    var body: some View {
        let w = max(1, cardWidth)
        let h = max(1, totalHeight)
        let banH = bannerHeight(w)
        let bodyH = max(0, h - headH - banH)

        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: w, height: h)
                .allowsHitTesting(false)

            if zones.contains(.logoBand) {
                pillButton(zone: .logoBand, x: w * 0.24, y: headH * 0.42)
            }
            if zones.contains(.headerRight) {
                pillButton(zone: .headerRight, x: w * 0.84, y: headH * 0.44)
            }
            if zones.contains(.backgroundImage) {
                pillButton(zone: .backgroundImage, x: w * 0.5, y: headH + banH * 0.5)
            }
            if zones.contains(.mainMetrics) {
                switch layoutStyle {
                case .walletPoints:
                    pillButton(zone: .mainMetrics, x: w * 0.24, y: headH + banH + bodyH * 0.2)
                case .stampGridInBanner:
                    pillButton(zone: .mainMetrics, x: w * 0.5, y: headH + banH * 0.5)
                }
            }
            if zones.contains(.cardAppearance) {
                pillButton(zone: .cardAppearance, x: w * 0.72, y: headH + banH + bodyH * 0.55)
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
    }
}
