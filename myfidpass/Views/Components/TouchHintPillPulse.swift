//
//  TouchHintPillPulse.swift
//  myfidpass
//
//  Pastilles « Touchez » — affichage statique (pas d’animation : évite le bobbing du scroll / GeometryReader).
//

import SwiftUI

/// Affichage fixe (l’ancien pulse `repeatForever` faisait bouger toute la page « Ma carte »).
struct TouchHintPillPulseModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: true, vertical: true)
    }
}

extension View {
    func touchHintPillPulse() -> some View {
        modifier(TouchHintPillPulseModifier())
    }

    /// Empêche les animations du parent (ex. carte) de déplacer un overlay positionné.
    func touchHintOverlayStableLayout() -> some View {
        transaction { transaction in
            transaction.disablesAnimations = true
        }
    }
}
