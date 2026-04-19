//
//  FatigueFrequencyStepView.swift
//  Process
//
//  Vue pour évaluer la fréquence de fatigue
//

import SwiftUI

struct FatigueFrequencyStepView: View {
    @Binding var selectedFrequency: FatigueFrequency?
    var onValidationChanged: ((Bool) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Image de fond Sleep
                Image("Sleep")
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
                        VStack(spacing: 16) {
                            ForEach(FatigueFrequency.allCases) { frequency in
                                Button(action: {
                                    HapticManager.shared.selection()
                                    selectedFrequency = frequency
                                    onValidationChanged?(true)
                                }) {
                                    HStack(spacing: 12) {
                                        Text(frequency.emoji)
                                            .font(.system(size: 24))

                                        Text(frequency.rawValue)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)

                                        Spacer()

                                        if selectedFrequency == frequency {
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
                                .opacity(selectedFrequency == frequency ? 1.0 : 0.6)
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
                    OnboardingTitleView("À quelle fréquence", "te sens-tu fatigué ?")
                        .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal) // Position ABSOLUE : 55pt depuis le haut
                    Spacer()
                }
            }
        }
        .onAppear {
            onValidationChanged?(selectedFrequency != nil)
        }
}
}
