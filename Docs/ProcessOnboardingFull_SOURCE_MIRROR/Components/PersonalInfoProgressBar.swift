//
//  PersonalInfoProgressBar.swift
//  Process
//
//  Barre de progression simple et clean pour les 4 étapes d'informations personnelles
//

import SwiftUI

struct PersonalInfoProgressBar: View {
    let currentStep: Int // 1, 2, 3 ou 4

    @State private var animatedProgress: Double = 0.0

    private var targetProgress: Double {
        return Double(currentStep) / 4.0
    }

    var body: some View {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Fond de la barre
                RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.2))
                    .frame(height: 6)

                // Barre de progression remplie - Vert pétant brillant avec animation fluide
                RoundedRectangle(cornerRadius: 3)
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
                    .frame(width: geometry.size.width * animatedProgress, height: 6)
                    .shadow(color: Color(red: 0.13, green: 0.98, blue: 0.47).opacity(0.5), radius: 2, x: 0, y: 0)
                }
            }
        .frame(height: 6)
        .frame(maxWidth: .infinity) // Plus longue - prend tout l'espace disponible
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
}
}
