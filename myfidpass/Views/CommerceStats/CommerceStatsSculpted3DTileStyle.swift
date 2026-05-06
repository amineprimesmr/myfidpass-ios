//
//  CommerceStatsSculpted3DTileStyle.swift
//  myfidpass
//
//  Tuiles statistiques : relief 3D marqué (biseau, dôme lumineux, gorge basse, double ombre) + enfoncé.
//

import SwiftUI

// MARK: - Teintes — fort contraste « bloc massif » (pas de gris moyen plat)

private enum CommerceStatsSculptedPalette {
    /// Fond blanc sculpté (version claire demandée pour toutes les tuiles 3D stats).
    static let bevelTop = Color.white
    static let bevelHigh = Color(red: 0.995, green: 0.995, blue: 0.995)
    static let faceMid = Color(red: 0.988, green: 0.988, blue: 0.988)
    /// Tranchant / gorge bas (léger gris pour conserver le relief).
    static let bevelShade = Color(red: 0.972, green: 0.972, blue: 0.972)
    static let bevelPit = Color(red: 0.955, green: 0.955, blue: 0.955)

    /// Bord vif côté lumière
    static let specularRim: Color = .white.opacity(0.92)
    static let specularDim: Color = .white.opacity(0.45)
    /// Côté ombre du bord extérieur
    static let outerRimShade: Color = .black.opacity(0.14)

    /// Ligne d’inset haut (face supérieure du chanfrein)
    static let innerTopHighlight: Color = .white.opacity(0.82)
    static let innerBottomCrease: Color = .black.opacity(0.12)
}

// MARK: - Calque (sans ombre extérieure)

struct CommerceStatsSculpted3DSurface: View {
    var cornerRadius: CGFloat
    var pressed: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 1) Volume principal : dégradé fort (clair haut / très sombre bas)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: CommerceStatsSculptedPalette.bevelTop, location: 0),
                            .init(color: CommerceStatsSculptedPalette.bevelHigh, location: 0.2),
                            .init(color: CommerceStatsSculptedPalette.faceMid, location: 0.52),
                            .init(color: CommerceStatsSculptedPalette.bevelShade, location: 0.82),
                            .init(color: CommerceStatsSculptedPalette.bevelPit, location: 1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(pressed ? Color.black.opacity(0.1) : Color.clear)
                )

            // 2) Dôme : spot doux haut-gauche (sensation de surélévation)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(pressed ? 0.02 : 0.08),
                            Color.white.opacity(0.02),
                            Color.clear,
                        ],
                        center: UnitPoint(x: 0.1, y: 0.08),
                        startRadius: 0,
                        endRadius: min(180, max(40, cornerRadius * 4.2))
                    )
                )
                .opacity(pressed ? 0.45 : 0.72)

            // 3) Assombrissement côté bas (un seul RoundedRect + dégradé, sans masque « rect » pour éviter des coins visuellement bancals)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .clear, location: 0.45),
                            .init(color: .black.opacity(0.08), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(0.55)
                .allowsHitTesting(false)

            // 4) Bord extérieur : lumière bord haut + ombre bord bas
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            CommerceStatsSculptedPalette.specularRim,
                            CommerceStatsSculptedPalette.specularDim,
                            Color.white.opacity(0.02),
                            CommerceStatsSculptedPalette.outerRimShade,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.65
                )
                .allowsHitTesting(false)

            // 5) Chanfrein intérieur (1 pt vers l’intérieur) : petit biseau
            RoundedRectangle(cornerRadius: max(2, cornerRadius - 1.3), style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [CommerceStatsSculptedPalette.innerTopHighlight, Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: 0.9
                )
                .padding(1.1)
                .opacity(0.9)
            RoundedRectangle(cornerRadius: max(2, cornerRadius - 1.3), style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.clear, CommerceStatsSculptedPalette.innerBottomCrease],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.1
                )
                .padding(1.4)
                .opacity(0.65)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Ombres extérieures (relief de la feuille entière)

private func commerceStatsSculptedOuterShadows(pressed: Bool) -> (Color, CGFloat, CGFloat, CGFloat) {
    // Désactivé: les ombres externes peuvent rasteriser en boîte rectangulaire sur certaines compositions.
    (Color.clear, 0, 0, 0)
}

private func commerceStatsSculptedAmbientShadow(pressed: Bool) -> (Color, CGFloat, CGFloat, CGFloat) {
    // Désactivé: on garde le relief via les dégradés internes uniquement (sans débordement hors arrondi).
    (Color.clear, 0, 0, 0)
}

// MARK: - ButtonStyle

struct CommerceStatsSculpted3DKpiButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        let c = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return ZStack(alignment: .topLeading) {
            CommerceStatsSculpted3DSurface(cornerRadius: cornerRadius, pressed: c)
            configuration.label
        }
        .clipShape(shape)
        .contentShape(shape)
        .scaleEffect(c ? 0.965 : 1.0)
        .animation(.easeOut(duration: 0.11), value: c)
    }
}

// MARK: - Fond 3D statique (ZStack conteneur)

extension View {
    /// Fond 3D **statique** (ex. conteneur avec plusieurs `Button` internes).
    func commerceStatsSculpted3DStaticBackground(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return ZStack(alignment: .topLeading) {
            CommerceStatsSculpted3DSurface(cornerRadius: cornerRadius, pressed: false)
            self
        }
        .clipShape(shape)
        .contentShape(shape)
    }
}
