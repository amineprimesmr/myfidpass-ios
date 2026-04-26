//
//  FluidZoomTransitionButtonStyle.swift
//  myfidpass
//
//  Transition « zoom fluide » iOS 18+ (source ↔ sheet) + effet verre aligné sur View+GlassStyle.
//

import SwiftUI

// MARK: - Zoom iOS 18+ : fond page d’origine (anti « dézoom » / marges)

/// Sur-échantillonner le canvas derrière la source de zoom pendant `navigationTransition(.zoom)` sur un `fullScreenCover`
/// (le système scale le fond → marges si le calque ne dépasse pas l’écran).
/// Même valeur que l’accueil tableau de bord / Commerce.
enum ZoomTransitionCanvasOverscan {
    static let inset: CGFloat = 56
}

// MARK: - Bouton source (carte)

/// Style proche des tutoriels « Fluid Zoom + Liquid Glass » : `matchedTransitionSource` + verre.
struct FluidZoomTransitionButtonStyle<S: Shape>: ButtonStyle {
    var id: String
    var namespace: Namespace.ID
    var shape: S
    var glassVariant: GlassEffectVariant

    @State private var hapticsTrigger: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if #available(iOS 18.0, *) {
                configuration.label
                    .matchedTransitionSource(id: id, in: namespace)
                    .modifier(ZoomCardGlassModifier(shape: shape, variant: glassVariant))
                    .sensoryFeedback(.impact(weight: .light, intensity: 0.75), trigger: hapticsTrigger)
            } else {
                configuration.label
                    .background(.ultraThinMaterial, in: shape)
                    .overlay(shape.stroke(Color.white.opacity(0.22), lineWidth: 1))
            }
        }
        .scaleEffect(configuration.isPressed ? 0.985 : 1)
        .animation(.spring(response: 0.26, dampingFraction: 0.84), value: configuration.isPressed)
        .onChange(of: configuration.isPressed) { _, newValue in
            guard newValue else { return }
            hapticsTrigger.toggle()
        }
    }
}

// MARK: - Verre sur forme arbitraire

private struct ZoomCardGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let variant: GlassEffectVariant

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            switch variant {
            case .clear:
                content.glassEffect(.clear, in: shape)
            case .regular:
                content.glassEffect(.regular, in: shape)
            case .regularInteractive:
                content.glassEffect(.regular.interactive(), in: shape)
            }
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.22), lineWidth: 1))
        }
    }
}

// MARK: - Source (sans bouton verre — ex. carte accueil + `MerchantPressableButtonStyle`)

/// Applique `matchedTransitionSource` sur iOS 18+ pour une paire avec `statsDetailZoomTransition`.
struct ZoomTransitionSourceModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

extension View {
    func zoomTransitionSource(id: String, in namespace: Namespace.ID) -> some View {
        modifier(ZoomTransitionSourceModifier(id: id, namespace: namespace))
    }

    /// À appliquer sur le **contenu présenté** (sheet / `navigationDestination`) pour lier le zoom à la source `id` / `namespace`.
    @ViewBuilder
    func statsDetailZoomTransition(sourceID: String, namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            self
        }
    }

    // MARK: - Feuille plein écran « Ma carte » (accueil) — même ordre de modificateurs

    /// À enchaîner **juste après** `statsDetailZoomTransition` sur le **même** conteneur que `NavigationStack`,
    /// comme sur l’accueil : le zoom doit suivre immédiatement les `environment`, puis seulement le chrome transparent.
    /// (Ne pas intercaler `presentationBackground` avant `navigationTransition(.zoom)`.)
    func merchantFluidZoomFullScreenTransparentChrome() -> some View {
        presentationBackground(.clear)
    }
}
