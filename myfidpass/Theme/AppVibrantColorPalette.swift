//
//  AppVibrantColorPalette.swift
//  myfidpass
//
//  Palette unique (neutres + terre/beige + teintes vives) : même liste que la section *Roue*
//  du flyer et pour tous les choix de couleur de l’app.
//

import Foundation
import UIKit

/// Pastilles unifiées — partout (carte, catégories, champs couleur, roue flyer).
enum AppVibrantColorPalette {
    /// Catalogue unique : ordre **neutres → terre/beige → cercle chromatique** (dégradé progressif par famille).
    private static let swatchCatalog: [(name: String, hex: String)] = [
        // Neutres (noir → blanc)
        ("Noir", "000000"), ("Graphite", "1C1C1E"), ("Anthracite", "3A3A3C"), ("Gris", "636366"),
        ("Gris moyen", "8E8E93"), ("Gris perle", "C7C7CC"), ("Gris clair", "F5F5F7"), ("Blanc", "FFFFFF"),
        // Terre, brun & beige (foncé → clair)
        ("Espresso", "1A120B"), ("Brun cacao", "3E2723"), ("Brun", "4E342E"), ("Marron", "5D4037"),
        ("Taupe foncé", "6D4C41"), ("Brun clair", "795548"), ("Taupe", "8D6E63"), ("Grège", "A1887F"),
        ("Grège clair", "BCAAA4"), ("Beige rosé", "D7CCC8"), ("Camel", "A67B5B"), ("Doré beige", "C9A66B"),
        ("Caramel", "DDB892"), ("Sable", "E8DCC8"), ("Crème", "F0E6D8"), ("Ivoire", "F5EBDD"), ("Blanc cassé", "FAF3E8"),
        // Rouge → rose
        ("Bordeaux", "4A0000"), ("Rouge sombre", "7F0000"), ("Grenat", "5C0011"), ("Rouge profond", "B71C1C"),
        ("Rouge brique", "C62828"), ("Rouge", "D50000"), ("Rouge vif", "E53935"), ("Rouge corail", "F44336"),
        ("Rouge éclat", "FF1744"), ("Magenta", "FF0066"), ("Framboise claire", "E91E63"), ("Rose", "FF4081"),
        ("Rose pâle", "FF80AB"), ("Rose bonbon", "F48FB1"), ("Rose néon", "FF00A8"), ("Rose blush", "FCE4EC"),
        // Corail, orange, pêche
        ("Terracotta", "BF360C"), ("Rouge orangé", "D84315"), ("Orange brûlé", "FF3D00"), ("Orange profond", "FF5722"),
        ("Corail", "FF7043"), ("Pêche", "FF8A65"), ("Feu", "E65100"), ("Orange", "FF6D00"),
        ("Orange clair", "FF9100"), ("Ambre", "FFAB00"), ("Ambre doré", "FFB300"), ("Mandarine", "FFA726"),
        ("Pêche claire", "FFCC80"), ("Abricot", "FFE0B2"),
        // Jaune → citron
        ("Moutarde", "F57F17"), ("Or", "F9A825"), ("Jaune doré", "FBC02D"), ("Jaune soleil", "FDD835"),
        ("Jaune miel", "FFE082"), ("Jaune", "FFEA00"), ("Jaune clair", "FFF176"), ("Jaune pâle", "FFF9C4"),
        ("Lime", "C6FF00"), ("Vert citron", "C0CA33"), ("Chartreuse", "CDDC39"), ("Citron", "CCFF00"),
        // Vert & olive
        ("Vert forêt", "1B5E20"), ("Vert sapin", "33691E"), ("Vert pin", "2E7D32"), ("Vert gazon", "388E3C"),
        ("Vert mousse", "558B2F"), ("Vert olive", "689F38"), ("Olive foncé", "827717"), ("Olive", "9E9D24"),
        ("Vert", "7CB342"), ("Vert pomme", "8BC34A"), ("Vert lime", "AEEA00"), ("Vert fluo", "64DD17"),
        ("Vert vif", "00C853"), ("Vert menthe", "00E676"), ("Menthe néon", "00FF9D"), ("Sauge", "C5E1A5"),
        ("Vert pastel", "A5D6A7"),
        // Teal → cyan
        ("Teal profond", "004D40"), ("Teal", "00695C"), ("Teal moyen", "00796B"), ("Turquoise", "00897B"),
        ("Sarcelle", "009688"), ("Turquoise vif", "00BFA5"), ("Teal clair", "26A69A"), ("Turquoise pastel", "4DB6AC"),
        ("Turquoise pâle", "80CBC4"), ("Cyan profond", "00ACC1"), ("Cyan", "00BCD4"), ("Cyan néon", "00E5FF"),
        ("Cyan clair", "18FFFF"), ("Cyan pastel", "4DD0E1"), ("Cyan brume", "B2EBF2"),
        // Bleu
        ("Bleu marine", "0D47A1"), ("Bleu profond", "1565C0"), ("Bleu nuit", "0D3B66"), ("Bleu", "1976D2"),
        ("Bleu royal", "1E88E5"), ("Bleu ciel", "2196F3"), ("Bleu vif", "0091EA"), ("Azur", "00B0FF"),
        ("Bleu clair", "42A5F5"), ("Bleu pastel", "64B5F6"), ("Bleu roi", "2979FF"), ("Bleu indigo", "304FFE"),
        ("Indigo", "3D5AFE"), ("Bleu gris", "7986CB"), ("Bleu brume", "9FA8DA"),
        // Indigo → violet
        ("Indigo nuit", "1A237E"), ("Indigo profond", "283593"), ("Violet profond", "311B92"), ("Violet royal", "4527A0"),
        ("Violet", "512DA8"), ("Violet vif", "651FFF"), ("Violet clair", "7C4DFF"), ("Prune", "673AB7"),
        ("Pourpre", "9C27B0"), ("Violet doux", "BA68C8"), ("Violet néon", "AA00FF"), ("Lilas clair", "CE93D8"),
        // Magenta
        ("Magenta profond", "4A148C"), ("Violet intense", "6A1B9A"), ("Mauve", "7B1FA2"), ("Orchidée", "8E24AA"),
        ("Lilas", "AB47BC"), ("Framboise", "C51162"), ("Fuchsia", "D500F9"), ("Magenta clair", "E040FB"),
        ("Lavande", "EA80FC"), ("Lavande brume", "F3E5F5"),
    ]

    /// Hex 6 **sans** `#` (API / PassKit / stockage).
    static let hex6: [String] = swatchCatalog.map(\.hex)

    /// Neutres exclus du **carrousel** d’édition flyer — pas de noir / gris / blanc / beiges très clairs.
    private static let flyerCarouselExcludedHex6: Set<String> = [
        "000000", "1C1C1E", "3A3A3C", "636366", "8E8E93", "C7C7CC", "F5F5F7", "FFFFFF",
        "F0E6D8", "F5EBDD", "FAF3E8", "FCE4EC", "FFF9C4", "FFE0B2", "B2EBF2", "F3E5F5",
    ]

    /// Pastilles carrousel « Modifier le flyer » : teintes seules, ordre **cercle chromatique**.
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
    static let cardRowPresets: [(name: String, hex: String)] = swatchCatalog

    static func containsHex6(_ raw: String) -> Bool {
        let n = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "").uppercased()
        return knownHex6Set.contains(n)
    }

    /// Grille dense HSB (onglet « grille » uniquement — pas de spectre / curseurs système).
    /// Beaucoup d’échantillons, ordre **cercle chromatique** puis dégradé *saturation ↓* puis *luminosité ↓*.
    static let precisionPickerGridHex6: [String] = {
        var seen = Set<String>()
        var ordered: [(h: CGFloat, s: CGFloat, b: CGFloat, hex: String)] = []
        /// 72 pas ≈ 5° — ruban chromatique très fin.
        let hueCount = 72
        /// Du quasi-gris au plein : progression régulière (beiges/teintes douces → vifs).
        let sats: [CGFloat] = [
            0.04, 0.07, 0.10, 0.13, 0.16, 0.19, 0.22, 0.25, 0.28, 0.31, 0.34, 0.37, 0.40, 0.43,
            0.46, 0.49, 0.52, 0.55, 0.58, 0.61, 0.64, 0.67, 0.70, 0.73, 0.76, 0.79, 0.82, 0.85,
            0.88, 0.91, 0.94, 0.97, 1.0,
        ]
        /// Du profond au très lumineux.
        let bris: [CGFloat] = [
            0.28, 0.32, 0.36, 0.40, 0.44, 0.48, 0.52, 0.56, 0.60, 0.64, 0.68, 0.72, 0.76,
            0.80, 0.84, 0.88, 0.91, 0.94, 0.97, 1.0,
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

    private static let knownHex6Set: Set<String> = Set(hex6).union(Set(precisionPickerGridHex6))
}
