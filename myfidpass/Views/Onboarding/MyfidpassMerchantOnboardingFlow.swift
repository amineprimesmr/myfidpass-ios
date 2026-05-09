//
//  MyfidpassMerchantOnboardingFlow.swift
//  myfidpass
//
//  Premier lancement (version courte) : nom d’établissement → connexion / inscription (RootView).
//

import SwiftUI
import Combine
import UIKit

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
            return selectedPlaceId != nil || relaxEstablishmentRequirement
        }
    }

    func persistSelectionsToUserDefaults() {
        let d = UserDefaults.standard
        if let pid = selectedPlaceId?.trimmingCharacters(in: .whitespacesAndNewlines),
           let desc = selectedPlaceDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
           !pid.isEmpty, !desc.isEmpty {
            d.set(pid, forKey: "myfidpass.ob.placeId")
            d.set(desc, forKey: "myfidpass.ob.placeDescription")
            d.removeObject(forKey: "myfidpass.ob.establishments")
            MerchantLinkedPlaceCache.save(placeId: pid, description: desc)
        } else {
            d.removeObject(forKey: "myfidpass.ob.placeId")
            d.removeObject(forKey: "myfidpass.ob.placeDescription")
            d.removeObject(forKey: "myfidpass.ob.establishments")
        }
        d.set(relaxEstablishmentRequirement, forKey: "myfidpass.ob.relaxPlaceRequirement")
        let snap = FirstLaunchOnboarding.readPendingEstablishment()
        if let pid = snap.placeId?.trimmingCharacters(in: .whitespacesAndNewlines), !pid.isEmpty,
           let name = snap.description?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            FirstLaunchOnboarding.persistSignupCommerceDraftBackup(placeId: pid, establishmentName: name)
        } else {
            FirstLaunchOnboarding.clearSignupCommerceDraftBackup()
        }
    }
}

// MARK: - Racine

struct MyfidpassMerchantOnboardingRootView: View {
    var onComplete: () -> Void
    /// Passer à l’écran connexion / inscription sans renseigner l’établissement (compte existant).
    var onAlreadyHaveAccount: (() -> Void)? = nil

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = MerchantOBViewModel()
    @StateObject private var hapticManager = HapticManager.shared
    @State private var keyboardHeight: CGFloat = 0
    @State private var isEstablishmentPredictionsVisible = false

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
        viewModel.currentStep > 0 || onAlreadyHaveAccount != nil
    }

    private var shouldShowGlobalContinue: Bool {
        step == .establishmentSearch && !isEstablishmentPredictionsVisible
    }

    private var canContinueNow: Bool {
        viewModel.canContinue(for: step)
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

            // Derrière le contenu : sinon le dégradé recouvre l’UI et les cartes (ex. propositions) paraissent transparentes.
            processAnimatedGlow

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
            .zIndex(0)

            if shouldShowGlobalContinue {
                VStack {
                    Spacer()

                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Button(action: handleContinueTap) {
                            Text("CONTINUER")
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(.black)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .buttonBorderShape(.roundedRectangle(radius: 50))
                        .liquidGlassButtonAppearance(.adaptive, cornerRadius: 50)
                        .frame(maxWidth: horizontalSizeClass == .regular ? 520 : .infinity)
                        .disabled(!canContinueNow)
                        .opacity(canContinueNow ? 1.0 : 0.5)
                        .allowsHitTesting(canContinueNow)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 40)

                    Spacer()
                        .frame(height: continueButtonsBottomInset)
                }
                .animation(.onboardingTransition, value: viewModel.currentStep)
                .animation(.easeOut(duration: 0.2), value: keyboardHeight)
                .zIndex(1)
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
                                    .foregroundStyle(Color.primary.opacity(0.88))
                                    .frame(width: 34, height: 34)
                            }
                            .buttonBorderShape(.circle)
                            .liquidGlassButtonAppearance(.adaptive, cornerRadius: 17)
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
                    .padding(.top, max(topSafeInset, 44) + 8)

                    Spacer()
                }
                .zIndex(3)
            }
        }
        .ignoresSafeArea(.all)
        .preferredColorScheme(.light)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard
                let userInfo = note.userInfo,
                let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            else { return }
            let screenH = UIScreen.main.bounds.height
            let overlap = max(0, screenH - endFrame.origin.y)
            keyboardHeight = overlap
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
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
    private var topSafeInset: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.top ?? 0
    }
    private var continueButtonsBottomInset: CGFloat {
        if keyboardHeight > 0 {
            // Place les actions juste au-dessus du clavier.
            return max(10, keyboardHeight + 6)
        }
        return continueButtonBottomOffset
    }

    private func handleContinueTap() {
        guard canContinueNow else { return }
        hapticManager.impact(.medium)
        switch step {
        case .establishmentSearch:
            finishOnboardingAndHandOffToAuth()
        }
    }

    private func goBack() {
        if viewModel.currentStep == 0 {
            onAlreadyHaveAccount?()
            return
        }
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
                relaxRequirement: $viewModel.relaxEstablishmentRequirement,
                isPredictionsVisible: $isEstablishmentPredictionsVisible
            )
        }
    }
}

// MARK: - Recherche établissement (même API que l’inscription)

private struct MerchantOBEstablishmentSearchContent: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var selectedPlaceId: String?
    @Binding var selectedDescription: String?
    @Binding var relaxRequirement: Bool
    @Binding var isPredictionsVisible: Bool

    private var establishmentSearchTopReserved: CGFloat {
        if horizontalSizeClass == .regular {
            return 56
        }
        return MyfidpassOnboardingConstants.titleAreaHeight
            + MyfidpassOnboardingConstants.titleToContentSpacing
            + MyfidpassOnboardingConstants.processStyleFieldExtraSpacing
    }

    private var horizontalGutter: CGFloat {
        horizontalSizeClass == .regular ? 40 : 16
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: establishmentSearchTopReserved)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        GoogleEstablishmentPicker(
                            selectedPlaceId: $selectedPlaceId,
                            selectedDescription: $selectedDescription,
                            relaxRequirement: $relaxRequirement,
                            compactIntro: true,
                            processEstablishmentStyle: true,
                            onPredictionsVisibilityChanged: { visible in
                                isPredictionsVisible = visible
                            }
                        )
                        .padding(.horizontal, horizontalGutter)
                    }
                    .padding(.bottom, 24)
                }
            }
        }
    }
}
