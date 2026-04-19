//
//  UnifiedEstimationGraphView.swift
//  Process
//
//  Composant unifié pour le graphique d'estimation avec échéance animée
//

import SwiftUI

struct UnifiedEstimationGraphView: View {
    let projectedDate: Date
    let currentValue: Double
    let targetValue: Double
    let startDate: Date
    let isWeightGoal: Bool
    let weightGoal: WeightGoal?

    @State private var animationProgress: Double = 0
    @State private var displayedDate: Date

    private var curveData: [(date: Date, value: Double)] {
        let service = GoalProjectionService.shared
        return service.generateProgressCurveData(
            startDate: startDate,
            endDate: projectedDate,
            currentValue: currentValue,
            targetValue: targetValue,
            isWeightGoal: isWeightGoal,
            weightGoal: weightGoal
        )
    }

    init(
        projectedDate: Date,
        currentValue: Double,
        targetValue: Double,
        isWeightGoal: Bool = false,
        weightGoal: WeightGoal? = nil,
        startDate: Date = Date()
    ) {
        self.projectedDate = projectedDate
        self.currentValue = currentValue
        self.targetValue = targetValue
        self.isWeightGoal = isWeightGoal
        self.weightGoal = weightGoal
        self.startDate = startDate

        // Utiliser la date initiale stockée si disponible, sinon utiliser la date projetée
        let service = GoalProjectionService.shared
        if let initialDate = service.getInitialProjectedDate(), initialDate > projectedDate {
            // Si on a une date initiale plus éloignée, commencer avec celle-ci
            _displayedDate = State(initialValue: initialDate)
        } else {
            // Sinon, stocker cette date comme initiale et commencer avec
            service.storeInitialProjectedDate(projectedDate, for: "estimation")
            _displayedDate = State(initialValue: projectedDate)
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Date projetée avec animation
            VStack(spacing: 8) {
                Text("Le")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Text(formatDate(displayedDate))
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                    .contentTransition(.numericText(value: displayedDate.timeIntervalSince1970))
                    .id(displayedDate) // Force la réanimation
            }
            .padding(.vertical, 20)

            // Courbe de progression
            if !curveData.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ta progression")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)

                    GeometryReader { geometry in
                        let width = geometry.size.width
                        let height = geometry.size.height

                        ZStack {
                            // Grille de fond
                            Path { path in
                                for i in 0...4 {
                                    let y = height * CGFloat(i) / 4
                                    path.move(to: CGPoint(x: 0, y: y))
                                    path.addLine(to: CGPoint(x: width, y: y))
                                }
                            }
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)

                            // Labels d'abscisse : "Aujourd'hui" à gauche et le mois d'atteinte à droite
                            VStack {
                                Spacer()
                                HStack {
                                    Text("Aujourd'hui")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                    Spacer()
                                    Text(formatMonth(projectedDate))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .padding(.horizontal, 0)
                                .padding(.top, 4)
                            }
                            .frame(height: height)

                            // Zone remplie sous la courbe
                            Path { path in
                                guard !curveData.isEmpty else { return }

                                // Utiliser currentValue et targetValue pour la normalisation
                                let minValue = min(currentValue, targetValue)
                                let maxValue = max(currentValue, targetValue)
                                let valueRange = max(maxValue - minValue, 0.1) // Éviter division par zéro

                                let stepWidth = width / CGFloat(curveData.count - 1)

                                path.move(to: CGPoint(x: 0, y: height))

                                for (index, data) in curveData.enumerated() {
                                    let x = CGFloat(index) * stepWidth
                                    let normalizedValue = (data.value - minValue) / valueRange
                                    let y = height - (CGFloat(normalizedValue) * height * animationProgress)

                                    if index == 0 {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    } else {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }

                                path.addLine(to: CGPoint(x: width, y: height))
                                path.closeSubpath()
                            }
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.green.opacity(0.3),
                                        Color.green.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            // Ligne de la courbe
                            Path { path in
                                guard !curveData.isEmpty else { return }

                                // Utiliser currentValue et targetValue pour la normalisation
                                let minValue = min(currentValue, targetValue)
                                let maxValue = max(currentValue, targetValue)
                                let valueRange = max(maxValue - minValue, 0.1) // Éviter division par zéro

                                let stepWidth = width / CGFloat(curveData.count - 1)

                                for (index, data) in curveData.enumerated() {
                                    let x = CGFloat(index) * stepWidth
                                    let normalizedValue = (data.value - minValue) / valueRange
                                    let y = height - (CGFloat(normalizedValue) * height * animationProgress)

                                    if index == 0 {
                                        path.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                            }
                            .stroke(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                            )

                            // Marqueur d'échéance sur la courbe
                            if animationProgress > 0.8 {
                                let minValue = min(currentValue, targetValue)
                                let maxValue = max(currentValue, targetValue)
                                let valueRange = max(maxValue - minValue, 0.1) // Éviter division par zéro
                                let stepWidth = width / CGFloat(curveData.count - 1)
                                let lastIndex = curveData.count - 1
                                let x = CGFloat(lastIndex) * stepWidth
                                let lastData = curveData[lastIndex]
                                let normalizedValue = (lastData.value - minValue) / valueRange
                                let y = height - (CGFloat(normalizedValue) * height * animationProgress)

                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 12, height: 12)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2)
                                        )

                                    Text("\(Int(lastData.value))")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(Color.green.opacity(0.8))
                                        )
                                }
                                .position(x: x, y: y - 25)
                            }
                        }
                    }
                    .frame(height: 200)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30) // Espace pour les labels
                }
            }
        }
        .onAppear {
            // Animation de la courbe
            withAnimation(.easeOut(duration: 1.5)) {
                animationProgress = 1.0
            }

            // Animation de la date qui se rapproche progressivement
            animateDateProgression()
        }
        .onChange(of: projectedDate) { _, newDate in
            // ✅ Quand la date change (devient plus proche), animer le décompte visible
            // S'assurer qu'on a bien une date initiale stockée pour l'animation
            let service = GoalProjectionService.shared
            if let initialDate = service.getInitialProjectedDate(), initialDate > newDate {
                // Si on a une date initiale plus éloignée, commencer l'animation depuis celle-ci
                displayedDate = initialDate
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    animateDateTo(newDate)
                }
            } else {
                // Sinon, animer depuis la date actuellement affichée
                animateDateTo(newDate)
            }
        }
    }

    private func animateDateProgression() {
        let service = GoalProjectionService.shared
        let calendar = Calendar.current

        // ✅ Si on a une date initiale stockée (plus éloignée), animer depuis celle-ci
        if let initialDate = service.getInitialProjectedDate(), initialDate > projectedDate {
            displayedDate = initialDate

            // ✅ Animer vers la date projetée (plus proche) avec un délai pour l'effet visuel
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 secondes
                animateDateTo(projectedDate)
            }
        } else {
            // ✅ Sinon, commencer avec une date 20% plus éloignée pour l'effet visuel
            let daysDifference = calendar.dateComponents([.day], from: startDate, to: projectedDate).day ?? 0
            let initialDays = Int(Double(daysDifference) * 1.2)

            if let initialDate = calendar.date(byAdding: .day, value: initialDays, to: startDate) {
                displayedDate = initialDate

                // Stocker cette date comme initiale
                service.storeInitialProjectedDate(initialDate, for: "estimation")

                // ✅ Animer vers la date projetée avec un délai pour l'effet visuel
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 secondes
                    animateDateTo(projectedDate)
                }
            }
        }
    }

    private func animateDateTo(_ targetDate: Date) {
        let calendar = Calendar.current
        let daysDifference = calendar.dateComponents([.day], from: displayedDate, to: targetDate).day ?? 0

        guard daysDifference != 0 else { return }

        // ✅ OPTIMISATION: Animation fluide avec Timer pour un décompte visible jour par jour
        let totalDuration: TimeInterval = 2.0 // Durée totale de l'animation (2 secondes)
        let startDate = displayedDate
        let direction = daysDifference > 0 ? -1 : 1 // Inverser car on veut se rapprocher

        // Calculer le nombre de jours à animer
        let totalDays = abs(daysDifference)

        // Pour les grandes différences (> 30 jours), animer par groupes de jours pour la performance
        // Pour les petites différences, animer jour par jour pour l'effet visuel
        let daysPerStep: Int
        let stepInterval: TimeInterval

        if totalDays > 30 {
            // Grande différence : animer par groupes de 2-3 jours
            daysPerStep = max(2, totalDays / 30)
            stepInterval = totalDuration / Double(totalDays / daysPerStep)
        } else {
            // Petite différence : animer jour par jour pour l'effet visuel
            daysPerStep = 1
            stepInterval = totalDuration / Double(totalDays)
        }

        // ✅ Utiliser Task pour l'animation asynchrone
        Task { @MainActor in
            var currentStep = 0
            let totalSteps = (totalDays / daysPerStep) + 1

            while currentStep <= totalSteps {
                let daysToAdd = currentStep * daysPerStep * direction

                if let newDate = calendar.date(byAdding: .day, value: daysToAdd, to: startDate) {
                    // S'assurer qu'on ne dépasse pas la date cible
                    let finalDate: Date
                    if direction < 0 {
                        finalDate = newDate < targetDate ? targetDate : newDate
                    } else {
                        finalDate = newDate > targetDate ? targetDate : newDate
                    }

                    // ✅ Animation fluide avec spring pour un effet naturel
                    withAnimation(.spring(response: 0.1, dampingFraction: 0.8)) {
                        displayedDate = finalDate
                    }

                    // ✅ Haptic feedback léger pour chaque étape importante
                    if currentStep % max(1, totalSteps / 10) == 0 {
                        HapticManager.shared.impact(.soft)
                    }

                    // Vérifier si on a atteint la date cible
                    if finalDate == targetDate {
                        break
                    }
                }

                currentStep += 1

                // Attendre avant la prochaine étape
                try? await Task.sleep(nanoseconds: UInt64(stepInterval * 1_000_000_000))
            }

            // ✅ Haptic feedback final quand l'animation est terminée
            HapticManager.shared.notification(.success)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }

    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM" // Format: "mai", "avril", etc.
        return formatter.string(from: date).capitalized // Capitaliser la première lettre
    }
}
