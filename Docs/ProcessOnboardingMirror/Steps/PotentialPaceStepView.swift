//
//  PotentialPaceStepView.swift
//  Process
//
//  Vue pour sélectionner la vitesse d'atteinte de 100% du potentiel
//

import SwiftUI

struct PotentialPaceStepView: View {
    @Binding var selectedPace: GoalPace?
    var onValidationChanged: ((Bool) -> Void)?

    @State private var sliderValue: Double = 2.0
    @State private var isDragging = false

    private let minValue: Double = 0.0
    private let maxValue: Double = 4.0

    var body: some View {
        VStack(spacing: 60) {
            // Titre aligné en haut (même position pour toutes les pages)
            VStack(alignment: .leading, spacing: 2) {
                Text("À quelle vitesse")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("veux-tu atteindre")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("100% de ton potentiel ?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal) // Position fixe en haut (même que les autres pages)

            VStack(spacing: 30) {
                // Affichage du rythme sélectionné
                if let pace = selectedPace {
                    VStack(spacing: 12) {
                        Image(systemName: pace.icon)
                            .font(.system(size: 50))
                            .foregroundColor(getPaceColor(pace))

                        Text(pace.rawValue)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text(pace.description)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(getPaceColor(pace).opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(getPaceColor(pace).opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 40)
                    .transition(.opacity.combined(with: .scale))
                }

                // Slider
                VStack(spacing: 16) {
                    Slider(value: $sliderValue, in: minValue...maxValue, step: 1.0)
                        .accentColor(selectedPace.map { getPaceColor($0) } ?? .blue)
                        .padding(.horizontal, 30)
                        .onChange(of: sliderValue) { _, newValue in
                            if !isDragging {
                                HapticManager.shared.selection()
                            }
                            updatePace(from: newValue)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !isDragging {
                                        isDragging = true
                                        HapticManager.shared.impact(.light)
                                    }
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    HapticManager.shared.impact(.light)
                                }
                        )

                    // Labels des extrémités
                    HStack {
                        Text("Lent")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))

                        Spacer()

                        Text("Rapide")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 30)
                }
            }

            Spacer()
        }
        .onAppear {
            // Initialiser avec une valeur moyenne (moderate = 2.0)
            sliderValue = 2.0
            // S'assurer que selectedPace est initialisé AVANT tout
            if selectedPace == nil {
                selectedPace = .moderate
            }
            // Appeler updatePace qui va mettre à jour selectedPace et appeler onValidationChanged
            updatePace(from: sliderValue)
            // ✅ CORRECTION: Un seul appel à onValidationChanged pour éviter les animations conflictuelles
            DispatchQueue.main.async {
                onValidationChanged?(true)
            }
        }
    }

    private func updatePace(from value: Double) {
        let pace: GoalPace

        // Mapper la valeur du slider (0-4) aux valeurs de GoalPace
        switch value {
        case 0.0:
            pace = .noRush  // Lent (gauche)
        case 1.0:
            pace = .relaxed
        case 2.0:
            pace = .moderate
        case 3.0:
            pace = .aggressive
        case 4.0:
            pace = .asFastAsPossible  // Rapide (droite)
        default:
            pace = .moderate
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedPace = pace
        }

        // ✅ CORRECTION: Un seul appel à onValidationChanged pour éviter les animations conflictuelles
        DispatchQueue.main.async {
            self.onValidationChanged?(true)
        }
    }

    private func getPaceColor(_ pace: GoalPace) -> Color {
        switch pace {
        case .asFastAsPossible:
            return .red
        case .aggressive:
            return .orange
        case .moderate:
            return .blue
        case .relaxed:
            return .green
        case .noRush:
            return .mint
        }
}
}
