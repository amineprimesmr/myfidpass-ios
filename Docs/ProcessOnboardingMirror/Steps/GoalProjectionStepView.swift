//
//  GoalProjectionStepView.swift
//  Process
//
//  Vue de projection dynamique avec courbe de progression
//

import SwiftUI

struct GoalProjectionStepView: View {
    let primaryGoals: Set<PrimaryGoal>
    let currentWeight: Double?
    let idealWeight: Double?
    let weightGoal: WeightGoal?
    let experienceLevel: ExperienceLevel?
    let yearsOfExperience: Int
    let selectedSports: Set<String>
    let deadline: GoalDeadline?
    let trainingFrequency: String?
    let goalPace: GoalPace?

    @State private var projectedDate: Date?
    @State private var projectionMessage: String = ""
    @State private var dayOnly: String = "" // Ex: "29"
    @State private var monthOnly: String = "" // Ex: "avril"
    @State private var monthlyProjectionMessage: String = ""
    @State private var monthlyProjectionSecondLine: String = "" // Deuxième ligne du message mensuel
    @State private var displayedDay: String = "" // Pour l'animation
    @State private var displayedMonth: String = "" // Pour l'animation
    @State private var countdownDays: Int = 0 // Compte à rebours en jours
    @State private var curveAnimationProgress: Double = 0 // Progression de l'animation de la courbe
    @State private var countdownTask: Task<Void, Never>? // ✅ Task pour pouvoir l'annuler
    @State private var isCountdownFinished: Bool = false // ✅ Suivre si l'animation du compteur est finie
    @State private var curveAnimationTimer: Timer? // ✅ Timer pour l'animation de la courbe

    var onValidationChanged: ((Bool) -> Void)?

    @State private var showCelebration = false

    var body: some View {
        mainContent(geometry: nil) // ✅ Pas besoin de GeometryReader, utiliser nil
            .onAppear {
            Logger.debug("[GoalProjectionStepView] VUE MONTÉE ! primaryGoals: \(primaryGoals)", category: "Onboarding")
            calculateProjection()

            // ✅ CRITIQUE: S'assurer que curveAnimationProgress commence à 0
            curveAnimationProgress = 0.0

            // ✅ Démarrer l'animation de la courbe progressivement avec un Timer pour un contrôle précis
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 secondes

                // ✅ Annuler le timer précédent s'il existe
                curveAnimationTimer?.invalidate()

                // ✅ Utiliser un Timer pour mettre à jour progressivement curveAnimationProgress
                let duration: TimeInterval = 3.0
                let startTime = Date()
                curveAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
                    let elapsed = Date().timeIntervalSince(startTime)
                    let progress = min(elapsed / duration, 1.0)

                    // ✅ Utiliser easeOut curve manuellement
                    let easeOutProgress = 1.0 - pow(1.0 - progress, 3.0)

                    curveAnimationProgress = easeOutProgress

                    if progress >= 1.0 {
                        timer.invalidate()
                        curveAnimationProgress = 1.0
                    }
                }

                if let timer = curveAnimationTimer {
                    RunLoop.main.add(timer, forMode: .common)
                }
            }

            // ✅ Démarrer le compte à rebours animé
            startCountdownAnimation()

            // Animation de célébration après un court délai
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showCelebration = true
                }
            }

            // ✅ NE PAS valider immédiatement - le bouton sera activé quand le compteur sera fini
            onValidationChanged?(false)
        }
        .onDisappear {
            // ✅ Annuler la Task pour arrêter les vibrations quand on quitte la page
            countdownTask?.cancel()
            countdownTask = nil
            // ✅ Annuler le timer d'animation de la courbe
            curveAnimationTimer?.invalidate()
            curveAnimationTimer = nil
        }
        .onChange(of: primaryGoals) { _, _ in
            calculateProjection()
        }
        .onChange(of: idealWeight) { _, _ in
            calculateProjection()
        }
        .onChange(of: experienceLevel) { _, _ in
            calculateProjection()
        }
        .onChange(of: yearsOfExperience) { _, _ in
            calculateProjection()
        }
        .onChange(of: trainingFrequency) { _, _ in
            calculateProjection()
        }
    }

    // MARK: - Computed Views

    private func mainContent(geometry: GeometryProxy?) -> some View {
        let screenWidth = UIScreen.main.bounds.width - 80 // ✅ Largeur de l'écran moins les paddings
        return ZStack {
            VStack(spacing: 0) {
                // Contenu principal - tout visible sans scroll
                VStack(spacing: 0) {
                    // 1. "D'après nos estimations" - plus visible
                    Text("D'après nos estimations")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.7)) // ✅ Augmenté de 0.4 à 0.7 pour plus de visibilité
                        .padding(.top, 60)
                        .frame(maxWidth: .infinity)

                    // 2. Message principal - plus gros et visible, centré (SANS la date)
                    Text(mainProjectionMessage)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 40)
                        .padding(.top, 24)

                    // 3. Deux rectangles glass avec date (jour à gauche, mois à droite)
                    dateButtonsView

                    // Espacement pour descendre le graphique plus bas
                    Spacer()
                        .frame(height: 70)

                    // 5. Graphique avec design exact de ProcessResultsDurabilityStepView
                    if let date = projectedDate {
                        graphViewWithDurabilityStyle(for: date)
                            .frame(height: 200)
                    }

                    // Espacement flexible
                    Spacer()

                    // 6. Message au-dessus du bouton CONTINUER
                    bottomMessagesView
                        .padding(.bottom, 120) // ✅ Espace pour le bouton CONTINUER
                }
            }
        }
    }

    private var dateButtonsView: some View {
        HStack(spacing: 10) {
            // Rectangle gauche : jour seulement (ex: "29")
            Button(action: {}) {
                Text(currentDisplayDay)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .frame(width: 50)
                    .frame(height: 28)
            }
            .glassStyle()
            .buttonBorderShape(.roundedRectangle(radius: 12))
            .controlSize(.large)

            // Rectangle droite : mois seulement (ex: "avril")
            Button(action: {}) {
                Text(currentDisplayMonth)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .contentTransition(.identity)
                    .frame(height: 28)
            }
            .glassStyle()
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .controlSize(.large)
        }
        .padding(.horizontal, 60)
        .padding(.top, 20)
    }

    // ✅ CORRIGÉ: Afficher toujours une valeur (jamais vide)
    private var currentDisplayDay: String {
        if !displayedDay.isEmpty { return displayedDay }
        if !dayOnly.isEmpty { return dayOnly }
        if let date = projectedDate {
            return "\(Calendar.current.component(.day, from: date))"
        }
        return "..."
    }

    private var currentDisplayMonth: String {
        if !displayedMonth.isEmpty { return displayedMonth }
        if !monthOnly.isEmpty { return monthOnly }
        if let date = projectedDate {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateFormat = "MMMM"
            return formatter.string(from: date).capitalized
        }
        return "..."
    }

    private var bottomMessagesView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Première ligne : "Basé sur ton profil" avec image check
            HStack(alignment: .top, spacing: 10) {
                Image("check")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)

                Text("Basé sur ton profil")
                    .font(.system(size: 15, weight: .regular)) // ✅ Moins gras
                    .foregroundColor(.white.opacity(0.7)) // ✅ Gris très clair
            }
            .padding(.top, 8) // ✅ Un peu plus haut

            // Deuxième ligne : message de progression avec image check
            if !monthlyProjectionSecondLine.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image("check")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)

                    Text(monthlyProjectionSecondLine)
                        .font(.system(size: 15, weight: .regular)) // ✅ Moins gras
                        .foregroundColor(.white.opacity(0.7)) // ✅ Gris très clair
                }
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading) // ✅ Aligné à gauche
        .padding(.leading, 50) // ✅ Padding gauche
        .padding(.trailing, 40)
    }

    // MARK: - Computed Properties

    private var mainProjectionMessage: String {
        // ✅ CORRIGÉ: Toujours afficher un message (jamais vide)
        let message = projectionMessage

        // Si le message est vide, utiliser un message par défaut
        if message.isEmpty {
            return "Tu auras atteint 100% de ton potentiel le"
        }

        // Retirer " d'ici le" suivi de la date (la date est déjà dans les boutons glass)
        if let range = message.range(of: " d'ici le") {
            return String(message[..<range.lowerBound])
        }
        // Retirer la date après " le " mais garder " le" à la fin
        // Le service génère " [objectif] le [date]", on veut garder " [objectif] le"
        if let range = message.range(of: " le ") {
            // Garder tout jusqu'à " le " inclus, puis retirer la date qui suit
            let beforeLe = String(message[..<range.upperBound])
            // La date commence après " le " et va jusqu'à la fin
            return beforeLe.trimmingCharacters(in: .whitespaces)
        }
        return message
    }

    // Graphique avec design exact de ProcessResultsDurabilityStepView
    private func graphViewWithDurabilityStyle(for date: Date) -> some View {
        let screenWidth = UIScreen.main.bounds.width - 80 // ✅ Largeur de l'écran moins les paddings
        let currentValue: Double
        let targetValue: Double
        let isWeightGoal: Bool

        if let current = currentWeight, let ideal = idealWeight, primaryGoals.contains(.manageWeight) {
            currentValue = current
            targetValue = ideal
            isWeightGoal = true
        } else {
            currentValue = 0
            targetValue = 100
            isWeightGoal = false
        }

        // ✅ Calculer directement le nombre de jours final (sans animation)
        let calendar = Calendar.current
        let now = Date()
        let finalCountdownDays = max(0, calendar.dateComponents([.day], from: now, to: date).day ?? 0)

        let service = GoalProjectionService.shared
        let curveData = service.generateProgressCurveData(
            startDate: Date(),
            endDate: date,
            currentValue: currentValue,
            targetValue: targetValue,
            isWeightGoal: isWeightGoal,
            weightGoal: weightGoal
        )

        return VStack(spacing: 0) { // ✅ Pas d'espacement pour que le graphique commence au même endroit que l'encadré
            GeometryReader { graphGeometry in
                let width = graphGeometry.size.width > 0 ? graphGeometry.size.width : screenWidth
                let height: CGFloat = 200

                // Convertir curveData en points pour le graphique - SIMPLIFIÉ (seulement 6 points)
                let simplifiedData: [Double] = {
                    if curveData.count <= 6 {
                        return curveData.map { data in
                            let minValue = min(currentValue, targetValue)
                            let maxValue = max(currentValue, targetValue)
                            let valueRange = max(maxValue - minValue, 0.1)
                            return (data.value - minValue) / valueRange
                        }
                    } else {
                        // Prendre seulement 6 points équitablement répartis
                        let step = max(1, curveData.count / 6)
                        return Array(stride(from: 0, to: curveData.count, by: step).prefix(6)).map { index in
                            let data = curveData[index]
                            let minValue = min(currentValue, targetValue)
                            let maxValue = max(currentValue, targetValue)
                            let valueRange = max(maxValue - minValue, 0.1)
                            return (data.value - minValue) / valueRange
                        }
                    }
                }()

                // Calculer les points simplifiés
                // ✅ Si objectif poids : selon le weightGoal (perte = haut→bas, gain = bas→haut)
                // ✅ Si objectif performance : toujours bas→haut (potentiel)
                let isAscending: Bool = {
                    if let weightGoal = weightGoal, primaryGoals.contains(.manageWeight) {
                        // Pour les objectifs de poids, respecter le sens selon le type
                        return (weightGoal == .gain)
                    } else {
                        // Pour les objectifs de performance, toujours monter (potentiel)
                        return true
                    }
                }()
                let allProgressPoints = calculateSimpleSmoothPoints(data: simplifiedData, width: width, height: height, isAscending: isAscending)

                // ✅ Utiliser tous les points pour construire le Path, mais ne dessiner que jusqu'à la progression
                let adjustedProgressPoints = allProgressPoints

                ZStack {
                    // ✨ Rectangle sombre en fond - moins large horizontalement
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )

                    // ✨ Texte "Ta progression" en haut à gauche et compte à rebours en haut à droite
                    VStack {
                        HStack {
                            Text("Ta progression")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.leading, 8) // ✅ Réduit de 16 à 8 pour réduire la largeur
                                .padding(.top, 12)

                            Spacer()

                            // ✅ Compte à rebours dans le graphique, à droite (sans animation, tout en gris)
                            HStack(spacing: 4) {
                                Text("Dans")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))

                                Text("\(finalCountdownDays)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white.opacity(0.7))

                                Text(finalCountdownDays <= 1 ? "jour" : "jours")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.trailing, 8) // ✅ Réduit de 16 à 8 pour réduire la largeur
                            .padding(.top, 12)
                        }
                        Spacer()
                    }

                    // ✨ Lignes horizontales en fond (grille) - seulement les lignes du milieu (1, 2, 3)
                    // ✅ Décalées pour commencer plus près du bord gauche
                    Path { path in
                        for i in 1...3 {
                            let y = height * CGFloat(i) / 4
                            // ✅ Commence exactement au bord gauche (pas de marge)
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: width, y: y))
                        }
                    }
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)

                        // ✨ Zone de remplissage sous la courbe (avec gradient violet) - ANIMÉE avec trimmedPath pour synchronisation fluide
                        if !adjustedProgressPoints.isEmpty {
                            Path { path in
                            let bottomOffset: CGFloat = height * 8.0
                            let bottomY = height + bottomOffset

                            path.move(to: CGPoint(x: 0, y: bottomY))

                            // ✅ Construire le chemin COMPLET une seule fois
                            if let firstPoint = adjustedProgressPoints.first {
                                path.addLine(to: CGPoint(x: firstPoint.x, y: firstPoint.y))
                            }

                            // Construire la courbe complète
                            for index in 1..<adjustedProgressPoints.count {
                                let point = adjustedProgressPoints[index]
                                let prevPoint = adjustedProgressPoints[index - 1]
                                let controlPoint1 = CGPoint(
                                    x: prevPoint.x + (point.x - prevPoint.x) / 3,
                                    y: prevPoint.y
                                )
                                let controlPoint2 = CGPoint(
                                    x: point.x - (point.x - prevPoint.x) / 3,
                                    y: point.y
                                )
                                path.addCurve(to: point, control1: controlPoint1, control2: controlPoint2)
                            }

                            // Fermer le chemin
                            if let lastPoint = adjustedProgressPoints.last {
                                path.addLine(to: CGPoint(x: lastPoint.x, y: bottomY))
                            }

                            path.addLine(to: CGPoint(x: 0, y: bottomY))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color(red: 0.7, green: 0.55, blue: 0.85).opacity(0.7), location: 0.0),
                                    .init(color: Color(red: 0.5, green: 0.3, blue: 0.7).opacity(0.9), location: 0.4),
                                    .init(color: Color(red: 0.4, green: 0.2, blue: 0.6).opacity(1.0), location: 0.5),
                                    .init(color: Color(red: 0.5, green: 0.3, blue: 0.7).opacity(0.6), location: 0.6),
                                    .init(color: Color(red: 0.6, green: 0.4, blue: 0.8).opacity(0.3), location: 0.75),
                                    .init(color: Color.clear, location: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .mask(
                            // ✅ Masque progressif qui suit exactement la progression de la courbe
                            GeometryReader { maskGeometry in
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(width: maskGeometry.size.width * curveAnimationProgress)
                                    Spacer()
                                }
                            }
                        )
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .white, location: 0.0),
                                    .init(color: .white.opacity(0.8), location: 0.6),
                                    .init(color: .white.opacity(0.3), location: 0.85),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        // ✨ OMBRE SOUS LA COURBE - ANIMÉE avec trimmedPath pour animation fluide
                        if !adjustedProgressPoints.isEmpty {
                            Path { path in
                                // ✅ Construire le chemin COMPLET une seule fois
                                for index in 0..<adjustedProgressPoints.count {
                                    let point = adjustedProgressPoints[index]
                                    let adjustedPoint = CGPoint(x: point.x, y: point.y + 2)
                                    if index == 0 {
                                        path.move(to: adjustedPoint)
                                    } else {
                                        let prevPoint = adjustedProgressPoints[index - 1]
                                        let prevAdjustedPoint = CGPoint(x: prevPoint.x, y: prevPoint.y + 2)
                                        let controlPoint1 = CGPoint(
                                            x: prevAdjustedPoint.x + (adjustedPoint.x - prevAdjustedPoint.x) / 3,
                                            y: prevAdjustedPoint.y
                                        )
                                        let controlPoint2 = CGPoint(
                                            x: adjustedPoint.x - (adjustedPoint.x - prevAdjustedPoint.x) / 3,
                                            y: adjustedPoint.y
                                        )
                                        path.addCurve(to: adjustedPoint, control1: controlPoint1, control2: controlPoint2)
                                    }
                                }
                            }
                            .trimmedPath(from: 0, to: curveAnimationProgress) // ✅ Utiliser trimmedPath pour animation fluide et continue
                            .stroke(
                                Color.black.opacity(0.4),
                                style: StrokeStyle(lineWidth: 5, lineCap: .square, lineJoin: .round) // ✅ .square au lieu de .round pour éviter l'arrondi au début
                            )
                            .blur(radius: 3)
                        }

                        // ✨ Courbe principale avec gradient violet - ANIMÉE avec trimmedPath pour animation fluide
                        if !adjustedProgressPoints.isEmpty {
                            Path { path in
                                // ✅ Construire le chemin COMPLET une seule fois
                                for index in 0..<adjustedProgressPoints.count {
                                    let point = adjustedProgressPoints[index]
                                    if index == 0 {
                                        path.move(to: point)
                                    } else {
                                        let prevPoint = adjustedProgressPoints[index - 1]
                                        let controlPoint1 = CGPoint(
                                            x: prevPoint.x + (point.x - prevPoint.x) / 3,
                                            y: prevPoint.y
                                        )
                                        let controlPoint2 = CGPoint(
                                            x: point.x - (point.x - prevPoint.x) / 3,
                                            y: point.y
                                        )
                                        path.addCurve(to: point, control1: controlPoint1, control2: controlPoint2)
                                    }
                                }
                            }
                            .trimmedPath(from: 0, to: curveAnimationProgress) // ✅ Utiliser trimmedPath pour animation fluide et continue
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.77, green: 0.64, blue: 0.97),
                                        Color(red: 0.6, green: 0.4, blue: 0.8),
                                        Color(red: 0.42, green: 0.05, blue: 0.51)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 5, lineCap: .square, lineJoin: .round) // ✅ .square au lieu de .round pour éviter l'arrondi au début
                            )
                        }

                        // ✨ TRAIT BLANC LÉGER SUR LE DESSUS DE LA COURBE - ANIMÉE avec trimmedPath pour animation fluide
                        if !adjustedProgressPoints.isEmpty {
                            Path { path in
                                // ✅ Construire le chemin COMPLET une seule fois
                                for index in 0..<adjustedProgressPoints.count {
                                    let point = adjustedProgressPoints[index]
                                    let adjustedPoint = CGPoint(x: point.x, y: point.y - 2)
                                    if index == 0 {
                                        path.move(to: adjustedPoint)
                                    } else {
                                        let prevPoint = adjustedProgressPoints[index - 1]
                                        let prevAdjustedPoint = CGPoint(x: prevPoint.x, y: prevPoint.y - 2)
                                        let controlPoint1 = CGPoint(
                                            x: prevAdjustedPoint.x + (adjustedPoint.x - prevAdjustedPoint.x) / 3,
                                            y: prevAdjustedPoint.y
                                        )
                                        let controlPoint2 = CGPoint(
                                            x: adjustedPoint.x - (adjustedPoint.x - prevAdjustedPoint.x) / 3,
                                            y: adjustedPoint.y
                                        )
                                        path.addCurve(to: adjustedPoint, control1: controlPoint1, control2: controlPoint2)
                                    }
                                }
                            }
                            .trimmedPath(from: 0, to: curveAnimationProgress) // ✅ Utiliser trimmedPath pour animation fluide et continue
                            .stroke(
                                Color.white.opacity(0.3),
                                style: StrokeStyle(lineWidth: 1, lineCap: .square, lineJoin: .round) // ✅ .square au lieu de .round pour éviter l'arrondi au début
                            )
                        }

                        // ✨ Point blanc à la fin de la courbe - ANIMÉE (apparaît uniquement à la fin de l'animation)
                        if curveAnimationProgress >= 1.0, let lastPoint = adjustedProgressPoints.last {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 12, height: 12)
                                .position(lastPoint)
                        }
                    }
                }
                .animation(nil, value: curveAnimationProgress)
            }
            .frame(height: 200)
            // ✅ Pas de padding horizontal pour que le graphique commence au même endroit que l'encadré

            // Labels "Aujourd'hui" et le mois sous le rectangle
            HStack {
                Text("Aujourd'hui")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.leading, 4) // ✅ Plus à gauche (réduit de 20 à 4)
                Spacer()
                Text(formatMonth(date))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.trailing, 20) // ✅ Plus à droite
            }
            .padding(.horizontal, 8)
            .padding(.top, 8) // ✅ Plus bas (augmenté de -4 à 8)
        }
        .padding(.horizontal, 60) // ✅ Augmenté de 20 à 60 pour rendre le rectangle moins large horizontalement
    }

    // ✅ Fonction pour calculer les points simplifiés
    // ✅ isAscending: true = commence en bas finit en haut (potentiel/prise de poids), false = commence en haut finit en bas (perte de poids)
    // ✅ Ajout de variations pour rendre la courbe moins régulière et plus réaliste
    private func calculateSimpleSmoothPoints(data: [Double], width: CGFloat, height: CGFloat, isAscending: Bool = false) -> [CGPoint] {
        guard !data.isEmpty else { return [] }

        // ✅ Pas de padding horizontal - la courbe commence exactement au bord gauche (x = 0)
        let usableWidth = width
        let stepWidth = usableWidth / CGFloat(max(1, data.count - 1))
        var points: [CGPoint] = []

        // ✅ Fonction pour générer une variation aléatoire mais déterministe basée sur l'index
        func randomVariation(for index: Int) -> CGFloat {
            // Utiliser un générateur pseudo-aléatoire basé sur l'index pour la reproductibilité
            let seed = Double(index) * 0.314159 + Double(index * index) * 0.123456
            let variation1 = sin(seed) * cos(seed * 2.5) // Variation entre -1 et 1
            let variation2 = sin(seed * 1.7) * cos(seed * 3.1) // Variation supplémentaire pour plus d'irrégularité
            let combinedVariation = (variation1 + variation2 * 0.5) / 1.5 // Combiner les variations
            return CGFloat(combinedVariation) * 25.0 // ✅ Variation max augmentée de 15 à 25 points pour plus d'irrégularité
        }

        // ✅ Direction de la courbe selon isAscending
        // isAscending = false : premier point en haut (normalizedValue = 0), dernier en bas (normalizedValue = 1)
        // isAscending = true : premier point en bas (normalizedValue = 1), dernier en haut (normalizedValue = 0)
        for (index, _) in data.enumerated() {
            let x: CGFloat
            // ✅ Commence exactement au bord gauche (0), même pour le premier point)
            if index == 0 {
                x = 0
            } else {
                x = CGFloat(index) * stepWidth
            }
            // Normaliser par l'index
            let normalizedValue = data.count > 1 ? Double(index) / Double(data.count - 1) : 0.0
            // ✅ Inverser la normalisation si isAscending (pour commencer en bas et finir en haut)
            let adjustedNormalizedValue = isAscending ? (1.0 - normalizedValue) : normalizedValue
            // ✅ AJOUT: Variation pour rendre la courbe moins régulière
            let baseY = (CGFloat(adjustedNormalizedValue) * height * 0.75) + (height * 0.20)
            // ✅ Plus de variation au milieu, moins aux extrémités pour garder le réalisme
            // ✅ Augmenter le facteur de variation pour plus d'irrégularité
            let variationFactor = sin(adjustedNormalizedValue * .pi) // 0 aux extrémités, 1 au milieu
            let additionalVariation = sin(Double(index) * 0.7) * cos(Double(index) * 1.3) * 8.0 // Variation supplémentaire
            let variation = randomVariation(for: index) * CGFloat(variationFactor) + CGFloat(additionalVariation)
            let y = baseY + variation

            points.append(CGPoint(x: x, y: min(height * 0.95, max(height * 0.20, y))))
        }

        return points
    }

    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date).capitalized
    }

    // MARK: - Methods

    private func calculateProjection() {
        let service = GoalProjectionService.shared

        // ✅ DEBUG: Logger les paramètres pour débugger
        Logger.debug("[GoalProjection] calculateProjection appelé avec:", category: "Onboarding")
        Logger.debug("  - primaryGoals: \(primaryGoals)", category: "Onboarding")
        Logger.debug("  - currentWeight: \(String(describing: currentWeight))", category: "Onboarding")
        Logger.debug("  - idealWeight: \(String(describing: idealWeight))", category: "Onboarding")
        Logger.debug("  - experienceLevel: \(String(describing: experienceLevel))", category: "Onboarding")
        Logger.debug("  - selectedSports: \(selectedSports)", category: "Onboarding")

        // ✅ CRITIQUE: Stocker la date actuelle AVANT de calculer la nouvelle
        let previousDate = projectedDate

        // Calculer la date projetée
        var calculatedDate = service.calculateProjectedDate(
            primaryGoals: primaryGoals,
            currentWeight: currentWeight,
            idealWeight: idealWeight,
            weightGoal: weightGoal,
            experienceLevel: experienceLevel,
            yearsOfExperience: yearsOfExperience,
            selectedSports: selectedSports,
            deadline: deadline,
            trainingFrequency: trainingFrequency,
            goalPace: goalPace
        )

        // ✅ SÉCURITÉ: Si le service retourne nil, utiliser une date par défaut (3 mois)
        if calculatedDate == nil {
            Logger.warning("[GoalProjection] Service retourne nil, utilisation de date par défaut (3 mois)", category: "Onboarding")
            calculatedDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())
        }

        if let date = calculatedDate {
            Logger.debug("[GoalProjection] Date calculée: \(date)", category: "Onboarding")

            // ✅ CRITIQUE: TOUJOURS assigner projectedDate et updateDateDisplay IMMÉDIATEMENT
            projectedDate = date
            updateDateDisplay(date: date) // ← Affiche la date finale dès le début

            // ✅ Si on a une date précédente ET qu'elle est plus éloignée que la nouvelle,
            // la stocker comme date initiale pour l'animation de décompte
            if let previous = previousDate, previous > date {
                service.storeInitialProjectedDate(previous, for: "goalProjection")
                // Animer depuis la date précédente vers la nouvelle
                animateDateFrom(previous, to: date)
            } else if previousDate == nil {
                // Première fois : stocker la date initiale
                service.storeInitialProjectedDate(date, for: "goalProjection")
                // Animer depuis une date plus éloignée (20% plus loin)
                let calendar = Calendar.current
                let daysDifference = calendar.dateComponents([.day], from: Date(), to: date).day ?? 0
                let initialDays = Int(Double(daysDifference) * 1.2)
                if let animInitialDate = calendar.date(byAdding: .day, value: initialDays, to: Date()) {
                    animateDateFrom(animInitialDate, to: date)
                }
            }

            // Générer le message
            let generatedMessage = service.generateProjectionMessage(
                primaryGoals: primaryGoals,
                projectedDate: date,
                idealWeight: idealWeight,
                weightGoal: weightGoal
            )

            // ✅ SÉCURITÉ: Si le message est vide, utiliser un message par défaut
            if generatedMessage.isEmpty {
                Logger.warning("[GoalProjection] Message vide, utilisation du message par défaut", category: "Onboarding")
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "fr_FR")
                formatter.dateFormat = "d MMMM"
                let dateString = formatter.string(from: date)
                projectionMessage = "Tu auras atteint 100% de ton potentiel le \(dateString)"
            } else {
                projectionMessage = generatedMessage
            }

            Logger.debug("[GoalProjection] Message: \(projectionMessage)", category: "Onboarding")

            // Calculer le message mensuel
            calculateMonthlyProjectionMessage()
        }
    }

    private func updateDateDisplay(date: Date) {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        dayOnly = "\(day)"

        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "fr_FR")
        monthFormatter.dateFormat = "MMMM"
        monthOnly = monthFormatter.string(from: date).capitalized
    }

    /// Anime la date depuis une date initiale (plus éloignée) vers une date cible (plus proche)
    private func animateDateFrom(_ fromDate: Date, to toDate: Date) {
        let calendar = Calendar.current
        let fromDay = calendar.component(.day, from: fromDate)
        let toDay = calendar.component(.day, from: toDate)

        let fromMonthFormatter = DateFormatter()
        fromMonthFormatter.locale = Locale(identifier: "fr_FR")
        fromMonthFormatter.dateFormat = "MMMM"
        let fromMonth = fromMonthFormatter.string(from: fromDate).capitalized

        let toMonthFormatter = DateFormatter()
        toMonthFormatter.locale = Locale(identifier: "fr_FR")
        toMonthFormatter.dateFormat = "MMMM"
        let toMonth = toMonthFormatter.string(from: toDate).capitalized

        // Calculer le nombre de jours entre les deux dates
        let daysDifference = abs(calendar.dateComponents([.day], from: fromDate, to: toDate).day ?? 0)

        // Définir la durée de l'animation (plus longue si la différence est grande)
        let animationDuration = min(max(Double(daysDifference) * 0.01, 1.0), 3.0) // Entre 1 et 3 secondes

        // Commencer avec la date initiale
        displayedDay = "\(fromDay)"
        displayedMonth = fromMonth

        // Mettre à jour les valeurs finales
        dayOnly = "\(toDay)"
        monthOnly = toMonth

        // Animer le jour
        if fromDay != toDay {
            // ✅ CORRECTION: Créer un tableau directement au lieu d'utiliser une expression ternaire avec types incompatibles
            let daySteps: [Int]
            if fromDay < toDay {
                daySteps = Array(fromDay...toDay)
            } else {
                daySteps = Array((toDay...fromDay).reversed())
            }

            let dayStepDuration = animationDuration / Double(daySteps.count)

            for (index, day) in daySteps.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * dayStepDuration) {
                    withAnimation(.easeOut(duration: dayStepDuration)) {
                        displayedDay = "\(day)"
                    }
                }
            }
        } else {
            displayedDay = "\(toDay)"
        }

        // Animer le mois si nécessaire
        if fromMonth != toMonth {
            // Attendre que l'animation du jour soit à mi-chemin
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 0.5) {
                withAnimation(.easeOut(duration: animationDuration * 0.5)) {
                    displayedMonth = toMonth
                }
            }
        } else {
            displayedMonth = toMonth
        }

        // Mettre à jour l'affichage final après l'animation
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            updateDateDisplay(date: toDate)
        }
    }

    private func calculateMonthlyProjectionMessage() {
        // ✅ Première ligne : toujours "Basé sur ton profil"
        monthlyProjectionMessage = "Basé sur ton profil"

        guard let date = projectedDate else {
            monthlyProjectionSecondLine = "tu progresseras à ton rythme"
            return
        }

        let calendar = Calendar.current
        let now = Date()

        guard let oneMonthLater = calendar.date(byAdding: .month, value: 1, to: now) else {
            monthlyProjectionSecondLine = "tu progresseras à ton rythme"
            return
        }

        let totalDays = calendar.dateComponents([.day], from: now, to: date).day ?? 30
        let daysInMonth = calendar.dateComponents([.day], from: now, to: oneMonthLater).day ?? 30

        if totalDays > 0 {
            let progressPercentage = (Double(daysInMonth) / Double(totalDays)) * 100
            monthlyProjectionSecondLine = "tu progresseras de \(String(format: "%.0f", progressPercentage))% en un mois"
        } else {
            monthlyProjectionSecondLine = "tu vas atteindre ton objectif rapidement"
        }
    }

    // ✅ Fonction pour démarrer l'animation du compte à rebours
    private func startCountdownAnimation() {
        guard let date = projectedDate else { return }

        // ✅ Annuler la Task précédente si elle existe
        countdownTask?.cancel()

        let calendar = Calendar.current
        let now = Date()
        let daysDifference = calendar.dateComponents([.day], from: now, to: date).day ?? 0

        // ✅ Commencer avec une valeur plus élevée pour l'effet de décompte
        let initialDays = max(daysDifference, Int(Double(daysDifference) * 1.2))
        countdownDays = initialDays

        // ✅ Animer progressivement vers la valeur réelle - PLUS LENT
        let totalDuration: TimeInterval = 4.0 // ✅ Augmenté de 2.5 à 4.0 pour rendre plus lent
        let steps = abs(initialDays - daysDifference)

        // ✅ Marquer que le compteur n'est pas encore fini
        isCountdownFinished = false

        if steps > 0 {
            let stepInterval = totalDuration / Double(steps)
            let direction = initialDays > daysDifference ? -1 : 1

            // ✅ Calculer le nombre réel de jours qui changent (pas les steps)
            let realDaysToAnimate = abs(daysDifference)

            countdownTask = Task { @MainActor in
                var currentDays = initialDays
                var lastVibratedDay: Int? // ✅ Suivre le dernier jour réel pour lequel on a vibré

                while currentDays != daysDifference {
                    // ✅ Vérifier si la Task a été annulée
                    if Task.isCancelled {
                        return
                    }

                    currentDays += direction

                    withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) {
                        countdownDays = currentDays
                    }

                    // ✅ Vibration UNIQUEMENT pour les jours réels (pas les jours fictifs initiaux)
                    // Si daysDifference = 9, on doit vibrer exactement 9 fois (une fois par jour qui défile)
                    let isInRealRange = (direction < 0 && currentDays >= daysDifference) || (direction > 0 && currentDays <= daysDifference)

                    if isInRealRange && currentDays != lastVibratedDay {
                        // ✅ Vérifier à nouveau avant de vibrer
                        guard !Task.isCancelled else { return }

                        HapticManager.shared.impact(.soft)
                        lastVibratedDay = currentDays
                    }

                    try? await Task.sleep(nanoseconds: UInt64(stepInterval * 1_000_000_000))

                    // ✅ Vérifier à nouveau après le sleep
                    if Task.isCancelled {
                        return
                    }
                }

                // ✅ Vérifier avant la vibration finale
                guard !Task.isCancelled else { return }

                // Haptic feedback final
                HapticManager.shared.notification(.success)

                // ✅ Marquer que le compteur est fini et activer le bouton
                isCountdownFinished = true
                onValidationChanged?(true)
            }
        } else {
            countdownDays = daysDifference
            // ✅ Si pas d'animation, activer immédiatement
            isCountdownFinished = true
            onValidationChanged?(true)
        }
    }
}
