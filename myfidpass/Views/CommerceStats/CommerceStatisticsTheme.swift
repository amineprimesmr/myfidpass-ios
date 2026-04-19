//
//  CommerceStatisticsTheme.swift
//  myfidpass
//
//  Palette type Revolut / iOS sombre pour la page statistiques Commerce.
//

import SwiftUI

enum CommerceStatisticsTheme {
    static let background = Color.black
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
}
