//
//  AppTheme.swift
//  myfidpass
//
//  Design system – couleurs, typographie, espacements.
//

import SwiftUI

enum AppTheme {
    // MARK: - Couleurs
    enum Colors {
        static let primary = Color(hex: "2563EB")      // Bleu
        static let primaryDark = Color(hex: "1D4ED8")
        static let accent = Color(hex: "F59E0B")       // Ambre
        static let background = Color(hex: "F8FAFC")
        static let cardBackground = Color.white
        static let textPrimary = Color(hex: "0F172A")
        static let textSecondary = Color(hex: "64748B")
        static let success = Color(hex: "10B981")
        static let warning = Color(hex: "F59E0B")
        static let error = Color(hex: "EF4444")
        static let shadow = Color.black.opacity(0.06)
    }

    // MARK: - Typographie
    enum Fonts {
        static func largeTitle() -> Font { .system(.largeTitle, design: .rounded, weight: .bold) }
        static func title() -> Font { .system(.title, design: .rounded, weight: .semibold) }
        static func title2() -> Font { .system(.title2, design: .rounded, weight: .semibold) }
        static func title3() -> Font { .system(.title3, design: .rounded, weight: .medium) }
        static func headline() -> Font { .system(.headline, design: .rounded, weight: .semibold) }
        static func subheadline() -> Font { .system(.subheadline, design: .default, weight: .regular) }
        static func body() -> Font { .system(.body, design: .default, weight: .regular) }
        static func callout() -> Font { .system(.callout, design: .default, weight: .regular) }
        static func caption() -> Font { .system(.caption, design: .default, weight: .regular) }
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
}
