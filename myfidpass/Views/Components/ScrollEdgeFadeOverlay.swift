//
//  ScrollEdgeFadeOverlay.swift
//  myfidpass
//
//  Fondu haut / bas du contenu scrollé via masque alpha (pas de bande colorée mal alignée).
//

import SwiftUI

/// Masque vertical : le contenu s’estompe aux bords sans recouvrir avec une couleur (évite les décalages avec le fond).
private struct ScrollContentEdgeMask: View {
    var edgeHeight: CGFloat = 36

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.clear, Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: edgeHeight)

            Color.black
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            LinearGradient(
                colors: [Color.black, Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: edgeHeight)
        }
    }
}

extension View {
    /// Adoucit le haut et le bas du scroll en fondu sur le contenu (aucune couche opaque parasite).
    func scrollContentEdgeFade(edgeHeight: CGFloat = 36) -> some View {
        mask {
            ScrollContentEdgeMask(edgeHeight: edgeHeight)
        }
    }
}
