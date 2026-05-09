//
//  AppVibrantColorPalette.swift
//  myfidpass
//
//  Palette unique (neutres + teintes vives) : même liste que la section *Roue* du flyer
//  et pour tous les choix de couleur de l’app.
//

import Foundation
import UIKit

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

    /// Neutres exclus du **carrousel** d’édition flyer (Couleur du fond / CADEAU) — pas de noir / gris clair / blanc.
    private static let flyerCarouselExcludedHex6: Set<String> = ["000000", "F5F5F7", "FFFFFF"]

    /// Pastilles carrousel « Modifier le flyer » : teintes seulement, ordre **cercle chromatique** (plus de bloc « dégradé luminance » ni doublons rouge/orange dispersés).
    static var flyerCarouselHex6: [String] {
        let chroma = hex6.filter { !flyerCarouselExcludedHex6.contains($0) }
        return chroma.sorted {
            Self.hueSortKey6($0) < Self.hueSortKey6($1)
        }
    }

    /// Clé de tri teinte (HSV) — partagée avec les pastilles « extraites » quand activées.
    static func flyerHueSortKey6(_ raw: String) -> Double {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard t.count == 6,
              let r = Int(t.prefix(2), radix: 16),
              let g = Int(t.dropFirst(2).prefix(2), radix: 16),
              let b = Int(t.suffix(2), radix: 16) else { return 0 }
        let color = UIColor(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: 1
        )
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b2: CGFloat = 0
        var a: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b2, alpha: &a)
        if s < 0.08 { return 1.0 + Double(b2) * 0.001 }
        return Double(h)
    }

    /// 0…1 — pour tri HSV (teinte).
    private static func hueSortKey6(_ raw: String) -> Double {
        flyerHueSortKey6(raw)
    }

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

    /// Grille dense HSB (onglet « grille » uniquement — pas de spectre / curseurs système).
    /// Beaucoup d’échantillons, ordre **cercle chromatique** puis dégradé *saturation ↓* puis *luminosité ↓* (même logique visuelle que le carrousel).
    static let precisionPickerGridHex6: [String] = {
        var seen = Set<String>()
        /// Tri sur les coordonnées **demandées** (H/S/B de boucle), pas sur `getHue` post-conversion — ordre stable et lisible.
        var ordered: [(h: CGFloat, s: CGFloat, b: CGFloat, hex: String)] = []
        /// 48 pas ≈ 7,5° — ruban fin sur le cercle.
        let hueCount = 48
        /// Du quasi-gris au plein : progression régulière (plus de nuances « pastel »).
        let sats: [CGFloat] = [
            0.10, 0.16, 0.24, 0.32, 0.40, 0.48, 0.56, 0.64, 0.72, 0.80, 0.88, 0.93, 0.97, 1.0
        ]
        /// Du soutenu au très lumineux.
        let bris: [CGFloat] = [
            0.44, 0.50, 0.56, 0.62, 0.68, 0.74, 0.79, 0.84, 0.88, 0.91, 0.94, 0.97, 1.0
        ]
        for hi in 0..<hueCount {
            let hIn = CGFloat(hi) / CGFloat(hueCount)
            for s in sats {
                for bIn in bris {
                    let ui = UIColor(hue: hIn, saturation: s, brightness: bIn, alpha: 1)
                    var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, a: CGFloat = 0
                    ui.getRed(&r, green: &g, blue: &bl, alpha: &a)
                    let hx = String(
                        format: "%02X%02X%02X",
                        Int(round(r * 255)),
                        Int(round(g * 255)),
                        Int(round(bl * 255))
                    )
                    guard seen.insert(hx).inserted else { continue }
                    ordered.append((hIn, s, bIn, hx))
                }
            }
        }
        ordered.sort {
            if abs($0.h - $1.h) > 0.00001 { return $0.h < $1.h }
            if abs($0.s - $1.s) > 0.00001 { return $0.s > $1.s }
            return $0.b > $1.b
        }
        return ordered.map(\.hex)
    }()
}
