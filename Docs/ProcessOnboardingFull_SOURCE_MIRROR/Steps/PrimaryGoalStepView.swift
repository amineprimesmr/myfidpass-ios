//
//  PrimaryGoalStepView.swift
//  Process
//

import SwiftUI

struct PrimaryGoalStepView: View {
    @Binding var selectedGoals: Set<PrimaryGoal>
    var onValidationChanged: ((Bool) -> Void)?

    private let goals: [PrimaryGoal] = [
        .improveSleep,
        .increaseRecovery,
        .boostPerformance,
        .manageWeight,
        .reduceStress,
        .improveFitness
    ]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)
                Spacer()
                    .frame(height: 5) // ✅ Réduit de 15 à 5 pour remonter les boutons

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(goals, id: \.self) { goal in
                            Button(action: {
                                HapticManager.shared.selection()
                                if selectedGoals.contains(goal) {
                                    selectedGoals.remove(goal)
                                } else {
                                    selectedGoals.insert(goal)
                                }
                                onValidationChanged?(!selectedGoals.isEmpty)
                            }) {
                                HStack(spacing: 12) {
                                    Text(goal.rawValue)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .frame(maxWidth: .infinity)
                            .glassStyle()
                            .buttonBorderShape(.roundedRectangle(radius: 16))
                            .opacity(selectedGoals.contains(goal) ? 1.0 : 0.6)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
                .frame(maxHeight: 500)
            }

            VStack {
                OnboardingTitleView("Que veux-tu", "améliorer ?")
                    .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal)
                Spacer()
            }
        }
    }
}
