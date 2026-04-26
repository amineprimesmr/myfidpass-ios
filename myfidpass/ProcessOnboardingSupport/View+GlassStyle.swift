//
//  View+GlassStyle.swift
//  Process
//
//  Extension globale pour le style Liquid Glass avec compatibilité iOS 17+
//  iOS 26+ : .buttonStyle(.glass(.regular)) ou .glass(.regular.tint(...)) — doc Apple « glass(_:) »
//
//  IMPORTANT: Le SDK Xcode 26 indique iOS 26.0 pour .glass, mais en runtime
//  .glass fonctionne sur iOS 18+. L'adaptation automatique est conservée.
//

import SwiftUI

// MARK: - Teinte « verre sombre » (API native)

/// Teintes passées à **`Glass.regular.tint(_)`** / **`buttonStyle(.glass(.regular.tint(_)))`** — voir documentation Apple
/// [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views).
enum LiquidGlassNativeTint {
    /// Gris très sombre type contrôle sur fond flou / sombre (lisible, pas un « faux » calque : c’est l’API `tint` du Glass).
    static let darkRegular = Color(red: 0.11, green: 0.11, blue: 0.14)
}

// MARK: - Apparence explicite Liquid Glass (boutons)

/// Configuration du **matériau** passé à `buttonStyle(.glass(...))` sur iOS 26+.
/// - `adaptive` : `Glass.regular` sans teinte — rendu **clair / translucide** géré par le système.
/// - `regularTint` : `Glass.regular.tint(color)` — teinte **dans** l’API Glass (opaque / sombre si la couleur l’est).  
///   Ne pas confondre avec le modificateur `.tint` sur la vue : celui-ci ne pilote pas pareil le remplissage du verre.
enum LiquidGlassButtonAppearance: Equatable {
    case adaptive
    case regularTint(Color)
}

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

/// Repli iOS 17–25 : `adaptive` = matériau léger ; `regularTint` = couche charcoal **opaque** (lisible sur fond noir).
private struct LiquidGlassLegacyMaterialButtonStyle: ButtonStyle {
    var appearance: LiquidGlassButtonAppearance
    var cornerRadius: CGFloat

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch appearance {
        case .adaptive:
            configuration.label
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.26), lineWidth: 1))
        case .regularTint(let color):
            configuration.label
                .background {
                    ZStack {
                        shape.fill(.thinMaterial)
                        shape.fill(color.opacity(0.92))
                    }
                }
                .clipShape(shape)
                .overlay(shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                .scaleEffect(configuration.isPressed ? 0.993 : 1)
                .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
        }
    }
}

// MARK: - View Extension - glassStyle() avec adaptation automatique

extension View {
    /// `buttonStyle(.glass(.regular))` + repli matériau. Pour un verre **sombre opaque**, utiliser `liquidGlassButtonAppearance(.regularTint(...))`.
    @ViewBuilder
    func liquidGlassButtonAppearance(_ appearance: LiquidGlassButtonAppearance, cornerRadius: CGFloat = 20) -> some View {
        #if os(watchOS)
        if #available(watchOS 11.0, *) {
            switch appearance {
            case .adaptive:
                self.buttonStyle(.glass)
            case .regularTint(let color):
                self.buttonStyle(.glass(.regular.tint(color)))
            }
        } else {
            self.buttonStyle(LiquidGlassLegacyMaterialButtonStyle(appearance: appearance, cornerRadius: cornerRadius))
        }
        #else
        if #available(iOS 26.0, *) {
            switch appearance {
            case .adaptive:
                self.buttonStyle(.glass)
            case .regularTint(let color):
                self.buttonStyle(.glass(.regular.tint(color)))
            }
        } else {
            self.buttonStyle(LiquidGlassLegacyMaterialButtonStyle(appearance: appearance, cornerRadius: cornerRadius))
        }
        #endif
    }

    /// Applique le style Liquid Glass aux boutons
    /// iOS 26+ : `buttonStyle(.glass(.regular))` (API configurable, doc Apple).
    /// iOS 17 : repli matériau.
    @ViewBuilder
    func glassStyle() -> some View {
        liquidGlassButtonAppearance(.adaptive, cornerRadius: 20)
    }

    /// Verre **sombre** via l’API native `Glass.regular.tint(...)` (onboarding clair : préférer `glassStyle()` adaptatif).
    @ViewBuilder
    func glassStyleDark(cornerRadius: CGFloat = 20) -> some View {
        liquidGlassButtonAppearance(.regularTint(LiquidGlassNativeTint.darkRegular), cornerRadius: cornerRadius)
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

    /// `glassEffect(.regular.tint(...))` — verre sombre **natif** (doc Apple « Applying Liquid Glass ») ; repli matériau + teinte sinon.
    @ViewBuilder
    func glassEffectRegularDark(cornerRadius: CGFloat = 20) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        #if os(watchOS)
        if #available(watchOS 12.0, *) {
            self.glassEffect(.regular.tint(LiquidGlassNativeTint.darkRegular), in: shape)
        } else {
            self.background {
                ZStack {
                    shape.fill(.thinMaterial)
                    shape.fill(LiquidGlassNativeTint.darkRegular.opacity(0.88))
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        }
        #else
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(LiquidGlassNativeTint.darkRegular), in: shape)
        } else {
            self.background {
                ZStack {
                    shape.fill(.thinMaterial)
                    shape.fill(LiquidGlassNativeTint.darkRegular.opacity(0.88))
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
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

/// Appliqué au **bouton** (label + action), comme `ProfileView` / `commerceTopBar` — `.glass(.regular.tint)` sombre (API native).
struct TopBarLiquidGlassButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass(.regular.tint(LiquidGlassNativeTint.darkRegular)))
                .buttonBorderShape(.circle)
                .controlSize(.small)
        } else {
            content
                .background {
                    ZStack {
                        Circle().fill(.thinMaterial)
                        Circle().fill(LiquidGlassNativeTint.darkRegular.opacity(0.9))
                    }
                }
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
                .buttonStyle(TopBarLiquidGlassPressableStyle())
        }
    }
}

/// Même principe que `TopBarLiquidGlassButtonModifier` : `.glass(.regular[.tint])`, forme **capsule**.
struct LiquidGlassCapsuleButtonModifier: ViewModifier {
    var tint: Color? = nil
    var controlSize: ControlSize = .small

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                content
                    .buttonStyle(.glass(.regular.tint(tint)))
                    .buttonBorderShape(.capsule)
                    .controlSize(controlSize)
            } else {
                content
                    .buttonStyle(.glass(.regular))
                    .buttonBorderShape(.capsule)
                    .controlSize(controlSize)
            }
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
