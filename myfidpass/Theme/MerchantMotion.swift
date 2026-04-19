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

/// Secousse horizontale du bloc « Créer mon flyer de jeu » quand l’utilisateur tente un autre onglet.
struct FlyerPrimaryCTAShakeModifier: ViewModifier {
    let shakeToken: Int
    @State private var offsetX: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offsetX)
            .onChange(of: shakeToken) { _, _ in
                guard shakeToken > 0 else { return }
                Task { @MainActor in
                    let pattern: [CGFloat] = [0, -11, 11, -9, 9, -6, 6, -3, 3, 0]
                    for x in pattern {
                        withAnimation(MerchantMotion.flyerCTAShakeStep) {
                            offsetX = x
                        }
                        try? await Task.sleep(nanoseconds: 38_000_000)
                    }
                }
            }
    }
}

extension MerchantMotion {
    /// Petits pas rapides pour la secousse « indispensable ».
    static let flyerCTAShakeStep: Animation = .spring(response: 0.16, dampingFraction: 0.62, blendDuration: 0)
}

extension View {
    func flyerPrimaryCTAShake(shakeToken: Int) -> some View {
        modifier(FlyerPrimaryCTAShakeModifier(shakeToken: shakeToken))
    }
}
