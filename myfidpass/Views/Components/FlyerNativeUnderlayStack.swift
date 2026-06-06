//
//  FlyerNativeUnderlayStack.swift
//
//  Fond de flyer (dégradé + photo IA + voile) — **sans** empilement d’ombres / lumières agressif.
//

import SwiftUI

struct FlyerNativeUnderlayStack: View {
    let state: FlyerStateDTO
    let image: UIImage

    private var bgOverlayOpacity: Double {
        max(0, min(0.8, state.flyerBgOverlayPct / 100))
    }

    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            if bgOverlayOpacity > 0 {
                LinearGradient(
                    colors: [
                        Color(hex: state.colorBgTop).opacity(bgOverlayOpacity * 0.88),
                        Color(hex: state.colorBgBottom).opacity(bgOverlayOpacity * 0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
