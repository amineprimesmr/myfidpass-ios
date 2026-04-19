//
//  ExperienceLevelStepView.swift
//  Process
//
//  Sélection niveau d'expérience
//

import SwiftUI

struct ExperienceLevelStepView: View {
    @Binding var selectedLevel: ExperienceLevel?
    var onValidationChanged: ((Bool) -> Void)?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Espace pour le titre en overlay + espacement uniforme
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                    // Espacement uniforme entre titre et réponses
                    Spacer()
                        .frame(height: OnboardingConstants.titleToContentSpacing)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(ExperienceLevel.allCases.filter { $0 != .intermediaire }, id: \.self) { level in
                        Button(action: {
                            HapticManager.shared.selection()
                            selectedLevel = level
                            onValidationChanged?(true)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: level.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(selectedLevel == level ? .blue : .white.opacity(0.7))

                                Text(level.rawValue)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Spacer()

                                if selectedLevel == level {
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
                        .opacity(selectedLevel == level ? 1.0 : 0.6)
                    }
                }
                .padding(.horizontal, 40)
            }
            .frame(maxHeight: 400)
            }

            // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
            VStack {
                OnboardingTitleView("Ton niveau", "d'expérience ?")
                    .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal)
                Spacer()
            }

            // ✅ Fond noir progressif en bas pour belle UX (dégradé fluide)
            VStack {
                Spacer()

                // Gradient progressif pour effet de transition fluide
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.6),
                        Color.black.opacity(0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)
            }
}
}
}
