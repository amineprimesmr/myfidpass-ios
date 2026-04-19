//
//  MainGoalStepView.swift
//  Process
//
//  Sélection objectif principal détaillé
//

import SwiftUI

struct MainGoalStepView: View {
    @Binding var selectedGoal: MainGoal?
    var onValidationChanged: ((Bool) -> Void)?

    var body: some View {
        VStack(spacing: 50) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Quel est ton")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("objectif principal ?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)

            // ✅ CORRECTION: Ajout du ScrollView pour éviter le débordement
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(MainGoal.allCases, id: \.self) { goal in
                        Button(action: {
                            HapticManager.shared.selection()
                            selectedGoal = goal
                            onValidationChanged?(true)
                        }) {
                            HStack {
                                Image(systemName: goal.icon)
                                    .font(.title2)
                                    .foregroundColor(selectedGoal == goal ? .purple : .white.opacity(0.7))

                                Text(goal.rawValue)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Spacer()

                                if selectedGoal == goal {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(20)
                        }
                        .glassStyle()
                        .buttonBorderShape(.roundedRectangle(radius: 16))
                        .opacity(selectedGoal == goal ? 1.0 : 0.6)
                    }
                }
                .padding(.horizontal, 40)
            }
            .frame(maxHeight: 500) // ✅ Limite la hauteur pour laisser de l'espace
        }
}
}
