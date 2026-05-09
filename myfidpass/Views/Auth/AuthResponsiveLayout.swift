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
}
