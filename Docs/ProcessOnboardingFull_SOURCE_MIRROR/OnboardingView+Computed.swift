//
//  OnboardingView+Computed.swift
//  Process
//
//  Propriétés calculées (visibilité boutons, padding) extraites de OnboardingView.
//

import SwiftUI
import UIKit

extension OnboardingView {

// MARK: - Computed Properties

var shouldShowBottomButton: Bool {
    let step = OnboardingStep(rawValue: viewModel.currentStep)
    switch step {
    case .videoIntroduction, .firstNameInput, .weight, .sportSelection, .sleepDataRecovery,
         .payment, .appleSignIn, .notificationPermission, .sleepInfo,
         .processWelcome, .featuresUnlock, .referralCode, .referralReward:  // ✅ Pas de bouton en bas (elles ont leur propre bouton)
        return false
    default:
        return true
    }
}

// ✅ NOUVEAU: Bouton CONTINUER global visible sur certaines pages
var shouldShowContinueButton: Bool {
    let step = OnboardingStep(rawValue: viewModel.currentStep)
    switch step {
    case .videoIntroduction, .sportSelection, .sleepDataRecovery,
         .payment, .appleSignIn, .notificationPermission, .sleepInfo,
         .processWelcome, .featuresUnlock, .referralCode, .referralReward,
         .healthKitPermissions, .biometricAuth, .caloriesGoal, .carryOverCalories:
        // ✅ programCreation retiré - utilise maintenant le bouton global CONTINUER
        return false
    default:
        return true
    }
}

// ✅ Pages qui ont un bouton spécifique (pas le bouton global CONTINUER)
var shouldShowSpecificButton: Bool {
    let step = OnboardingStep(rawValue: viewModel.currentStep)
    switch step {
    case .healthKitPermissions, .complete, .caloriesGoal, .carryOverCalories:
        return true
    default:
        return false
    }
}

// ✅ NOUVEAU: Offset depuis le bas pour le bouton selon la page
var continueButtonBottomOffset: CGFloat {
    let step = OnboardingStep(rawValue: viewModel.currentStep)

    switch step {
    case .firstNameInput:
        // Position plus haute pour la page prénom (clavier texte)
        return UIScreen.main.bounds.height * 0.38
    case .weight, .idealWeight:
        // Position pour les pages poids (clavier numérique)
        return UIScreen.main.bounds.height * 0.35
    default:
        // Position standard en bas (comme avant)
        return 50
    }
}

// ✅ NOUVEAU: Vérifier si on peut continuer (étape validée)
var canContinue: Bool {
    return viewModel.isCurrentStepValidated()
}

// ✅ NOUVEAU: Pages où le bouton doit être complètement caché jusqu'à validation
var shouldHideButtonUntilValidated: Bool {
    let step = OnboardingStep(rawValue: viewModel.currentStep)
    switch step {
    case .programCreation, .weightEstimation, .goalProjection:
        // Ces pages ont des animations - le bouton doit être caché jusqu'à la fin
        return true
    default:
        return false
    }
}

// ✅ NOUVEAU: Gérer le tap sur le bouton global
func handleContinueButtonTap() {
    hapticManager.impact(.medium)

    let step = OnboardingStep(rawValue: viewModel.currentStep)

    switch step {
    case .firstNameInput:
        // Fermer le clavier et sauvegarder
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        Task.detached(priority: .background) {
            // La sauvegarde est gérée par FirstNameInputStepView
        }
        nextStep()

    case .weight, .idealWeight:
        // Fermer le clavier et sauvegarder
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        // La sauvegarde est gérée par les vues via onChange
        nextStep()

    default:
        nextStep()
    }
}

var shouldShowBackButton: Bool {
    // Cacher le bouton retour si la recherche sport est active
    if isSportSearchActive {
        return false
    }

    guard let currentStep = OnboardingStep(rawValue: viewModel.currentStep) else {
        return false
    }

    // ✅ Le bouton retour pour heightWeight est maintenant géré par OnboardingView comme les autres pages

    return viewModel.currentStep > 0 &&
    currentStep != .videoIntroduction &&
    currentStep != .payment &&
    currentStep != .processWelcome &&  // ✅ Pas de retour depuis la page de bienvenue
    currentStep != .featuresUnlock &&  // ✅ Pas de retour depuis la page de déblocage
    currentStep != .sleepDataRecovery  // ✅ Pas de retour depuis la page animation lightspeed
}

var shouldAddTopPadding: Bool {
    guard let step = OnboardingStep(rawValue: viewModel.currentStep) else {
        return true
    }

    return step != .videoIntroduction &&
           step != .payment &&
           step != .notificationPermission &&
           step != .genderSelection &&
           step != .ageSelection &&
           step != .height && // ✅ Pas de padding pour height (comme ageSelection)
           step != .weight && // ✅ Pas de padding pour weight (comme ageSelection et height)
           step != .heightWeight &&
           step != .firstNameInput &&
           step != .processResultsDurability &&
           step != .weightMotivation &&
           step != .hasSportActivity &&
           step != .sportClub &&
           step != .processWelcome // ✅ CRITIQUE: Pas de padding pour la vidéo plein écran
}

}
