//
//  SportClubStepView.swift
//  Process
//
//  Page : Fais-tu de [sport] en club actuellement ? (Oui/Non)
//

import SwiftUI

struct SportClubStepView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @Binding var isInClub: Bool?

    let selectedSport: String  // Le sport sélectionné précédemment

    var onValidationChanged: ((Bool) -> Void)?
    var onBack: (() -> Void)?  // Callback pour le bouton retour

    // Extraire le nom du sport sans emoji
    private var sportName: String {
        // Enlever l'emoji et garder juste le texte
        let components = selectedSport.split(separator: " ")
        if components.count > 1 {
            return components.dropFirst().joined(separator: " ")
        }
        return selectedSport.replacingOccurrences(of: #"[^\w\s]"#, with: "", options: .regularExpression)
    }

    var body: some View {
        ZStack {
            // ✅ Le fond noir et la lueur animée sont gérés par OnboardingView

            VStack(spacing: 0) {
                // Espace pour le titre en overlay + espacement uniforme
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                // Espacement uniforme entre titre et contenu
                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing)

                // Boutons Oui/Non
                VStack(spacing: 20) {
                    Spacer()
                        .frame(height: OnboardingConstants.titleToContentSpacing)

                    // Bouton Oui
                    Button(action: {
                        HapticManager.shared.selection()
                        isInClub = true
                        onValidationChanged?(true)

                        // Sauvegarder
                        Task {
                            if var profile = profileService.currentProfile {
                                try? await profileService.saveProfile(profile)
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            Text("Oui")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Spacer()

                            if isInClub == true {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 20))
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.white.opacity(0.3))
                                    .font(.system(size: 20))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .glassStyle()
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .opacity(isInClub == true ? 1.0 : 0.6)

                    // Bouton Non
                    Button(action: {
                        HapticManager.shared.selection()
                        isInClub = false
                        onValidationChanged?(true)

                        // Sauvegarder
                        Task {
                            if var profile = profileService.currentProfile {
                                try? await profileService.saveProfile(profile)
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            Text("Non")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Spacer()

                            if isInClub == false {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 20))
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.white.opacity(0.3))
                                    .font(.system(size: 20))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .glassStyle()
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .opacity(isInClub == false ? 1.0 : 0.6)
                }
                .padding(.horizontal, 40)

                Spacer()
            }

            // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
            VStack {
                OnboardingTitleView("Pratiques-tu ce sport", "en club actuellement ?")
                    .padding(.top, OnboardingConstants.titleTopPadding)
                Spacer()
            }
        }
        .onAppear {
            // ✅ CRITIQUE: Ne pas valider immédiatement - attendre que l'utilisateur sélectionne une réponse
            onValidationChanged?(false)

            // Charger la valeur existante si disponible
            // Si une valeur existe déjà, valider
            if isInClub != nil {
                onValidationChanged?(true)
            }
        }
}
}
