//
//  WeightManagementExperienceStepView.swift
//  Process
//
//  Vue pour l'expérience avec la perte/prise de poids
//

import SwiftUI

struct WeightManagementExperienceStepView: View {
    @Binding var selectedExperience: WeightManagementExperience?
    var weightGoal: WeightGoal?  // Pour adapter le texte (perdre ou prendre)
    var onValidationChanged: ((Bool) -> Void)?

    private var actionText: String {
        guard let goal = weightGoal else { return "perdre ou prendre" }
        switch goal {
        case .lose:
            return "perdre"
        case .gain:
            return "prendre"
        default:
            return "perdre ou prendre"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Image de fond nutri
                Image("nutri")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)

                // ✅ Overlay très réduit pour permettre à la lueur d'être visible
                Color.black.opacity(0.1)
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    // Espace pour le titre en overlay (150pt)
                    Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                    // Espacement uniforme entre titre et réponses
                    Spacer()
                        .frame(height: OnboardingConstants.titleToContentSpacing)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(WeightManagementExperience.allCases) { experience in
                                Button(action: {
                                    HapticManager.shared.selection()
                                    selectedExperience = experience
                                    onValidationChanged?(true)
                                }) {
                                    HStack(spacing: 12) {
                                        Text(experience.rawValue)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)

                                        Spacer()

                                        if selectedExperience == experience {
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
                                .opacity(selectedExperience == experience ? 1.0 : 0.6)
                            }
                        }
                        .padding(.horizontal, 40)

                        // Espace pour le bouton en bas
                        Spacer()
                            .frame(height: 100)
                    }
                }

                // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
                VStack {
                    OnboardingTitleView("As-tu déjà", "essayé de \(actionText) du poids ?")
                        .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal) // Position ABSOLUE : 55pt depuis le haut
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
        .onAppear {
            onValidationChanged?(selectedExperience != nil)
        }
}
}
