//
//  FlyerNativeUnderlayStack.swift
//
//  Fond de flyer (dégradé + photo IA + voile) — **sans** empilement d’ombres / lumières agressif.
//

import SwiftUI

struct FlyerNativeUnderlayStack: View {
    let state: FlyerStateDTO
    let image: UIImage

    private var resolvedBaseColor: Color {
        let p = state.colorPrimary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !p.isEmpty { return Color(hex: p) }
        return Color(hex: state.colorBgTop)
    }

    private var resolvedTopColor: Color {
        Color(hex: state.colorBgTop)
    }

    private var resolvedBottomColor: Color {
        Color(hex: state.colorBgBottom)
    }

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    resolvedTopColor,
                    resolvedBaseColor,
                    resolvedBottomColor
                ],
                center: UnitPoint(x: 0.5, y: 0.5),
                startRadius: 0,
                endRadius: 740
            )
            RadialGradient(
                colors: [
                    Color.white.opacity(0.18),
                    Color.white.opacity(0.08),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.48),
                startRadius: 0,
                endRadius: 500
            )
            RadialGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.22)
                ],
                center: UnitPoint(x: 0.5, y: 0.5),
                startRadius: 120,
                endRadius: 800
            )
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.07)
                )
            ZStack {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.1),
                        Color.white.opacity(0.02),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.45)
                )
                .blendMode(.screen)
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.multiply)
            }
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
