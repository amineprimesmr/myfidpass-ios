//
//  AppTheme.swift
//  myfidpass
//
//  Design system – couleurs, typographie, espacements.
//

import SwiftUI
import UIKit

enum AppTheme {
    // MARK: - Couleurs (adaptatives clair / sombre via UITraitCollection)
    enum Colors {
        static let primary = Color(hex: "2563EB")
        static let primaryDark = Color(hex: "1D4ED8")
        static let accent = Color(hex: "F59E0B")
        static let success = Color(hex: "10B981")
        static let warning = Color(hex: "F59E0B")
        static let error = Color(hex: "EF4444")

        /// Fond d’écran principal (hors dashboard « Revolut »).
        static var background: Color {
            Color(uiColor: UIColor { tc in
                switch tc.userInterfaceStyle {
                case .dark:
                    return UIColor(red: 0.07, green: 0.09, blue: 0.14, alpha: 1)
                default:
                    return UIColor(red: 0.973, green: 0.980, blue: 0.988, alpha: 1)
                }
            })
        }

        static var cardBackground: Color {
            Color(uiColor: UIColor { tc in
                switch tc.userInterfaceStyle {
                case .dark:
                    return UIColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1)
                default:
                    return UIColor.systemBackground
                }
            })
        }

        static var textPrimary: Color { Color(uiColor: .label) }
        static var textSecondary: Color { Color(uiColor: .secondaryLabel) }

        static var shadow: Color {
            Color(uiColor: UIColor { tc in
                switch tc.userInterfaceStyle {
                case .dark:
                    return UIColor.black.withAlphaComponent(0.45)
                default:
                    return UIColor.black.withAlphaComponent(0.08)
                }
            })
        }
    }

    // MARK: - Carte Wallet (PassKit / Ma carte — défauts nouveaux comptes)
    /// Hex **sans** `#`, aligné sur `CardTemplate.primaryColorHex` / API.
    enum WalletCardAppearanceDefaults {
        /// Fond carte (`background_color`).
        static let backgroundHex = "FFFFFF"
        /// Titres / libellés (`label_color`) — contraste avec le fond blanc et avec les pastilles « Configurer ».
        static let labelTitlesHex = "000000"
        /// Textes de valeur et liens (`foreground_color`).
        static let bodyTextHex = "2563EB"
        /// Accent pastilles / emphase (`Colors.accent`) — hex sans `#` pour previews et DTO.
        static let accentHex = "F59E0B"
    }

    // MARK: - Typographie
    /// SF Pro (design **default**) — aligné sur les apps système Apple ; Dynamic Type respecté via styles textuels.
    enum Fonts {
        static func largeTitle() -> Font { .system(.largeTitle, design: .default, weight: .bold) }
        static func title() -> Font { .system(.title, design: .default, weight: .semibold) }
        static func title2() -> Font { .system(.title2, design: .default, weight: .semibold) }
        static func title3() -> Font { .system(.title3, design: .default, weight: .medium) }
        static func headline() -> Font { .system(.headline, design: .default, weight: .semibold) }
        static func subheadline() -> Font { .system(.subheadline, design: .default, weight: .regular) }
        static func body() -> Font { .system(.body, design: .default, weight: .regular) }
        static func callout() -> Font { .system(.callout, design: .default, weight: .regular) }
        static func caption() -> Font { .system(.caption, design: .default, weight: .regular) }
        static func caption2() -> Font { .system(.caption2, design: .default, weight: .regular) }
    }

    // MARK: - Espacements
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Rayons
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 999
    }

    // MARK: - Écran (sans UIScreen.main, déprécié iOS 26)
    enum DisplayMetrics {
        /// Échelle pour raster (QR, etc.) — préféré à `UIScreen.main.scale`.
        static var displayScale: CGFloat {
            UITraitCollection.current.displayScale
        }

        /// Hauteur du `UIScreen` associé à la scène au premier plan (aperçus qui dépendent de la taille « téléphone »).
        static var activeScreenHeight: CGFloat {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            if let s = scenes.first(where: { $0.activationState == .foregroundActive }) {
                return s.screen.bounds.height
            }
            return scenes.first?.screen.bounds.height ?? 844
        }
    }

    // MARK: - Aperçus carte (Wallet / tampons)
    /// Métriques communes pour que textes et QR restent proportionnels à la largeur réelle de la carte (tous iPhone, Dynamic Type).
    enum CardPreviewLayout {
        static let referenceWidth: CGFloat = 375

        static func widthScale(cardWidth: CGFloat) -> CGFloat {
            min(1.08, max(0.72, cardWidth / referenceWidth))
        }

        /// Côté affiché du QR (points) — plafonné pour ne pas écraser la carte sur petit écran.
        static func qrDisplaySide(cardWidth: CGFloat, compact: Bool) -> CGFloat {
            let cap: CGFloat = compact ? 92 : 128
            let floor: CGFloat = compact ? 62 : 70
            let ratio: CGFloat = compact ? 0.24 : 0.30
            return min(cap, max(floor, cardWidth * ratio))
        }

        static func scaledFont(base: CGFloat, cardWidth: CGFloat, minSize: CGFloat = 9) -> CGFloat {
            let v = base * widthScale(cardWidth: cardWidth)
            return max(minSize, (v * 2).rounded() / 2)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// true si la couleur est sombre (pour adapter le contraste du QR : blanc sur fond sombre, noir sur fond clair).
    /// Résolution en mode clair pour éviter les faux positifs sur des hex fixes (aperçu carte).
    var isDark: Bool {
        let ui = UIColor(self)
        let traits = UITraitCollection(userInterfaceStyle: .light)
        let resolved = ui.resolvedColor(with: traits)
        guard let cg = resolved.cgColor.components, cg.count >= 3 else { return true }
        let r = cg[0], g = cg[1], b = cg[2]
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance < 0.5
    }

    /// Couleur de texte lisible sur `background` (aperçu Ma carte / Wallet : évite texte noir sur fond bleu nuit).
    func passForegroundReadable(on background: Color) -> Color {
        if background.isDark && self.isDark { return .white }
        if !background.isDark && !self.isDark { return Color.black.opacity(0.88) }
        return self
    }

    /// Hex `#RRGGBB` pour champs texte / API (aligné SaaS `personnaliserBgHex`).
    func toHexRGBString() -> String {
        let u = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        u.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }
}

// MARK: - Clavier logiciel (ex. masquer la pastille d’essai 1 €)

private struct IsSoftwareKeyboardVisibleKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// `true` quand le clavier logiciel iOS est affiché (texte, pas le clavier matériel seul).
    var isSoftwareKeyboardVisible: Bool {
        get { self[IsSoftwareKeyboardVisibleKey.self] }
        set { self[IsSoftwareKeyboardVisibleKey.self] = newValue }
    }
}

// MARK: - Feuilles modales (sans barre de navigation système)

extension View {
    /// Masque la barre de navigation dans une sheet (évite la bande grise + boutons dans la toolbar système).
    func sheetHideNavigationBar() -> some View {
        self
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    func sheetHideNavigationBar(_ hidden: Bool) -> some View {
        if hidden {
            self.sheetHideNavigationBar()
        } else {
            self
        }
    }
}

/// Bouton de fermeture en haut de feuille, hors toolbar système (à placer dans le contenu).
struct SheetDismissBar: View {
    var label: String = "Fermer"
    var action: () -> Void

    var body: some View {
        HStack {
            if #available(iOS 26.0, *) {
                Button(label, action: action)
                    .buttonStyle(.glass(.regular))
                    .buttonBorderShape(.capsule)
                    .controlSize(.regular)
            } else {
                Button(label, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
            }
            Spacer(minLength: 0)
        }
    }
}
