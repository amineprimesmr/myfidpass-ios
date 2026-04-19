//
//  MyfidpassMerchantOnboardingFlow.swift
//  myfidpass
//
//  Premier lancement (version courte) : nom d’établissement → connexion / inscription (RootView).
//

import SwiftUI
import Combine

// MARK: - Étapes du parcours commerçant

private enum MerchantOBStep: Int, CaseIterable {
    case establishmentSearch = 0
}

@MainActor
private final class MerchantOBViewModel: ObservableObject {
    @Published var currentStep: Int = 0
    @Published var visitedSteps: [Int] = [0]

    @Published var selectedPlaceId: String?
    @Published var selectedPlaceDescription: String?
    @Published var relaxEstablishmentRequirement = false

    let flowStepCount: Int = MerchantOBStep.allCases.count

    var visitedCount: Int { max(1, visitedSteps.count) }

    func estimatedTotalForBar() -> Int {
        max(flowStepCount, visitedCount)
    }

    func appendVisited(_ index: Int) {
        if !visitedSteps.contains(index) {
            visitedSteps.append(index)
        }
    }

    func canContinue(for step: MerchantOBStep) -> Bool {
        switch step {
        case .establishmentSearch:
            return selectedPlaceId != nil
        }
    }

    func persistSelectionsToUserDefaults() {
        let d = UserDefaults.standard
        if let pid = selectedPlaceId?.trimmingCharacters(in: .whitespacesAndNewlines), !pid.isEmpty {
            d.set(pid, forKey: "myfidpass.ob.placeId")
        }
        if let desc = selectedPlaceDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
            d.set(desc, forKey: "myfidpass.ob.placeDescription")
        }
        d.set(relaxEstablishmentRequirement, forKey: "myfidpass.ob.relaxPlaceRequirement")
        if let pid = selectedPlaceId?.trimmingCharacters(in: .whitespacesAndNewlines), !pid.isEmpty {
            MerchantLinkedPlaceCache.save(placeId: pid, description: selectedPlaceDescription)
        }
    }
}

// MARK: - Racine

struct MyfidpassMerchantOnboardingRootView: View {
    var onComplete: () -> Void
    /// Passer à l’écran connexion / inscription sans renseigner l’établissement (compte existant).
    var onAlreadyHaveAccount: (() -> Void)? = nil

    @StateObject private var viewModel = MerchantOBViewModel()
    @StateObject private var hapticManager = HapticManager.shared

    private var step: MerchantOBStep {
        MerchantOBStep(rawValue: viewModel.currentStep) ?? .establishmentSearch
    }

    private func totalStepsForFlow() -> Int {
        viewModel.flowStepCount
    }

    private var shouldShowFullProcessHeader: Bool {
        true
    }

    private var shouldShowBackButton: Bool {
        viewModel.currentStep > 0
    }

    private var shouldShowGlobalContinue: Bool {
        step == .establishmentSearch
    }

    private var canContinueNow: Bool {
        viewModel.canContinue(for: step)
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Group {
                    stepContent(for: step)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, shouldAddTopPadding ? 60 : 0)
                .ignoresSafeArea(.all)
                .animation(.onboardingTransition, value: viewModel.currentStep)
                .id("onboarding_content_\(viewModel.currentStep)")
            }

            if shouldShowGlobalContinue {
                VStack {
                    Spacer()

                    Button(action: handleContinueTap) {
                        Text("CONTINUER")
                            .font(.system(size: 20, weight: .black))
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .glassStyle()
                    .buttonBorderShape(.roundedRectangle(radius: 50))
                    .tint(.primary)
                    .padding(.horizontal, 40)
                    .disabled(!canContinueNow)
                    .opacity(canContinueNow ? 1.0 : 0.5)
                    .allowsHitTesting(canContinueNow)

                    if let skipToLogin = onAlreadyHaveAccount {
                        Button {
                            hapticManager.impact(.light)
                            skipToLogin()
                        } label: {
                            Text("J’ai déjà un compte")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 6)
                    }

                    Spacer()
                        .frame(height: continueButtonBottomOffset)
                }
                .animation(.onboardingTransition, value: viewModel.currentStep)
            }

            if shouldShowFullProcessHeader {
                VStack {
                    HStack(spacing: 12) {
                        if shouldShowBackButton {
                            Button(action: {
                                hapticManager.impact(.light)
                                goBack()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.Colors.textPrimary.opacity(0.85))
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
            }

            processAnimatedGlow
        }
        .ignoresSafeArea(.all)
        .preferredColorScheme(.light)
    }

    private var processAnimatedGlow: some View {
        let visitedCount = max(1, viewModel.visitedSteps.count)
        let estimatedTotal = max(totalStepsForFlow(), visitedCount)
        return AnimatedOnboardingGlow(
            currentStep: viewModel.currentStep,
            visitedStepsCount: visitedCount,
            totalStepsForFlow: estimatedTotal
        )
        .opacity(0.22)
        .ignoresSafeArea(.all)
        .allowsHitTesting(false)
    }

    private var shouldAddTopPadding: Bool {
        true
    }

    private var continueButtonBottomOffset: CGFloat { 50 }

    private func handleContinueTap() {
        guard canContinueNow else { return }
        hapticManager.impact(.medium)
        switch step {
        case .establishmentSearch:
            finishOnboardingAndHandOffToAuth()
        }
    }

    private func goBack() {
        guard viewModel.currentStep > 0 else { return }
        viewModel.visitedSteps.removeAll { $0 == viewModel.currentStep }
        withAnimation(.onboardingTransition) {
            viewModel.currentStep -= 1
        }
    }

    /// Fin du flux : enregistre le lieu puis affiche RootView (connexion / inscription).
    private func finishOnboardingAndHandOffToAuth() {
        viewModel.persistSelectionsToUserDefaults()
        hapticManager.notification(.success)
        onComplete()
    }

    // MARK: Contenu

    @ViewBuilder
    private func stepContent(for step: MerchantOBStep) -> some View {
        switch step {
        case .establishmentSearch:
            MerchantOBEstablishmentSearchContent(
                selectedPlaceId: $viewModel.selectedPlaceId,
                selectedDescription: $viewModel.selectedPlaceDescription,
                relaxRequirement: $viewModel.relaxEstablishmentRequirement
            )
        }
    }
}

// MARK: - Recherche établissement (même API que l’inscription)

private struct MerchantOBEstablishmentSearchContent: View {
    @Binding var selectedPlaceId: String?
    @Binding var selectedDescription: String?
    @Binding var relaxRequirement: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: MyfidpassOnboardingConstants.titleAreaHeight)
                Spacer()
                    .frame(
                        height: MyfidpassOnboardingConstants.titleToContentSpacing
                            + MyfidpassOnboardingConstants.processStyleFieldExtraSpacing
                    )

                ScrollView(showsIndicators: false) {
                    GoogleEstablishmentPicker(
                        selectedPlaceId: $selectedPlaceId,
                        selectedDescription: $selectedDescription,
                        relaxRequirement: $relaxRequirement,
                        compactIntro: true,
                        processEstablishmentStyle: true
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}
