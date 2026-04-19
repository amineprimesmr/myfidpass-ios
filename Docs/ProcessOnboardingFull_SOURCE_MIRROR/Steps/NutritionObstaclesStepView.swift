//
//  NutritionObstaclesStepView.swift
//  Process
//
//  Vue pour identifier les obstacles à une bonne nutrition
//

import SwiftUI

struct NutritionObstaclesStepView: View {
    @Binding var selectedObstacles: Set<NutritionObstacle>
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

                    // Espacement uniforme entre titre et contenu
                    Spacer()
                        .frame(height: OnboardingConstants.titleToContentSpacing)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(NutritionObstacle.allCases) { obstacle in
                                Button(action: {
                                    HapticManager.shared.selection()

                                    if obstacle == .noObstacle {
                                        // Si "Aucun obstacle" est sélectionné, vider les autres
                                        selectedObstacles = [.noObstacle]
                                    } else {
                                        // Retirer "Aucun obstacle" si on sélectionne autre chose
                                        selectedObstacles.remove(.noObstacle)

                                        if selectedObstacles.contains(obstacle) {
                                            selectedObstacles.remove(obstacle)
                                        } else {
                                            selectedObstacles.insert(obstacle)
                                        }
                                    }

                                    onValidationChanged?(true)
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: obstacle.icon)
                                            .font(.system(size: 20))
                                            .foregroundColor(selectedObstacles.contains(obstacle) ? .orange : .white.opacity(0.7))

                                        Text(obstacle.rawValue)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Spacer()

                                        if selectedObstacles.contains(obstacle) {
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
                                .opacity(selectedObstacles.contains(obstacle) ? 1.0 : 0.6)
                            }
                        }
                        .padding(.horizontal, 40)

                        // Espace pour le bouton en bas
                        Spacer()
                            .frame(height: 100)
                    }
                }
            }

            // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
            VStack {
                OnboardingTitleView("Qu'est-ce qui", "t'empêche de bien manger ?")
                    .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal)
                Spacer()
            }
        }
        .onAppear {
            onValidationChanged?(true)
        }
}
}
