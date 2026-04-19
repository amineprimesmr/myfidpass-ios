//
//  OnboardingView+StepContent.swift
//  Process
//
//  Contenu des étapes d'onboarding (switch extrait de OnboardingView).
//

import SwiftUI
import FirebaseAuth
import AuthenticationServices
import HealthKit
import Combine
import LocalAuthentication

extension OnboardingView {
    @ViewBuilder
    func onboardingStepContent(for step: OnboardingStep) -> some View {
        switch step {
        case .videoIntroduction:
            VideoIntroductionStepView(onComplete: nextStep)
        case .genderSelection:
            GenderSelectionStepView(
                selectedGender: $viewModel.selectedGender,
                onValidationChanged: { isValid in
                    viewModel.isGenderSelected = isValid
                }
            )
        case .ageSelection:
            AgeSelectionStepView(
                selectedAge: $viewModel.selectedAge,
                onValidationChanged: { isValid in
                    viewModel.isAgeSelected = isValid
                }
            )
        case .height:
            HeightStepView(
                selectedHeight: $viewModel.selectedHeight,
                onValidationChanged: { isValid in
                    Logger.debug("[OnboardingView] HeightStepView validation changed: \(isValid)", category: "Onboarding")
                    // ✅ Forcer la mise à jour sur le main thread
                    Task { @MainActor in
                        viewModel.isHeightWeightSelected = isValid
                        Logger.debug("[OnboardingView] isHeightWeightSelected = \(viewModel.isHeightWeightSelected), selectedHeight = \(viewModel.selectedHeight)", category: "Onboarding")
                    }
                }
            )
        case .weight:
            WeightStepView(
                selectedWeight: $viewModel.selectedWeight,
                onValidationChanged: { isValid in
                    Logger.debug("[OnboardingView] WeightStepView validation changed: \(isValid)", category: "Onboarding")
                    viewModel.isHeightWeightSelected = isValid
                    Logger.debug("[OnboardingView] isHeightWeightSelected = \(viewModel.isHeightWeightSelected), selectedWeight = \(viewModel.selectedWeight)", category: "Onboarding")
                },
                onContinue: nextStep // ✅ NOUVEAU: Passer à l'étape suivante depuis le clavier
            )
        case .heightWeight:
            // ✅ Ancienne page combinée (dépréciée, gardée pour compatibilité)
            HeightWeightStepView(
                selectedHeight: $viewModel.selectedHeight,
                selectedWeight: $viewModel.selectedWeight,
                onValidationChanged: { isValid in
                    viewModel.isHeightWeightSelected = isValid
                },
                onBack: previousStep
            )
        case .bodyScan:
            // ✅ Page bodyScan supprimée - rediriger directement vers firstNameInput
            EmptyView()
                .onAppear {
                    // Passer directement à firstNameInput
                    nextStep()
                }
        case .firstNameInput:
            FirstNameInputStepView(
                firstName: $viewModel.firstName,
                onComplete: nextStep,
                onValidationChanged: { isValid in
                    viewModel.isFirstNameEntered = isValid
                }
            )
        case .personalizedWelcome:
            PersonalizedWelcomeStepView(
                viewModel: viewModel, // ✅ Passer le ViewModel
                firstName: viewModel.firstName,
                onComplete: nextStep,
                onValidationChanged: { _ in
                    // Validation automatique
                }
            )
        case .processResultsDurability:
            ProcessResultsDurabilityStepView(
                onComplete: nextStep,
                onValidationChanged: { _ in
                    // Validation automatique
                },
                onBack: previousStep
            )
        case .primaryGoal:
            PrimaryGoalStepView(
                selectedGoals: $viewModel.selectedPrimaryGoals,
                onValidationChanged: { isValid in
                    viewModel.isPrimaryGoalSelected = isValid
                    if isValid {
                        buildPendingStepsQueue()
                    }
                }
            )
        case .weightGoal:
            WeightGoalStepView(
                selectedGoal: $viewModel.selectedWeightGoal,
                onValidationChanged: { isValid in
                    viewModel.isWeightGoalSelected = isValid
                }
            )
        case .weightGoalIncompatible:
            WeightGoalIncompatibleStepView(
                firstName: viewModel.firstName,
                currentWeight: viewModel.selectedWeight,
                height: viewModel.selectedHeight,
                selectedGoal: viewModel.selectedWeightGoal ?? .lose,
                onBack: previousStep,
                onValidationChanged: { _ in
                    // Validation automatique
                }
            )
        case .idealWeight:
            IdealWeightStepView(
                idealWeight: $viewModel.idealWeightValue,
                currentWeight: viewModel.selectedWeight,
                height: viewModel.selectedHeight, // ✅ CRITIQUE : Passer height depuis le ViewModel
                weightGoal: viewModel.selectedWeightGoal,
                firstName: viewModel.firstName, // ✅ CRITIQUE : Passer firstName depuis le ViewModel
                onValidationChanged: { isValid in
                    viewModel.isIdealWeightEntered = isValid
                }
            )
        case .weightMotivation:
            WeightMotivationStepView(
                viewModel: viewModel, // ✅ Passer le ViewModel
                currentWeight: viewModel.selectedWeight,
                idealWeight: viewModel.idealWeightValue,
                weightGoal: viewModel.selectedWeightGoal,
                onComplete: nextStep,
                onValidationChanged: { _ in
                    // Validation automatique
                }
            )
        case .hasSportActivity:
            HasSportActivityStepView(
                hasSportActivity: $viewModel.hasSportActivity,
                onValidationChanged: { _ in
                    // Validation automatique
                }
            )
        case .sportSelection:
            SportSelectionStepView(
                onComplete: nextStep,
                onValidationChanged: { isValid in
                    viewModel.isSportsSelected = isValid
                },
                onSearchStateChanged: { isSearching in
                    isSportSearchActive = isSearching
                }
            )
        case .sportClub:
            SportClubStepView(
                isInClub: $viewModel.isInClub,
                selectedSport: profileService.currentProfile?.sports.first?.name ?? "sport",
                onValidationChanged: { _ in
                    // Validation automatique
                },
                onBack: previousStep
            )
        case .experienceLevel:
            ExperienceLevelStepView(
                selectedLevel: $viewModel.selectedExperienceLevel,
                onValidationChanged: { isValid in
                    viewModel.isExperienceLevelSelected = isValid
                    if isValid {
                        Task {
                            await savePlanDataProgressively()
                        }
                    }
                }
            )
        case .yearsOfExperience:
            EmptyView()
                .onAppear { nextStep() }
        case .deadlineSelection, .eventDetails:
            // Flux « deadline / combat / course » retiré de l'onboarding (reprise de progression ancienne)
            EmptyView()
                .onAppear { nextStep() }
        case .goalProjection:
            GoalProjectionStepView(
                primaryGoals: viewModel.selectedPrimaryGoals,
                currentWeight: viewModel.selectedWeight,
                idealWeight: viewModel.isIdealWeightEntered ? viewModel.idealWeightValue : nil,
                weightGoal: viewModel.selectedWeightGoal,
                experienceLevel: viewModel.selectedExperienceLevel,
                yearsOfExperience: viewModel.selectedYearsOfExperience,
                selectedSports: Set(profileService.currentProfile?.sports.map { $0.name } ?? []),
                deadline: viewModel.goalDeadline,
                trainingFrequency: viewModel.selectedTrainingFrequency,
                goalPace: viewModel.selectedGoalPace
            )
        case .goalPace:
            GoalPaceStepView(
                selectedPace: $viewModel.selectedGoalPace,
                weightGoal: viewModel.selectedWeightGoal,
                onValidationChanged: { isValid in
                    viewModel.isGoalPaceSelected = isValid
                }
            )
        case .potentialPace:
            EmptyView()
                .onAppear {
                    Logger.debug("[OnboardingView] potentialPace (étape 21) MONTÉE - Appel de nextStep()", category: "Onboarding")
                    nextStep()
                }
        case .weightEstimation:
            if viewModel.selectedPrimaryGoals.contains(.manageWeight),
               let weightGoal = viewModel.selectedWeightGoal,
               viewModel.isIdealWeightEntered {
                WeightEstimationStepView(
                    currentWeight: viewModel.selectedWeight,
                    idealWeight: viewModel.idealWeightValue,
                    weightGoal: weightGoal,
                    weeklyRate: viewModel.selectedGoalPace?.weightEstimationWeeklyRate ?? 0.5,
                    // ✅ Paramètres pour la deuxième estimation (après questions sport)
                    experienceLevel: viewModel.selectedExperienceLevel,
                    yearsOfExperience: viewModel.selectedYearsOfExperience,
                    selectedSports: Set(profileService.currentProfile?.sports.map { $0.name } ?? []),
                    deadline: viewModel.goalDeadline,
                    trainingFrequency: viewModel.selectedTrainingFrequency,
                    goalPace: viewModel.selectedGoalPace,
                    onValidationChanged: { isValid in
                        // ✅ Mettre à jour l'état de validation dans le ViewModel
                        // Le bouton "Continuer" apparaîtra seulement quand isValid est true
                        // (après que l'animation du compteur soit terminée)
                        viewModel.isWeightEstimationCompleted = isValid
                    }
                )
            } else {
                EmptyView()
                    .onAppear { nextStep() }
            }
        case .trainingFrequency:
            EmptyView()
                .onAppear { nextStep() }
        case .nutritionQuality:
            NutritionQualityStepView(
                selectedQuality: $viewModel.nutritionProfile.nutritionQuality,
                onValidationChanged: { isValid in
                    viewModel.isNutritionQualitySelected = isValid
                }
            )
        case .nutritionScanFeature:
            EmptyView()
                .onAppear { nextStep() }
        case .hasDietaryRestrictions:
            HasDietaryRestrictionsStepView(
                hasDietaryRestrictions: $viewModel.hasDietaryRestrictions,
                onValidationChanged: { isValid in
                    viewModel.isHasDietaryRestrictionsSelected = isValid
                }
            )
        case .whichRestrictions:
            WhichRestrictionsStepView(
                selectedRestrictions: $viewModel.nutritionProfile.dietaryRestrictions,
                otherRestriction: $viewModel.otherDietaryRestriction,
                onValidationChanged: { isValid in
                    viewModel.isWhichRestrictionsSelected = isValid
                    if !viewModel.otherDietaryRestriction.isEmpty {
                        viewModel.nutritionProfile.otherRestrictions = viewModel.otherDietaryRestriction
                    }
                }
            )
        case .weightManagementExperience:
            WeightManagementExperienceStepView(
                selectedExperience: $viewModel.nutritionProfile.weightManagementExperience,
                weightGoal: viewModel.selectedWeightGoal,
                onValidationChanged: { isValid in
                    viewModel.isWeightManagementExperienceSelected = isValid
                }
            )
        case .weightFailureReasons:
            WeightFailureReasonsStepView(
                selectedReasons: $viewModel.nutritionProfile.nutritionObstacles,
                onValidationChanged: { _ in
                    // Validation automatique
                }
            )
        case .hardestMeal:
            HardestMealStepView(
                selectedMeal: $viewModel.nutritionProfile.hardestMeal,
                onValidationChanged: { isValid in
                    viewModel.isHardestMealSelected = isValid
                }
            )
        case .nutritionPotential:
            // ✅ Page supprimée : sauter directement
            EmptyView()
                .onAppear { nextStep() }
        case .nutritionObstacles:
            EmptyView()
                .onAppear { nextStep() }
        case .perfectNutritionBelief:
            EmptyView()
                .onAppear { nextStep() }
        case .hasSufficientHydration:
            EmptyView()
                .onAppear { nextStep() }
        case .hydrationLevel:
            EmptyView()
                .onAppear { nextStep() }
        // Ces pages ont été complètement retirées du flux d'onboarding
        case .sleepNeed:
            // ✅ Supprimé : Page désactivée - Passer automatiquement à l'étape suivante
            EmptyView()
                .onAppear { nextStep() }
        case .faceAnalysis:
            EmptyView()
                .onAppear { nextStep() }
        case .planGeneration:
            EmptyView()
                .onAppear { nextStep() }
        case .healthKitPermissions:
            HealthKitPermissionsStepView(
                healthKitGranted: viewModel.healthKitGranted,
                checkPermissions: checkPermissions,
                firstName: viewModel.firstName // ✅ CRITIQUE : Passer firstName depuis le ViewModel
            )
        case .sleepDataRecovery:
            HealthDataAnimationStepView(
                onComplete: {
                    nextStep()
                },
                onBack: previousStep
            )
        case .newsStep, .sleepNeedReveal, .sleepDebtInfo:
            // Pages supprimées — uniquement migration ancienne sauvegarde (45–47)
            EmptyView()
                .onAppear { nextStep() }
        case .alarmConfiguration:
            AlarmConfigurationStepView(
                onComplete: {
                    nextStep()
                },
                onValidationChanged: { _ in
                    // Validation automatique
                },
                onBack: previousStep
            )
            .sheet(isPresented: $showingAlarmSheet) {
                AlarmCreationSheet(
                    editingAlarm: nil,
                    onAlarmCreated: {
                        // ✅ Callback direct : l'alarme a été créée, passer à l'étape suivante immédiatement
                        Logger.debug("[OnboardingView] Callback reçu : alarme créée, passage à l'étape suivante", category: "Onboarding")
                        nextStep()
                    }
                )
            }
        case .sleepWindowReveal:
            SleepWindowRevealStepView(
                onComplete: {
                    nextStep()
                },
                onValidationChanged: { _ in
                    // Validation automatique
                },
                onBack: previousStep
            )
        case .planReady:
            EmptyView()
                .onAppear { nextStep() }
        case .onboardingInfo:
            EmptyView()
                .onAppear { nextStep() }
        case .appleSignIn:
            AppleSignInStepView(onComplete: {
                // ✅ CRITIQUE: Forcer la validation après Apple Sign In
                Task {
                    // Attendre un peu pour que l'auth soit bien synchronisée
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    // Forcer la mise à jour de la validation
                    await MainActor.run {
                        // Vérifier que l'utilisateur est bien authentifié
                        if Auth.auth().currentUser != nil {
                            nextStep()
                        } else {
                            Logger.warning("Utilisateur non authentifié après Apple Sign In", category: "Onboarding")
                        }
                    }
                }
            })
        // ✅ TEMPORAIRE : Pages désactivées dans le flux (gardées dans le code)
        case .referralCode:
            // ✅ Cette page est sautée dans OnboardingNavigationEngine
            ReferralCodeStepView(
                onComplete: nextStep,
                onBack: previousStep
            )
        case .appRating:
            AppRatingStepView(
                onComplete: nextStep,
                onBack: previousStep
            )
        // ✅ TEMPORAIRE : Pages désactivées dans le flux (gardées dans le code)
        case .caloriesGoal:
            // ✅ Cette page est sautée dans OnboardingNavigationEngine
            CaloriesGoalStepView(
                onComplete: nextStep,
                onBack: previousStep
            )
        case .carryOverCalories:
            // ✅ Cette page est sautée dans OnboardingNavigationEngine
            CarryOverCaloriesStepView(
                onComplete: nextStep,
                onBack: previousStep
            )
        case .programCreation:
            ProgramCreationStepView(
                onComplete: nextStep,
                onBack: previousStep,
                onValidationChanged: { isValid in
                    viewModel.isProgramCreationCompleted = isValid
                }
            )
            .onAppear {
                // Réinitialiser la validation quand on arrive sur la page
                viewModel.isProgramCreationCompleted = false
            }
        case .biometricAuth:
            BiometricAuthStepView(
                onComplete: nextStep,
                onBack: previousStep,
                onAuthenticationComplete: { completed in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        biometricAuthCompleted = completed
                    }
                }
            )
            .onAppear {
                // Réinitialiser l'état quand on arrive sur cette page
                biometricAuthCompleted = false
            }
        case .notificationPermission:
            NotificationPermissionStepView(
                onComplete: nextStep,
                onBack: previousStep
            )
        case .payment:
            PaywallView(onComplete: {
                // Après le paiement, afficher les pages de bienvenue
                nextStep()
            }, onBack: previousStep)
        case .processWelcome:
            ProcessWelcomeView(onComplete: {
                // ✅ CRITIQUE: Terminer l'onboarding directement après "Commencer"
                Task { @MainActor in
                    await completeOnboarding()
                }
            }, onBack: previousStep)
        case .complete:
            CompleteStepView()
        @unknown default:
            EmptyView()
                .onAppear {
                    Logger.error("OnboardingStep inconnu: \(step)", category: "Onboarding")
                    nextStep()
                }
        }

    }
}
