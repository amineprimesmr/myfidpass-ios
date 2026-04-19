//
//  HealthDataAnimationStepView+AnimationLogic.swift
//  Process
//
//  Chargement HealthKit, animations séquentielles et helpers — extrait de HealthDataAnimationStepView.
//

import SwiftUI
import FirebaseAuth
import HealthKit

extension HealthDataAnimationStepView {
    func getSleepDebtTypes() -> [String] {
        // ✅ TOUJOURS afficher les valeurs récupérées, même si elles sont à 0
        var types: [String] = []

        // ✅ Afficher les pas avec la valeur récupérée
        types.append("Nombre de pas : \(displaySteps) / 9500")

        // ✅ Afficher les calories avec la valeur récupérée
        let calories = Int(displayCalories)
        let targetCalories = max(500, calories + 500) // Au moins 500 si calories = 0
        types.append("Calories total : \(calories)kcal / \(targetCalories)kcal")

        // ✅ Afficher le score d'effort avec la valeur récupérée
        let effortScore = Int(displayEffortScore)
        types.append("Score effort aujourd'hui : \(effortScore)%")

        return types
    }
    func getSleepPatternTypes() -> [String] {
        // ✅ TOUJOURS formater et afficher les données, même si elles sont à 0
        // Formater l'heure de coucher
        let bedtimeString: String
        if let bedtime = displayBedtime {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.locale = Locale(identifier: "fr_FR")
            bedtimeString = formatter.string(from: bedtime)
        } else {
            bedtimeString = "--:--"
        }

        // Formater la durée de sommeil (heures:minutes)
        let sleepDurationHours = Int(displaySleepDuration)
        let sleepDurationMinutes = Int((displaySleepDuration - Double(sleepDurationHours)) * 60)
        let sleepDurationString = String(format: "%02d:%02d", sleepDurationHours, sleepDurationMinutes)

        // Formater la dette de sommeil (heures:minutes)
        let sleepDebtHours = Int(displaySleepDebt)
        let sleepDebtMinutes = Int((displaySleepDebt - Double(sleepDebtHours)) * 60)
        let sleepDebtString = String(format: "%dh%02d", sleepDebtHours, sleepDebtMinutes)

        // ✅ Si on a des données valides, afficher avec les valeurs, sinon juste les labels
        if hasValidSleepData {
            return [
                "Heure de coucher : \(bedtimeString)",
                "Durée de sommeil : \(sleepDurationString)",
                "Dette de sommeil : \(sleepDebtString)"
            ]
        } else {
            // Afficher quand même les valeurs récupérées (même si 0) pour debug
            return [
                "Heure de coucher : \(bedtimeString)",
                "Durée de sommeil : \(sleepDurationString)",
                "Dette de sommeil : \(sleepDebtString)"
            ]
        }
    }
    func getValue(for key: String) -> String {
        let value: String

        switch key {
        case "steps":
            value = "\(displaySteps)"
        case "activeEnergyBurned":
            value = String(format: "%.0f", displayCalories)
        case "flightsClimbed":
            value = "\(displayFloors)"
        case "heartRate":
            value = String(format: "%.0f", displayHeartRate)
        case "effortScore":
            value = String(format: "%.0f", displayEffortScore)
        default:
            value = "0"
        }

        return value
    }

    func loadHealthData() async {
        // ✨ Étape 0 : Récupérer les vraies sources de données HealthKit
        await fetchRealDataSources()

        // ✨ Démarrer le compteur en parallèle dès l'arrivée sur la page (ne bloque pas)
        async let counterTask = animateDaysCounter()

        // ✨ Étape 1 : Animer les sources de données (en parallèle avec le compteur)
        await animateSources()

        // ✨ Attendre que l'animation des sources soit complétée (délai de 1 seconde déjà dans animateHealthSources)
        // On attend ici que sourcesAnimationComplete soit true avant de continuer
        while !sourcesAnimationComplete {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 secondes
        }

        // ✨ DÉMARRER IMMÉDIATEMENT "Aujourd'hui" dès que les sources deviennent compactes
        // ✨ Afficher la section "Aujourd'hui" immédiatement (titre + compteur)
        await MainActor.run {
            currentSection = .myViewpoint
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                showMyViewpointContent = true
                showDataSection = true
            }
        }

        // ✅ CRITIQUE: Lancer le timer de sécurité AVANT tout (garantit que le bouton apparaîtra toujours)
        Task {
            try? await Task.sleep(nanoseconds: 12_000_000_000) // 12 secondes - délai de sécurité absolu
            await MainActor.run {
                Logger.debug("[HealthDataAnimation] Affichage automatique du bouton Continuer (timer de sécurité 12s)", category: "HealthDataAnimation")
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showContinueButton = true
                }
            }
        }

        // ✨ Charger les données HealthKit (nécessaires pour les animations)
        // ✅ CRITIQUE: Attendre que les données soient chargées AVANT de démarrer l'animation
        // Sinon l'animation affichera des valeurs à 0
        await loadHealthKitData()

        // ✅ Démarrer l'animation APRÈS que les données soient chargées
        await animateMyViewpoint()

        // ✨ Le compteur continue en arrière-plan, on ne l'attend pas
        // (il se terminera naturellement)
    }

    // ✨ Animation du compteur de jours (0 à 364) - beaucoup plus lent
    func animateDaysCounter() async {
        // Initialiser le compteur à 0
        await MainActor.run {
            daysFound = 0
        }

        // ✨ Démarrer l'animation du compteur immédiatement (0 à 364) - beaucoup plus lent
        let targetDays = 364
        let animationDuration: UInt64 = 5_000_000_000 // 5 secondes (beaucoup plus lent)
        let steps = 200 // Nombre d'étapes pour une animation fluide

        // ✨ Animer le compteur progressivement de 0 à 364
        for step in 0...steps {
            let delay = animationDuration / UInt64(steps)
            try? await Task.sleep(nanoseconds: delay)

            // Calculer la valeur actuelle basée sur la progression
            let currentValue = Int(Double(targetDays) * (Double(step) / Double(steps)))

            await MainActor.run {
                withAnimation(.linear(duration: 0.05)) {
                    daysFound = currentValue
                }
            }
        }

        // ✨ S'assurer qu'on arrive à 364
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.3)) {
                daysFound = 364
            }
        }
    }

    // ✨ Récupérer TOUTES les vraies sources de données HealthKit (toutes les apps et appareils)
    func fetchRealDataSources() async {
        // ✨ Vérifier explicitement si Apple Watch est connectée (via AppleWatchService)
        await appleWatchService.refreshWatchConnectionStatus()
        let hasAppleWatch = appleWatchService.isWatchConnected || appleWatchService.isWatchPaired

        // ✨ Types de données HealthKit à interroger pour trouver TOUTES les sources
        // ✨ Convertir en HKSampleType car HKSourceQuery nécessite HKSampleType
        let dataTypes: [HKSampleType] = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .heartRate),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            HKObjectType.quantityType(forIdentifier: .flightsClimbed)
        ].compactMap { $0 as? HKSampleType } // ✨ Convertir en HKSampleType et retirer les nil

        // ✨ Collecter toutes les sources de tous les types de données (en parallèle)
        let allSources = await withTaskGroup(of: Set<HKSource>.self) { group in
            for dataType in dataTypes {
                group.addTask {
                    await withCheckedContinuation { continuation in
                        let sourceQuery = HKSourceQuery(sampleType: dataType, samplePredicate: nil) { _, sources, error in
                            var foundSources: Set<HKSource> = []

                            if let error = error {
                                Logger.debug("Erreur récupération sources pour \(dataType): \(error.localizedDescription)", category: "HealthDataAnimation")
                            } else if let sources = sources {
                                // Ajouter toutes les sources trouvées
                                for source in sources {
                                    foundSources.insert(source)
                                }
                            }

                            continuation.resume(returning: foundSources)
                        }

                        healthManager.executeQuery(sourceQuery)
                    }
                }
            }

            // Fusionner toutes les sources trouvées
            var mergedSources: Set<HKSource> = []
            for await sources in group {
                mergedSources.formUnion(sources)
            }

            return mergedSources
        }

        // ✨ Nettoyer et formater les noms des sources
        await MainActor.run {
            var cleanedSources: [String] = []
            var hasWatchSource = false

            for source in allSources {
                let name = source.name

                // Normaliser les noms connus
                if name.contains("Watch") || name.contains("watch") || name == "Apple Watch" {
                    hasWatchSource = true
                    if !cleanedSources.contains("Apple Watch") {
                        cleanedSources.append("Apple Watch")
                    }
                } else if name.contains("iPhone") || name == "iPhone" || name == "Health" {
                    if !cleanedSources.contains("iPhone") {
                        cleanedSources.append("iPhone")
                    }
                } else if name.contains("WHOOP") || name.contains("Whoop") {
                    if !cleanedSources.contains("WHOOP") {
                        cleanedSources.append("WHOOP")
                    }
                } else if name.contains("Garmin") {
                    if !cleanedSources.contains("Garmin") {
                        cleanedSources.append("Garmin")
                    }
                } else if name.contains("Bevel") {
                    if !cleanedSources.contains("Bevel") {
                        cleanedSources.append("Bevel")
                    }
                } else if name.contains("QWatch") || name.contains("Qwatch") {
                    // Ignorer QWatch Pro (supprimé)
                } else {
                    // ✨ Ajouter TOUTES les autres sources telles quelles (apps tierces, appareils, etc.)
                    if !cleanedSources.contains(name) && !name.isEmpty {
                        cleanedSources.append(name)
                    }
                }
            }

            // ✨ Si Apple Watch est connectée mais pas détectée dans les sources, l'ajouter quand même
            if hasAppleWatch && !hasWatchSource && !cleanedSources.contains("Apple Watch") {
                cleanedSources.insert("Apple Watch", at: 0) // Ajouter en premier
                Logger.debug("Apple Watch détectée via AppleWatchService mais pas dans sources HealthKit - ajoutée manuellement", category: "HealthDataAnimation")
            }

            // ✨ Si Apple Watch n'est PAS connectée mais détectée dans les sources, la retirer
            if !hasAppleWatch && cleanedSources.contains("Apple Watch") {
                cleanedSources.removeAll { $0 == "Apple Watch" }
                Logger.debug("Apple Watch détectée dans sources HealthKit mais non connectée - retirée", category: "HealthDataAnimation")
            }

            // Si aucune source trouvée, utiliser un fallback
            if cleanedSources.isEmpty {
                if hasAppleWatch {
                    cleanedSources = ["iPhone", "Apple Watch"]
                } else {
                    cleanedSources = ["iPhone"]
                }
            }

            // ✨ Toujours ajouter iPhone si pas présent (source par défaut)
            if !cleanedSources.contains("iPhone") {
                cleanedSources.insert("iPhone", at: 0)
            }

            self.realDataSources = cleanedSources
            Logger.debug("TOUTES les sources réelles trouvées: \(cleanedSources) (Apple Watch connectée: \(hasAppleWatch), Total sources HealthKit: \(allSources.count))", category: "HealthDataAnimation")
        }
    }

    // ✨ Animation des sources de données avec 2 sous-parties
    func animateSources() async {
        currentSection = .sources

        // Attendre que les vraies sources soient chargées
        while realDataSources.isEmpty {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 secondes
        }

        // ✨ D'abord, afficher le contenu de la section Sources de données
        await MainActor.run {
            withAnimation(.easeIn(duration: 0.5)) {
                showSourcesContent = true
            }
        }

        // Attendre un peu avant de commencer les animations
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 secondes (plus rapide)

        // ✨ Charger "Mouvement du téléphone" et "Santé Apple" en parallèle
        async let phoneTask = animatePhoneMovement()
        async let healthDataTypesTask = animateHealthDataTypes()

        // Attendre que les deux soient terminés
        await phoneTask
        await healthDataTypesTask

        // ✨ Étape 3 : Animer "Santé Apple" - Sources
        await animateHealthSources()
    }

    // ✨ Animation "Mouvement du téléphone"
    func animatePhoneMovement() async {
        // ✨ Animer la barre de progression de 0 à 1 de manière irrégulière (plus rapide)
        let totalDuration: Double = 1.5 // 1.5 secondes (plus rapide)
        let steps = 20 // Nombre d'étapes réduit pour plus de rapidité

        for step in 0...steps {
            // ✨ Créer une progression irrégulière avec une courbe d'accélération/décélération variable
            let progress = Double(step) / Double(steps)
            // Utiliser une fonction d'ease-in-out avec des variations pour rendre irrégulier
            let easedProgress = easeInOutIrregular(progress)

            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    phoneMovementProgress = easedProgress
                }
            }

            // ✨ Délai variable pour rendre l'animation irrégulière (plus lent au début, plus rapide au milieu, ralentit à la fin)
            let baseDelay = totalDuration / Double(steps)
            let variation = Double.random(in: 0.8...1.2) // Variation de ±20%
            let delay = baseDelay * variation

            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        // S'assurer qu'on arrive à 100%
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.2)) {
                phoneMovementProgress = 1.0
            }
        }

        HapticManager.shared.selection()
    }

    // ✨ Fonction helper pour créer une progression irrégulière
    func easeInOutIrregular(_ t: Double) -> Double {
        // Fonction ease-in-out de base
        let base = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
        // Ajouter des variations pour rendre irrégulier
        let variation = sin(t * .pi * 3) * 0.05 // Petite variation sinusoïdale
        return min(1.0, max(0.0, base + variation))
    }

    // ✨ Animation des types de données "Santé Apple"
    func animateHealthDataTypes() async {
        for dataType in healthDataTypes {
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 secondes (plus rapide)

            let loadingDuration = Double.random(in: 0.4...0.7) // Plus rapide
            try? await Task.sleep(nanoseconds: UInt64(loadingDuration * 1_000_000_000))

            await MainActor.run {
                withAnimation {
                    completedDataTypes.insert(dataType)
                }
                // Mettre à jour la barre de progression (basée sur toutes les sources réelles)
                let sourcesToAnimate = Array(realDataSources.prefix(10))
                let totalItems = healthDataTypes.count + sourcesToAnimate.count
                appleHealthProgress = Double(completedDataTypes.count) / Double(totalItems)
            }

            HapticManager.shared.selection()
        }
    }

    // ✨ Animation des sources "Santé Apple"
    func animateHealthSources() async {
        // ✅ CORRECTION: Animer TOUTES les sources réelles trouvées (pas seulement celles dans defaultHealthSources)
        // Limiter à 10 sources max pour l'animation (trop de sources rendrait l'UI illisible)
        let realSourcesToAnimate = Array(realDataSources.prefix(10))

        for source in realSourcesToAnimate {
            // ✨ Afficher l'indicateur de chargement
            await MainActor.run {
                withAnimation {
                    loadingHealthSources.insert(source)
                }
            }

            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 secondes (plus rapide)

            // Simuler un chargement (plus rapide)
            let loadingDuration = Double.random(in: 0.4...0.8)
            try? await Task.sleep(nanoseconds: UInt64(loadingDuration * 1_000_000_000))

            await MainActor.run {
                withAnimation {
                    loadingHealthSources.remove(source) // Retirer le loading
                    completedHealthSources.insert(source)
                    completedSources.insert(source) // Garder pour compatibilité
                }
                // Mettre à jour la barre de progression avec animation fluide (basée sur toutes les sources réelles)
                let sourcesToAnimate = Array(realDataSources.prefix(10))
                let totalItems = healthDataTypes.count + sourcesToAnimate.count
                let newProgress = Double(completedDataTypes.count + completedHealthSources.count) / Double(totalItems)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    appleHealthProgress = newProgress
                }
            }

            HapticManager.shared.selection()
        }

        // S'assurer que la barre est à 100%
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.3)) {
                appleHealthProgress = 1.0
            }
        }

        // ✨ Attendre 1 seconde pour voir toutes les données validées
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde

        // ✨ Marquer l'animation des sources comme complétée pour déclencher la transition
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                sourcesAnimationComplete = true
            }
        }
    }

    // ✨ Animation des types de données "Besoin de sommeil" (anciennement "Patterns de sommeil")
    func animateSleepPatternTypes() async {
        let types = getSleepPatternTypes()
        for dataType in types {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 secondes (réduit de 0.3s)

            let loadingDuration = Double.random(in: 0.3...0.5) // Plus rapide (réduit de 0.8-1.2s)
            try? await Task.sleep(nanoseconds: UInt64(loadingDuration * 1_000_000_000))

            await MainActor.run {
                withAnimation {
                    completedSleepPattern.insert(dataType)
                }
                // Mettre à jour la barre de progression (basée sur les types uniquement)
                sleepPatternProgress = Double(completedSleepPattern.count) / Double(types.count)
            }

            HapticManager.shared.selection()
        }

        // S'assurer que la barre est à 100%
        await MainActor.run {
            withAnimation {
                sleepPatternProgress = 1.0
            }
        }

        // Attendre un peu avant de passer à la section suivante (plus rapide)
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 secondes (réduit de 0.5s)
    }

    // ✨ Animation "Aujourd'hui" (identique à "Sources de données")
    // ✨ NOTE: La section "Aujourd'hui" est déjà affichée dans loadHealthData()
    // Cette fonction anime uniquement les sous-sections
    func animateMyViewpoint() async {
        // ✨ Les données HealthKit sont déjà chargées, on peut commencer immédiatement
        // Attendre juste un peu pour que l'apparition de la section soit visible
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 secondes

        // ✨ Étape 1 : Animer "Besoin de sommeil" (anciennement "Patterns de sommeil") - Types de données (la barre se remplit progressivement)
        await animateSleepPatternTypes()

        // ✨ Étape 2 : Animer les sections DATA (en même temps que les autres)
        await animateDataSection()

        // ✨ Vérifier que toutes les données sont complétées et afficher le texte de complétion
        let allSleepPatternCompleted = completedSleepPattern.count == getSleepPatternTypes().count
        let allSleepNeedCompleted = completedSleepNeed.count == sleepNeedTypes.count
        let allSleepDebtCompleted = completedSleepDebt.count == getSleepDebtTypes().count

        if allSleepPatternCompleted && allSleepNeedCompleted && allSleepDebtCompleted {
            // Attendre un peu avant d'afficher le texte
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 secondes

            await MainActor.run {
                withAnimation(.easeIn(duration: 0.5)) {
                    showCompletionText = true
                }
            }
        }

        // ✅ CRITIQUE: Toujours afficher le bouton Continuer après les animations (si le timer de sécurité ne l'a pas déjà fait)
        // Attendre que toutes les animations soient terminées
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde après la fin des animations

        await MainActor.run {
            // Ne mettre à true que si pas déjà true (pour éviter les conflits avec le timer de sécurité)
            if !showContinueButton {
                Logger.debug("[HealthDataAnimation] Affichage du bouton Continuer (après animations, données: sommeil=\(displaySleepDuration)h, coucher=\(displayBedtime != nil ? "oui": "non"))", category: "HealthDataAnimation")
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showContinueButton = true
                }
            }
        }
    }

    // ✨ Animation de la section DATA (identique aux autres sections)
    // ✨ Note: showDataSection est maintenant géré dans animateMyViewpoint()
    func animateDataSection() async {
        // Attendre un peu avant de commencer les animations (plus rapide)
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 secondes (réduit de 0.2s)

        // ✨ Étape 1 : Animer "Récupération" (anciennement "Besoin de sommeil") - Types de données (la barre se remplit progressivement)
        await animateSleepNeedTypes()

        // ✨ Étape 2 : Animer "Capacité d'entrainement" (anciennement "Dette de sommeil") - Types de données (la barre se remplit progressivement)
        await animateSleepDebtTypes()

        // Attendre un peu avant de passer à la section suivante (plus rapide)
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 secondes (réduit de 0.5s)
    }

    // ✨ Animation des types de données "Besoin de sommeil"
    func animateSleepNeedTypes() async {
        for dataType in sleepNeedTypes {
            try? await Task.sleep(nanoseconds: 80_000_000) // 0.08 secondes (réduit de 0.15s)

            let loadingDuration = Double.random(in: 0.2...0.4) // Plus rapide (réduit de 0.4-0.7s)
            try? await Task.sleep(nanoseconds: UInt64(loadingDuration * 1_000_000_000))

            await MainActor.run {
                withAnimation {
                    completedSleepNeed.insert(dataType)
                }
                // Mettre à jour la barre de progression avec animation fluide (uniquement pour cette sous-partie)
                let newProgress = Double(completedSleepNeed.count) / Double(sleepNeedTypes.count)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    sleepNeedProgress = newProgress
                }
            }

            HapticManager.shared.selection()
        }

        // S'assurer que la barre est à 100% pour cette sous-partie
        await MainActor.run {
            withAnimation {
                sleepNeedProgress = 1.0
            }
        }
    }

    // ✨ Animation des types de données "Capacité d'entrainement"
    func animateSleepDebtTypes() async {
        let types = getSleepDebtTypes()
        for dataType in types {
            try? await Task.sleep(nanoseconds: 80_000_000) // 0.08 secondes (réduit de 0.15s)

            let loadingDuration = Double.random(in: 0.2...0.4) // Plus rapide (réduit de 0.4-0.7s)
            try? await Task.sleep(nanoseconds: UInt64(loadingDuration * 1_000_000_000))

            await MainActor.run {
                withAnimation {
                    completedSleepDebt.insert(dataType)
                }
                // Mettre à jour la barre de progression avec animation fluide (uniquement pour cette sous-partie)
                let newProgress = Double(completedSleepDebt.count) / Double(types.count)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    sleepDebtProgress = newProgress
                }
            }

            HapticManager.shared.selection()
        }

        // S'assurer que la barre est à 100% pour cette sous-partie
        await MainActor.run {
            withAnimation {
                sleepDebtProgress = 1.0
            }
        }
    }

    // ✨ Chargement des données HealthKit avec fallback robuste (aujourd'hui -> hier -> avant-hier)
    func loadHealthKitData() async {
        await MainActor.run {
            isLoadingData = true
        }

        // Vérifier si l'utilisateur est authentifié
        guard let currentUser = Auth.auth().currentUser else {
            Logger.error("HealthDataAnimation - Aucun utilisateur authentifié", category: "General")
            await MainActor.run {
                isLoadingData = false
                startAnimation()
            }
            return
        }

        // ✅ CRITIQUE: Vérifier et forcer la vérification des permissions HealthKit
        // Parfois isAuthorized n'est pas à jour après la page de permissions
        if !healthManager.isAuthorized {
            Logger.warning("[HealthDataAnimation] HealthKit non autorisé selon isAuthorized, mais on va essayer quand même...", category: "HealthDataAnimation")
            // Essayer quand même de récupérer les données (HealthKit peut retourner des données même si isAuthorized est false)
            // Apple cache le vrai statut pour la vie privée
        } else {
            Logger.debug("[HealthDataAnimation] HealthKit autorisé selon isAuthorized", category: "HealthDataAnimation")
        }

        // ✅ Note: La vérification des permissions sera faite automatiquement par HealthKit
        // lors de la récupération des données. Pas besoin de vérifier explicitement ici.
        Logger.debug("[HealthDataAnimation] Début de la récupération des données HealthKit", category: "HealthDataAnimation")

        let calendar = Calendar.current
        let today = Date()

        // ✅ CRITIQUE: Essayer jusqu'à 7 jours en arrière pour trouver les dernières données disponibles
        var foundData = false
        var bestDate = today
        let maxDaysBack = 7

        for dayOffset in 0...maxDaysBack {
            let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today

            let dateLabel = dayOffset == 0 ? "aujourd'hui" : (dayOffset == 1 ? "hier" : dayOffset == 2 ? "avant-hier" : "jour -\(dayOffset)")
            Logger.debug("[HealthDataAnimation] Tentative récupération données pour \(dateLabel)", category: "HealthDataAnimation")

            // ✅ CRITIQUE: Récupérer les données DIRECTEMENT depuis HealthKit pour la date cible
            // Ne PAS utiliser les propriétés @Published (steps, activeEnergyBurned, etc.) car elles sont
            // toujours pour le jour actuel, pas pour targetDate !
            Logger.debug("[HealthDataAnimation] Récupération directe des données HealthKit pour \(dateLabel)", category: "HealthDataAnimation")

            // ✅ Étape 1 : Vérifier les permissions AVANT de récupérer les données
            let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)
            let caloriesType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)

            if let stepsType = stepsType {
                let stepsAuth = healthManager.authorizationStatus(for: stepsType)
                Logger.debug("[HealthDataAnimation] Permission steps pour \(dateLabel): \(stepsAuth.rawValue)", category: "HealthDataAnimation")
            }
            if let caloriesType = caloriesType {
                let caloriesAuth = healthManager.authorizationStatus(for: caloriesType)
                Logger.debug("[HealthDataAnimation] Permission calories pour \(dateLabel): \(caloriesAuth.rawValue)", category: "HealthDataAnimation")
            }
            if let sleepType = sleepType {
                let sleepAuth = healthManager.authorizationStatus(for: sleepType)
                Logger.debug("[HealthDataAnimation] Permission sommeil pour \(dateLabel): \(sleepAuth.rawValue)", category: "HealthDataAnimation")
            }

            // ✅ Étape 2 : Récupérer les métriques pour la date spécifique
            Logger.debug("[HealthDataAnimation] Appel getHealthMetricsForDate pour \(dateLabel)...", category: "HealthDataAnimation")
            let healthMetrics = await healthManager.getHealthMetricsForDate(targetDate)

            let steps = healthMetrics.totalSteps
            let calories = healthMetrics.activeCalories
            let floors = healthMetrics.totalFloors
            let heartRate = healthMetrics.avgHeartRate

            Logger.debug("[HealthDataAnimation] Données HealthKit récupérées pour \(dateLabel) - Steps: \(steps), Calories: \(String(format: "%.0f", calories)), Floors: \(floors), HeartRate: \(String(format: "%.0f", heartRate))", category: "HealthDataAnimation")

            // ✅ Étape 2 : Vérifier si on a des données valides
            let hasValidData = steps > 0 || calories > 0 || floors > 0

            // ✅ OPTIMISATION: Ne PAS appeler syncHealthDataForDate() ici
            // car ça déclenche tous les calculs lourds (Recovery, Sleep, Effort scores)
            // qui bloquent l'affichage. On le fera EN ARRIÈRE-PLAN après l'animation.

            if hasValidData {
                Logger.debug("[HealthDataAnimation] Données valides trouvées pour \(dateLabel) - Steps: \(steps), Calories: \(String(format: "%.0f", calories))", category: "HealthDataAnimation")
                bestDate = targetDate
                foundData = true

                // ✅ OPTIMISATION: Mettre à jour l'UI IMMÉDIATEMENT avec les données récupérées
                await MainActor.run {
                    displaySteps = steps
                    displayCalories = calories
                    displayFloors = floors
                    displayHeartRate = heartRate
                    hasValidStepsData = steps > 0
                    hasValidCaloriesData = calories > 0
                }

                break
            } else if dayOffset < 3 {
                // Logger seulement pour les 3 premiers jours
                Logger.debug("[HealthDataAnimation] Pas de données valides pour \(dateLabel) (Steps: \(steps), Calories: \(String(format: "%.0f", calories))), essai suivant...", category: "HealthDataAnimation")
            }
        }

        // ✅ OPTIMISATION: Lancer la synchronisation lourde EN ARRIÈRE-PLAN
        // pour ne pas bloquer l'affichage des données
        if foundData {
            Task.detached(priority: .background) {
                Logger.debug("[HealthDataAnimation] Synchronisation lourde en arrière-plan...", category: "HealthDataAnimation")
                await self.healthManager.syncHealthDataForDate(bestDate)
                await self.dataManager.updateCurrentDayData(with: self.healthManager)
                Logger.debug("[HealthDataAnimation] Synchronisation arrière-plan terminée", category: "HealthDataAnimation")
            }
        } else {
            Logger.warning("[HealthDataAnimation] Aucune donnée valide trouvée dans les 7 derniers jours", category: "HealthDataAnimation")
        }

        // ✅ Étape 5 : Récupérer les données de sommeil avec fallback ET timeout
        var sleepDuration: Double = 0.0
        var bedtime: Date?
        var sleepDebt: Double = 0.0

        // ✅ CORRECTION: Essayer de récupérer le sommeil avec timeout pour éviter de bloquer
        // Utiliser le même maxDaysBack que pour les autres données (déjà défini plus haut)
        var foundSleepData = false

        for dayOffset in 0...maxDaysBack {
            let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            let dateLabel = dayOffset == 0 ? "aujourd'hui" : (dayOffset == 1 ? "hier" : dayOffset == 2 ? "avant-hier" : "jour -\(dayOffset)")

            Logger.debug("[HealthDataAnimation] Recherche données de sommeil pour \(dateLabel)", category: "HealthDataAnimation")

            // ✅ CRITIQUE: Essayer d'abord getSleepDurationForDate directement (gère le cache et la récupération)
            // Cette fonction peut fonctionner même si refreshSleepDataForDate est ignoré
            var duration = await healthManager.getSleepDurationForDate(targetDate)

            Logger.debug("[HealthDataAnimation] Première tentative getSleepDurationForDate pour \(dateLabel): \(String(format: "%.2f", duration))h", category: "HealthDataAnimation")

            // ✅ OPTIMISATION: Si on n'a pas de données, essayer un refresh SANS délai d'attente
            if duration == 0.0 {
                Logger.debug("[HealthDataAnimation] Aucune donnée trouvée, tentative refresh pour \(dateLabel)", category: "HealthDataAnimation")
                await healthManager.refreshSleepDataForDate(targetDate)

                // ✅ OPTIMISATION: Pas de délai - réessayer immédiatement
                duration = await healthManager.getSleepDurationForDate(targetDate)
                Logger.debug("[HealthDataAnimation] Après refresh pour \(dateLabel): \(String(format: "%.2f", duration))h", category: "HealthDataAnimation")
            }

            if duration > 0 {
                sleepDuration = duration
                foundSleepData = true

                // Récupérer les échantillons de sommeil pour détecter l'heure de coucher
                let sleepSamples = await healthManager.fetchSleepDataIntelligent(for: targetDate)

                Logger.debug("[HealthDataAnimation] \(sleepSamples.count) échantillons de sommeil récupérés pour \(dateLabel)", category: "HealthDataAnimation")

                if !sleepSamples.isEmpty {
                    // ✅ Détecter l'heure de coucher : prendre le premier échantillon de sommeil réel (asleep)
                    let asleepSamples = sleepSamples.filter { sample in
                        let value = sample.value
                        return value == HKCategoryValueSleepAnalysis.asleep.rawValue ||
                               value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                               value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                               value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                               value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    }

                    if let firstAsleep = asleepSamples.min(by: { $0.startDate < $1.startDate }) {
                        bedtime = firstAsleep.startDate
                        Logger.debug("[HealthDataAnimation] Heure de coucher détectée: \(bedtime?.description ?? "nil")", category: "HealthDataAnimation")
                    } else {
                        // Fallback: utiliser le premier échantillon inBed
                        let inBedSamples = sleepSamples.filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }
                        if let firstInBed = inBedSamples.min(by: { $0.startDate < $1.startDate }) {
                            bedtime = firstInBed.startDate
                            Logger.debug("[HealthDataAnimation] Heure de coucher (inBed) détectée: \(bedtime?.description ?? "nil")", category: "HealthDataAnimation")
                        } else {
                            // Dernier fallback: premier échantillon tout confondu
                            let sortedSamples = sleepSamples.sorted { $0.startDate < $1.startDate }
                            bedtime = sortedSamples.first?.startDate
                            Logger.debug("[HealthDataAnimation] Heure de coucher (fallback) détectée: \(bedtime?.description ?? "nil")", category: "HealthDataAnimation")
                        }
                    }
                }

                Logger.debug("[HealthDataAnimation] Données de sommeil trouvées pour \(dateLabel): \(String(format: "%.1f", duration))h, coucher: \(bedtime != nil ? "oui": "non")", category: "HealthDataAnimation")
                break
            } else if dayOffset < 3 {
                // Logger seulement pour les 3 premiers jours (aujourd'hui, hier, avant-hier)
                Logger.debug("[HealthDataAnimation] Pas de données de sommeil pour \(dateLabel) (durée: \(duration)h), essai suivant...", category: "HealthDataAnimation")
            }
        }

        // ✅ Si aucune donnée trouvée après 7 jours, logger et continuer avec valeurs par défaut
        if !foundSleepData {
            Logger.warning("[HealthDataAnimation] Aucune donnée de sommeil trouvée dans les 7 derniers jours - utilisation valeurs par défaut", category: "HealthDataAnimation")
        }

        // ✅ Étape 6 : Calculer la dette de sommeil si on a des données de sommeil
        if sleepDuration > 0 {
            // Utiliser une valeur par défaut de 8h pour le besoin de sommeil
            // (le système de calcul de dette est désactivé selon le code)
            let sleepNeed = 8.0
            sleepDebt = max(0.0, sleepNeed - sleepDuration)
        }

        // ✅ Étape 7 : Calculer le score d'effort AVANT d'entrer dans MainActor
        var effortScore: Double = 0.0
        if let dataEffortScore = dataManager.currentEffortData?.effortScore, dataEffortScore > 0 {
            effortScore = dataEffortScore
        } else {
            // Calculer le score d'effort pour la meilleure date
            effortScore = await healthManager.getEffortScoreForDate(bestDate)
        }

        // ✅ CRITIQUE: Récupérer les métriques finales pour bestDate (pas pour aujourd'hui)
        // Ne PAS utiliser les propriétés @Published qui sont toujours pour aujourd'hui
        let finalMetrics = await healthManager.getHealthMetricsForDate(bestDate)

        await MainActor.run {
            isLoadingData = false

            // ✅ Utiliser les données récupérées pour bestDate (pas les propriétés temps réel)
            // Si DataManager a des données, les utiliser, sinon utiliser les métriques récupérées
            let stepsValue = dataManager.currentEffortData?.steps ?? finalMetrics.totalSteps
            let caloriesValue = dataManager.currentEffortData?.activeEnergyBurned ?? finalMetrics.activeCalories
            let floorsValue = dataManager.currentEffortData?.flightsClimbed ?? finalMetrics.totalFloors
            let heartRateValue = dataManager.currentHealthMetricsData?.heartRate ?? finalMetrics.avgHeartRate

            // ✅ CRITIQUE: TOUJOURS assigner les valeurs récupérées, même si elles sont à 0
            displaySteps = stepsValue
            displayCalories = caloriesValue
            displayFloors = floorsValue
            displayHeartRate = heartRateValue
            displayEffortScore = effortScore

            // ✅ Données de sommeil récupérées avec fallback
            displayBedtime = bedtime
            displaySleepDuration = sleepDuration
            displaySleepDebt = sleepDebt

            // ✅ Déterminer si on a vraiment des données valides APRÈS l'assignation
            // Ces flags servent uniquement pour le style d'affichage, pas pour masquer les données
            hasValidStepsData = stepsValue > 0
            hasValidCaloriesData = caloriesValue > 0
            hasValidSleepData = sleepDuration > 0 && foundSleepData
            hasValidEffortScoreData = effortScore > 0

            // ✅ Log détaillé pour diagnostic
            Logger.debug("[HealthDataAnimation] Données assignées - Steps: \(displaySteps), Calories: \(String(format: "%.0f", displayCalories)), Sommeil: \(String(format: "%.2f", displaySleepDuration))h, Coucher: \(displayBedtime != nil ? "oui": "non"), Effort: \(String(format: "%.0f", displayEffortScore))%", category: "HealthDataAnimation")
            Logger.debug("[HealthDataAnimation] Flags de validation - Steps: \(hasValidStepsData), Calories: \(hasValidCaloriesData), Sommeil: \(hasValidSleepData), Effort: \(hasValidEffortScoreData), foundSleepData: \(foundSleepData)", category: "HealthDataAnimation")

            // ✅ Log final pour diagnostic
            let calendar = Calendar.current
            let dayOffset = calendar.dateComponents([.day], from: bestDate, to: today).day ?? 0
            let dateLabel = dayOffset == 0 ? "aujourd'hui" : (dayOffset == 1 ? "hier" : dayOffset == 2 ? "avant-hier" : "jour -\(dayOffset)")
            Logger.debug("[HealthDataAnimation] Données finales - Steps: \(displaySteps) (valide: \(hasValidStepsData)), Calories: \(String(format: "%.0f", displayCalories)) (valide: \(hasValidCaloriesData)), Sommeil: \(String(format: "%.1f", sleepDuration))h (valide: \(hasValidSleepData)), Date utilisée: \(dateLabel)", category: "HealthDataAnimation")

            // Forcer la mise à jour de l'interface
            dataRefreshTrigger = UUID()

            startAnimation()
        }
    }

    func startAnimation() {
        // Animation de 5 secondes
        withAnimation(.easeInOut(duration: 5.0)) {
            animationProgress = 1.0
        }

        // Afficher les données progressivement
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { timer in
            if self.currentDataIndex < self.dataItems.count - 1 {
                self.currentDataIndex += 1
            } else {
                timer.invalidate()
                self.animationTimer = nil

                // ✅ REMOVED: Le bouton Continuer est maintenant géré dans animateMyViewpoint()
                // pour s'assurer qu'il apparaît toujours, même si les données manquent
            }
        }

        // Démarrer l'affichage des données après un court délai
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showData = true
        }
    }

    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

}
