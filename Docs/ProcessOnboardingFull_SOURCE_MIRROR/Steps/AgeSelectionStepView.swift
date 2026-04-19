//
//  AgeSelectionStepView.swift
//  Process
//
//  Page de sélection d'âge avec roulette scrollable ultra fluide
//

import SwiftUI

struct AgeSelectionStepView: View {
    @StateObject private var hapticManager = HapticManager.shared
    @Binding var selectedAge: Int
    @State private var hasLoadedInitialAge = false
    @State private var hasForcedDefault = false

    // Callback pour notifier la validation
    var onValidationChanged: ((Bool) -> Void)?

    private let minAge = 13
    private let maxAge = 100
    private let defaultAge = 25

    @EnvironmentObject var profileService: UnifiedProfileService

    var body: some View {
        ZStack {
            // Fond noir géré par OnboardingView

            VStack(spacing: 0) {
                // Espace pour le titre en overlay
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                // Espacement entre titre et contenu
                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing)

                // Contenu principal avec roulette uniquement
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 40) // Moins d'espace en haut pour remonter la roulette

                    // Roulette de sélection
                    AgeWheelPicker(
                        selectedAge: $selectedAge,
                        minAge: minAge,
                        maxAge: maxAge,
                        onAgeChanged: { newAge in
                            hapticManager.selection()
                            onValidationChanged?(true)

                            // Sauvegarder après un court délai
                            Task {
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                if selectedAge == newAge {
                                    await OnboardingProgressService.shared.saveAge(newAge, to: profileService)
                                }
                            }
                        }
                    )
                    .padding(.horizontal, 40)

                    Spacer()
                }
            }

            // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
            VStack {
                OnboardingTitleView("Quel est ton âge ?")
                    .padding(.top, OnboardingConstants.titleTopPadding)
                Spacer()
            }

        }
        .onAppear {
            // ✅ FORCER IMMÉDIATEMENT à 25 - SANS CONDITIONS
            // Ignorer complètement le profil au démarrage pour garantir 25
            if !hasForcedDefault {
                selectedAge = defaultAge
                onValidationChanged?(true)
                hasForcedDefault = true
            }
        }
        .onChange(of: selectedAge) { _, newValue in
            // ✅ PROTECTION: Si l'âge change vers une valeur suspecte, le forcer à 25
            let suspectAges: Set<Int> = [minAge, 13, 16, 21]
            if !hasForcedDefault && suspectAges.contains(newValue) {
                DispatchQueue.main.async {
                    selectedAge = defaultAge
                }
            }
        }
        .task {
            // ✅ Double vérification: Toujours forcer à 25 au démarrage
            // Ne JAMAIS charger depuis le profil pour éviter les valeurs erronées
            if !hasLoadedInitialAge {
                selectedAge = defaultAge
                onValidationChanged?(true)
                hasLoadedInitialAge = true
            }
        }
    }
}
