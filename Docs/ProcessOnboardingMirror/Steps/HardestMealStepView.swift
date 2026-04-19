//
//  HardestMealStepView.swift
//
//  Vue pour demander à quel repas il est le plus difficile de manger sainement
//

import SwiftUI

struct HardestMealStepView: View {
    @Binding var selectedMeal: HardestMeal?
    var onValidationChanged: ((Bool) -> Void)?

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
                        VStack(spacing: 12) { // ✅ Harmonisé avec les autres pages (16 → 12)
                            ForEach(HardestMeal.allCases) { meal in
                                Button(action: {
                                    HapticManager.shared.selection()
                                    selectedMeal = meal
                                    onValidationChanged?(true)
                                }) {
                                    HStack(spacing: 12) {
                                        Text(meal.emoji)
                                            .font(.system(size: 20)) // ✅ Emoji plus petit (24 → 20)

                                        Text(meal.rawValue)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Spacer()

                                        if selectedMeal == meal {
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
                                .opacity(selectedMeal == meal ? 1.0 : 0.6)
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
                    OnboardingTitleView("À quel repas est-il", "le plus difficile de", "bien manger ?")
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
            if selectedMeal != nil {
                onValidationChanged?(true)
            }
}
}
}
