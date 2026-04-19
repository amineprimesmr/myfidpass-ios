//
//  OnboardingFlowHelpers.swift
//  Process
//
//  Validation d'étapes, reprise de progression et estimation du nombre d'étapes — extraits de OnboardingView.
//

import Foundation

// MARK: - Validation de disponibilité d'étape

/// Indique si une étape peut être affichée avec les données actuelles du ViewModel (reprise de progression).
func validateOnboardingStepAvailability(step: OnboardingStep, viewModel: OnboardingViewModel) -> Bool {
    switch step {
    case .videoIntroduction, .genderSelection, .ageSelection, .height, .weight, .primaryGoal,
         .hasSportActivity, .deadlineSelection, .eventDetails, .nutritionQuality,
         .hasSufficientHydration,
         .sleepInfo, .sleepQuality, .fatigueFrequency, .fatiguePeaks,
         .healthKitPermissions, .planGeneration, .sleepDataRecovery,
         .newsStep, .sleepNeedReveal, .sleepDebtInfo,
         .alarmConfiguration,
         .sleepWindowReveal, .sleepNeed, .referralCode, .referralReward,
         .featuresUnlock, .payment, .appRating, .appleSignIn,
         .notificationPermission, .processWelcome, .complete,
         .nutritionScanFeature, .yearsOfExperience:
        return true

    case .heightWeight:
        return true
    case .bodyScan:
        return viewModel.selectedHeight > 0 && viewModel.selectedWeight > 0
    case .firstNameInput:
        return true
    case .personalizedWelcome:
        return !viewModel.firstName.isEmpty
    case .processResultsDurability:
        return true

    case .weightGoal, .idealWeight, .weightMotivation, .goalPace, .weightEstimation,
         .weightManagementExperience, .weightFailureReasons:
        return !viewModel.selectedPrimaryGoals.isEmpty

    case .weightGoalIncompatible:
        return viewModel.selectedWeightGoal != nil
    case .goalProjection:
        return !viewModel.selectedPrimaryGoals.isEmpty
    case .potentialPace:
        return !viewModel.selectedPrimaryGoals.isEmpty

    case .sportSelection, .sportClub, .experienceLevel:
        return viewModel.hasSportActivity == true

    case .hasDietaryRestrictions, .whichRestrictions:
        return false

    case .hydrationLevel:
        return viewModel.nutritionProfile.hasSufficientHydration == false

    case .nutritionObstacles:
        return true

    case .perfectNutritionBelief, .hardestMeal:
        return true

    case .trainingFrequency:
        return true

    case .planReady, .onboardingInfo:
        return false

    case .nutritionPotential, .faceAnalysis, .programCreation, .biometricAuth, .caloriesGoal, .carryOverCalories:
        return false
    }
}

// MARK: - Dernière étape valide (reprise)

/// Parcourt l’historique des étapes visitées et retourne la dernière étape affichable.
func findLastValidOnboardingStepIndex(visitedSteps: [Int], viewModel: OnboardingViewModel) -> Int {
    let sorted = visitedSteps.sorted()
    for stepValue in sorted.reversed() {
        guard let step = OnboardingStep(rawValue: stepValue) else { continue }
        if validateOnboardingStepAvailability(step: step, viewModel: viewModel) {
            Logger.debug("Dernière étape valide trouvée: \(stepValue) (\(step))", category: "Onboarding")
            return stepValue
        }
    }
    Logger.warning("Aucune étape valide trouvée - Recommencement depuis le début", category: "Onboarding")
    return OnboardingStep.videoIntroduction.rawValue
}

// MARK: - Nombre d'étapes pour la barre / lueur

/// Calcule le nombre total d'étapes du flux actuel pour la progression et la lueur.
func calculateTotalOnboardingStepsForFlow(viewModel: OnboardingViewModel) -> Int {
    var total = 7 + 1

    if viewModel.selectedPrimaryGoals.contains(.manageWeight) {
        total += 1
        if let weightGoal = viewModel.selectedWeightGoal, weightGoal == .lose || weightGoal == .gain {
            total += 1
            total += 1
            total += 1
            total += 1
        }
    }

    let hasSportGoals = viewModel.selectedPrimaryGoals.contains(.boostPerformance) ||
        viewModel.selectedPrimaryGoals.contains(.increaseRecovery) ||
        viewModel.selectedPrimaryGoals.contains(.optimizeEnergy) ||
        viewModel.selectedPrimaryGoals.contains(.improveSleep) ||
        viewModel.selectedPrimaryGoals.contains(.reduceStress) ||
        viewModel.selectedPrimaryGoals.contains(.improveFitness)

    if hasSportGoals {
        total += 1
        if viewModel.hasSportActivity == true {
            total += 1
            total += 1
            total += 1
        }
    }

    total += 1
    total += 1

    if viewModel.selectedPrimaryGoals.contains(.manageWeight) {
        total += 1
    }
    total += 1

    total += 1
    total += 1
    total += 1
    total += 1
    total += 1
    total += 1
    total += 1
    total += 1
    total += 1
    total += 1
    total += 1
    total += 1
    total += 1
    total += 1
    total += 1
    total += 1
    total += 1
    total += 1
    total += 1
    total += 1
    total += 1
    total += 1
    total += 1
    total += 1

    let visitedCount = viewModel.visitedSteps.count
    return max(total, visitedCount, 20)
}
