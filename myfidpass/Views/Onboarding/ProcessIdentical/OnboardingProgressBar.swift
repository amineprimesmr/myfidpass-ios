//
//  OnboardingProgressBar.swift
//  Process
//
//  Barre de progression générale pour toutes les pages de l'onboarding
//
//  Copie à l’identique depuis le projet Process (Bureau).
//

import SwiftUI

struct OnboardingProgressBar: View {
    let currentStep: Int // Étape actuelle (0-indexed)
    let totalSteps: Int // Nombre total d'étapes

    @State private var animatedProgress: Double = 0.0

    private var targetProgress: Double {
        guard totalSteps > 0 else { return 0.0 }
        return Double(currentStep + 1) / Double(totalSteps)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Fond de la barre (lisible sur fond clair)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 8)

                // Barre de progression remplie - Vert pétant brillant avec animation fluide
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.13, green: 0.98, blue: 0.47), // #21fa78 - Vert pétant
                                Color(red: 0.35, green: 1.0, blue: 0.65),  // Vert brillant
                                Color(red: 0.65, green: 1.0, blue: 0.95) // #a6fff2 - Cyan brillant
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * animatedProgress, height: 8)
                    .shadow(color: Color(red: 0.13, green: 0.98, blue: 0.47).opacity(0.5), radius: 2, x: 0, y: 0)
            }
        }
        .frame(height: 8)
        .frame(maxWidth: .infinity)
        .onAppear {
            // Animation fluide au démarrage
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = targetProgress
            }
        }
        .onChange(of: currentStep) { _, _ in
            // Animation fluide progressive quand on change de page
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = targetProgress
            }
        }
        .onChange(of: totalSteps) { _, _ in
            // Réajuster si le total change
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = targetProgress
            }
        }
    }
}
