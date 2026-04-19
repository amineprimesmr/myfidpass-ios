//
//  ProgressBarView.swift
//  Process
//
//  Barre de progression animée pour les 4 premières pages d'onboarding
//

import SwiftUI

struct ProgressBarView: View {
    let currentStep: OnboardingStep

    @State private var progress: CGFloat = 0.0
    @State private var isAnimating = false

    private var targetProgress: CGFloat {
        switch currentStep {
        case .genderSelection:
            return 0.25 // 25%
        case .ageSelection:
            return 0.50 // 50%
        case .heightWeight:
            return 0.75 // 75%
        case .firstNameInput:
            return 1.0 // 100%
        default:
            return 0.0
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let barWidth = geometry.size.width
            let barHeight: CGFloat = 4

            ZStack(alignment: .leading) {
                // Fond de la barre (gris transparent)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: barHeight)

                // Barre de progression animée (vert/turquoise pétant)
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.0, green: 0.9, blue: 0.7), // Vert pétant
                                Color(red: 0.2, green: 0.8, blue: 0.9), // Turquoise
                                Color(red: 0.0, green: 0.7, blue: 1.0)  // Bleu-vert
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: barWidth * progress, height: barHeight)
                    .shadow(color: Color(red: 0.0, green: 0.9, blue: 0.7).opacity(0.6), radius: 4, x: 0, y: 0)
                    .overlay(
                        // Effet de brillance animé
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.0),
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: barWidth * progress, height: barHeight)
                            .offset(x: isAnimating ? barWidth * progress : -barWidth * progress)
                            .animation(
                                Animation.linear(duration: 1.5)
                                    .repeatForever(autoreverses: false),
                                value: isAnimating
                            )
                    )
            }
        }
        .frame(height: 4)
        .frame(maxWidth: 200) // Largeur maximale de la barre
        .onAppear {
            // Animation fluide du remplissage
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                progress = targetProgress
            }

            // Démarrer l'animation de brillance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAnimating = true
            }
        }
        .onChange(of: currentStep) { _ in
            // Réanimer quand on change de page
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                progress = targetProgress
            }
}
}
}
