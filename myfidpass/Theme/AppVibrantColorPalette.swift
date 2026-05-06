//
//  AppVibrantColorPalette.swift
//  myfidpass
//
//  Palette unique (neutres + teintes vives) : même liste que la section *Roue* du flyer
//  et pour tous les choix de couleur de l’app.
//

import Foundation

/// Pastilles unifiées — partout (carte, catégories, champs couleur, roue flyer).
enum AppVibrantColorPalette {
    /// Hex 6 **sans** `#` (API / PassKit / stockage) — **identique** à `flyerWheelAccentHex6`.
    static let hex6: [String] = [
        "000000",
        "F5F5F7",
        "FFFFFF",
        "FF0066", "FF1744", "FF3D00", "FF6D00", "FFAB00", "FFEA00", "CCFF00", "00FF9D", "00E5FF",
        "00B0FF", "3D5AFE", "651FFF", "D500F9", "FF00A8", "C51162", "D50000", "E65100", "F57F17",
        "7CB342", "00BFA5", "0091EA", "304FFE", "AA00FF"
    ]

    /// Même contenu que `hex6` (section *Roue* du hub flyer).
    static var flyerWheelAccentHex6: [String] { hex6 }

    /// Repli quand une valeur hex est invalide (bleu présent dans la grille).
    static let defaultHex6 = "304FFE"

    /// Identifiant + hex pour `ForEach` (scroll type Canva).
    static let scrollSwatches: [(id: String, hex: String)] = hex6.enumerated().map { ("p\($0.offset + 1)", $0.element) }

    /// Noms affichés sous les pastilles (écran *Ma carte* et lieux similaires).
    static let cardRowPresets: [(name: String, hex: String)] = [
        ("Noir", "000000"), ("Gris clair", "F5F5F7"), ("Blanc", "FFFFFF"),
        ("Magenta", "FF0066"), ("Rouge vif", "FF1744"), ("Orange brûlé", "FF3D00"), ("Orange", "FF6D00"), ("Ambre", "FFAB00"), ("Jaune", "FFEA00"), ("Citron", "CCFF00"),
        ("Menthe", "00FF9D"), ("Cyan", "00E5FF"), ("Azur", "00B0FF"), ("Indigo", "3D5AFE"), ("Violet", "651FFF"), ("Pourpre", "D500F9"), ("Rose néon", "FF00A8"), ("Framboise", "C51162"), ("Rouge", "D50000"), ("Feu", "E65100"), ("Moutarde", "F57F17"),
        ("Vert", "7CB342"), ("Turquoise", "00BFA5"), ("Bleu", "0091EA"), ("Bleu roi", "304FFE"), ("Violet vif", "AA00FF")
    ]

    static func containsHex6(_ raw: String) -> Bool {
        let n = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "").uppercased()
        return hex6.contains(n)
    }
}
