//
//  OptimizationGoalsStepView.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import SwiftUI

struct OptimizationGoalsStepView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @State private var selectedGoals: Set<String> = []

    // Callback pour notifier la validation
    var onValidationChanged: ((Bool) -> Void)?

    private let goals = [
        "Améliorer mes performances",
        "Mieux récupérer et dormir",
        "Avoir plus d'énergie",
        "Optimiser ma nutrition"
    ]

    var body: some View {
        VStack(spacing: 50) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Que souhaites-tu")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("optimiser ?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)

            // ✅ CORRECTION: Ajout du ScrollView pour cohérence
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(goals, id: \.self) { goal in
                        Button(action: {
                            toggleGoal(goal)
                        }) {
                            HStack {
                                Text(goal)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)

                                Spacer()

                                if selectedGoals.contains(goal) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                        .glassStyle()
                        .buttonBorderShape(.roundedRectangle(radius: 16))
                        .opacity(selectedGoals.contains(goal) ? 1.0 : 0.7)
                    }
                }
                .padding(.horizontal, 40)
            }
            .frame(maxHeight: 350) // ✅ Limite la hauteur

            // Bouton Continuer
            Button(action: {
                // Action vide - géré par OnboardingView
            }) {
                Text("CONTINUER")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .glassStyle()
            .buttonBorderShape(.roundedRectangle(radius: 50))
            .padding(.horizontal, 40)
            .disabled(selectedGoals.isEmpty)
            .opacity(selectedGoals.isEmpty ? 0.5 : 1.0)
        }
    }

    private func toggleGoal(_ goal: String) {
        // Vibration pour la sélection
        HapticManager.shared.selection()

        if selectedGoals.contains(goal) {
            selectedGoals.remove(goal)
        } else {
            selectedGoals.insert(goal)
        }

        // Notifier la validation
        onValidationChanged?(!selectedGoals.isEmpty)

        // ✅ NOUVEAU: Sauvegarder immédiatement
        Task {
            await OnboardingProgressService.shared.saveOptimizationGoals(selectedGoals, to: profileService)
        }
}
}
