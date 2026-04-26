//
//  MerchantMotion.swift
//  myfidpass
//
//  Courbes d’animation et retour tactile cohérents pour navigation + boutons (UX fluide).
//

import SwiftUI

/// Animations partagées — ressorts légèrement amortis pour éviter l’effet « ressort trop nerveux ».
enum MerchantMotion {
    /// Changement d’onglet (TabView) ou sélection programmatique.
    static let tabSwitch: Animation = .spring(response: 0.38, dampingFraction: 0.86, blendDuration: 0)

    /// Push / pop dans un `NavigationStack` (profondeur de pile).
    static let navigationPath: Animation = .spring(response: 0.42, dampingFraction: 0.88, blendDuration: 0)

    /// Apparition de contenu (listes, cartes).
    static let contentReveal: Animation = .spring(response: 0.48, dampingFraction: 0.82, blendDuration: 0)

    /// Bouton : press / release — réactif, peu de rebond.
    static let buttonPress: Animation = .spring(response: 0.3, dampingFraction: 0.78, blendDuration: 0)
}

/// Style de bouton « press » pour cartes et CTA : léger zoom + assombrissement, sans lag.
struct MerchantPressableButtonStyle: ButtonStyle {
    var scalePressed: CGFloat = 0.97
    var opacityPressed: Double = 0.9

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scalePressed : 1)
            .brightness(configuration.isPressed ? -0.035 : 0)
            .opacity(configuration.isPressed ? opacityPressed : 1)
            .animation(MerchantMotion.buttonPress, value: configuration.isPressed)
    }
}

// MARK: - Onboarding flyer (secousse CTA)

/// Secousse horizontale du seul CTA « Créer mon flyer de jeu » (onglet Commerce) quand l’utilisateur tente un autre onglet.
struct FlyerPrimaryCTAShakeModifier: ViewModifier {
    let shakeToken: Int
    @State private var offsetX: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offsetX)
            .onChange(of: shakeToken) { _, _ in
                guard shakeToken > 0 else { return }
                Task { @MainActor in
                    // Assez long à l’écran (~1,1 s de pauses + ressort) pour que la secousse se lise clairement.
                    let pattern: [CGFloat] = [0, -20, 20, -18, 18, -16, 16, -12, 12, -8, 8, -4, 4, 0]
                    for x in pattern {
                        withAnimation(MerchantMotion.flyerCTAShakeStep) {
                            offsetX = x
                        }
                        try? await Task.sleep(nanoseconds: 80_000_000)
                    }
                }
            }
    }
}

extension MerchantMotion {
    /// Pulsations lisibles (chaque impulsion a le temps d’aller au point avant la suivante).
    static let flyerCTAShakeStep: Animation = .interpolatingSpring(
        mass: 0.3,
        stiffness: 300,
        damping: 16,
        initialVelocity: 0
    )
}

extension View {
    func flyerPrimaryCTAShake(shakeToken: Int) -> some View {
        modifier(FlyerPrimaryCTAShakeModifier(shakeToken: shakeToken))
    }
}
