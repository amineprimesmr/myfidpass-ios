//
//  OnboardingView.swift
//  Process
//
//  Version refactorée complète utilisant ViewModel et NavigationEngine
//

import SwiftUI
import FirebaseAuth
import AuthenticationServices
import HealthKit
import Combine
import LocalAuthentication

struct OnboardingView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var permissionsManager: PermissionsManager
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var authManager: AuthenticationManager

    /// `internal` : accès depuis `OnboardingView+StepContent`, `+Computed`, `+Navigation` (autres fichiers).
    @StateObject var viewModel = OnboardingViewModel()
    @StateObject var hapticManager = HapticManager.shared

    // ✅ État pour les transitions fluides
    @State var previousStepIndex: Int?
    @State var transitionDirection: TransitionDirection = .forward
    @State var isTransitioning: Bool = false

    // État pour les choix Oui/Non
    @State private var caloriesGoalSelected: Bool?
    @State private var carryOverCaloriesSelected: Bool?

    // État pour l'authentification biométrique
    @State var biometricAuthCompleted: Bool = false

    // État pour le sheet de configuration d'alarme
    @State var showingAlarmSheet: Bool = false

    /// Recherche sport active : masque le bouton retour
    @State var isSportSearchActive = false

    // ✅ État pour gérer la transition "Vérification" → "Disponible"
    @State private var isFirstNameAvailable: Bool = false
    @State private var firstNameDebounceTask: Task<Void, Never>?

    var navigationEngine: OnboardingNavigationEngine {
        OnboardingNavigationEngine(viewModel: viewModel, profileService: profileService)
    }

    let totalSteps = 70  // ✅ CORRECTION: Permettre d'aller jusqu'à complete + weight (67) + autres étapes

    var body: some View {
        // ✅ CRITIQUE: Si l'onboarding est terminé, ne rien afficher
        // ContentView devrait déjà avoir remplacé cette vue par MainAppView
        // Ne pas afficher d'écran de chargement car cela bloque la transition
        Group {
            if authManager.hasCompletedOnboarding {
                Color.clear
                    .ignoresSafeArea(.all)
                    .onAppear {
                        Logger.debug("Onboarding terminé - OnboardingView doit être remplacé par MainAppView", category: "Onboarding")
                    }
            } else {
            ZStack {
                // ✅ FOND NOIR pour toutes les pages d'onboarding
                Color.black
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Contenu principal avec transition ultra fluide
                Group {
                    // ✅ CORRECTION: Gérer le cas où rawValue est invalide (EXC_BAD_ACCESS)
                    if let step = OnboardingStep(rawValue: viewModel.currentStep) {
                        onboardingStepContent(for: step)
                    } else {
                        // ✅ CORRECTION: Si rawValue est invalide, réinitialiser à l'étape de départ
                        VideoIntroductionStepView(onComplete: nextStep)
                            .onAppear {
                                Logger.error("OnboardingStep invalide (rawValue: \(viewModel.currentStep)) - Réinitialisation à videoIntroduction", category: "Onboarding")
                                // Réinitialiser à l'étape de départ
                                viewModel.currentStep = OnboardingStep.videoIntroduction.rawValue
                                viewModel.visitedSteps = [OnboardingStep.videoIntroduction.rawValue]
                            }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, shouldAddTopPadding ? 60 : 0)
                .ignoresSafeArea(.all)
                .animation(.onboardingTransition, value: viewModel.currentStep)
                .id("onboarding_content_\(viewModel.currentStep)") // Force le re-render pour animations fluides

            }

            // ✅ NOUVEAU: Bouton CONTINUER global avec position animée
            if shouldShowContinueButton {
                VStack {
                    Spacer()

                    Button(action: {
                        handleContinueButtonTap()
                    }) {
                        // ✅ Texte du bouton avec transition fluide entre "CONTINUER", "Vérification" et "Disponible"
                        Group {
                            if viewModel.currentStep == OnboardingStep.firstNameInput.rawValue && !viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                // ✅ Afficher "Vérification" ou "Disponible" avec animation de couleur
                                AnimatedVerificationButtonText(isAvailable: isFirstNameAvailable)
                                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            } else {
                                // ✅ Afficher "CONTINUER" normal
                                Text("CONTINUER")
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundColor(.white)
                                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .glassStyle()
                    .buttonBorderShape(.roundedRectangle(radius: 50))
                    .padding(.horizontal, 40)
                    .disabled(!canContinue)
                    .opacity(shouldHideButtonUntilValidated ? (canContinue ? 1.0 : 0.0) : (canContinue ? 1.0 : 0.5))

                    Spacer()
                        .frame(height: continueButtonBottomOffset)
                }
                .animation(.onboardingTransition, value: viewModel.currentStep)
                .animation(.easeInOut(duration: 0.3), value: viewModel.firstName.isEmpty)
            }

            // ✅ Boutons spécifiques pour certaines pages (healthKitPermissions, complete, etc.)
            if shouldShowSpecificButton {
                VStack {
                    Spacer()
                    OnboardingSpecificBottomBar(
                        viewModel: viewModel,
                        hapticManager: hapticManager,
                        caloriesGoalSelected: $caloriesGoalSelected,
                        carryOverCaloriesSelected: $carryOverCaloriesSelected,
                        biometricAuthCompleted: $biometricAuthCompleted,
                        showingAlarmSheet: $showingAlarmSheet,
                        onNextStep: nextStep,
                        onRequestHealthKit: { await requestHealthKitAndContinue() },
                        onCompleteOnboarding: { await completeOnboarding() },
                        onBiometricContinue: { await triggerBiometricAuthAndContinue() }
                    )
                    Spacer()
                        .frame(height: 50)
                }
            }

            // ✅ Header unifié : Bouton retour | Barre de progression | Bouton langue
            OnboardingHeaderChrome(
                viewModel: viewModel,
                hapticManager: hapticManager,
                shouldShowBackButton: shouldShowBackButton,
                totalStepsForFlow: { calculateTotalOnboardingStepsForFlow(viewModel: viewModel) },
                onPreviousStep: previousStep
            )

            // Lueur animée
            let visitedCount = max(1, viewModel.visitedSteps.count)
            let estimatedTotal = max(calculateTotalOnboardingStepsForFlow(viewModel: viewModel), visitedCount)
            AnimatedOnboardingGlow(
                currentStep: viewModel.currentStep,
                visitedStepsCount: visitedCount,
                totalStepsForFlow: estimatedTotal
            )
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea(.all)
            }
        }
        .onAppear {
            // ✅ CRITIQUE: Ne pas charger l'étape sauvegardée si l'onboarding est terminé
            if authManager.hasCompletedOnboarding {
                Logger.debug("Onboarding terminé - Ne pas charger l'étape sauvegardée", category: "Onboarding")
                return
            }

            checkPermissions()
            if !authManager.isInOnboarding {
                authManager.startOnboarding()
            }

            // ✅ CRITIQUE: Charger le profil AVANT de déterminer l'étape
            Task {
                if profileService.currentProfile == nil {
                    await profileService.loadProfile()
                }

                // ✅ CRITIQUE: Synchroniser le ViewModel avec le profil existant
                await MainActor.run {
                    if let profile = profileService.currentProfile {
                        viewModel.syncWithExistingProfile(profile)
                        Logger.debug("ViewModel synchronisé avec le profil au démarrage - Âge: \(profile.age), Taille: \(profile.height), Poids: \(profile.weight)", category: "Onboarding")
                    }

                    // ✅ INTELLIGENT: Valider l'étape sauvegardée et déterminer la meilleure étape de départ
                    let savedStep = OnboardingProgressService.shared.loadCurrentStep()

                    // Vérifier si l'étape sauvegardée est valide
                    guard let step = OnboardingStep(rawValue: savedStep), savedStep >= 0, savedStep < totalSteps else {
                        // ✅ Étape invalide : recommencer depuis le début
                        Logger.warning("Étape sauvegardée invalide (\(savedStep)) - Recommencement depuis le début", category: "Onboarding")
                        viewModel.currentStep = OnboardingStep.videoIntroduction.rawValue
                        viewModel.visitedSteps = [OnboardingStep.videoIntroduction.rawValue]
                        viewModel.saveProgress()
                        return
                    }

                    // ✅ Vérifier si l'étape nécessite des données qui sont disponibles
                    let canDisplayStep = validateOnboardingStepAvailability(step: step, viewModel: viewModel)

                    if canDisplayStep && savedStep > 0 {
                        // ✅ Étape valide et données disponibles : reprendre où on s'était arrêté
                        viewModel.currentStep = savedStep
                        if !viewModel.visitedSteps.contains(savedStep) {
                            viewModel.visitedSteps.append(savedStep)
                        }
                        Logger.debug("Reprise de l'onboarding à l'étape \(savedStep) (\(step))", category: "Onboarding")
                    } else if !canDisplayStep && savedStep > 0 {
                        // ✅ Étape nécessite des données manquantes : trouver la dernière étape valide
                        Logger.warning("Étape \(savedStep) nécessite des données manquantes - Recherche de la dernière étape valide", category: "Onboarding")
                        let lastValidStep = findLastValidOnboardingStepIndex(visitedSteps: viewModel.visitedSteps, viewModel: viewModel)
                        viewModel.currentStep = lastValidStep
                        if !viewModel.visitedSteps.contains(lastValidStep) {
                            viewModel.visitedSteps.append(lastValidStep)
                        }
                        viewModel.saveProgress()
                        Logger.debug("Reprise de l'onboarding à l'étape \(lastValidStep) (dernière étape valide)", category: "Onboarding")
                    } else {
                        // ✅ Pas d'étape sauvegardée ou début : commencer depuis le début
                        if viewModel.visitedSteps.isEmpty {
                            viewModel.visitedSteps = [OnboardingStep.videoIntroduction.rawValue]
                        }
                        if viewModel.currentStep == 0 {
                            viewModel.currentStep = OnboardingStep.videoIntroduction.rawValue
                        }
                        Logger.debug("Début de l'onboarding depuis la première étape", category: "Onboarding")
                    }
                }
            }
        }
        .onChange(of: profileService.currentProfile) { _, newValue in
            // ✅ CRITIQUE: Synchroniser le ViewModel à chaque fois que le profil change
            if let profile = newValue {
                viewModel.syncWithExistingProfile(profile)
                Logger.debug("ViewModel synchronisé après changement de profil - Âge: \(profile.age), Taille: \(profile.height), Poids: \(profile.weight)", category: "Onboarding")
            }

            // L'onboarding ne doit être complété QUE quand toutes les étapes sont terminées
            // (appel explicite de completeOnboarding() dans FeaturesUnlockView)
        }
        .onChange(of: viewModel.firstName) { _, newValue in
            // ✅ Détecter quand l'utilisateur arrête de taper pour afficher "Disponible"
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

            // ✅ Réinitialiser l'état "Disponible" si le champ est vide
            if trimmed.isEmpty {
                isFirstNameAvailable = false
                firstNameDebounceTask?.cancel()
                firstNameDebounceTask = nil
                return
            }

            // ✅ Annuler la tâche précédente si elle existe
            firstNameDebounceTask?.cancel()

            // ✅ Réinitialiser à "Vérification" immédiatement quand l'utilisateur tape
            isFirstNameAvailable = false

            // ✅ Créer une nouvelle tâche avec debounce de 1 seconde
            firstNameDebounceTask = Task {
                // Attendre 1 seconde
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde

                // ✅ Vérifier que la tâche n'a pas été annulée et que le prénom n'est pas vide
                guard !Task.isCancelled else { return }

                let currentTrimmed = viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !currentTrimmed.isEmpty else { return }

                // ✅ Passer à "Disponible" avec animation fluide
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        isFirstNameAvailable = true
                    }
                }
            }
        }
        .onChange(of: viewModel.currentStep) { oldValue, newValue in
            // ✅ Réinitialiser l'état quand on quitte la page firstNameInput
            if oldValue == OnboardingStep.firstNameInput.rawValue && newValue != OnboardingStep.firstNameInput.rawValue {
                isFirstNameAvailable = false
                firstNameDebounceTask?.cancel()
                firstNameDebounceTask = nil
            }
        }
    }

}
