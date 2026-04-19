//
//  LanguageSelectorView.swift
//  Process
//
//  Sélecteur de langue avec style Liquid Glass pour l'onboarding
//
//  Copie UI identique ; persistance locale (UserDefaults) au lieu de Firebase pour MyFidpass.
//

import SwiftUI

// MARK: - Langues supportées
enum SupportedLanguage: String, CaseIterable, Identifiable {
    case french = "fr"
    case english = "en"
    case spanish = "es"
    case german = "de"
    case italian = "it"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .french: return "Français"
        case .english: return "English"
        case .spanish: return "Español"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        }
    }

    var flag: String {
        switch self {
        case .french: return "🇫🇷"
        case .english: return "🇬🇧"
        case .spanish: return "🇪🇸"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        }
    }
}

// MARK: - Vue de sélection de langue (Process — même layout)
struct LanguageSelectorView: View {
    private static let udKey = "myfidpass.processOnboarding.language"

    @State private var currentLanguage: String = "fr"

    var body: some View {
        Menu {
            ForEach(SupportedLanguage.allCases) { language in
                Button(action: {
                    HapticManager.shared.selection()
                    currentLanguage = language.rawValue
                    UserDefaults.standard.set(language.rawValue, forKey: Self.udKey)
                }) {
                    Label {
                        Text(language.displayName)
                    } icon: {
                        Text(language.flag)
                    }
                }
            }
        } label: {
            Text(currentLanguageFlag)
                .font(.system(size: 18))
                .frame(width: 34, height: 34)
        }
        .glassStyle()
        .buttonBorderShape(.circle)
        .onAppear {
            if let saved = UserDefaults.standard.string(forKey: Self.udKey) {
                currentLanguage = saved
            }
        }
    }

    private var currentLanguageFlag: String {
        SupportedLanguage.allCases.first(where: { $0.rawValue == currentLanguage })?.flag ?? "🇫🇷"
    }
}
