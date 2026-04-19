//
//  HasSportActivityStepView.swift
//  Process
//
//  Page : Pratiques-tu une activité sportive ? (Oui/Non)
//

import SwiftUI

struct HasSportActivityStepView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @Binding var hasSportActivity: Bool?

    var onValidationChanged: ((Bool) -> Void)?

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
                        hasSportActivity = true
                        onValidationChanged?(true)

                        // Sauvegarder
                        Task {
                            if var profile = profileService.currentProfile {
                                // On peut stocker cette info dans le profil si nécessaire
                                try? await profileService.saveProfile(profile)
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            Text("Oui")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Spacer()

                            if hasSportActivity == true {
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
                    .opacity(hasSportActivity == true ? 1.0 : 0.6)

                    // Bouton Non
                    Button(action: {
                        HapticManager.shared.selection()
                        hasSportActivity = false
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

                            if hasSportActivity == false {
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
                    .opacity(hasSportActivity == false ? 1.0 : 0.6)
                }
                .padding(.horizontal, 40)

                Spacer()
            }

            // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
            VStack {
                OnboardingTitleView("Pratiques-tu une", "activité sportive actuellement ?")
                    .padding(.top, OnboardingConstants.titleTopPadding)
                Spacer()
            }

        }
        .onAppear {
            // ✅ CRITIQUE: Ne pas valider immédiatement - attendre que l'utilisateur sélectionne une réponse
            onValidationChanged?(false)

            // Charger la valeur existante si disponible
            // Si une valeur existe déjà, valider
            if hasSportActivity != nil {
                onValidationChanged?(true)
            }
        }
}
}
