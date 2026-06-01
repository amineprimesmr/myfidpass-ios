//
//  SettingsVisualTheme.swift
//  myfidpass
//

import SwiftUI

struct SettingsVisualTheme {
    let colorScheme: ColorScheme
    var isDark: Bool { colorScheme == .dark }

    var noticeBG: Color {
        isDark ? Color.green.opacity(0.18) : AppTheme.Colors.success.opacity(0.12)
    }

    var accentPositive: Color {
        isDark ? Color.green.opacity(0.95) : AppTheme.Colors.success
    }
}
