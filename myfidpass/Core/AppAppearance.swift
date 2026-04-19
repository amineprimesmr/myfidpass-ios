//
//  AppAppearance.swift
//  myfidpass
//
//  Préférence d’affichage (clair / sombre / système). L’app est actuellement forcée en mode clair
//  (`myfidpassApp` + Info.plist) ; ce module sert à réactiver le choix utilisateur plus tard.
//

import SwiftUI

enum AppAppearance {
    static let storageKey = "myfidpass.settings.appearance"
    static let light = "light"
    static let dark = "dark"
    static let system = "system"

    static func colorScheme(for raw: String) -> ColorScheme? {
        switch raw {
        case dark: return .dark
        case system: return nil
        default: return .light
        }
    }
}
