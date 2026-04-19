//
//  CaloriesGoalStepView.swift
//  Process
//
//  Page : Ajouter les calories brûlées à votre objectif quotidien ?
//

import SwiftUI

struct CaloriesGoalStepView: View {
    @StateObject private var hapticManager = HapticManager.shared

    let onComplete: () -> Void
    let onBack: (() -> Void)?

    init(onComplete: @escaping () -> Void, onBack: (() -> Void)? = nil) {
        self.onComplete = onComplete
        self.onBack = onBack
    }

    var body: some View {
        ZStack {
            // Fond noir
            Color.black
                .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                // Espacement en haut
                Spacer()
                    .frame(height: 60)

                // Question principale
                Text("Ajouter les calories brûlées à ton objectif quotidien ?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)

                // Image avec carte superposée
                ZStack(alignment: .bottomLeading) {
                    // Image (placeholder - sera remplacée par l'image dans les assets)
                    // TODO: Remplacer par Image("nom_image") quand l'image sera dans les assets
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.gray.opacity(0.4),
                                    Color.gray.opacity(0.2)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 300)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("Image à ajouter dans les assets")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)

                    // Carte blanche superposée en bas à gauche (exactement comme l'image)
                    VStack(alignment: .leading, spacing: 10) {
                        // "Objectif du jour"
                        Text("Objectif du jour")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)

                        // "500 Cals" avec icône flamme
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                            Text("500 Cals")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.black)
                        }

                        // "Course" avec icône chaussure
                        HStack(spacing: 6) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                            Text("Course")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.black)
                        }

                        // "+100 kcal"
                        Text("+100 kcal")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.black)
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white)
                    )
                    .padding(.leading, 40)
                    .padding(.bottom, 20)
                }

                Spacer()
            }
}
}
}
