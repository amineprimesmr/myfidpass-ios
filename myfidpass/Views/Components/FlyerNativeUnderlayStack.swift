//
//  FlyerNativeUnderlayStack.swift
//  myfidpass
//
//  Fond de flyer (dégradé + photo IA + voile) aligné sur `et()` dans
//  `app-flyer-qr-draw` : sous WKWebView quand le canvas n’est pas rempli (skip) et qu’on affiche le PNG en UIImage natif.
//

import SwiftUI

struct FlyerNativeUnderlayStack: View {
    let state: FlyerStateDTO
    let image: UIImage

    private var topOverlayOpacity: Double {
        min(0.9, max(0, Double(state.flyerBgOverlayPct) / 100.0 * 0.88))
    }

    private var bottomOverlayOpacity: Double {
        min(0.95, max(0, Double(state.flyerBgOverlayPct) / 100.0 * 0.95))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: state.colorBgTop), Color(hex: state.colorBgBottom)],
                startPoint: .top,
                endPoint: .bottom
            )
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
            if state.flyerBgOverlayPct > 0.5 {
                LinearGradient(
                    colors: [
                        Color(hex: state.colorBgTop).opacity(topOverlayOpacity),
                        Color(hex: state.colorBgBottom).opacity(bottomOverlayOpacity)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
        }
    }
}
