//
//  WeightGoalStepView.swift
//  Process
//
//  Étape onboarding : Objectif de poids
//

import SwiftUI

enum WeightGoal: String, CaseIterable, Codable {
    case lose = "Perdre du poids"
    case gain = "Prendre du poids"

    var icon: String {
        switch self {
        case .lose: return "arrow.down.circle.fill"
        case .gain: return "arrow.up.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .lose: return "Réduire ton poids de manière saine"
        case .gain: return "Augmenter ton poids (masse musculaire)"
        }
    }
}

struct WeightGoalStepView: View {
    @Binding var selectedGoal: WeightGoal?
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
                VStack(spacing: 12) {
                    // Espacement uniforme entre titre et réponses
                    Spacer()
                        .frame(height: OnboardingConstants.titleToContentSpacing)
                    ForEach(WeightGoal.allCases, id: \.self) { goal in
                        Button(action: {
                            HapticManager.shared.selection()
                            selectedGoal = goal
                            onValidationChanged?(true)
                        }) {
                            HStack(spacing: 12) {
                                Text(goal.rawValue)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Spacer()

                                if selectedGoal == goal {
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
                        .opacity(selectedGoal == goal ? 1.0 : 0.6)
                    }
                }
                .padding(.horizontal, 40)
            }
            .frame(maxHeight: 500)
            }

            // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
            VStack {
                OnboardingTitleView("Quel est ton", "objectif de poids ?")
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
