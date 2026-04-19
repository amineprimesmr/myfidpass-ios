//
//  LanguageSelectorView.swift
//  Process
//
//  Sélecteur de langue avec style Liquid Glass pour l'onboarding
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

// MARK: - Vue de sélection de langue
struct LanguageSelectorView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @State private var currentLanguage: String = "fr"

    var body: some View {
        // ✅ Menu natif iOS avec les mêmes fonctions
        Menu {
            ForEach(SupportedLanguage.allCases) { language in
                Button(action: {
                    HapticManager.shared.selection()
                    currentLanguage = language.rawValue
                    Task {
                        await saveLanguage(language.rawValue)
                    }
                }) {
                    Label {
                        Text(language.displayName)
                    } icon: {
                        Text(language.flag)
                    }
                }
            }
        } label: {
            // Bouton avec le drapeau de la langue actuelle
            Text(currentLanguageFlag)
                .font(.system(size: 18))
                .frame(width: 34, height: 34)
        }
        .glassStyle()
        .buttonBorderShape(.circle)
        .onAppear {
            // Charger la langue actuelle depuis les préférences
            if let profile = profileService.currentProfile {
                currentLanguage = profile.preferences.language
            }
        }
        .onChange(of: profileService.currentProfile?.preferences.language) { _, newValue in
            if let newLanguage = newValue {
                currentLanguage = newLanguage
            }
        }
    }

    private var currentLanguageFlag: String {
        SupportedLanguage.allCases.first(where: { $0.rawValue == currentLanguage })?.flag ?? "🇫🇷"
    }

    private func saveLanguage(_ languageCode: String) async {
        guard var profile = profileService.currentProfile else {
            // Si pas de profil, sauvegarder dans UserDefaults temporairement
            UserDefaults.standard.set(languageCode, forKey: "selectedLanguage")
            return
        }

        var preferences = profile.preferences
        preferences.language = languageCode

        do {
            try await profileService.updatePreferences(preferences)
            Logger.debug("Langue mise à jour: \(languageCode)", category: "Onboarding")
        } catch {
            Logger.error("Erreur sauvegarde langue: \(error)", category: "Onboarding")
        }
}
}
