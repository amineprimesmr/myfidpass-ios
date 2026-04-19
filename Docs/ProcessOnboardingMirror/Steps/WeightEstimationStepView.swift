//
//  WeightEstimationStepView.swift
//  Process
//
//  Vue d'estimation de la date d'atteinte du poids idéal
//  ✅ Design unifié avec GoalProjectionStepView
//

import SwiftUI
import Foundation

struct WeightEstimationStepView: View {
    let currentWeight: Double
    let idealWeight: Double
    let weightGoal: WeightGoal
    let weeklyRate: Double  // Vitesse en kg/semaine (0.2, 0.3, 0.5, 0.7, 1.0) - Utilisé pour la première estimation

    // ✅ Paramètres optionnels pour la deuxième estimation (après questions sport)
    let experienceLevel: ExperienceLevel?
    let yearsOfExperience: Int
    let selectedSports: Set<String>
    let deadline: GoalDeadline?
    let trainingFrequency: String?
    let goalPace: GoalPace?

    var onValidationChanged: ((Bool) -> Void)?

    @State private var projectedDate: Date?
    @State private var dayOnly: String = "" // Ex: "29"
    @State private var monthOnly: String = "" // Ex: "avril"
    @State private var monthlyProjectionMessage: String = ""
    @State private var monthlyProjectionSecondLine: String = "" // Deuxième ligne du message mensuel
    @State private var displayedDay: String = "" // Pour l'animation
    @State private var displayedMonth: String = "" // Pour l'animation
    @State private var countdownDays: Int = 0 // Compte à rebours en jours
    @State private var curveAnimationProgress: Double = 0 // Progression de l'animation de la courbe
    @State private var countdownTask: Task<Void, Never>? // ✅ Task pour pouvoir l'annuler
    @State private var dateAnimationTasks: [DispatchWorkItem] = [] // ✅ Tasks pour l'animation de date pour pouvoir les annuler
    @State private var isCountdownFinished: Bool = false // ✅ Suivre si l'animation du compteur est finie
    @State private var curveAnimationTimer: Timer? // ✅ Timer pour l'animation de la courbe
    @State private var showingInitialDate: Bool = false // ✅ Pour afficher la date initiale pendant 1 seconde
    @State private var initialDisplayDate: Date? // ✅ Date initiale à afficher (pour la deuxième estimation)

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 1. "D'après nos estimations" - plus visible
                Text("D'après nos estimations")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
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

                // Espacement pour descendre le graphique plus bas
                Spacer()
                    .frame(height: 70)

                // 5. Graphique avec design exact de ProcessResultsDurabilityStepView
                if let displayDate = showingInitialDate ? initialDisplayDate : projectedDate {
                    graphViewWithDurabilityStyle(for: displayDate, isSecondEstimation: showingInitialDate)
                        .frame(height: 200)
                }

                // Espacement flexible
                Spacer()

                // 6. Message au-dessus du bouton CONTINUER
                bottomMessagesView
                    .padding(.bottom, 120) // ✅ Espace suffisant pour le bouton CONTINUER
            }
            .onAppear {
                calculateProjectedDate()
                calculateMonthlyProjectionMessage()

                // ✅ CRITIQUE: S'assurer que curveAnimationProgress commence à 0
                curveAnimationProgress = 0.0

                // ✅ NE PAS valider immédiatement - le bouton sera activé quand le compteur sera fini
                onValidationChanged?(false)
                isCountdownFinished = false

                // ✅ GARANTIE DE SÉCURITÉ: Activer le bouton après un délai maximum (6 secondes)
                // pour éviter que l'utilisateur reste bloqué même si les animations échouent
                let safetyTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 6_000_000_000) // 6 secondes
                    if !isCountdownFinished {
                        Logger.debug("[WeightEstimation] Activation de sécurité du bouton Continuer après 6 secondes", category: "WeightEstimation")
                        isCountdownFinished = true
                        onValidationChanged?(true)
                    }
                }

                // ✅ Démarrer les animations avec délai pour la date initiale (si deuxième estimation)
                let service = GoalProjectionService.shared
                let initialDate = service.getInitialProjectedDate()
                let isSecondEstimation = experienceLevel != nil || !selectedSports.isEmpty || trainingFrequency != nil

                if isSecondEstimation, let initial = initialDate, let final = projectedDate, initial > final {
                    // ✅ DEUXIÈME ESTIMATION: Afficher d'abord la date initiale pendant 1 seconde
                    initialDisplayDate = initial
                    showingInitialDate = true
                    updateDateDisplay(date: initial) // Afficher la date initiale

                    Task {
                        // Attendre 1 seconde avec la date initiale
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde

                        // ✅ Vérifier si la Task a été annulée
                        guard !Task.isCancelled else {
                            safetyTask.cancel()
                            return
                        }

                        // ✅ Maintenant animer vers la nouvelle date ET démarrer le compteur en même temps
                        showingInitialDate = false
                        let animationDuration = animateDateFrom(initial, to: final) { duration in
                            // ✅ Callback: démarrer le compteur de jours EN MÊME TEMPS que l'animation de date
                            self.startCountdownAnimation(totalDuration: duration)
                        }

                        // ✅ Annuler la tâche de sécurité car l'animation normale va gérer l'activation du bouton
                        safetyTask.cancel()

                        // ✅ Démarrer l'animation de la courbe (qui finit plus tôt)
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 secondes après le début de l'animation de date

                        // ✅ Vérifier à nouveau si la Task a été annulée
                        guard !Task.isCancelled else { return }

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
                } else {
                    // ✅ PREMIÈRE ESTIMATION: Animation normale
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 secondes

                        // ✅ Vérifier si la Task a été annulée
                        guard !Task.isCancelled else {
                            safetyTask.cancel()
                            return
                        }

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

                        // ✅ Le compte à rebours sera démarré par animateDateFrom() avec le callback
                        // (appelé dans calculateProjectedDate() pour la première estimation)
                        // ✅ Si le compteur n'a pas été démarré par animateDateFrom, le démarrer ici
                        if countdownDays == 0, let date = projectedDate {
                            let calendar = Calendar.current
                            let now = Date()
                            let daysDifference = calendar.dateComponents([.day], from: now, to: date).day ?? 0
                            if daysDifference > 0 {
                                // Le compteur n'a pas été démarré, le démarrer maintenant
                                startCountdownAnimation()
                                // ✅ Activer le bouton après la durée standard
                                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                                    safetyTask.cancel()
                                    self.isCountdownFinished = true
                                    self.onValidationChanged?(true)
                                }
                            } else {
                                // Pas de jours à compter, activer immédiatement
                                safetyTask.cancel()
                                isCountdownFinished = true
                                onValidationChanged?(true)
                            }
                        } else {
                            // Le compteur a été démarré par animateDateFrom, annuler la tâche de sécurité
                            // (le bouton sera activé par animateDateFrom quand l'animation finit)
                        }
                    }
                }
            }
            .onDisappear {
                // ✅ Annuler la Task pour arrêter les vibrations quand on quitte la page
                countdownTask?.cancel()
                countdownTask = nil
                // ✅ Annuler toutes les tasks d'animation de date
                dateAnimationTasks.forEach { $0.cancel() }
                dateAnimationTasks.removeAll()
                // ✅ Annuler le timer d'animation de la courbe
                curveAnimationTimer?.invalidate()
                curveAnimationTimer = nil
            }
        }
    }

    // MARK: - Computed Properties

    private var mainProjectionMessage: String {
        // Afficher uniquement le poids idéal, pas la différence de poids
        return "Tu feras \(String(format: "%.0f", idealWeight)) kg le"
    }

    // ✅ CORRIGÉ: Afficher toujours une valeur (jamais vide)
    private var currentDisplayDay: String {
        if !displayedDay.isEmpty { return displayedDay }
        if !dayOnly.isEmpty { return dayOnly }
        // Fallback: calculer immédiatement
        if let date = projectedDate {
            return "\(Calendar.current.component(.day, from: date))"
        }
        return "..."
    }

    private var currentDisplayMonth: String {
        if !displayedMonth.isEmpty { return displayedMonth }
        if !monthOnly.isEmpty { return monthOnly }
        // Fallback: calculer immédiatement
        if let date = projectedDate {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateFormat = "MMMM"
            return formatter.string(from: date).capitalized
        }
        return "..."
    }

    // MARK: - Methods

    private func calculateProjectedDate() {
        let calendar = Calendar.current
        let now = Date()
        let service = GoalProjectionService.shared

        // ✅ Détecter si c'est la deuxième estimation (après questions sport)
        // On détecte cela si on a des informations de sport/expérience
        let isSecondEstimation = experienceLevel != nil || !selectedSports.isEmpty || trainingFrequency != nil

        // ✅ CRITIQUE: Récupérer la date initiale de la première estimation pour l'animation
        let initialDate = service.getInitialProjectedDate()

        var calculatedDate: Date?

        if isSecondEstimation {
            // ✅ DEUXIÈME ESTIMATION: Utiliser le système intelligent avec toutes les informations
            // Cela va calculer une date plus optimiste (antérieure à la première)
            calculatedDate = service.calculateProjectedDate(
                primaryGoals: Set([.manageWeight]),
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
        } else {
            // ✅ PREMIÈRE ESTIMATION: Calcul simple avec weeklyRate
            let difference = abs(idealWeight - currentWeight)
            guard difference > 0 else {
                calculatedDate = calendar.date(byAdding: .month, value: 1, to: now)
                if let date = calculatedDate {
                    // Stocker la date initiale pour la deuxième estimation
                    service.storeInitialProjectedDate(date, for: "weightEstimation")
                    // Animer depuis une date plus éloignée (20% plus loin)
                    let daysDifference = calendar.dateComponents([.day], from: now, to: date).day ?? 0
                    let initialDays = Int(Double(daysDifference) * 1.2)
                    if let initialDate = calendar.date(byAdding: .day, value: initialDays, to: now) {
                        // ✅ CRITIQUE: Toujours passer un callback pour démarrer le compteur et activer le bouton
                        let animationDuration = animateDateFrom(initialDate, to: date) { duration in
                            self.startCountdownAnimation(totalDuration: duration)
                        }
                    } else {
                        updateDateDisplay(date: date)
                        // ✅ CRITIQUE: Si pas d'animation de date, démarrer le compteur et activer le bouton après un délai
                        startCountdownAnimation()
                        // ✅ Activer le bouton après la durée standard de 4 secondes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                            self.isCountdownFinished = true
                            self.onValidationChanged?(true)
                        }
                    }
                    projectedDate = date
                }
                return
            }

            // Calculer le nombre de semaines nécessaires
            let weeksNeeded = Int(ceil(difference / weeklyRate))
            calculatedDate = calendar.date(byAdding: .weekOfYear, value: weeksNeeded, to: now)
        }

        // ✅ SÉCURITÉ: Si le calcul a échoué, utiliser une date par défaut (2 mois)
        if calculatedDate == nil {
            Logger.warning("[WeightEstimation] Calcul échoué, utilisation de date par défaut (2 mois)", category: "WeightEstimation")
            calculatedDate = calendar.date(byAdding: .month, value: 2, to: now)
        }

        // ✅ Gérer l'animation de date
        if let date = calculatedDate {
            // ✅ CRITIQUE: TOUJOURS assigner projectedDate et updateDateDisplay IMMÉDIATEMENT
            projectedDate = date
            updateDateDisplay(date: date) // ← Affiche la date finale dès le début

            if let initial = initialDate, initial > date {
                // ✅ DEUXIÈME ESTIMATION: Animer depuis la première date (plus tard) vers la nouvelle (plus tôt)
                service.storeInitialProjectedDate(initial, for: "weightEstimation")
                // Note: L'animation de date sera gérée dans onAppear avec le callback
            } else if initialDate == nil {
                // ✅ PREMIÈRE ESTIMATION: Stocker la date initiale
                service.storeInitialProjectedDate(date, for: "weightEstimation")
                // Animer depuis une date plus éloignée (20% plus loin)
                let daysDifference = calendar.dateComponents([.day], from: now, to: date).day ?? 0
                let initialDays = Int(Double(daysDifference) * 1.2)
                if let animInitialDate = calendar.date(byAdding: .day, value: initialDays, to: now) {
                    // Pour la première estimation, démarrer l'animation de date
                    _ = animateDateFrom(animInitialDate, to: date) { duration in
                        self.startCountdownAnimation(totalDuration: duration)
                    }
                } else {
                    // Si pas d'animation de date, démarrer le compteur normalement
                    startCountdownAnimation()
                }
            } else {
                // Pas d'animation nécessaire, démarrer le compteur
                startCountdownAnimation()
                // Activer le bouton après la durée standard de 4 secondes
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    self.isCountdownFinished = true
                    self.onValidationChanged?(true)
                }
            }
        } else {
            // ✅ CRITIQUE: Si aucune date n'a été calculée, activer le bouton quand même après un délai
            // (cas de sécurité pour éviter que l'utilisateur reste bloqué)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.isCountdownFinished = true
                self.onValidationChanged?(true)
            }
        }
    }

    /// Anime la date depuis une date initiale (plus éloignée) vers une date cible (plus proche)
    /// ✅ Retourne la durée de l'animation pour synchroniser avec le compteur de jours
    @discardableResult
    private func animateDateFrom(_ fromDate: Date, to toDate: Date, startCountdownCallback: ((TimeInterval) -> Void)? = nil) -> TimeInterval {
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

        // ✅ CRITIQUE: Utiliser une durée fixe de 4.0 secondes pour synchroniser avec le compteur de jours
        // (au lieu d'une durée variable entre 1 et 3 secondes)
        let animationDuration: TimeInterval = 4.0

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

            // ✅ Annuler les tasks précédentes
            dateAnimationTasks.forEach { $0.cancel() }
            dateAnimationTasks.removeAll()

            for (index, day) in daySteps.enumerated() {
                let workItem = DispatchWorkItem {
                    withAnimation(.easeOut(duration: dayStepDuration)) {
                        displayedDay = "\(day)"
                    }
                    // ✅ Vibration exactement une fois par jour qui défile (sauf le premier jour)
                    if index > 0 {
                        HapticManager.shared.impact(.soft)
                    }
                }
                dateAnimationTasks.append(workItem)
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * dayStepDuration, execute: workItem)
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

        // ✅ Démarrer le compteur de jours en même temps que l'animation de date
        // Passer la durée de l'animation au callback pour qu'il puisse synchroniser le compteur
        if let callback = startCountdownCallback {
            callback(animationDuration)
        }

        // Mettre à jour l'affichage final après l'animation
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            updateDateDisplay(date: toDate)

            // ✅ CRITIQUE: Marquer que l'animation est finie et activer le bouton ICI
            // (au même moment que les vibrations finissent)
            self.isCountdownFinished = true
            self.onValidationChanged?(true)
        }

        return animationDuration
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

        let totalDifference = abs(idealWeight - currentWeight)
        let totalDays = calendar.dateComponents([.day], from: now, to: date).day ?? 30
        let daysInMonth = calendar.dateComponents([.day], from: now, to: oneMonthLater).day ?? 30

        if totalDays > 0 {
            let monthlyProgress = (totalDifference * Double(daysInMonth)) / Double(totalDays)
            let monthlyWeight = String(format: "%.1f", monthlyProgress)

            if weightGoal == .lose {
                monthlyProjectionSecondLine = "tu vas perdre \(monthlyWeight) kg en un mois"
            } else if weightGoal == .gain {
                monthlyProjectionSecondLine = "tu vas prendre \(monthlyWeight) kg en un mois"
            } else {
                monthlyProjectionSecondLine = "tu vas atteindre \(monthlyWeight) kg de progression en un mois"
            }
        } else {
            monthlyProjectionSecondLine = "tu vas atteindre ton objectif rapidement"
        }
    }

    // ✅ Message en bas avec images check
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

    // ✅ Fonction pour démarrer l'animation du compte à rebours
    // ✅ totalDuration: durée totale de l'animation (doit correspondre à l'animation de date)
    private func startCountdownAnimation(totalDuration: TimeInterval = 4.0) {
        guard let date = projectedDate else {
            // ✅ CRITIQUE: Si pas de date, activer le bouton immédiatement
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isCountdownFinished = true
                self.onValidationChanged?(true)
            }
            return
        }

        // ✅ Annuler la Task précédente si elle existe
        countdownTask?.cancel()

        let calendar = Calendar.current
        let now = Date()
        let daysDifference = calendar.dateComponents([.day], from: now, to: date).day ?? 0

        // ✅ Commencer avec une valeur plus élevée pour l'effet de décompte
        let initialDays = max(daysDifference, Int(Double(daysDifference) * 1.2))
        countdownDays = initialDays

        // ✅ Animer progressivement vers la valeur réelle avec la durée synchronisée
        let steps = abs(initialDays - daysDifference)

        // ✅ Marquer que le compteur n'est pas encore fini (mais ne pas activer le bouton ici)
        // Le bouton sera activé par animateDateFrom() quand les vibrations finissent
        isCountdownFinished = false

        if steps > 0 {
            let stepInterval = totalDuration / Double(steps)
            let direction = initialDays > daysDifference ? -1 : 1

            countdownTask = Task { @MainActor in
                var currentDays = initialDays

                while currentDays != daysDifference {
                    // ✅ Vérifier si la Task a été annulée
                    if Task.isCancelled {
                        return
                    }

                    currentDays += direction

                    withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) {
                        countdownDays = currentDays
                    }

                    // ✅ PAS DE VIBRATION ICI - Les vibrations sont gérées par l'animation de date (animateDateFrom)
                    // PAS DE VIBRATION FINALE ICI - Elle sera gérée par animateDateFrom()

                    try? await Task.sleep(nanoseconds: UInt64(stepInterval * 1_000_000_000))

                    // ✅ Vérifier à nouveau après le sleep
                    if Task.isCancelled {
                        return
                    }
                }

                // ✅ Ne pas activer le bouton ici - il sera activé par animateDateFrom()
                // Le compteur de jours finit, mais le bouton attend que les vibrations finissent aussi
            }
        } else {
            countdownDays = daysDifference
            // ✅ Si pas d'animation, ne pas activer immédiatement si on attend l'animation de date
            // (mais on peut activer si il n'y a pas d'animation de date)
        }
    }

    // MARK: - Computed Views

    // Graphique avec design exact de ProcessResultsDurabilityStepView
    // ✅ isSecondEstimation: true si on affiche la date initiale (avant animation vers date finale plus courte)
    private func graphViewWithDurabilityStyle(for date: Date, isSecondEstimation: Bool = false) -> some View {
        let screenWidth = UIScreen.main.bounds.width - 80 // ✅ Largeur de l'écran moins les paddings
        let service = GoalProjectionService.shared
        let curveData = service.generateProgressCurveData(
            startDate: Date(),
            endDate: date,
            currentValue: currentWeight,
            targetValue: idealWeight,
            isWeightGoal: true,
            weightGoal: weightGoal
        )

        // ✅ Calculer directement le nombre de jours final (sans animation)
        let calendar = Calendar.current
        let now = Date()
        let finalCountdownDays = max(0, calendar.dateComponents([.day], from: now, to: date).day ?? 0)

        return VStack(spacing: 0) { // ✅ Pas d'espacement pour que le graphique commence au même endroit que l'encadré
            GeometryReader { graphGeometry in
                let width = graphGeometry.size.width > 0 ? graphGeometry.size.width : screenWidth
                let height: CGFloat = 200

                // Convertir curveData en points pour le graphique - SIMPLIFIÉ (seulement 6 points)
                let simplifiedData: [Double] = {
                    var baseData: [Double]

                    if curveData.count <= 6 {
                        baseData = curveData.map { data in
                            let minValue = min(currentWeight, idealWeight)
                            let maxValue = max(currentWeight, idealWeight)
                            let valueRange = max(maxValue - minValue, 0.1)
                            return (data.value - minValue) / valueRange
                        }
                    } else {
                        // Prendre seulement 6 points équitablement répartis
                        let step = max(1, curveData.count / 6)
                        baseData = Array(stride(from: 0, to: curveData.count, by: step).prefix(6)).map { index in
                            let data = curveData[index]
                            let minValue = min(currentWeight, idealWeight)
                            let maxValue = max(currentWeight, idealWeight)
                            let valueRange = max(maxValue - minValue, 0.1)
                            return (data.value - minValue) / valueRange
                        }
                    }

                    // ✅ DEUXIÈME ESTIMATION: Accélérer la progression pour atteindre l'objectif plus tôt
                    // Faire en sorte que l'avant-dernier point soit déjà à 100% (0 pour perte de poids, 1 pour gain)
                    let isGainWeightForCurve = weightGoal == .gain
                    if isSecondEstimation && baseData.count >= 2 {
                        let targetValue = isGainWeightForCurve ? 1.0 : 0.0
                        // Modifier l'avant-dernier point pour qu'il soit proche de la cible
                        var acceleratedData = baseData
                        let secondLastIndex = acceleratedData.count - 2
                        if secondLastIndex >= 0 {
                            // Interpoler pour que l'avant-dernier point soit à ~95% de la cible
                            let progress = 0.95
                            acceleratedData[secondLastIndex] = baseData[secondLastIndex] + (targetValue - baseData[secondLastIndex]) * progress
                            // Le dernier point est à 100%
                            acceleratedData[acceleratedData.count - 1] = targetValue
                        }
                        return acceleratedData
                    }

                    return baseData
                }()

                // Calculer les points simplifiés selon le type de poids
                // ✅ Perte de poids : commence en haut, finit en bas
                // ✅ Prise de poids : commence en bas, finit en haut
                let isGainWeight = weightGoal == .gain
                let allProgressPoints = calculateSimpleSmoothPoints(data: simplifiedData, width: width, height: height, isAscending: isGainWeight)

                // ✅ Utiliser tous les points pour construire le Path, mais ne dessiner que jusqu'à la progression
                let adjustedProgressPoints = allProgressPoints

                return ZStack {
                    // ✨ Rectangle sombre en fond (EXACTEMENT comme ProcessResultsDurabilityStepView)
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
                        .opacity(curveAnimationProgress)
                    }

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
            .frame(height: 200)

            // Labels "Aujourd'hui" et le mois sous le rectangle
            HStack {
                Text("Aujourd'hui")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.leading, 4) // ✅ Plus à gauche
                Spacer()
                Text(formatMonth(date))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.trailing, 20) // ✅ Plus à droite
            }
            .padding(.horizontal, 8)
            .padding(.top, 8) // ✅ Plus bas (augmenté de -4 à 8)
        }
        .padding(.horizontal, 60) // ✅ Ajouté pour rendre le rectangle moins large horizontalement
    }

    // ✅ Fonction pour calculer les points simplifiés
    // ✅ isAscending: true = commence en bas finit en haut (prise de poids/potentiel), false = commence en haut finit en bas (perte de poids)
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
}
