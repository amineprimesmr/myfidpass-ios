//
//  HasSufficientHydrationStepView.swift
//
//  Vue pour demander si l'utilisateur pense s'hydrater suffisamment (Oui/Non)
//

import SwiftUI

struct HasSufficientHydrationStepView: View {
    @Binding var hasSufficientHydration: Bool?
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

                    VStack(spacing: 16) {
                        // Bouton Oui
                        Button(action: {
                            HapticManager.shared.selection()
                            hasSufficientHydration = true
                            onValidationChanged?(true)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(hasSufficientHydration == true ? .green : .white.opacity(0.7))

                                Text("Oui")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)

                                Spacer()

                                if hasSufficientHydration == true {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 24))
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.white.opacity(0.3))
                                        .font(.system(size: 24))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                        .glassStyle()
                        .buttonBorderShape(.roundedRectangle(radius: 20))
                        .controlSize(.large)
                        .opacity(hasSufficientHydration == true ? 1.0 : 0.7)

                        // Bouton Non
                        Button(action: {
                            HapticManager.shared.selection()
                            hasSufficientHydration = false
                            onValidationChanged?(true)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(hasSufficientHydration == false ? .orange : .white.opacity(0.7))

                                Text("Non")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)

                                Spacer()

                                if hasSufficientHydration == false {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 24))
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.white.opacity(0.3))
                                        .font(.system(size: 24))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                        .glassStyle()
                        .buttonBorderShape(.roundedRectangle(radius: 20))
                        .controlSize(.large)
                        .opacity(hasSufficientHydration == false ? 1.0 : 0.7)
                    }
                    .padding(.horizontal, 40)

                    Spacer()
                }

                // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
                VStack {
                    OnboardingTitleView("Penses-tu", "t'hydrater", "suffisamment ?")
                        .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal) // Position ABSOLUE : 55pt depuis le haut
                    Spacer()
                }
            }
            .onAppear {
                if hasSufficientHydration != nil {
                    onValidationChanged?(true)
                }
}
}
}
}
