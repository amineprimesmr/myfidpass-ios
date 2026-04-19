//
//  OnboardingView+Navigation.swift
//  Process
//
//  Navigation, HealthKit, finalisation onboarding et actions bouton Continuer.
//

import SwiftUI
import UIKit
import FirebaseAuth
import LocalAuthentication

extension OnboardingView {

// MARK: - Navigation

func nextStep() {
    let stepName = OnboardingStep(rawValue: viewModel.currentStep).map { "\($0)" } ?? "inconnu"
    Logger.debug("nextStep() appelé - Étape actuelle: \(viewModel.currentStep) (\(stepName))", category: "Onboarding")

    guard viewModel.isCurrentStepValidated() else {
        Logger.warning("Étape \(viewModel.currentStep) (\(stepName)) non validée - Passage bloqué", category: "Onboarding")
        return
    }

    let warnings = viewModel.validateCrossStepConsistency()
    if !warnings.isEmpty {
        Logger.warning("Avertissements: \(warnings.joined(separator: ", "))", category: "Onboarding")
    }

    hapticManager.impact(.medium)

    OnboardingProgressService.shared.saveLastCompletedStep(viewModel.currentStep)

    guard let nextStepIndex = navigationEngine.getNextStep(),
          nextStepIndex < totalSteps else {
        Logger.warning("Dernière étape atteinte ou pas de prochaine étape - Étape actuelle: \(viewModel.currentStep)", category: "Onboarding")
        return
    }

    Logger.debug("Navigation vers l'étape \(nextStepIndex) depuis l'étape \(viewModel.currentStep)", category: "Onboarding")

    // ✅ Ajouter l'étape actuelle à l'historique si pas déjà présente
    if !viewModel.visitedSteps.contains(viewModel.currentStep) {
        viewModel.visitedSteps.append(viewModel.currentStep)
    }

    // ✅ Transition ultra fluide vers l'avant
    previousStepIndex = viewModel.currentStep
    transitionDirection = .forward
    isTransitioning = true

    withAnimation(.onboardingTransition) {
        viewModel.currentStep = nextStepIndex
    }

    // ✅ Ajouter la nouvelle étape à l'historique
    if !viewModel.visitedSteps.contains(nextStepIndex) {
        viewModel.visitedSteps.append(nextStepIndex)
    }

    // Réinitialiser l'état de transition après l'animation
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
        isTransitioning = false
    }

    OnboardingProgressService.shared.saveCurrentStep(nextStepIndex)
    viewModel.saveProgress()
}

// MARK: - Biometric Auth

func triggerBiometricAuthAndContinue() async {
    hapticManager.impact(.medium)

    let context = LAContext()
    var error: NSError?

    // Vérifier si l'authentification biométrique est disponible
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
        // Si non disponible, continuer quand même
        await MainActor.run {
            nextStep()
        }
        return
    }

    // Déterminer le type d'authentification
    let biometricType = context.biometryType
    let reason: String

    switch biometricType {
    case .faceID:
        reason = "Utilise Face ID pour confirmer ton engagement"
    case .touchID:
        reason = "Restez appuyé avec votre doigt pour confirmer votre engagement"
    default:
        reason = "Authentifie-toi pour confirmer ton engagement"
    }

    // Évaluer l'authentification
    do {
        let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        if success {
            hapticManager.notification(.success)
            // Petit délai pour voir le succès
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 secondes
            await MainActor.run {
                nextStep()
            }
        } else {
            // L'utilisateur a annulé, ne rien faire
        }
    } catch {
        // Erreur d'authentification, continuer quand même
        await MainActor.run {
            nextStep()
        }
    }
}

func previousStep() {
    hapticManager.impact(.light)

    Logger.debug("[previousStep] Étape actuelle: \(viewModel.currentStep), Historique: \(viewModel.visitedSteps)", category: "Onboarding")

    // ✅ PRIORITÉ 1: Utiliser le moteur de navigation (source de vérité)
    if let enginePreviousStep = navigationEngine.getPreviousStep() {
        Logger.debug("[previousStep] Moteur de navigation suggère: \(enginePreviousStep)", category: "Onboarding")

        // Retirer l'étape actuelle de l'historique
        viewModel.visitedSteps.removeAll { $0 == viewModel.currentStep }

        // ✅ Transition ultra fluide vers l'arrière
        previousStepIndex = viewModel.currentStep
        transitionDirection = .backward
        isTransitioning = true

        withAnimation(.onboardingTransition) {
            viewModel.currentStep = enginePreviousStep
        }

        // ✅ Sauvegarder la progression après retour en arrière
        OnboardingProgressService.shared.saveCurrentStep(enginePreviousStep)
        viewModel.saveProgress()

        // Réinitialiser l'état de transition après l'animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isTransitioning = false
        }
        return
    }

    // ✅ FALLBACK: Utiliser l'historique si le moteur n'a pas de suggestion
    guard viewModel.visitedSteps.count > 1 else {
        Logger.warning("Impossible de revenir en arrière - Pas d'historique ni de suggestion du moteur", category: "Onboarding")
        return
    }

    // Retirer l'étape actuelle de l'historique
    viewModel.visitedSteps.removeAll { $0 == viewModel.currentStep }

    // Prendre la dernière étape de l'historique (celle d'avant)
    guard let historyPreviousStep = viewModel.visitedSteps.last else {
        Logger.warning("Impossible de revenir en arrière - Historique vide après suppression", category: "Onboarding")
        return
    }

    Logger.debug("[previousStep] Utilisation de l'historique: \(historyPreviousStep)", category: "Onboarding")

    // ✅ Transition ultra fluide vers l'arrière
    previousStepIndex = viewModel.currentStep
    transitionDirection = .backward
    isTransitioning = true

    withAnimation(.onboardingTransition) {
        viewModel.currentStep = historyPreviousStep
    }

    // ✅ Sauvegarder la progression après retour en arrière
    OnboardingProgressService.shared.saveCurrentStep(historyPreviousStep)
    viewModel.saveProgress()

    // Réinitialiser l'état de transition après l'animation
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
        isTransitioning = false
    }
}

func buildPendingStepsQueue() {
    viewModel.pendingSpecificSteps = []

    let priorityOrder: [PrimaryGoal] = [.manageWeight, .boostPerformance, .increaseRecovery, .optimizeEnergy, .improveSleep, .reduceStress, .improveFitness]

    for goal in priorityOrder {
        guard viewModel.selectedPrimaryGoals.contains(goal) else { continue }

        switch goal {
        case .manageWeight:
            viewModel.pendingSpecificSteps.append(.weightGoal)
        case .boostPerformance, .increaseRecovery, .optimizeEnergy, .improveSleep, .reduceStress, .improveFitness:
            viewModel.pendingSpecificSteps.append(.sportSelection)
            viewModel.pendingSpecificSteps.append(.experienceLevel)
        }
    }
}

// MARK: - HealthKit

func requestHealthKitAndContinue() async {
    hapticManager.impact(.heavy)
    viewModel.isRequestingHealthKit = true

    // ✅ Les permissions de localisation et mouvement sont maintenant demandées au chargement de la page HealthKitPermissionsStepView
    // On demande uniquement HealthKit ici

    // ✅ CORRECTION: Attendre vraiment la réponse de HealthKit au lieu d'un délai artificiel
    await healthManager.requestAuthorizationAsync()

    await MainActor.run {
        viewModel.healthKitGranted = healthManager.isAuthorized
        viewModel.isRequestingHealthKit = false

        if viewModel.healthKitGranted {
            Logger.debug("HealthKit autorisé", category: "Onboarding")
        } else {
            Logger.warning("HealthKit refusé - Fonctionnalités limitées", category: "Onboarding")
        }

        // ✅ Passer à l'étape suivante immédiatement après la réponse
        nextStep()
    }
}

func checkPermissions() {
    viewModel.healthKitGranted = healthManager.isAuthorized
}

// MARK: - Completion

func completeOnboarding() async {
    // ✅ CRITIQUE: ÉVITER LA RÉCURSION - Ne pas réexécuter si déjà complété
    await MainActor.run {
        guard !authManager.hasCompletedOnboarding else {
            Logger.debug("OnboardingView: Onboarding déjà complété - Éviter récursion", category: "Onboarding")
            return
        }
    }

    hapticManager.impact(.heavy)
    viewModel.isCompleting = true

    do {
        let coordinator = OnboardingCoordinator(viewModel: viewModel, profileService: profileService)
        try await coordinator.saveAllOnboardingData()

        // ✅ CRITIQUE: Marquer l'onboarding comme terminé AVANT toute réinitialisation
        try await OnboardingService.shared.completeOnboarding()

        // ✅ CRITIQUE: Mettre à jour AuthenticationManager et sauvegarder IMMÉDIATEMENT
        await MainActor.run {
            // ✅ Double vérification pour éviter la récursion
            guard !authManager.hasCompletedOnboarding else {
                Logger.debug("OnboardingView: Onboarding déjà complété (vérification finale) - Éviter récursion", category: "Onboarding")
                viewModel.isCompleting = false
                return
            }

            authManager.completeOnboarding()
        }

        hapticManager.notification(.success)

        // ✅ CRITIQUE: NE PAS réinitialiser currentStep ici car OnboardingView sera remplacé par MainAppView
        // La réinitialisation se fera automatiquement au prochain démarrage si nécessaire

        // ✅ CRITIQUE: Ne pas attendre - la transition doit être IMMÉDIATE
        // Le délai de 200ms causait l'écran noir/infini

        Logger.success("✅ Onboarding terminé avec succès - Navigation vers l'app principale", category: "Onboarding")
    } catch {
        hapticManager.notification(.error)
        Logger.error("Erreur finalisation: \(error.localizedDescription)", category: "Onboarding")
        viewModel.isCompleting = false
        viewModel.errorMessage = "Erreur lors de la finalisation. Veuillez réessayer."
        // TODO: Afficher alerte d'erreur à l'utilisateur
    }

    viewModel.isCompleting = false
}

// MARK: - Helpers

func savePlanDataProgressively() async {
    await OnboardingProgressService.shared.savePlanData(
        mainGoal: nil, // Legacy - pas utilisé
        experienceLevel: viewModel.selectedExperienceLevel,
        yearsOfExperience: viewModel.selectedYearsOfExperience,
        sessionsPerWeek: viewModel.selectedSessionsPerWeek,
        sessionDuration: viewModel.selectedSessionDuration,
        trainingLocation: viewModel.selectedTrainingLocation,
        equipment: viewModel.selectedEquipment,
        weightGoal: viewModel.selectedWeightGoal,
        to: profileService
    )
}

}
