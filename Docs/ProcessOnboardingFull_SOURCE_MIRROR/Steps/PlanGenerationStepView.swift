//
//  PlanGenerationStepView.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import SwiftUI
import FirebaseAuth

struct PlanGenerationStepView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @State private var userFirstName = "Utilisateur"
    @State private var animationProgress: Double = 0
    @State private var isAnimating = false

    // Données du graphique (simulation de progression)
    private let chartData: [(month: String, value: Double)] = [
        ("JAN", 0.2),
        ("FÉV", 0.4),
        ("MAR", 0.7),
        ("AVR", 0.5),
        ("MAI", 0.8),
        ("JUN", 0.6),
        ("JUL", 1.0)
    ]

    var body: some View {
        VStack(spacing: 60) {
            // Titre aligné en haut (même position pour toutes les pages)
            VStack(alignment: .leading, spacing: 2) {
                Text("Process génère ton plan personnalisé \(userFirstName)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal) // Position fixe en haut (même que les autres pages)

            // Graphique animé dans un rectangle glass
            Button(action: {}) {
                VStack(spacing: 20) {
                    // En-tête du graphique
                    HStack {
                        Text("PROGRESSION")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        Spacer()

                        Text("100%")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }

                    // Graphique
                    ZStack {
                        // Fond du graphique
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 120)

                        // Graphique en courbe
                        GeometryReader { geometry in
                            let width = geometry.size.width
                            let height = geometry.size.height

                            ZStack {
                                // Zone remplie sous la courbe
                                Path { path in
                                    let stepWidth = width / CGFloat(chartData.count - 1)

                                    path.move(to: CGPoint(x: 0, y: height))

                                    for (index, data) in chartData.enumerated() {
                                        let x = CGFloat(index) * stepWidth
                                        let y = height - (CGFloat(data.value) * height * animationProgress)

                                        if index == 0 {
                                            path.addLine(to: CGPoint(x: x, y: y))
                                        } else {
                                            path.addLine(to: CGPoint(x: x, y: y))
                                        }
                                    }

                                    // Fermer la zone sous la courbe
                                    path.addLine(to: CGPoint(x: width, y: height))
                                    path.closeSubpath()
                                }
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.purple.opacity(0.6),
                                            Color.blue.opacity(0.3)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                                // Ligne de la courbe
                                Path { path in
                                    let stepWidth = width / CGFloat(chartData.count - 1)

                                    for (index, data) in chartData.enumerated() {
                                        let x = CGFloat(index) * stepWidth
                                        let y = height - (CGFloat(data.value) * height * animationProgress)

                                        if index == 0 {
                                            path.move(to: CGPoint(x: x, y: y))
                                        } else {
                                            path.addLine(to: CGPoint(x: x, y: y))
                                        }
                                    }
                                }
                                .stroke(Color.white, lineWidth: 2)

                                // Points de données
                                ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                                    let stepWidth = width / CGFloat(chartData.count - 1)
                                    let x = CGFloat(index) * stepWidth
                                    let y = height - (CGFloat(data.value) * height * animationProgress)

                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 6, height: 6)
                                        .position(x: x, y: y)
                                        .opacity(animationProgress > 0 ? 1 : 0)

                                    // Valeur au-dessus du point (pour le point culminant)
                                    if index == 2 && animationProgress > 0.8 { // Point de mars
                                        Text("\(Int(data.value * 100))%")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.white.opacity(0.2))
                                            )
                                            .position(x: x, y: y - 20)
                                    }
                                }
                            }
                        }
                        .frame(height: 120)

                        // Flèche de progression
                        if animationProgress > 0.9 {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.trailing, 8)
                            }
                        }
                    }

                    // Labels des mois
                    HStack(spacing: 0) {
                        ForEach(chartData, id: \.month) { data in
                            Text(data.month)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(20)
            }
            .glassStyle()
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .disabled(true)
            .padding(.horizontal, 40)
        }
        .onAppear {
            loadUserFirstName()
            startAnimation()
        }
        .onChange(of: profileService.currentProfile?.firstName) { newValue in
            if let newFirstName = newValue, !newFirstName.isEmpty {
                userFirstName = newFirstName
            }
        }
    }

    private func loadUserFirstName() {
        if let user = Auth.auth().currentUser {
            // 1. Priorité 1: Récupérer depuis le profil utilisateur (le plus fiable)
            if let profile = profileService.currentProfile,
               !profile.firstName.isEmpty {
                userFirstName = profile.firstName
            }
            // 2. Priorité 2: Récupérer depuis displayName de Firebase Auth
            else if let displayName = user.displayName, !displayName.isEmpty {
                userFirstName = displayName
            }
            // 3. Fallback: Utiliser un nom générique au lieu de l'email
            else {
                userFirstName = "Utilisateur"
            }
        }
    }

    private func startAnimation() {
        withAnimation(.easeInOut(duration: 3.0)) {
            animationProgress = 1.0
        }
}
}
