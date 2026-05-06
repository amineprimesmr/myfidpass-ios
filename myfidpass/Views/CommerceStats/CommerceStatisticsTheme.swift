//
//  CommerceStatisticsTheme.swift
//  myfidpass
//
//  Palette type Revolut / iOS sombre pour la page statistiques Commerce.
//

import SwiftUI

enum CommerceStatisticsTheme {
    // MARK: - Typographie (SF Pro, design système — aligné sur les apps Apple)

    /// Texte courant de la page statistiques : **SF Pro** (pas de police custom).
    static func statsText(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    /// Titres sous « Outils d'analyse » (mois KPI, « Plus de données »…) : **SF Pro** pour un gras réel (Inter seul = pas de vrai bold).
    static func statsChromeSectionTitle(size: CGFloat = 18, weight: Font.Weight = .bold) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    /// Chiffres / montants : SF Pro **design par défaut** (formes droites, pas de variante « rounded » carte / arrondie).
    static func statisticNumbers(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    static let background = Color.black
    /// Feuille « Nouveaux membres » (liste membres) : fond #1C1C1E.
    static let newMembersSheetBackground = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
    static let card = Color(red: 0.11, green: 0.11, blue: 0.12) // ~ #1C1C1E
    static let cardElevated = Color(red: 0.17, green: 0.17, blue: 0.18) // ~ #2C2C2E
    static let secondaryLabel = Color(red: 0.56, green: 0.56, blue: 0.58) // ~ #8E8E93
    static let accentBlue = Color(red: 0.0, green: 0.39, blue: 0.85)
    static let accentPurple = Color(red: 0.69, green: 0.32, blue: 0.87)
    static let accentPink = Color(red: 1.0, green: 0.18, blue: 0.57)
    static let accentTeal = Color(red: 0.18, green: 0.62, blue: 0.78)
    /// Vert de référence des tendances KPI (aligné sur « +x nouveaux » de la carte Membres).
    static let kpiTrendPositiveGreen = Color(red: 0.18, green: 0.68, blue: 0.43)
    static let positive = Color(red: 0.19, green: 0.82, blue: 0.35)
    static let negative = Color(red: 1.0, green: 0.27, blue: 0.23)
    static let pillBackground = Color(red: 0.22, green: 0.22, blue: 0.24)

    static let segmentColors: [Color] = [
        Color(red: 0.0, green: 0.48, blue: 1.0),
        Color(red: 0.55, green: 0.36, blue: 0.97),
        Color(red: 0.25, green: 0.52, blue: 0.95),
        Color(red: 0.45, green: 0.45, blue: 0.48),
    ]

    // MARK: - Overlay plein écran (même palette sombre que la page stats hors feuille)

    static func cardSurface(forGlassOverlay _: Bool) -> Color {
        card
    }

    /// Fond `cardElevated` des tuiles **Membres / Panier / Fréquence** (cible ~un peu plus translucide que les listes).
    static let kpiClusterTileBackgroundOpacity: CGFloat = 0.86

    /// Cartes KPI (nouveaux membres, panier moyen, fréquence…) : overlay un peu translucide mais lisible ; plein écran bien opaque.
    static func kpiIndicatorCardBackground(forGlassOverlay g: Bool) -> Color {
        g ? cardElevated.opacity(kpiClusterTileBackgroundOpacity) : cardElevated.opacity(kpiClusterTileBackgroundOpacity)
    }

    static func onCardPrimary(forGlassOverlay g: Bool) -> Color {
        g ? Color.white : Color.black
    }

    static func onCardSecondary(forGlassOverlay g: Bool) -> Color {
        g ? secondaryLabel : Color.black.opacity(0.62)
    }

    /// Titres des tuiles KPI (Membres, Panier moyen, Fréquence…) : même style partout, un peu plus lisible que le libellé secondaire générique.
    static func kpiTileTitleFont() -> Font {
        statsText(size: 15, weight: .semibold)
    }

    static func kpiTileTitleGradient(forGlassOverlay g: Bool) -> LinearGradient {
        if g {
            return LinearGradient(
                colors: [
                    Color(red: 0.78, green: 0.78, blue: 0.8),
                    Color(red: 0.93, green: 0.93, blue: 0.95),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color.black.opacity(0.92),
                Color.black.opacity(0.78),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func kpiTileTitleForeground(forGlassOverlay g: Bool) -> Color {
        if g {
            return Color.white.opacity(0.92)
        }
        return Color.black.opacity(0.84)
    }

    static func pageTitle(forGlassOverlay g: Bool) -> Color {
        g ? Color.white : Color.black
    }

    static func subtleBorder(forGlassOverlay g: Bool) -> Color {
        g ? Color.white.opacity(0.07) : Color.black.opacity(0.09)
    }

    static func neutralChartAccent(forGlassOverlay _: Bool) -> Color {
        accentBlue
    }
}
