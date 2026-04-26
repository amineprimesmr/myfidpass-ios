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

    /// Titres sous « Outils d'analyse » (« Votre commerce ce mois », « Plus de données »…) : **SF Pro** pour un gras réel (Inter seul = pas de vrai bold).
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
    static let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let accentPurple = Color(red: 0.69, green: 0.32, blue: 0.87)
    static let accentPink = Color(red: 1.0, green: 0.18, blue: 0.57)
    static let accentTeal = Color(red: 0.35, green: 0.78, blue: 0.98)
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

    static func onCardPrimary(forGlassOverlay _: Bool) -> Color {
        Color.white
    }

    static func onCardSecondary(forGlassOverlay _: Bool) -> Color {
        secondaryLabel
    }

    /// Titres des tuiles KPI (Membres, Panier moyen, Fréquence…) : même style partout, un peu plus lisible que le libellé secondaire générique.
    static func kpiTileTitleFont() -> Font {
        statsText(size: 14, weight: .semibold)
    }

    static func kpiTileTitleForeground(forGlassOverlay g: Bool) -> Color {
        if g {
            return Color.white.opacity(0.92)
        }
        return Color(red: 0.7, green: 0.7, blue: 0.72)
    }

    static func pageTitle(forGlassOverlay _: Bool) -> Color {
        Color.white
    }

    static func subtleBorder(forGlassOverlay _: Bool) -> Color {
        Color.white.opacity(0.07)
    }

    static func neutralChartAccent(forGlassOverlay _: Bool) -> Color {
        accentBlue
    }
}
