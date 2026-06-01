//
//  MerchantMotion.swift
//  myfidpass
//
//  Courbes d’animation et retour tactile cohérents pour navigation + boutons (UX fluide).
//

import SwiftUI

// MARK: - Aperçu carte accueil (pression tactile)

/// Contexte tactile optionnel pour **`MerchantPressableButtonStyle`** (zoom immédiat sans bloquer un scroll voisin).
/// Sur l’accueil commerçant : `.inactive`. Conservé pour d’éventuels écrans avec paging horizontal à côté d’un bouton.
struct HomeCarouselPressContext: Equatable {
    /// Petit mouvement encore traité comme « doigt à l’écran » pour l’effet visuel press.
    var fingerDownForVisual: Bool = false
    /// Scroll / swipe horizontal prioritaire : désactive l’effet press sur la carte.
    var horizontalPageSwipe: Bool = false

    static let inactive = HomeCarouselPressContext()
}

private struct HomeCarouselPressKey: EnvironmentKey {
    static let defaultValue = HomeCarouselPressContext.inactive
}

extension EnvironmentValues {
    var homeCarouselPress: HomeCarouselPressContext {
        get { self[HomeCarouselPressKey.self] }
        set { self[HomeCarouselPressKey.self] = newValue }
    }
}

/// Animations partagées — ressorts légèrement amortis pour éviter l’effet « ressort trop nerveux ».
enum MerchantMotion {
    /// Changement d’onglet (TabView) — ressort proche de l’onboarding.
    static let tabSwitch: Animation = .spring(response: 0.42, dampingFraction: 0.88, blendDuration: 0)

    /// Push / pop dans un `NavigationStack` (profondeur de pile).
    static let navigationPath: Animation = .spring(response: 0.42, dampingFraction: 0.88, blendDuration: 0)

    /// Apparition de contenu (listes, cartes).
    static let contentReveal: Animation = .spring(response: 0.48, dampingFraction: 0.82, blendDuration: 0)

    /// Bouton : press / release — réactif, peu de rebond.
    static let buttonPress: Animation = .spring(response: 0.3, dampingFraction: 0.78, blendDuration: 0)

    /// Menu latéral style X (Accueil).
    static let sidebar: Animation = .interactiveSpring(duration: 0.2, extraBounce: 0.02)

    /// Overlay plein écran / feuille modale lourde.
    static let overlayPresent: Animation = .spring(response: 0.42, dampingFraction: 0.88, blendDuration: 0)

    /// Crossfade léger entre états racine (ex. auth ↔ app).
    static let rootCrossfade: Animation = .easeInOut(duration: 0.22)
}

extension NavigationPath {
    /// Push animé dans une pile SwiftUI.
    mutating func appendAnimated<T>(_ value: T, animation: Animation = MerchantMotion.navigationPath) where T: Hashable {
        withAnimation(animation) {
            append(value)
        }
    }
}

/// Style de bouton « press » pour cartes et CTA : léger zoom + assombrissement.
///
/// - Par défaut : suit `configuration.isPressed`.
/// - `recognizeTouchImmediately` : combine `isPressed` avec `Environment.homeCarouselPress` (souvent `.inactive`).
struct MerchantPressableButtonStyle: ButtonStyle {
    var scalePressed: CGFloat = 0.97
    var opacityPressed: Double = 0.9
    var recognizeTouchImmediately: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        PressBody(
            configuration: configuration,
            scalePressed: scalePressed,
            opacityPressed: opacityPressed,
            recognizeTouchImmediately: recognizeTouchImmediately
        )
    }

    private struct PressBody: View {
        let configuration: Configuration
        let scalePressed: CGFloat
        let opacityPressed: Double
        let recognizeTouchImmediately: Bool

        @Environment(\.homeCarouselPress) private var homeCarouselPress

        private var pressedEffective: Bool {
            if !recognizeTouchImmediately {
                return configuration.isPressed
            }
            if homeCarouselPress.horizontalPageSwipe {
                return false
            }
            return configuration.isPressed || homeCarouselPress.fingerDownForVisual
        }

        var body: some View {
            configuration.label
                .scaleEffect(pressedEffective ? scalePressed : 1)
                .brightness(pressedEffective ? -0.035 : 0)
                .opacity(pressedEffective ? opacityPressed : 1)
                .animation(MerchantMotion.buttonPress, value: pressedEffective)
        }
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
