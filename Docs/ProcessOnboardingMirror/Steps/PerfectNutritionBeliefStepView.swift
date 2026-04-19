//
//  PerfectNutritionBeliefStepView.swift
//
//  Vue pour demander si l'utilisateur pense avoir une alimentation parfaite
//

import SwiftUI

struct PerfectNutritionBeliefStepView: View {
    @Binding var hasPerfectNutrition: Bool?
    var onValidationChanged: ((Bool) -> Void)?

    var body: some View {
        VStack(spacing: 60) {
            // Titre aligné en haut (même position pour toutes les pages)
            VStack(alignment: .leading, spacing: 2) {
                Text("Penses-tu avoir")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("une alimentation parfaite")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("à la hauteur de tes objectifs ?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal) // Position fixe en haut (même que les autres pages)

            VStack(spacing: 16) {
                // Bouton Oui
                Button(action: {
                    HapticManager.shared.selection()
                    hasPerfectNutrition = true
                    onValidationChanged?(true)
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(hasPerfectNutrition == true ? .green : .white.opacity(0.7))

                        Text("Oui")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        if hasPerfectNutrition == true {
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
                .opacity(hasPerfectNutrition == true ? 1.0 : 0.7)

                // Bouton Non
                Button(action: {
                    HapticManager.shared.selection()
                    hasPerfectNutrition = false
                    onValidationChanged?(true)
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(hasPerfectNutrition == false ? .orange : .white.opacity(0.7))

                        Text("Non")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        if hasPerfectNutrition == false {
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
                .opacity(hasPerfectNutrition == false ? 1.0 : 0.7)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .onAppear {
            if hasPerfectNutrition != nil {
                onValidationChanged?(true)
            }
}
}
}
