//
//  WeightFailureReasonsStepView.swift
//  Process
//
//  Vue pour identifier ce qui a empêché l'utilisateur de réussir à perdre/prendre du poids
//

import SwiftUI

struct WeightFailureReasonsStepView: View {
    @Binding var selectedReasons: Set<NutritionObstacle>
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
                    // Espace pour le titre en overlay
                    Spacer()
                        .frame(height: OnboardingConstants.titleAreaHeight)

                    // Espacement uniforme entre titre et réponses
                    Spacer()
                        .frame(height: OnboardingConstants.titleToContentSpacing)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            // ✅ Filtrer "Aucun obstacle" de la liste car ce n'est pas pertinent ici
                            ForEach(NutritionObstacle.allCases.filter { $0 != .noObstacle }) { obstacle in
                                Button(action: {
                                    HapticManager.shared.selection()

                                    if selectedReasons.contains(obstacle) {
                                        selectedReasons.remove(obstacle)
                                    } else {
                                        selectedReasons.insert(obstacle)
                                    }

                                    onValidationChanged?(!selectedReasons.isEmpty)
                                }) {
                                    HStack(spacing: 12) {
                                        Text(obstacle.rawValue)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Spacer()

                                        if selectedReasons.contains(obstacle) {
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
                                .opacity(selectedReasons.contains(obstacle) ? 1.0 : 0.6)
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
                    OnboardingTitleView("Qu'est-ce qui t'a", "empêché de réussir ?")
                        .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal)
                    Spacer()
                }
            }
        }
        .onAppear {
            onValidationChanged?(!selectedReasons.isEmpty)
        }
}
}
