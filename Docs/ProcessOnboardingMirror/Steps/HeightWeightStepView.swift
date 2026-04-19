//
//  HeightWeightStepView.swift
//  Process
//
//  Page de sélection de la taille et du poids avec 2 sliders horizontaux
//

import SwiftUI
import FirebaseAuth

struct HeightWeightStepView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @StateObject private var hapticManager = HapticManager.shared

    @Binding var selectedHeight: Double  // en cm
    @Binding var selectedWeight: Double  // en kg
    @State private var lastHapticHeight: Int = -1 // ✅ Dernière taille entière utilisée pour la vibration
    @State private var lastHapticWeight: Int = -1 // ✅ Dernier poids entier utilisé pour la vibration

    var onValidationChanged: ((Bool) -> Void)?
    var onBack: (() -> Void)?

    private let minHeight: Double = 140  // 140 cm (1m40)
    private let maxHeight: Double = 200  // 200 cm (2m)
    private let minWeight: Double = 40   // 40 kg
    private let maxWeight: Double = 130  // 130 kg

    var body: some View {
        ZStack {
            // ✅ Le fond noir et la lueur animée sont gérés par OnboardingView

            VStack(spacing: 0) {
                // Espace pour le titre en overlay
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                // Espacement entre titre et contenu
                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing + 40)

                // ✅ Section Taille - Simple et propre
                VStack(spacing: 16) {
                    // Bouton "Taille" au-dessus du slider
                Button(action: {}) {
                        HStack(spacing: 6) {
                        Text("\(Int(selectedHeight) / 100)")
                                .font(.system(size: 28, weight: .bold)) // ✅ Taille augmentée
                            .contentTransition(.numericText())

                        Text("m")
                                .font(.system(size: 18, weight: .medium)) // ✅ Taille augmentée

                        Text("\(Int(selectedHeight) % 100)")
                                .font(.system(size: 28, weight: .bold)) // ✅ Taille augmentée
                            .contentTransition(.numericText())
                        }
                        .foregroundColor(.white.opacity(1.0)) // ✅ Blanc 100%
                        .frame(maxWidth: .infinity)
                        .frame(height: 65) // ✅ Hauteur augmentée
                    }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 20))
                .controlSize(.large)
                    .disabled(true)

                    // Slider natif avec style glass
                    Slider(value: $selectedHeight, in: minHeight...maxHeight, step: 1)
                        .tint(.white)
                        .onChange(of: selectedHeight) { _, newValue in
                            // ✅ Vibration uniquement lors du changement de cm entier
                            let currentHeightCm = Int(newValue)
                            if currentHeightCm != lastHapticHeight {
                                lastHapticHeight = currentHeightCm
                                hapticManager.selection()
                            }
                            onValidationChanged?(true)
                            Task {
                                await saveHeightWeight()
                            }
                        }
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 40)

                // Espacement entre les deux sections
            Spacer()
                    .frame(height: 50)

                // ✅ Section Poids - Simple et propre
                VStack(spacing: 16) {
                    // Bouton "Poids" au-dessus du slider
                Button(action: {}) {
                        HStack(spacing: 6) {
                        Text("\(Int(selectedWeight))")
                                .font(.system(size: 28, weight: .bold)) // ✅ Taille augmentée
                            .contentTransition(.numericText())

                        Text("kg")
                                .font(.system(size: 18, weight: .medium)) // ✅ Taille augmentée
                        }
                        .foregroundColor(.white.opacity(1.0)) // ✅ Blanc 100%
                        .frame(maxWidth: .infinity)
                        .frame(height: 65) // ✅ Hauteur augmentée
                    }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 20))
                .controlSize(.large)
                    .disabled(true)

                    // Slider natif avec style glass
                    Slider(value: $selectedWeight, in: minWeight...maxWeight, step: 0.5)
                        .tint(.white)
                        .onChange(of: selectedWeight) { _, newValue in
                            // ✅ Vibration uniquement lors du changement de kg entier (60→61→62)
                            let currentWeightKg = Int(newValue)
                            if currentWeightKg != lastHapticWeight {
                                lastHapticWeight = currentWeightKg
                                hapticManager.selection()
                            }
                            onValidationChanged?(true)
                            Task {
                                await saveHeightWeight()
                            }
                        }
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 40)

            Spacer()
            }

            // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
            VStack {
                OnboardingTitleView("Quelle est ta taille et ton", "poids ?")
                    .padding(.top, OnboardingConstants.titleTopPadding)
                Spacer()
            }
        }
        .onAppear {
            // Charger les valeurs existantes si disponibles
            if let profile = profileService.currentProfile {
                if profile.height > 0 {
                    selectedHeight = profile.height
                }
                if profile.weight > 0 {
                    selectedWeight = profile.weight
                }
            }
            // ✅ Initialiser les dernières valeurs pour éviter les vibrations inutiles
            lastHapticHeight = Int(selectedHeight)
            lastHapticWeight = Int(selectedWeight)
            // Valider par défaut
            onValidationChanged?(true)
        }
    }

    private func saveHeightWeight() async {
        guard var profile = profileService.currentProfile else {
            // Si pas de profil, créer un profil temporaire
            if let userId = Auth.auth().currentUser?.uid {
                let tempProfile = UnifiedUserProfile(
                    userId: userId,
                    firstName: "Utilisateur",
                    birthDate: Date(),
                    gender: .male,
                    height: selectedHeight,
                    weight: selectedWeight
                )
                do {
                    try await profileService.saveProfile(tempProfile)
                    Logger.debug("Taille et poids sauvegardés: \(Int(selectedHeight))cm, \(Int(selectedWeight))kg", category: "Onboarding")
                } catch {
                    Logger.error("Erreur sauvegarde taille/poids: \(error)", category: "Onboarding")
                }
            }
            return
        }

        // Mettre à jour le profil existant
        profile.height = selectedHeight
        profile.weight = selectedWeight

        do {
            try await profileService.saveProfile(profile)
            Logger.debug("Taille et poids sauvegardés: \(Int(selectedHeight))cm, \(Int(selectedWeight))kg", category: "Onboarding")
        } catch {
            Logger.error("Erreur sauvegarde taille/poids: \(error)", category: "Onboarding")
        }
}
}
