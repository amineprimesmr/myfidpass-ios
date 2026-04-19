//
//  View+GlassStyle.swift
//  Process
//
//  Extension globale pour le style Liquid Glass avec compatibilité iOS 17+
//  Utilise .buttonStyle(.glass) natif iOS 18+ avec fallback automatique pour iOS 17
//
//  IMPORTANT: Le SDK Xcode 26 indique iOS 26.0 pour .glass, mais en runtime
//  .glass fonctionne sur iOS 18+. L'adaptation automatique est conservée.
//

import SwiftUI

// MARK: - Glass Button Style Fallback (iOS 17)

/// Style de bouton Liquid Glass avec fallback pour iOS 17
/// Utilise .ultraThinMaterial + stroke blanc 28% opacity
struct GlassButtonStyleFallback: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            )
    }
}

// MARK: - View Extension - glassStyle() avec adaptation automatique

extension View {
    /// Applique le style Liquid Glass aux boutons
    /// iOS 26.0+ (SDK) / iOS 18+ (runtime) / watchOS 11+ : utilise .buttonStyle(.glass) natif automatiquement
    /// iOS 17 / watchOS 10 : utilise le fallback .ultraThinMaterial + stroke blanc 28% opacity automatiquement
    /// 
    /// IMPORTANT: Le SDK Xcode 26 indique iOS 26.0 pour .glass, mais en runtime .glass fonctionne sur iOS 18+
    /// Pour satisfaire le compilateur, on doit vérifier iOS 26.0, ce qui signifie que sur iOS 18-25
    /// on utilisera le fallback (limitation du compilateur). En runtime sur iOS 26.0+, .glass fonctionnera.
    @ViewBuilder
    func glassStyle() -> some View {
        #if os(watchOS)
        // ✅ watchOS : Support Liquid Glass
        if #available(watchOS 11.0, *) {
            // watchOS 11+ : Style Liquid Glass natif
            self.buttonStyle(.glass)
        } else {
            // watchOS 10 : Fallback avec GlassButtonStyleFallback
            self.buttonStyle(GlassButtonStyleFallback())
        }
        #else
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(GlassButtonStyleFallback())
        }
        #endif
    }
}

// MARK: - View Extension - glassEffect() avec compatibilité

extension View {
    /// Applique l'effet Liquid Glass natif avec compatibilité iOS
    /// iOS 26.0+ (SDK) / iOS 18+ (runtime) : utilise .glassEffect() natif automatiquement
    /// iOS 17 : utilise le fallback .ultraThinMaterial + stroke blanc 28% opacity automatiquement
    /// 
    /// Variants disponibles :
    /// - `.clear` : Effet glass le plus transparent (nécessite un fond pour la lisibilité)
    /// - `.regular` : Maintient automatiquement la lisibilité selon la luminosité du fond (recommandé)
    /// - `.regular.interactive()` : Réactif au toucher et aux interactions
    /// 
    /// IMPORTANT: .glassEffect() doit être appliqué en dernier dans la chaîne de modificateurs
    @ViewBuilder
    @_disfavoredOverload
    func glassEffect(_ variant: GlassEffectVariant = .regular, cornerRadius: CGFloat = 20) -> some View {
        #if os(watchOS)
        // Pas de `#available` imbriqués (évite avertissements « check inutile » selon la cible watchOS).
        if #available(watchOS 12.0, *) {
            _applyNativeGlassEffect(self, variant: variant, cornerRadius: cornerRadius)
        } else if #available(watchOS 11.0, *) {
            self.background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
        } else {
            self.background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
        }
        #else
        if #available(iOS 26.0, *) {
            _applyNativeGlassEffect(self, variant: variant, cornerRadius: cornerRadius)
        } else {
            self.background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
        }
        #endif
    }
}

// MARK: - Enum pour les variants de GlassEffect (wrapper pour éviter la récursion)

enum GlassEffectVariant {
    case clear
    case regular
    case regularInteractive
}

// MARK: - Helper pour appeler l'API native glassEffect sans récursion

/// Encapsule l’API SwiftUI `glassEffect` (annotée iOS 26+ / watchOS 12+ dans le SDK Xcode 26).
@available(iOS 26.0, watchOS 12.0, *)
private struct NativeGlassEffectModifier: ViewModifier {
    let variant: GlassEffectVariant
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        // Utiliser directement l'API native SwiftUI sur Content
        // Content n'a pas accès à notre extension personnalisée, donc cela appellera l'API native
        // IMPORTANT: .glassEffect() doit être le dernier modificateur pour fonctionner correctement
        // L'API native SwiftUI utilise: .glassEffect(.clear), .glassEffect(.regular), .glassEffect(.regular.interactive())
        switch variant {
        case .clear:
            // Variant le plus transparent
            content.glassEffect(.clear, in: .rect(cornerRadius: cornerRadius))
        case .regular:
            // Variant régulier qui maintient automatiquement la lisibilité (plus d'opacité)
            content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        case .regularInteractive:
            // Variant régulier avec interactions tactiles
            content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - Helper pour appliquer le modificateur natif

@available(iOS 26.0, watchOS 12.0, *)
private func _applyNativeGlassEffect<V: View>(_ view: V, variant: GlassEffectVariant, cornerRadius: CGFloat) -> some View {
    // Utiliser le ViewModifier qui appelle l'API native
    // Le ViewModifier garantit que .glassEffect() est appliqué en dernier
    view.modifier(NativeGlassEffectModifier(variant: variant, cornerRadius: cornerRadius))
}

// MARK: - Extension pour sheet avec UnevenRoundedRectangle

extension View {
    /// Applique l'effet Liquid Glass natif avec une forme UnevenRoundedRectangle (pour les sheets)
    /// iOS 26.0+ (SDK) / iOS 18+ (runtime) : utilise .glassEffect() natif automatiquement
    /// iOS 17 : utilise le fallback .ultraThinMaterial + stroke blanc 28% opacity automatiquement
    @ViewBuilder
    func glassEffectSheetShape(_ variant: GlassEffectVariant = .clear) -> some View {
        #if os(watchOS)
        if #available(watchOS 12.0, *) {
            self.modifier(NativeGlassEffectSheetModifier(variant: variant))
        } else if #available(watchOS 11.0, *) {
            self.background(.ultraThinMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 25, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 25))
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: 25, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 25)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
        } else {
            self.background(.ultraThinMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 25, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 25))
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: 25, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 25)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
        }
        #else
        if #available(iOS 26.0, *) {
            self.modifier(NativeGlassEffectSheetModifier(variant: variant))
        } else {
            self.background(.ultraThinMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 25, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 25))
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: 25, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 25)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
        }
        #endif
    }
}

// MARK: - Helper pour sheet avec UnevenRoundedRectangle

@available(iOS 26.0, watchOS 12.0, *)
struct NativeGlassEffectSheetModifier: ViewModifier {
    let variant: GlassEffectVariant

    func body(content: Content) -> some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 25,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 25
        )

        switch variant {
        case .clear:
            content.glassEffect(.clear, in: shape)
        case .regular:
            content.glassEffect(.regular, in: shape)
        case .regularInteractive:
            content.glassEffect(.regular.interactive(), in: shape)
        }
    }
}

// MARK: - Même style que le bouton « Réglages » (Commerce, en-tête)

/// Appliqué au **bouton** (label + action), comme `ProfileView` / `commerceTopBar`.
struct TopBarLiquidGlassButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.small)
        } else {
            content
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.15))
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.9)
                )
                .clipShape(Circle())
                .buttonStyle(TopBarLiquidGlassPressableStyle())
        }
    }
}

/// Même principe que `TopBarLiquidGlassButtonModifier` : `.glass` natif, forme **capsule** (ex. Activer / Réglages).
/// `tint` colore le verre (ex. `.green` pour l’état activé) via `.tint` + `GlassButtonStyle`, sans perdre l’effet liquid glass.
struct LiquidGlassCapsuleButtonModifier: ViewModifier {
    var tint: Color? = nil
    var controlSize: ControlSize = .small

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            Group {
                if let tint {
                    content.tint(tint)
                } else {
                    content
                }
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(controlSize)
        } else {
            if let tint {
                content
                    .background(tint.opacity(0.38), in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.9)
                    )
                    .buttonStyle(TopBarLiquidGlassPressableStyle())
            } else {
                content
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.9)
                    )
                    .buttonStyle(TopBarLiquidGlassPressableStyle())
            }
        }
    }
}

private struct TopBarLiquidGlassPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
