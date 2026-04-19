//
//  OnboardingNavigationEngine.swift
//  Process
//
//  Engine de navigation propre et maintenable pour remplacer la logique fragile
//

import Foundation

@MainActor
class OnboardingNavigationEngine {
    let viewModel: OnboardingViewModel
    let profileService: UnifiedProfileService

    init(viewModel: OnboardingViewModel, profileService: UnifiedProfileService) {
        self.viewModel = viewModel
        self.profileService = profileService
    }

    // MARK: - Next Step

    func getNextStep() -> Int? {
        guard let current = OnboardingStep(rawValue: viewModel.currentStep) else {
            return nil
        }

        // Flow initial
        switch current {
        case .videoIntroduction:
            return OnboardingStep.genderSelection.rawValue
        case .genderSelection:
            return OnboardingStep.ageSelection.rawValue
        case .ageSelection:
            return OnboardingStep.height.rawValue
        case .height:
            return OnboardingStep.weight.rawValue
        case .weight:
            return OnboardingStep.firstNameInput.rawValue // ✅ Supprimé bodyScan, aller directement à firstNameInput
        case .heightWeight:
            return OnboardingStep.firstNameInput.rawValue // ✅ Ancienne page combinée (dépréciée)
        case .firstNameInput:
            return OnboardingStep.personalizedWelcome.rawValue
        case .bodyScan:
            // ✅ Déprécié - rediriger vers firstNameInput si jamais atteint
            return OnboardingStep.firstNameInput.rawValue
        case .personalizedWelcome:
            // ✅ TEMPORAIRE : Skip processResultsDurability, aller directement à primaryGoal
            return OnboardingStep.primaryGoal.rawValue
        case .processResultsDurability:
            return OnboardingStep.primaryGoal.rawValue
        case .primaryGoal:
            return getNextStepAfterPrimaryGoal()
        default:
            break
        }

        // Flow objectifs spécifiques
        if let next = getNextStepInSpecificFlow(from: current) {
            return next
        }

        // Flow nutrition
        if let next = getNextStepInNutritionFlow(from: current) {
            return next
        }

        // Flow sommeil
        if let next = getNextStepInSleepFlow(from: current) {
            return next
        }

        // Flow finalisation
        if let next = getNextStepInFinalizationFlow(from: current) {
            return next
        }

        // Fallback : étape suivante
        let nextIndex = viewModel.currentStep + 1
        return nextIndex < 53 ? nextIndex : nil  // ✅ Corrigé : 53 étapes totales
    }

    // MARK: - Previous Step

    func getPreviousStep() -> Int? {
        guard let current = OnboardingStep(rawValue: viewModel.currentStep) else {
            return nil
        }

        // Flow initial inversé
        switch current {
        case .genderSelection:
            return OnboardingStep.videoIntroduction.rawValue
        case .ageSelection:
            return OnboardingStep.genderSelection.rawValue
        case .height:
            return OnboardingStep.ageSelection.rawValue
        case .weight:
            return OnboardingStep.height.rawValue
        case .bodyScan:
            return OnboardingStep.weight.rawValue // ✅ Déprécié - ne devrait plus être atteint
        case .heightWeight:
            return OnboardingStep.ageSelection.rawValue // ✅ Ancienne page combinée (dépréciée)
        case .firstNameInput:
            return OnboardingStep.weight.rawValue // ✅ Retour direct vers weight (bodyScan supprimé)
        case .personalizedWelcome:
            return OnboardingStep.firstNameInput.rawValue
        case .processResultsDurability:
            return OnboardingStep.personalizedWelcome.rawValue
        case .primaryGoal:
            // ✅ TEMPORAIRE : Skip processResultsDurability, revenir directement à personalizedWelcome
            return OnboardingStep.personalizedWelcome.rawValue
        default:
            break
        }

        // Flow objectifs spécifiques inversé
        if let previous = getPreviousStepInSpecificFlow(from: current) {
            return previous
        }

        // Flow nutrition inversé
        if let previous = getPreviousStepInNutritionFlow(from: current) {
            return previous
        }

        // Flow sommeil inversé
        if let previous = getPreviousStepInSleepFlow(from: current) {
            return previous
        }

        // Flow finalisation inversé
        if let previous = getPreviousStepInFinalizationFlow(from: current) {
            return previous
        }

        // Fallback : étape précédente
        return max(0, viewModel.currentStep - 1)
    }

    // MARK: - Specific Flow (Objectifs)

    private func getNextStepAfterPrimaryGoal() -> Int {
        // Construire la queue des étapes selon les objectifs
        viewModel.pendingSpecificSteps = buildPendingStepsQueue()

        // Prendre la première étape de la queue
        if let firstStep = viewModel.pendingSpecificSteps.first {
            return firstStep.rawValue
        }

        // Si aucun objectif, aller à trainingFrequency
        return OnboardingStep.trainingFrequency.rawValue
    }

    private func buildPendingStepsQueue() -> [OnboardingStep] {
        var queue: [OnboardingStep] = []

        // Ordre de priorité : Poids → Sport → Récupération → Énergie
        if viewModel.selectedPrimaryGoals.contains(.manageWeight) {
            queue.append(.weightGoal)
            // idealWeight sera ajouté après weightGoal si nécessaire
        }

        // ✅ CORRECTION: TOUJOURS ajouter les questions sportives, même si l'objectif est uniquement "changer mon poids"
        // L'utilisateur doit répondre à ces questions pour personnaliser son plan
        queue.append(.hasSportActivity)
        // sportSelection et sportClub seront ajoutés conditionnellement selon hasSportActivity
        queue.append(.experienceLevel)

        return queue
    }

    private func getNextStepInSpecificFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .weightGoal:
            // ✅ NOUVELLE LOGIQUE: Vérifier l'incompatibilité IMC/objectif avant de continuer
            if let weightGoal = viewModel.selectedWeightGoal {
                // Calculer l'IMC actuel
                let height = viewModel.selectedHeight
                let currentWeight = viewModel.selectedWeight
                let heightInMeters = height / 100.0
                let currentBMI = currentWeight / (heightInMeters * heightInMeters)

                // Vérifier l'incompatibilité
                let isIncompatible = (currentBMI >= 25.0 && weightGoal == .gain) || (currentBMI < 18.5 && weightGoal == .lose)

                if isIncompatible {
                    // Rediriger vers la page de blocage
                    return OnboardingStep.weightGoalIncompatible.rawValue
                }

                // Si compatible, continuer normalement
                if weightGoal == .lose || weightGoal == .gain {
                    return OnboardingStep.idealWeight.rawValue
                }
            }
            // Continuer avec la queue après weightGoal
            return getNextStepInQueue(after: .weightGoal) ?? getDeadlineOrTrainingFrequency()

        case .weightGoalIncompatible:
            // ✅ Depuis la page de blocage, l'utilisateur ne peut que revenir en arrière
            // Cette page ne devrait jamais être atteinte en navigation forward
            // Mais au cas où, on retourne à weightGoal
            return OnboardingStep.weightGoal.rawValue

        case .idealWeight:
            return OnboardingStep.weightMotivation.rawValue

        case .weightMotivation:
            return OnboardingStep.goalPace.rawValue

        case .goalPace:
            if viewModel.selectedPrimaryGoals.contains(.manageWeight),
               let weightGoal = viewModel.selectedWeightGoal,
               weightGoal == .lose || weightGoal == .gain,
               viewModel.isIdealWeightEntered {
                return OnboardingStep.weightEstimation.rawValue
            }
            return OnboardingStep.goalProjection.rawValue

        case .weightEstimation:
            // ✅ CORRECTION: Distinguer première et deuxième estimation de poids
            // - Première estimation (avant questions sport) → hasSportActivity
            // - Deuxième estimation (après questions sport) → weightManagementExperience
            // On détecte la deuxième fois si les questions sport ont été répondues
            if viewModel.hasSportActivity != nil || viewModel.selectedExperienceLevel != nil {
                // Deuxième estimation de poids (après questions sport) → aller à weightManagementExperience
                return OnboardingStep.weightManagementExperience.rawValue
            }
            // Première estimation de poids (avant questions sport) → aller aux questions sportives
            return OnboardingStep.hasSportActivity.rawValue

        case .hasSportActivity:
            // Si l'utilisateur pratique un sport, aller à sportSelection
            if viewModel.hasSportActivity == true {
                return OnboardingStep.sportSelection.rawValue
            } else {
                // ✅ NOUVELLE LOGIQUE: Si l'utilisateur ne pratique pas de sport
                // - Si l'utilisateur a choisi "changer mon poids" → aller à weightManagementExperience
                // - Sinon → aller directement à nutritionQuality
                if viewModel.selectedPrimaryGoals.contains(.manageWeight) {
                    return OnboardingStep.weightManagementExperience.rawValue
                } else {
                    return OnboardingStep.nutritionQuality.rawValue
                }
            }

        case .sportSelection:
            return OnboardingStep.sportClub.rawValue

        case .sportClub:
            // ✅ Après « en club » → niveau d'expérience uniquement (plus de page « années d'expérience »)
            return OnboardingStep.experienceLevel.rawValue

        case .experienceLevel:
            if viewModel.selectedPrimaryGoals.contains(.manageWeight),
               let weightGoal = viewModel.selectedWeightGoal,
               weightGoal == .lose || weightGoal == .gain,
               viewModel.isIdealWeightEntered {
                return OnboardingStep.weightEstimation.rawValue
            }
            return getDeadlineOrTrainingFrequency()

        case .yearsOfExperience:
            // Étape supprimée — migration (même sortie qu’après experienceLevel)
            if viewModel.selectedPrimaryGoals.contains(.manageWeight),
               let weightGoal = viewModel.selectedWeightGoal,
               weightGoal == .lose || weightGoal == .gain,
               viewModel.isIdealWeightEntered {
                return OnboardingStep.weightEstimation.rawValue
            }
            return getDeadlineOrTrainingFrequency()

        case .trainingFrequency:
            // Navigation gérée automatiquement par EmptyView().onAppear { nextStep() }
            return nil

        case .deadlineSelection:
            // ✅ Si l'utilisateur a un événement, aller à eventDetails, sinon continuer normalement
            if viewModel.goalDeadline.type != .noDeadline {
                return OnboardingStep.eventDetails.rawValue
            }
            // Si pas d'événement, continuer normalement
            // ✅ CORRECTION: Pour les objectifs de poids, toujours afficher une deuxième estimation de poids
            if viewModel.selectedPrimaryGoals.contains(.manageWeight),
               let weightGoal = viewModel.selectedWeightGoal,
               weightGoal == .lose || weightGoal == .gain,
               viewModel.isIdealWeightEntered {
                // Deuxième estimation de poids avec date plus précise (après questions sport)
                return OnboardingStep.weightEstimation.rawValue
            }
            // Si pas d'objectif poids → potentialPace ou goalProjection
            return OnboardingStep.potentialPace.rawValue

        case .eventDetails:
            // ✅ Après eventDetails, continuer normalement
            // ✅ CORRECTION: Pour les objectifs de poids, toujours afficher une deuxième estimation de poids
            if viewModel.selectedPrimaryGoals.contains(.manageWeight),
               let weightGoal = viewModel.selectedWeightGoal,
               weightGoal == .lose || weightGoal == .gain,
               viewModel.isIdealWeightEntered {
                // Deuxième estimation de poids avec date plus précise (après questions sport)
                return OnboardingStep.weightEstimation.rawValue
            }
            // Si pas d'objectif poids → potentialPace ou goalProjection
            return OnboardingStep.potentialPace.rawValue

        case .potentialPace:
            Logger.debug("[NavigationEngine] potentialPace → goalProjection (étape 19)", category: "Onboarding")
            return OnboardingStep.goalProjection.rawValue

        case .goalProjection:
            if viewModel.selectedPrimaryGoals.contains(.manageWeight) {
                return OnboardingStep.weightManagementExperience.rawValue
            }
            return OnboardingStep.nutritionQuality.rawValue

        default:
            return nil
        }
    }

    private func getNextStepInNutritionFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .weightManagementExperience:
            // ✅ NOUVELLE LOGIQUE: Si l'utilisateur a répondu "J'ai essayé plusieurs fois" ou "J'essaie actuellement"
            // Aller à weightFailureReasons, sinon aller directement à nutritionQuality
            if let experience = viewModel.nutritionProfile.weightManagementExperience,
               experience == .triedMultiple || experience == .currentlyTrying {
                return OnboardingStep.weightFailureReasons.rawValue
            }
            return OnboardingStep.nutritionQuality.rawValue

        case .weightFailureReasons:
            // ✅ Après weightFailureReasons, aller à nutritionQuality
            return OnboardingStep.nutritionQuality.rawValue

        case .nutritionQuality:
            return OnboardingStep.appleSignIn.rawValue

        case .nutritionScanFeature:
            // Page supprimée — migration vers Apple Sign In
            return OnboardingStep.appleSignIn.rawValue

        case .hasDietaryRestrictions:
            // ✅ DÉPRÉCIÉ: Page supprimée, rediriger vers hardestMeal
            return OnboardingStep.hardestMeal.rawValue

        case .whichRestrictions:
            // ✅ DÉPRÉCIÉ: Page supprimée, rediriger vers hardestMeal
            return OnboardingStep.hardestMeal.rawValue

        case .hardestMeal:
            // ✅ DÉPRÉCIÉ: Page supprimée, rediriger vers appleSignIn
            return OnboardingStep.appleSignIn.rawValue

        default:
            return nil
        }
    }

    private func getNextStepInSleepFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .sleepInfo, .sleepQuality, .fatigueFrequency, .fatiguePeaks:
            return nil

        case .appleSignIn:
            // ✅ NOUVEL ORDRE: Après authentification Apple, aller à healthKitPermissions
            return OnboardingStep.healthKitPermissions.rawValue

        case .healthKitPermissions:
            // ✅ Après healthKitPermissions, afficher l'animation des données HealthKit
            return OnboardingStep.sleepDataRecovery.rawValue

        case .bodyScan:
            // ✅ Déprécié - rediriger vers firstNameInput si jamais atteint
            return OnboardingStep.firstNameInput.rawValue

        case .sleepDataRecovery:
            return OnboardingStep.alarmConfiguration.rawValue

        // Étapes 45–47 supprimées (news / besoin de sommeil / dette) — migration vers l’alarme
        case .newsStep, .sleepNeedReveal, .sleepDebtInfo:
            return OnboardingStep.alarmConfiguration.rawValue

        case .alarmConfiguration:
            return OnboardingStep.sleepWindowReveal.rawValue

        case .sleepWindowReveal:
            // ✅ Après sleepWindowReveal, aller directement à appRating (appleSignIn est maintenant avant sleepDataRecovery)
            return OnboardingStep.appRating.rawValue

        default:
            return nil
        }
    }

    private func getNextStepInFinalizationFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .appleSignIn:
            // ✅ NOTE: appleSignIn est maintenant dans le flux sommeil (avant sleepDataRecovery)
            // Cette fonction ne devrait plus être appelée pour appleSignIn
            // Mais on garde le fallback au cas où
            return OnboardingStep.appRating.rawValue

        case .referralCode:
            // ✅ TEMPORAIRE : Page désactivée, ne devrait pas être atteinte
            return OnboardingStep.appRating.rawValue

        case .appRating:
            // ✅ TEMPORAIRE : Sauter caloriesGoal et carryOverCalories, aller directement à biometricAuth
            return OnboardingStep.biometricAuth.rawValue

        case .caloriesGoal:
            // ✅ TEMPORAIRE : Page désactivée, ne devrait pas être atteinte
            return OnboardingStep.biometricAuth.rawValue

        case .carryOverCalories:
            // ✅ TEMPORAIRE : Page désactivée, ne devrait pas être atteinte
            return OnboardingStep.biometricAuth.rawValue

        case .biometricAuth:
            return OnboardingStep.notificationPermission.rawValue

        case .notificationPermission:
            return OnboardingStep.programCreation.rawValue

        case .programCreation:
            return OnboardingStep.payment.rawValue

        case .payment:
            // ✅ Après le paiement, afficher d'abord les pages de bienvenue
            return OnboardingStep.processWelcome.rawValue

        case .processWelcome:
            // ✅ Après la page de bienvenue, terminer directement l'onboarding
            // Supprimer les pages referralReward et featuresUnlock
            return OnboardingStep.complete.rawValue

        default:
            return nil
        }
    }

    // MARK: - Previous Steps (Inverse)

    private func getPreviousStepInSpecificFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .weightGoal:
            return OnboardingStep.primaryGoal.rawValue

        case .weightGoalIncompatible:
            // ✅ Revenir à weightGoal depuis la page de blocage
            return OnboardingStep.weightGoal.rawValue

        case .idealWeight:
            return OnboardingStep.weightGoal.rawValue

        case .weightMotivation:
            return OnboardingStep.idealWeight.rawValue

        case .goalPace:
            // Si on vient de weightMotivation, revenir à weightMotivation
            if viewModel.selectedPrimaryGoals.contains(.manageWeight) &&
               viewModel.selectedWeightGoal != nil &&
               viewModel.isIdealWeightEntered {
                return OnboardingStep.weightMotivation.rawValue
            }
            // Sinon, revenir à idealWeight ou trainingFrequency selon le contexte
            if viewModel.selectedPrimaryGoals.contains(.manageWeight) {
                return OnboardingStep.idealWeight.rawValue
            }
            return OnboardingStep.trainingFrequency.rawValue

        case .weightEstimation:
            return OnboardingStep.goalPace.rawValue

        case .hasSportActivity:
            // ✅ CORRIGÉ: Revenir à l'étape AVANT hasSportActivity dans le flux
            // Si on a l'objectif "changer mon poids", revenir à weightEstimation ou goalPace
            if viewModel.selectedPrimaryGoals.contains(.manageWeight) {
                // Si on a fait une première estimation de poids, revenir à weightEstimation
                if viewModel.selectedWeightGoal != nil && viewModel.isIdealWeightEntered {
                    return OnboardingStep.weightEstimation.rawValue
                }
                // Sinon revenir à weightGoal
                return OnboardingStep.weightGoal.rawValue
            }
            // Si pas d'objectif poids, revenir à primaryGoal
            return OnboardingStep.primaryGoal.rawValue

        case .sportSelection:
            // Toujours revenir à hasSportActivity
            return OnboardingStep.hasSportActivity.rawValue

        case .sportClub:
            // ✅ CORRECTION: Revenir à sportSelection depuis sportClub
            return OnboardingStep.sportSelection.rawValue

        case .experienceLevel:
            // ✅ CORRIGÉ: Revenir à la page précédente selon le parcours de l'utilisateur
            // Si l'utilisateur ne pratique pas de sport, on ne devrait jamais être ici
            // car hasSportActivity=false mène directement à weightManagementExperience ou nutritionQuality
            if viewModel.hasSportActivity == true {
                // Si l'utilisateur a un sport, revenir à sportClub
                return OnboardingStep.sportClub.rawValue
            }
            // Si pas de sport mais qu'on est quand même sur experienceLevel,
            // revenir à hasSportActivity (cas de sécurité)
            return OnboardingStep.hasSportActivity.rawValue

        case .yearsOfExperience:
            return OnboardingStep.experienceLevel.rawValue

        case .trainingFrequency:
            return OnboardingStep.experienceLevel.rawValue

        case .deadlineSelection:
            return getLastSpecificStepInQueue()

        case .eventDetails:
            return OnboardingStep.experienceLevel.rawValue

        case .potentialPace:
            if viewModel.hasSportActivity == true {
                return OnboardingStep.experienceLevel.rawValue
            }

            // Si l'utilisateur ne pratique pas de sport, on vient de hasSportActivity
            if viewModel.hasSportActivity == false {
                return OnboardingStep.hasSportActivity.rawValue
            }

            // Sinon, on vient de trainingFrequency (utilisateur pratique un sport)
            return OnboardingStep.trainingFrequency.rawValue

        case .goalProjection:
            if viewModel.selectedPrimaryGoals.contains(.manageWeight) {
                return OnboardingStep.trainingFrequency.rawValue
            }
            return OnboardingStep.trainingFrequency.rawValue

        case .weightManagementExperience:
            // ✅ NOUVELLE LOGIQUE: Si l'utilisateur est arrivé depuis hasSportActivity (pas de sport + objectif poids)
            // Revenir à hasSportActivity, sinon revenir à goalProjection
            if viewModel.hasSportActivity == false && viewModel.selectedPrimaryGoals.contains(.manageWeight) {
                return OnboardingStep.hasSportActivity.rawValue
            }
            return OnboardingStep.goalProjection.rawValue

        default:
            return nil
        }
    }

    private func getPreviousStepInNutritionFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .nutritionQuality:
            // ✅ NOUVELLE LOGIQUE: Si l'utilisateur est arrivé depuis hasSportActivity (pas de sport + pas d'objectif poids)
            // Revenir à hasSportActivity, sinon revenir à weightFailureReasons ou goalProjection
            if viewModel.hasSportActivity == false && !viewModel.selectedPrimaryGoals.contains(.manageWeight) {
                return OnboardingStep.hasSportActivity.rawValue
            }
            // Si on vient de weightFailureReasons, revenir à weightFailureReasons
            if let experience = viewModel.nutritionProfile.weightManagementExperience,
               experience == .triedMultiple || experience == .currentlyTrying {
                return OnboardingStep.weightFailureReasons.rawValue
            }
            return OnboardingStep.goalProjection.rawValue

        case .weightFailureReasons:
            // ✅ Revenir à weightManagementExperience depuis weightFailureReasons
            return OnboardingStep.weightManagementExperience.rawValue

        case .hasDietaryRestrictions:
            // ✅ DÉPRÉCIÉ: Page supprimée
            return OnboardingStep.nutritionQuality.rawValue

        case .whichRestrictions:
            // ✅ DÉPRÉCIÉ: Page supprimée
            return OnboardingStep.nutritionQuality.rawValue

        case .hardestMeal:
            // ✅ DÉPRÉCIÉ: Page supprimée
            return OnboardingStep.nutritionQuality.rawValue

        default:
            return nil
        }
    }

    private func getPreviousStepInSleepFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .appleSignIn:
            return OnboardingStep.nutritionQuality.rawValue

        case .healthKitPermissions:
            // ✅ NOUVEL ORDRE: Revenir à appleSignIn (avant healthKitPermissions)
            return OnboardingStep.appleSignIn.rawValue

        case .bodyScan:
            // ✅ Revenir à weight depuis bodyScan
            return OnboardingStep.weight.rawValue

        case .sleepDebtInfo, .sleepNeedReveal, .newsStep:
            return OnboardingStep.sleepDataRecovery.rawValue

        case .sleepDataRecovery:
            // ✅ NOUVEL ORDRE: Revenir à healthKitPermissions depuis sleepDataRecovery
            return OnboardingStep.healthKitPermissions.rawValue

        case .sleepWindowReveal:
            return OnboardingStep.alarmConfiguration.rawValue

        case .alarmConfiguration:
            return OnboardingStep.sleepDataRecovery.rawValue

        default:
            return nil
        }
    }

    private func getPreviousStepInFinalizationFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .referralCode:
            // ✅ TEMPORAIRE : Page désactivée, ne devrait pas être atteinte
            return OnboardingStep.sleepWindowReveal.rawValue

        case .sleepWindowReveal:
            return OnboardingStep.alarmConfiguration.rawValue

        case .appRating:
            // ✅ Revenir à sleepWindowReveal (appleSignIn est maintenant dans le flux sommeil, avant sleepDataRecovery)
            return OnboardingStep.sleepWindowReveal.rawValue

        case .caloriesGoal:
            // ✅ TEMPORAIRE : Page désactivée, ne devrait pas être atteinte
            return OnboardingStep.appRating.rawValue

        case .carryOverCalories:
            // ✅ TEMPORAIRE : Page désactivée, ne devrait pas être atteinte
            return OnboardingStep.appRating.rawValue

        case .programCreation:
            // ✅ TEMPORAIRE : Revenir à biometricAuth (sauter carryOverCalories)
            return OnboardingStep.biometricAuth.rawValue

        case .biometricAuth:
            // ✅ TEMPORAIRE : Revenir directement à appRating (sauter carryOverCalories et caloriesGoal)
            return OnboardingStep.appRating.rawValue

        case .notificationPermission:
            return OnboardingStep.biometricAuth.rawValue

        case .payment:
            return OnboardingStep.notificationPermission.rawValue

        case .processWelcome:
            // ✅ Revenir au paiement depuis la page de bienvenue
            return OnboardingStep.payment.rawValue

        case .complete:
            // ✅ Revenir à la page de déblocage depuis la page de complétion
            return OnboardingStep.featuresUnlock.rawValue

        default:
            return nil
        }
    }

    // MARK: - Helper Methods

    private func getDeadlineOrTrainingFrequency() -> Int {
        Logger.debug("[NavigationEngine] getDeadlineOrTrainingFrequency() appelé", category: "Onboarding")
        Logger.debug("  - selectedPrimaryGoals: \(viewModel.selectedPrimaryGoals)", category: "Onboarding")
        Logger.debug("  - contains(.manageWeight): \(viewModel.selectedPrimaryGoals.contains(.manageWeight))", category: "Onboarding")

        if viewModel.selectedPrimaryGoals.contains(.manageWeight) {
            Logger.debug("  → Retourne goalProjection (19) car manageWeight", category: "Onboarding")
            return OnboardingStep.goalProjection.rawValue
        }

        // Pas de page « combat / course / deadline » dans l'onboarding : aller directement à la projection
        Logger.debug("  → Retourne goalProjection (19) — flux deadline/combat/course désactivé", category: "Onboarding")
        return OnboardingStep.goalProjection.rawValue
    }

    private func getNextStepInQueue(after step: OnboardingStep) -> Int? {
        guard let stepIndex = viewModel.pendingSpecificSteps.firstIndex(of: step) else {
            return nil
        }

        let nextIndex = stepIndex + 1
        if nextIndex < viewModel.pendingSpecificSteps.count {
            return viewModel.pendingSpecificSteps[nextIndex].rawValue
        }

        return nil
    }

    private func getPreviousStepInQueue(from step: OnboardingStep) -> Int? {
        guard let stepIndex = viewModel.pendingSpecificSteps.firstIndex(of: step),
              stepIndex > 0 else {
            return nil
        }

        return viewModel.pendingSpecificSteps[stepIndex - 1].rawValue
    }

    private func getLastSpecificStepInQueue() -> Int {
        if viewModel.selectedPrimaryGoals.contains(.manageWeight) {
            if viewModel.isIdealWeightEntered {
                return OnboardingStep.idealWeight.rawValue
            } else if viewModel.isWeightGoalSelected {
                return OnboardingStep.weightGoal.rawValue
            }
        }

        if viewModel.selectedPrimaryGoals.contains(.boostPerformance) ||
           viewModel.selectedPrimaryGoals.contains(.increaseRecovery) ||
           viewModel.selectedPrimaryGoals.contains(.optimizeEnergy) ||
           viewModel.selectedPrimaryGoals.contains(.improveSleep) ||
           viewModel.selectedPrimaryGoals.contains(.reduceStress) ||
           viewModel.selectedPrimaryGoals.contains(.improveFitness) {
            if viewModel.isExperienceLevelSelected {
                return OnboardingStep.experienceLevel.rawValue
            } else if viewModel.isSportsSelected {
                return OnboardingStep.sportSelection.rawValue
            }
        }

        return viewModel.pendingSpecificSteps.last?.rawValue ?? OnboardingStep.primaryGoal.rawValue
    }
}
