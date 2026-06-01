//
//  AuthResponsiveLayout.swift
//  myfidpass
//
//  Règles communes pour auth / welcome : iPad et fenêtres larges utilisent un panneau
//  scindé afin d’éviter l’effet « mini téléphone au milieu d’océan de blanc ».
//

import SwiftUI

enum AuthResponsiveLayout {
    /// `true` pour iPad, iPhone paysage large, ou Stage Manager.
    static func useSplitAuthPanel(width: CGFloat, horizontalSizeClass: UserInterfaceSizeClass?) -> Bool {
        if width >= 700 { return true }
        return horizontalSizeClass == .regular
    }

    /// Largeur utile du bloc formulaire / boutons dans une colonne.
    static func authFormMaxWidth(containerWidth: CGFloat) -> CGFloat {
        min(480, max(280, containerWidth - 40))
    }

    static func heroWidthFractionSplit() -> CGFloat { 0.5 }

    // MARK: - Carrousel auth empilé (Connexion / Inscription, iPad portrait)

    /// Hauteur du carrousel : iPhone quasi plein écran ; iPad réduit mais lisible (~55 %).
    static func authStackedHeroHeightFraction(
        width: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> CGFloat {
        if horizontalSizeClass == .regular { return 0.55 }
        if width >= 600 { return 0.58 }
        return 0.82
    }

    /// Largeur du carrousel (centré sur grands écrans).
    static func authStackedHeroImageWidth(
        containerWidth: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> CGFloat {
        if horizontalSizeClass == .regular {
            return min(520, containerWidth * 0.68)
        }
        if containerWidth >= 600 {
            return min(480, containerWidth * 0.65)
        }
        return containerWidth
    }

    /// `true` → image entière visible (plus petite), pas de recadrage plein écran.
    static func authStackedHeroUsesContainedImage(
        width: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> Bool {
        horizontalSizeClass == .regular || width >= 600
    }

    /// Décalage vertical du carrousel sous la barre de statut (iPad).
    static func authStackedHeroTopPadding(
        width: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?,
        safeTop: CGFloat
    ) -> CGFloat {
        if horizontalSizeClass == .regular || width >= 600 {
            return max(safeTop, 44) + 4
        }
        return -8
    }

    /// Hauteur max du visuel welcome (iPhone) — un peu plus compact que le plein écran.
    static func welcomeHeroMaxHeightFraction(
        width: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> CGFloat {
        if horizontalSizeClass == .regular { return 0.58 }
        if width >= 600 { return 0.56 }
        return 0.62
    }
}
