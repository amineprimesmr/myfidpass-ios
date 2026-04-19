//
//  GoalPaceStepView.swift
//  Process
//
//  Vue pour sélectionner la vitesse de perte/prise de poids par semaine
//  Design simplifié avec slider natif
//

import SwiftUI

struct GoalPaceStepView: View {
    @Binding var selectedPace: GoalPace?
    var weightGoal: WeightGoal?  // Objectif de poids (perdre/prendre)
    var onValidationChanged: ((Bool) -> Void)?

    // ✅ Valeurs discrètes : 0.2, 0.3, 0.5, 0.7, 1.2 kg/semaine (5 options)
    private let paceValues: [Double] = [0.2, 0.3, 0.5, 0.7, 1.2]
    private let paceRange: ClosedRange<Double> = 0.0...4.0  // 5 positions : 0, 1, 2, 3, 4

    @State private var sliderValue: Double = 2.0  // Valeur par défaut : 0.5 kg/semaine (index 2)
    @State private var paceComment: PaceComment = .moderate

    var body: some View {
        ZStack {
            // ✅ Le fond noir et la lueur animée sont gérés par OnboardingView

            VStack(spacing: 0) {
                // Espace pour le titre en overlay
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                // Espacement entre titre et contenu
                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing + 40)

                // ✅ Section Vitesse - Simple et propre (même design que IdealWeightStepView)
                VStack(spacing: 16) {
                    // Bouton "Vitesse" au-dessus du slider
                    Button(action: {}) {
                        HStack(spacing: 4) {
                            Text("\(String(format: "%.1f", currentPaceValue))")
                                .font(.system(size: 18, weight: .bold))
                                .contentTransition(.numericText())

                            Text("kg/semaine")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .glassStyle()
                    .buttonBorderShape(.roundedRectangle(radius: 20))
                    .controlSize(.large)
                    .disabled(true)

                    // Slider natif avec style glass
                    Slider(value: $sliderValue, in: paceRange, step: 1.0)
                        .tint(.white)
                        .onChange(of: sliderValue) { _, newValue in
                            // Snap à la valeur entière la plus proche (0, 1, ou 2)
                            let snappedValue = round(newValue)
                            sliderValue = snappedValue

                            HapticManager.shared.selection()

                            // Mettre à jour le commentaire
                            paceComment = updatePaceComment(for: snappedValue)

                            // Convertir en GoalPace
                            updateGoalPace(from: snappedValue)

                            // Validation
                            onValidationChanged?(true)
                        }
                        .padding(.horizontal, 4)

                    // ✅ Commentaire dynamique simple
                    HStack(spacing: 8) {
                        Image(systemName: paceComment.icon)
                            .foregroundColor(paceComment.color)
                            .font(.system(size: 16, weight: .semibold))

                        Text(paceComment.text)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(paceComment.color)
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal, 40)

                Spacer()
            }

            // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
            VStack {
                OnboardingTitleView("À quelle vitesse", getTitleText())
                    .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal)
                Spacer()
            }
        }
        .onAppear {
            // Initialiser avec la valeur recommandée (0.5 kg/semaine, index 2)
            sliderValue = 2.0
            paceComment = updatePaceComment(for: 2.0)
            updateGoalPace(from: 2.0)
            onValidationChanged?(true)
        }
    }

    // ✅ Valeur actuelle du rythme en kg/semaine
    private var currentPaceValue: Double {
        let index = Int(sliderValue)
        guard index >= 0 && index < paceValues.count else {
            return paceValues[2] // Valeur par défaut (0.5 kg/semaine, index 2)
        }
        return paceValues[index]
    }

    // ✅ Mettre à jour le GoalPace depuis la valeur du slider
    private func updateGoalPace(from value: Double) {
        let index = Int(value)
        guard index >= 0 && index < paceValues.count else {
            selectedPace = .moderate
            return
        }

        // Convertir en GoalPace (5 options)
        let goalPace: GoalPace
        switch index {
        case 0: // 0.2 kg/semaine - Très lent
            goalPace = .noRush
        case 1: // 0.3 kg/semaine - Lent
            goalPace = .relaxed
        case 2: // 0.5 kg/semaine - Modéré (recommandé)
            goalPace = .moderate
        case 3: // 0.7 kg/semaine - Rapide
            goalPace = .aggressive
        case 4: // 1.2 kg/semaine - Très rapide
            goalPace = .asFastAsPossible
        default:
            goalPace = .moderate
        }

        selectedPace = goalPace
    }

    // ✅ Mettre à jour le commentaire selon la vitesse
    private func updatePaceComment(for value: Double) -> PaceComment {
        let index = Int(value)
        guard index >= 0 && index < paceValues.count else {
            return .moderate
        }

        switch index {
        case 0: // 0.2 kg/semaine - Très lent
            return .verySlow
        case 1: // 0.3 kg/semaine - Lent
            return .slow
        case 2: // 0.5 kg/semaine - Modéré (recommandé)
            return .moderate
        case 3: // 0.7 kg/semaine - Rapide
            return .fast
        case 4: // 1.2 kg/semaine - Très rapide
            return .veryFast
        default:
            return .moderate
        }
    }

    private func getTitleText() -> String {
        guard let weightGoal = weightGoal else {
            return "veux-tu atteindre ton objectif ?"
        }

        switch weightGoal {
        case .lose:
            return "veux-tu perdre du poids ?"
        case .gain:
            return "veux-tu prendre du poids ?"
        }
    }

    // ✅ Enum pour les commentaires (5 options)
    enum PaceComment {
        case verySlow  // 0.2 kg/semaine
        case slow      // 0.3 kg/semaine
        case moderate  // 0.5 kg/semaine (recommandé)
        case fast      // 0.7 kg/semaine
        case veryFast  // 1.2 kg/semaine

        var text: String {
            switch self {
            case .verySlow:
                return "Rythme très doux"
            case .slow:
                return "Rythme doux"
            case .moderate:
                return "Rythme recommandé ✨"
            case .fast:
                return "Rythme rapide"
            case .veryFast:
                return "Rythme très rapide"
            }
        }

        var color: Color {
            switch self {
            case .verySlow:
                return Color(red: 0.13, green: 0.98, blue: 0.47) // Vert Process
            case .slow:
                return Color(red: 0.13, green: 0.98, blue: 0.47) // Vert Process
            case .moderate:
                return Color(red: 0.13, green: 0.98, blue: 0.47) // Vert Process
            case .fast:
                return .orange
            case .veryFast:
                return .orange
            }
        }

        var icon: String {
            switch self {
            case .verySlow:
                return "checkmark.circle.fill"
            case .slow:
                return "checkmark.circle.fill"
            case .moderate:
                return "sparkles"
            case .fast:
                return "exclamationmark.triangle.fill"
            case .veryFast:
                return "exclamationmark.triangle.fill"
            }
        }
}
}
