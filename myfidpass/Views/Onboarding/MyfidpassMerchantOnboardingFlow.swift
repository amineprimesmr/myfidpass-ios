//
//  MyfidpassMerchantOnboardingFlow.swift
//  myfidpass
//
//  Premier lancement : nom d’établissement → e-mail → connexion / inscription (RootView).
//

import SwiftUI
import Combine
import UIKit
import PhotosUI

// MARK: - Feature flags (MAJ temporaire)

/// `true` : après vérification e-mail, pas d’étapes création carte (tampons, logo, média, couleurs, aperçu).
private enum MerchantOnboardingFeatureFlags {
    static let skipsCardSetupSteps = true
}

// MARK: - Étapes du parcours commerçant

private enum MerchantOBStep: Int, CaseIterable {
    case welcome = 0
    case establishmentSearch = 1
    case emailCapture = 2
    case otpVerification = 3
    case cardProgram = 4
    case cardLogo = 5
    case cardMedia = 6
    case cardColors = 7
    case cardPreview = 8
    case subscriptionPaywall = 9
}

private enum MerchantOnboardingProgress {
    /// Parcours sans étapes carte (welcome + paywall sans barre) : établissement → e-mail → OTP = 3 segments.
    static var totalSegments: Int {
        MerchantOnboardingFeatureFlags.skipsCardSetupSteps ? 3 : 6
    }
}

@MainActor
private final class MerchantOBViewModel: ObservableObject {
    @Published var currentStep: Int = 0
    @Published var visitedSteps: [Int] = [0]

    @Published var selectedPlaceId: String?
    @Published var selectedPlaceDescription: String?
    @Published var relaxEstablishmentRequirement = false

    @Published var signupEmail: String = ""
    @Published var isCheckingEmail = false
    @Published var emailError: String?
    @Published var showExistingAccountSheet = false

    @Published var otpCode = ""
    @Published var isSendingOtpCode = false
    @Published var isVerifyingOtp = false
    @Published var otpError: String?
    @Published var otpShowSuccess = false
    @Published var otpAdvanceInFlight = false

    @Published var cardDraft = MerchantOBCardDraft()
    @Published var cardLogoPhotoItem: PhotosPickerItem?
    @Published var cardBackgroundPhotoItem: PhotosPickerItem?
    @Published var cardSetupError: String?
    @Published var isSavingCardSetup = false

    let flowStepCount: Int = MerchantOBStep.allCases.count

    var visitedCount: Int { max(1, visitedSteps.count) }

    var normalizedSignupEmail: String {
        signupEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var isSignupEmailValid: Bool {
        MerchantOnboardingEmailValidation.isValid(normalizedSignupEmail)
    }

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
        case .welcome:
            return true
        case .establishmentSearch:
            return selectedPlaceId != nil || relaxEstablishmentRequirement
        case .emailCapture:
            return isSignupEmailValid && !isCheckingEmail && !isSendingOtpCode
        case .otpVerification:
            return false
        case .cardProgram:
            return true
        case .cardLogo, .cardMedia, .cardColors:
            return true
        case .cardPreview:
            return !isSavingCardSetup
        case .subscriptionPaywall:
            return false
        }
    }

    func filledProgressSegments(for step: MerchantOBStep) -> Int {
        if MerchantOnboardingFeatureFlags.skipsCardSetupSteps {
            switch step {
            case .welcome: return 0
            case .establishmentSearch: return 1
            case .emailCapture: return 2
            case .otpVerification: return 3
            case .subscriptionPaywall: return MerchantOnboardingProgress.totalSegments
            case .cardProgram, .cardLogo, .cardMedia, .cardColors, .cardPreview:
                return 3
            }
        }
        switch step {
        case .welcome: return 0
        case .establishmentSearch: return 1
        case .emailCapture: return 2
        case .otpVerification: return 3
        case .cardProgram: return 4
        case .cardLogo: return 5
        case .cardMedia, .cardColors: return 5
        case .cardPreview, .subscriptionPaywall: return 6
        }
    }

    func seedCardDraftFromEstablishment() {
        let desc = selectedPlaceDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !desc.isEmpty {
            let parts = desc.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            let title = parts.first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? desc
            if !title.isEmpty {
                cardDraft.displayName = title
            }
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

enum MerchantOnboardingEmailValidation {
    static func isValid(_ email: String) -> Bool {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard e.count >= 5, e.contains("@") else { return false }
        let parts = e.split(separator: "@")
        guard parts.count == 2, let domain = parts.last, domain.contains(".") else { return false }
        return true
    }
}

// MARK: - Racine

struct MyfidpassMerchantOnboardingRootView: View {
    /// Console admin : création commerçant (même UI que le premier lancement, sans dépendre du timing `onAppear`).
    var adminProvisioningMode: Bool = false
    var onComplete: () -> Void
    var onSignIn: (() -> Void)? = nil
    /// Passer à l’écran connexion sans renseigner l’établissement (legacy).
    var onAlreadyHaveAccount: (() -> Void)? = nil
    /// E-mail déjà enregistré côté serveur — bascule connexion.
    var onExistingAccountEmail: ((String) -> Void)? = nil
    /// Fin du parcours admin (compte commerçant créé, session admin inchangée).
    var onAdminProvisioningFinished: ((String?) -> Void)? = nil
    /// Annulation du parcours admin (retour console).
    var onAdminProvisioningCancelled: (() -> Void)? = nil

    @EnvironmentObject private var authService: AuthService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = MerchantOBViewModel()
    @StateObject private var hapticManager = HapticManager.shared
    @State private var keyboardHeight: CGFloat = 0
    @State private var isEstablishmentPredictionsVisible = false
    @State private var previousStep: Int?
    @State private var isStepTransitionInFlight = false

    private var step: MerchantOBStep {
        MerchantOBStep(rawValue: viewModel.currentStep) ?? .welcome
    }

    private var shouldShowFullProcessHeader: Bool {
        switch step {
        case .welcome, .subscriptionPaywall:
            return false
        default:
            return true
        }
    }

    private var isAdminProvisioningFlow: Bool {
        adminProvisioningMode || authService.isAdminProvisioningMerchant
    }

    private var shouldShowBackButton: Bool {
        viewModel.currentStep > 0
    }

    private var shouldReserveTopChrome: Bool {
        shouldShowFullProcessHeader || (step == .welcome && isAdminProvisioningFlow)
    }

    private var shouldShowGlobalContinue: Bool {
        switch step {
        case .welcome:
            return true
        case .establishmentSearch:
            return !isEstablishmentPredictionsVisible
        case .emailCapture:
            return true
        case .otpVerification:
            return false
        case .cardProgram, .cardLogo, .cardMedia, .cardColors, .cardPreview:
            return true
        case .subscriptionPaywall:
            return false
        }
    }

    private var canContinueNow: Bool {
        viewModel.canContinue(for: step)
    }

    var body: some View {
        onboardingRootLayout
            .preferredColorScheme(.light)
        .sheet(isPresented: $viewModel.showExistingAccountSheet) {
            MerchantOnboardingExistingAccountSheet(
                email: viewModel.normalizedSignupEmail,
                onRecover: {
                    viewModel.showExistingAccountSheet = false
                    FirstLaunchOnboarding.persistSignupEmail(viewModel.normalizedSignupEmail)
                    hapticManager.notification(.success)
                    onExistingAccountEmail?(viewModel.normalizedSignupEmail)
                },
                onDismiss: {
                    viewModel.showExistingAccountSheet = false
                }
            )
        }
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
        .onChange(of: viewModel.signupEmail) { _, _ in
            if viewModel.emailError != nil {
                viewModel.emailError = nil
            }
        }
        .onChange(of: viewModel.otpCode) { oldValue, newValue in
            guard viewModel.otpError != nil else { return }
            let oldDigits = oldValue.filter(\.isNumber)
            let newDigits = newValue.filter(\.isNumber)
            guard newDigits != oldDigits, !newDigits.isEmpty else { return }
            viewModel.otpError = nil
        }
        .onChange(of: viewModel.cardLogoPhotoItem) { _, item in
            Task { await importCardLogo(from: item) }
        }
        .onChange(of: viewModel.cardBackgroundPhotoItem) { _, item in
            Task { await importCardBackground(from: item) }
        }
        .onAppear {
            if viewModel.signupEmail.isEmpty,
               let saved = FirstLaunchOnboarding.readLastKnownAuthEmail() {
                viewModel.signupEmail = saved
            }
        }
    }

    /// Welcome + étapes suivantes : même `ZStack` + `OnboardingTransitionContainer` (slide Process, pas de fade entre branches).
    private var onboardingRootLayout: some View {
        GeometryReader { geo in
            // Sous `.ignoresSafeArea()`, `geo.safeAreaInsets.top` est souvent 0 → illustration welcome trop haute.
            let topInset = merchantScanHeaderTopInset(from: geo)
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()

                if step == .welcome {
                    welcomeBackgroundLayer(topInset: topInset)
                        .transition(.identity)
                        .animation(nil, value: viewModel.currentStep)
                }

                processAnimatedGlow
                    .opacity(step == .welcome || step == .subscriptionPaywall ? 0 : 0.22)
                    .allowsHitTesting(false)

                OnboardingTransitionContainer(
                    currentStep: viewModel.currentStep,
                    previousStep: previousStep,
                    isTransitioning: false
                ) {
                    stepContent(for: step)
                }
                .padding(.top, shouldReserveTopChrome ? topChromeReservedHeight(topInset: topInset) : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(step != .welcome)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .bottom) {
                if shouldShowGlobalContinue {
                    onboardingBottomChrome
                        .allowsHitTesting(true)
                }
            }
            .overlay(alignment: .top) {
                if step == .welcome && isAdminProvisioningFlow {
                    adminWelcomeTopBar(topInset: topInset)
                } else if shouldShowFullProcessHeader {
                    processOnboardingHeaderBar(topInset: topInset)
                }
            }
        }
        .ignoresSafeArea()
        .onChange(of: viewModel.currentStep) { _, newStep in
            if newStep == MerchantOBStep.welcome.rawValue {
                keyboardHeight = 0
            }
        }
    }

    private func topChromeReservedHeight(topInset: CGFloat) -> CGFloat {
        max(topInset, 44) + 52
    }

    private func adminWelcomeTopBar(topInset: CGFloat) -> some View {
        HStack {
            adminHeaderCancelButton
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, max(topInset, 44) + 8)
    }

    private var adminHeaderCancelButton: some View {
        Button {
            hapticManager.impact(.light)
            authService.cancelAdminMerchantProvisioning()
            onAdminProvisioningCancelled?()
        } label: {
            Text("Annuler")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.88))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .glassStyle()
        .buttonBorderShape(.capsule)
    }

    /// Illustration plein écran (dégradé bas intégré) — les boutons passent par-dessus, sans bandeau.
    private func welcomeBackgroundLayer(topInset: CGFloat) -> some View {
        AuthWelcomeImageView()
            .padding(.top, max(topInset, 16))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
    }

    private func processOnboardingHeaderBar(topInset: CGFloat) -> some View {
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
                .glassStyle()
                .buttonBorderShape(.circle)
            } else {
                Spacer()
                    .frame(width: 34, height: 34)
            }

            OnboardingSegmentedProgressBar(
                filledSegments: viewModel.filledProgressSegments(for: step),
                totalSegments: MerchantOnboardingProgress.totalSegments,
                style: .lightBackground
            )
            .frame(maxWidth: .infinity)
            .frame(height: 8)

            if isAdminProvisioningFlow {
                adminHeaderCancelButton
            } else {
                LanguageSelectorView()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, max(topInset, 44) + 8)
    }

    private var onboardingBottomChrome: some View {
        Group {
            if step == .welcome {
                welcomeBottomChrome
            } else {
                processBottomChrome
            }
        }
    }

    /// Welcome : boutons flottants sur l’image (comme `AuthLaunchEntryView` phone — pas de fond opaque).
    private var welcomeBottomChrome: some View {
        VStack(spacing: 24) {
            welcomePrimaryCTAButton
                .frame(maxWidth: .infinity)

            if !isAdminProvisioningFlow {
                signInFromWelcomeButton
                    .disabled(isStepTransitionInFlight)
            }
        }
        .padding(.horizontal, MyfidpassOnboardingConstants.primaryCTAHorizontalPaddingCompact)
        .padding(.top, 12)
        .padding(.bottom, continueButtonsBottomInset)
    }

    /// Étapes process : barre CTA sur fond uni (clavier, formulaires).
    private var processBottomChrome: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                processContinueButton
                    .frame(maxWidth: horizontalSizeClass == .regular ? 520 : .infinity)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 40)
        .padding(.bottom, continueButtonsBottomInset)
        .animation(.easeOut(duration: 0.2), value: keyboardHeight)
    }

    /// Même rendu / interaction que `processContinueButton` (`.buttonStyle(.glass)` + hauteur identique).
    private var welcomePrimaryCTAButton: some View {
        Button(action: handleContinueTap) {
            Text("COMMENCER")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: MyfidpassOnboardingConstants.primaryCTAHeight)
        }
        .buttonBorderShape(.roundedRectangle(radius: 50))
        .liquidGlassButtonAppearance(.adaptive, cornerRadius: 50)
        .contentShape(RoundedRectangle(cornerRadius: 50, style: .continuous))
    }

    @ViewBuilder
    private var processContinueButton: some View {
        let isEnabled = canContinueNow && !isStepTransitionInFlight
        Button(action: handleContinueTap) {
            Group {
                if viewModel.isCheckingEmail || viewModel.isSendingOtpCode, step == .emailCapture {
                    ProgressView()
                        .tint(.black)
                } else if viewModel.isSavingCardSetup, step == .cardProgram || step == .cardPreview {
                    ProgressView()
                        .tint(.black)
                } else {
                    Text(step == .cardPreview ? "TERMINER" : "CONTINUER")
                        .font(.system(size: 20, weight: .black))
                        .id("continue-label-\(step.rawValue)")
                }
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: MyfidpassOnboardingConstants.primaryCTAHeight)
        }
        .buttonBorderShape(.roundedRectangle(radius: 50))
        .liquidGlassButtonAppearance(.adaptive, cornerRadius: 50)
        .contentShape(RoundedRectangle(cornerRadius: 50, style: .continuous))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
    }

    private var processAnimatedGlow: some View {
        let visitedCount = max(1, viewModel.visitedSteps.count)
        let estimatedTotal = max(MerchantOBStep.allCases.count, visitedCount)
        return AnimatedOnboardingGlow(
            currentStep: viewModel.currentStep,
            visitedStepsCount: visitedCount,
            totalStepsForFlow: estimatedTotal
        )
        .ignoresSafeArea(.all)
        .allowsHitTesting(false)
    }

    private var continueButtonBottomOffset: CGFloat { MyfidpassOnboardingConstants.primaryCTABottomInset }
    private var continueButtonsBottomInset: CGFloat {
        if keyboardHeight > 0 {
            return max(10, keyboardHeight + 6)
        }
        return continueButtonBottomOffset
    }

    private func handleContinueTap() {
        guard canContinueNow else { return }
        if step != .welcome, isStepTransitionInFlight { return }
        hapticManager.impact(.medium)
        switch step {
        case .welcome:
            keyboardHeight = 0
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            advanceFromWelcomeStep()
        case .establishmentSearch:
            viewModel.persistSelectionsToUserDefaults()
            advanceToNextStep()
        case .emailCapture:
            Task { await handleEmailContinue() }
        case .otpVerification:
            Task { await handleOtpCelebrationAndAdvance() }
        case .cardProgram:
            Task { await handleCardProgramContinue() }
        case .cardLogo, .cardMedia, .cardColors:
            Task { await handleCardCustomizationContinue() }
        case .cardPreview:
            Task { await handleCardPreviewFinish() }
        case .subscriptionPaywall:
            break
        }
    }

    /// Welcome → établissement : pas de verrou 580 ms (évite un CTA bloqué si la vue est recréée).
    private func advanceFromWelcomeStep() {
        guard step == .welcome else { return }
        previousStep = viewModel.currentStep
        let next = MerchantOBStep.establishmentSearch.rawValue
        viewModel.appendVisited(next)
        withAnimation(.onboardingTransition) {
            viewModel.currentStep = next
        }
    }

    private func advanceToNextStep() {
        guard !isStepTransitionInFlight else { return }
        isStepTransitionInFlight = true
        previousStep = viewModel.currentStep
        let next = nextOnboardingStep(after: viewModel.currentStep)
        viewModel.appendVisited(next)
        withAnimation(.onboardingTransition) {
            viewModel.currentStep = next
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(580))
            isStepTransitionInFlight = false
        }
    }

    private func handleEmailContinue() async {
        guard viewModel.isSignupEmailValid else { return }
        viewModel.emailError = nil
        viewModel.isCheckingEmail = true
        defer { viewModel.isCheckingEmail = false }

        do {
            let exists = try await authService.checkAccountExists(identifier: viewModel.normalizedSignupEmail)
            if exists {
                hapticManager.notification(.warning)
                viewModel.showExistingAccountSheet = true
            } else {
                FirstLaunchOnboarding.persistSignupEmail(viewModel.normalizedSignupEmail)
                viewModel.isSendingOtpCode = true
                defer { viewModel.isSendingOtpCode = false }
                do {
                    try await authService.sendEmailOtp(email: viewModel.normalizedSignupEmail)
                    viewModel.otpCode = ""
                    viewModel.otpError = nil
                    hapticManager.notification(.success)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    advanceToNextStep()
                } catch AuthError.apiMessage(let msg) {
                    viewModel.emailError = msg
                } catch {
                    viewModel.emailError = "Impossible d'envoyer le code. Réessayez."
                }
            }
        } catch AuthError.apiMessage(let msg) {
            viewModel.emailError = msg
        } catch {
            viewModel.emailError = "Impossible de vérifier l'e-mail. Réessayez."
        }
    }

    private func handleOtpCelebrationAndAdvance() async {
        guard viewModel.otpCode.filter(\.isNumber).count == 6 else { return }
        guard !viewModel.otpAdvanceInFlight, !viewModel.otpShowSuccess else { return }

        viewModel.otpError = nil
        viewModel.otpAdvanceInFlight = true
        viewModel.isVerifyingOtp = true
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        do {
            let response = try await authService.performEmailOtpVerification(
                email: viewModel.normalizedSignupEmail,
                code: viewModel.otpCode.filter(\.isNumber),
                isSignup: true,
                name: nil
            )
            viewModel.isVerifyingOtp = false

            withAnimation(.spring(response: 0.46, dampingFraction: 0.74)) {
                viewModel.otpShowSuccess = true
            }
            hapticManager.notification(.success)

            try await Task.sleep(for: .milliseconds(780))

            viewModel.otpShowSuccess = false

            if isAdminProvisioningFlow {
                let merchantEmail = response.user.email?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                await authService.completeAdminMerchantProvisioning(merchantEmail: merchantEmail)
                viewModel.otpAdvanceInFlight = false
                onAdminProvisioningFinished?(merchantEmail)
                return
            }

            authService.finalizeEmailOtpSignIn(response: response, isSignup: true)
            if MerchantOnboardingFeatureFlags.skipsCardSetupSteps {
                completeSignupAndEnterApp()
            } else {
                authService.beginSignupCardSetupPhase()
                viewModel.seedCardDraftFromEstablishment()
                advanceToNextStep()
            }
            viewModel.otpAdvanceInFlight = false
        } catch AuthError.invalidCredentials {
            viewModel.isVerifyingOtp = false
            viewModel.otpAdvanceInFlight = false
            viewModel.otpShowSuccess = false
            viewModel.otpError = "Code incorrect ou expiré."
            viewModel.otpCode = ""
        } catch AuthError.missingEstablishment(let msg) {
            viewModel.isVerifyingOtp = false
            viewModel.otpAdvanceInFlight = false
            viewModel.otpError = msg
        } catch AuthError.apiMessage(let msg) {
            viewModel.isVerifyingOtp = false
            viewModel.otpAdvanceInFlight = false
            viewModel.otpError = msg
            if msg.localizedCaseInsensitiveContains("aucun code")
                || msg.localizedCaseInsensitiveContains("expiré")
                || msg.localizedCaseInsensitiveContains("trop de tentatives") {
                viewModel.otpCode = ""
            }
        } catch {
            viewModel.isVerifyingOtp = false
            viewModel.otpAdvanceInFlight = false
            viewModel.otpError = error.localizedDescription
        }
    }

    private func handleCardProgramContinue() async {
        guard !viewModel.isSavingCardSetup else { return }
        viewModel.cardSetupError = nil
        viewModel.cardDraft.applyDefaultRewardsForCurrentMode()
        viewModel.isSavingCardSetup = true
        defer { viewModel.isSavingCardSetup = false }

        await MerchantOBCardSettingsSaver.saveBestEffort(
            from: viewModel.cardDraft,
            authService: authService
        )
        hapticManager.notification(.success)
        advanceToNextStep()
    }

    private func handleCardCustomizationContinue() async {
        viewModel.cardSetupError = nil
        await MerchantOBCardSettingsSaver.saveBestEffort(
            from: viewModel.cardDraft,
            authService: authService
        )
        advanceToNextStep()
    }

    private func completeSignupAndEnterApp() {
        authService.finishSignupCardSetupPhase()
        viewModel.persistSelectionsToUserDefaults()
        FirstLaunchOnboarding.hasCompleted = true
        FirstLaunchOnboarding.markMerchantPremisesOnboardingFinished()
        hapticManager.notification(.success)

        if authService.bypassesMerchantSubscriptionGate || authService.hasEncashedMerchantSubscription {
            authService.finishSignupPaywallPhase(honorPaidThankYou: false)
            return
        }

        authService.beginSignupPaywallPhaseIfNeeded()
        advanceToPaywallStep()
    }

    /// Dernière étape onboarding : paywall dans le même `OnboardingTransitionContainer` (slide Process).
    private func advanceToPaywallStep() {
        guard !isStepTransitionInFlight else { return }
        isStepTransitionInFlight = true
        previousStep = viewModel.currentStep
        let next = MerchantOBStep.subscriptionPaywall.rawValue
        viewModel.appendVisited(next)
        withAnimation(.onboardingTransition) {
            viewModel.currentStep = next
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(580))
            isStepTransitionInFlight = false
        }
    }

    private func handleCardPreviewFinish() async {
        guard !viewModel.isSavingCardSetup else { return }
        viewModel.isSavingCardSetup = true
        defer { viewModel.isSavingCardSetup = false }

        viewModel.cardDraft.applyDefaultRewardsForCurrentMode()
        await MerchantOBCardSettingsSaver.saveBestEffort(
            from: viewModel.cardDraft,
            authService: authService
        )
        viewModel.cardSetupError = nil
        completeSignupAndEnterApp()
    }

    private func importCardLogo(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let path = CardLogoStorage.saveImage(image, slug: onboardingCardStorageSlug()) else { return }
        await MainActor.run {
            viewModel.cardDraft.logoLocalPath = path
            viewModel.cardLogoPhotoItem = nil
        }
    }

    private func importCardBackground(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let path = CardLogoStorage.saveCardBackground(image, slug: onboardingCardStorageSlug()) else { return }
        await MainActor.run {
            viewModel.cardDraft.cardBackgroundLocalPath = path
            viewModel.cardBackgroundPhotoItem = nil
        }
    }

    private func onboardingCardStorageSlug() -> String {
        let raw = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "_onboarding" : raw
    }

    /// Étape suivante en incrémentant, en sautant le bloc carte si désactivé temporairement.
    private func nextOnboardingStep(after current: Int) -> Int {
        let next = current + 1
        guard MerchantOnboardingFeatureFlags.skipsCardSetupSteps else { return next }
        let cardFirst = MerchantOBStep.cardProgram.rawValue
        let paywall = MerchantOBStep.subscriptionPaywall.rawValue
        if next >= cardFirst, next < paywall {
            return paywall
        }
        return next
    }

    private func goBack() {
        guard viewModel.currentStep > 0, !isStepTransitionInFlight else { return }
        isStepTransitionInFlight = true
        if step == .otpVerification {
            viewModel.otpCode = ""
            viewModel.otpError = nil
            viewModel.otpShowSuccess = false
            viewModel.otpAdvanceInFlight = false
            viewModel.isVerifyingOtp = false
        } else if step == .cardProgram || step == .cardLogo || step == .cardMedia || step == .cardColors {
            viewModel.cardSetupError = nil
        } else if step == .cardPreview {
            viewModel.cardSetupError = nil
        } else if step == .subscriptionPaywall {
            authService.finishSignupPaywallPhase(honorPaidThankYou: false)
        } else {
            viewModel.emailError = nil
        }
        viewModel.visitedSteps.removeAll { $0 == viewModel.currentStep }
        previousStep = viewModel.currentStep
        let target: Int
        if step == .subscriptionPaywall, MerchantOnboardingFeatureFlags.skipsCardSetupSteps {
            target = MerchantOBStep.otpVerification.rawValue
        } else {
            target = viewModel.currentStep - 1
        }
        withAnimation(.onboardingTransition) {
            viewModel.currentStep = target
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(580))
            isStepTransitionInFlight = false
        }
    }


    // MARK: Contenu

    @ViewBuilder
    private func stepContent(for step: MerchantOBStep) -> some View {
        switch step {
        case .welcome:
            Color.clear
        case .establishmentSearch:
            MerchantOBEstablishmentSearchContent(
                selectedPlaceId: $viewModel.selectedPlaceId,
                selectedDescription: $viewModel.selectedPlaceDescription,
                relaxRequirement: $viewModel.relaxEstablishmentRequirement,
                isPredictionsVisible: $isEstablishmentPredictionsVisible
            )
        case .emailCapture:
            MerchantOBEmailCaptureContent(
                email: $viewModel.signupEmail,
                isChecking: viewModel.isCheckingEmail || viewModel.isSendingOtpCode,
                errorMessage: viewModel.emailError
            )
        case .otpVerification:
            AuthEmailOtpVerificationView(
                code: $viewModel.otpCode,
                email: viewModel.normalizedSignupEmail,
                commerceTitle: merchantCommerceTitleForOtp,
                isVerifying: viewModel.isVerifyingOtp,
                isSendingCode: viewModel.isSendingOtpCode,
                showSuccessCelebration: viewModel.otpShowSuccess,
                interactionLocked: viewModel.otpAdvanceInFlight,
                errorMessage: viewModel.otpError,
                onResend: {
                    Task {
                        viewModel.isSendingOtpCode = true
                        defer { viewModel.isSendingOtpCode = false }
                        do {
                            try await authService.sendEmailOtp(email: viewModel.normalizedSignupEmail)
                            hapticManager.notification(.success)
                        } catch AuthError.apiMessage(let msg) {
                            viewModel.otpError = msg
                        } catch {
                            viewModel.otpError = "Impossible d'envoyer le code."
                        }
                    }
                },
                onCodeComplete: { Task { await handleOtpCelebrationAndAdvance() } }
            )
        case .cardProgram:
            if MerchantOnboardingFeatureFlags.skipsCardSetupSteps {
                Color.clear
            } else {
                MerchantOBCardProgramStepContent(draft: $viewModel.cardDraft)
            }
        case .cardLogo:
            if MerchantOnboardingFeatureFlags.skipsCardSetupSteps {
                Color.clear
            } else {
                MerchantOBCardLogoStepContent(
                    draft: $viewModel.cardDraft,
                    logoPhotoItem: $viewModel.cardLogoPhotoItem
                )
            }
        case .cardMedia:
            if MerchantOnboardingFeatureFlags.skipsCardSetupSteps {
                Color.clear
            } else {
                MerchantOBCardMediaStepContent(
                    draft: $viewModel.cardDraft,
                    backgroundPhotoItem: $viewModel.cardBackgroundPhotoItem
                )
            }
        case .cardColors:
            if MerchantOnboardingFeatureFlags.skipsCardSetupSteps {
                Color.clear
            } else {
                MerchantOBCardColorsStepContent(draft: $viewModel.cardDraft)
            }
        case .cardPreview:
            if MerchantOnboardingFeatureFlags.skipsCardSetupSteps {
                Color.clear
            } else {
                MerchantOBCardPreviewStepContent(
                    draft: viewModel.cardDraft,
                    infoMessage: viewModel.cardSetupError
                )
            }
        case .subscriptionPaywall:
            MerchantSubscriptionGateView(
                isMandatory: true,
                requiredCommerceSlots: 1,
                signupCommerceDisplayName: signupCommerceDisplayName
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var signupCommerceDisplayName: String? {
        let trimmed = authService.businesses.first?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        return merchantCommerceTitleForOtp
    }

    private var signInFromWelcomeButton: some View {
        Button {
            hapticManager.impact(.light)
            onSignIn?()
        } label: {
            Text("Se connecter")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black.opacity(0.78))
                .underline(true, color: .black.opacity(0.35))
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var merchantCommerceTitleForOtp: String? {
        if viewModel.relaxEstablishmentRequirement { return nil }
        let desc = viewModel.selectedPlaceDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !desc.isEmpty else { return nil }
        let parts = desc.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        let title = parts.first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? desc
        return title.isEmpty ? nil : title
    }
}

// MARK: - E-mail (même structure / espacements que recherche établissement)

private struct MerchantOBEmailCaptureContent: View {
    @Binding var email: String
    var isChecking: Bool
    var errorMessage: String?

    var body: some View {
        ProcessEmailCaptureLayout {
            MerchantOnboardingEmailStepContent(
                email: $email,
                isChecking: isChecking,
                errorMessage: errorMessage
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
