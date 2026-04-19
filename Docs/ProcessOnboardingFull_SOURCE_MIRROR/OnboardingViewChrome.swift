//
//  OnboardingViewChrome.swift
//  Process
//
//  Barre d’actions spécifiques (HealthKit, fin, calories, etc.) et header onboarding
//  (retour, progression, langue). Extrait de OnboardingView pour réduire la taille du fichier.
//

import SwiftUI

// MARK: - Barre du bas (étapes avec boutons dédiés)

struct OnboardingSpecificBottomBar: View {
    @ObservedObject var viewModel: OnboardingViewModel
    var hapticManager: HapticManager
    @Binding var caloriesGoalSelected: Bool?
    @Binding var carryOverCaloriesSelected: Bool?
    @Binding var biometricAuthCompleted: Bool
    @Binding var showingAlarmSheet: Bool

    var onNextStep: () -> Void
    var onRequestHealthKit: () async -> Void
    var onCompleteOnboarding: () async -> Void
    var onBiometricContinue: () async -> Void

    var body: some View {
        bottomButtonContent
    }

    @ViewBuilder
    private var bottomButtonContent: some View {
        switch OnboardingStep(rawValue: viewModel.currentStep) {
        case .healthKitPermissions:
            Button(action: {
                Task {
                    await onRequestHealthKit()
                }
            }) {
                HStack(spacing: 12) {
                    if viewModel.isRequestingHealthKit {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(viewModel.isRequestingHealthKit ? "Demande en cours..." : "AUTORISER L'ACCÈS")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .glassStyle()
            .buttonBorderShape(.roundedRectangle(radius: 50))
            .padding(.horizontal, 40)

        case .complete:
            Button(action: {
                Task {
                    await onCompleteOnboarding()
                }
            }) {
                HStack(spacing: 12) {
                    if viewModel.isCompleting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(viewModel.isCompleting ? "Finalisation..." : "TERMINER")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .glassStyle()
            .buttonBorderShape(.roundedRectangle(radius: 50))
            .padding(.horizontal, 40)
            .disabled(viewModel.isCompleting)

        case .caloriesGoal:
            HStack(spacing: 12) {
                Button(action: {
                    hapticManager.impact(.medium)
                    caloriesGoalSelected = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onNextStep()
                    }
                }) {
                    Text("Non")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 50))

                Button(action: {
                    hapticManager.impact(.medium)
                    caloriesGoalSelected = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onNextStep()
                    }
                }) {
                    Text("Oui")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 50))
            }
            .padding(.horizontal, 40)

        case .carryOverCalories:
            HStack(spacing: 12) {
                Button(action: {
                    hapticManager.impact(.medium)
                    carryOverCaloriesSelected = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onNextStep()
                    }
                }) {
                    Text("Non")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 50))

                Button(action: {
                    hapticManager.impact(.medium)
                    carryOverCaloriesSelected = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onNextStep()
                    }
                }) {
                    Text("Oui")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 50))
            }
            .padding(.horizontal, 40)

        case .hasDietaryRestrictions:
            HStack(spacing: 12) {
                Button(action: {
                    hapticManager.impact(.medium)
                    viewModel.hasDietaryRestrictions = false
                    viewModel.isHasDietaryRestrictionsSelected = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onNextStep()
                    }
                }) {
                    Text("Non")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 50))

                Button(action: {
                    hapticManager.impact(.medium)
                    viewModel.hasDietaryRestrictions = true
                    viewModel.isHasDietaryRestrictionsSelected = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onNextStep()
                    }
                }) {
                    Text("Oui")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 50))
            }
            .padding(.horizontal, 40)

        case .biometricAuth:
            if biometricAuthCompleted {
                Button(action: {
                    Task {
                        await onBiometricContinue()
                    }
                }) {
                    Text("Je m'engage envers moi-même")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 50))
                .padding(.horizontal, 40)
                .transition(.opacity.combined(with: .scale))
            }

        case .alarmConfiguration:
            VStack(spacing: 12) {
                Button(action: {
                    showingAlarmSheet = true
                }) {
                    Text("Créer une alarme")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 50))
                .padding(.horizontal, 40)
                .disabled(!viewModel.isCurrentStepValidated())
                .opacity(viewModel.isCurrentStepValidated() ? 1.0 : 0.0)
                .allowsHitTesting(viewModel.isCurrentStepValidated())

                #if DEBUG
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    Logger.debug("[DEBUG] Passage forcé de la page alarme depuis OnboardingView", category: "Onboarding")
                    onNextStep()
                }) {
                    Text("🔧 Passer (DEBUG)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 22))
                .padding(.horizontal, 40)
                #endif
            }

        case .bodyScan:
            EmptyView()

        default:
            let isValid = viewModel.isCurrentStepValidated()
            let currentStep = OnboardingStep(rawValue: viewModel.currentStep)

            let canContinue: Bool = {
                if currentStep == .height {
                    return viewModel.selectedHeight > 0
                } else if currentStep == .weight {
                    return viewModel.selectedWeight > 0
                } else {
                    return isValid
                }
            }()

            Button(action: {
                Logger.debug("[OnboardingView] Bouton CONTINUER cliqué pour step \(viewModel.currentStep)", category: "Onboarding")
                onNextStep()
            }) {
                Text("CONTINUER")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .glassStyle()
            .buttonBorderShape(.roundedRectangle(radius: 50))
            .padding(.horizontal, 40)
            .disabled(!canContinue)
            .opacity(canContinue ? 1.0 : 0.5)
            .animation(.easeInOut(duration: 0.3), value: canContinue)
            .allowsHitTesting(canContinue)
            .onAppear {
                if currentStep == .height || currentStep == .weight {
                    Logger.debug("[OnboardingView] Bouton CONTINUER pour \(currentStep?.rawValue ?? -1) - isValid: \(isValid), isHeightWeightSelected: \(viewModel.isHeightWeightSelected), selectedHeight: \(viewModel.selectedHeight), selectedWeight: \(viewModel.selectedWeight)", category: "Onboarding")
                }
            }
        }
    }
}

// MARK: - Header (retour, progression, langue)

struct OnboardingHeaderChrome: View {
    @EnvironmentObject private var profileService: UnifiedProfileService
    @ObservedObject var viewModel: OnboardingViewModel
    var hapticManager: HapticManager
    var shouldShowBackButton: Bool
    var totalStepsForFlow: () -> Int
    var onPreviousStep: () -> Void

    var body: some View {
        headerContent
    }

    @ViewBuilder
    private var headerContent: some View {
        let isEstimationPage = viewModel.currentStep == OnboardingStep.goalProjection.rawValue || viewModel.currentStep == OnboardingStep.weightEstimation.rawValue

        let pagesWithFullHeader: Set<Int> = [
            OnboardingStep.height.rawValue,
            OnboardingStep.weight.rawValue,
            OnboardingStep.heightWeight.rawValue
        ]

        let isInNormalRange = viewModel.currentStep > OnboardingStep.videoIntroduction.rawValue && viewModel.currentStep <= OnboardingStep.healthKitPermissions.rawValue
        let shouldShowFullHeader = (isInNormalRange || pagesWithFullHeader.contains(viewModel.currentStep)) && !isEstimationPage

        let shouldShowBackButtonOnly = viewModel.currentStep == OnboardingStep.appleSignIn.rawValue && shouldShowBackButton

        let pagesWithOwnBackButton: [Int] = [
            OnboardingStep.processWelcome.rawValue
        ]
        let shouldShowBackButtonOnlyAfterHealthKit = viewModel.currentStep > OnboardingStep.healthKitPermissions.rawValue &&
            !pagesWithOwnBackButton.contains(viewModel.currentStep) &&
            shouldShowBackButton

        if shouldShowFullHeader {
            VStack {
                HStack(spacing: 12) {
                    if shouldShowBackButton {
                        Button(action: {
                            hapticManager.impact(.light)
                            onPreviousStep()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 34, height: 34)
                        }
                        .glassStyle()
                        .buttonBorderShape(.circle)
                    } else {
                        Spacer()
                            .frame(width: 34, height: 34)
                    }

                    let visitedCount = max(1, viewModel.visitedSteps.count)
                    let estimatedTotal = max(totalStepsForFlow(), visitedCount)
                    OnboardingProgressBar(
                        currentStep: visitedCount - 1,
                        totalSteps: estimatedTotal
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 8)

                    LanguageSelectorView()
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)

                Spacer()
            }
        } else if shouldShowBackButtonOnly || shouldShowBackButtonOnlyAfterHealthKit {
            VStack {
                HStack {
                    Button(action: {
                        hapticManager.impact(.light)
                        onPreviousStep()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 34, height: 34)
                    }
                    .glassStyle()
                    .buttonBorderShape(.circle)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)

                Spacer()
            }
        } else {
            EmptyView()
        }
    }
}
