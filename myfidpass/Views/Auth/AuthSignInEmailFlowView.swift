//
//  AuthSignInEmailFlowView.swift
//  myfidpass
//
//  Connexion : e-mail → code OTP à 6 chiffres.
//

import Combine
import SwiftUI
import UIKit

enum AuthSignInIdentifierValidation {
    static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isValid(_ raw: String) -> Bool {
        let norm = normalized(raw)
        guard !norm.isEmpty else { return false }
        return MerchantOnboardingEmailValidation.isValid(norm)
    }
}

private enum AuthSignInStep: Int, CaseIterable {
    case identifier = 0
    case otp = 1
}

private enum AuthSignInProgress {
    static let totalSegments = 2
}

@MainActor
private final class AuthSignInFlowViewModel: ObservableObject {
    @Published var currentStep: Int = 0
    @Published var identifier = ""
    @Published var otpCode = ""
    @Published var isCheckingIdentifier = false
    @Published var isSendingCode = false
    @Published var isVerifying = false
    @Published var identifierError: String?
    @Published var otpError: String?
    @Published var otpShowSuccess = false
    @Published var otpSubmitInFlight = false

    var normalizedIdentifier: String {
        AuthSignInIdentifierValidation.normalized(identifier)
    }

    var isIdentifierValid: Bool {
        AuthSignInIdentifierValidation.isValid(identifier)
    }

    func filledProgressSegments(for step: AuthSignInStep) -> Int {
        switch step {
        case .identifier: return 1
        case .otp: return 2
        }
    }

    func canContinue(for step: AuthSignInStep) -> Bool {
        switch step {
        case .identifier:
            return isIdentifierValid && !isCheckingIdentifier && !isSendingCode
        case .otp:
            return otpCode.filter(\.isNumber).count == 6 && !isVerifying
        }
    }
}

struct AuthSignInEmailFlowView: View {
    /// E-mail prérempli (ex. sheet « compte existant »).
    var initialIdentifier: String? = nil
    /// Compte déjà vérifié côté inscription — pas de second appel check-email.
    var accountAlreadyVerified: Bool = false

    var onBack: () -> Void

    @EnvironmentObject private var authService: AuthService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = AuthSignInFlowViewModel()
    @StateObject private var hapticManager = HapticManager.shared
    @State private var keyboardHeight: CGFloat = 0
    @State private var previousStep: Int?
    @State private var skipExistenceCheck = false

    private var step: AuthSignInStep {
        AuthSignInStep(rawValue: viewModel.currentStep) ?? .identifier
    }

    private var canContinueNow: Bool {
        viewModel.canContinue(for: step)
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

            AnimatedOnboardingGlow(
                currentStep: viewModel.currentStep,
                visitedStepsCount: viewModel.currentStep + 1,
                totalStepsForFlow: AuthSignInStep.allCases.count
            )
            .opacity(0.22)
            .ignoresSafeArea(.all)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                OnboardingTransitionContainer(
                    currentStep: viewModel.currentStep,
                    previousStep: previousStep,
                    isTransitioning: false
                ) {
                    stepContent(for: step)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)
                .animation(.onboardingTransition, value: viewModel.currentStep)
            }
            .zIndex(0)

            if step == .identifier {
                VStack {
                    Spacer()

                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        continueButton
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

            VStack {
                HStack(spacing: 12) {
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

                    OnboardingSegmentedProgressBar(
                        filledSegments: viewModel.filledProgressSegments(for: step),
                        totalSegments: AuthSignInProgress.totalSegments,
                        style: .lightBackground
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
        .ignoresSafeArea(.all)
        .preferredColorScheme(.light)
        .onAppear {
            if let initial = initialIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines), !initial.isEmpty {
                viewModel.identifier = initial
            } else if let saved = FirstLaunchOnboarding.readLastKnownAuthEmail() {
                viewModel.identifier = saved
            }
            skipExistenceCheck = accountAlreadyVerified
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard
                let userInfo = note.userInfo,
                let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            else { return }
            let screenH = UIScreen.main.bounds.height
            keyboardHeight = max(0, screenH - endFrame.origin.y)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .onChange(of: viewModel.identifier) { _, _ in
            viewModel.identifierError = nil
            skipExistenceCheck = false
        }
        .onChange(of: viewModel.otpCode) { _, _ in
            viewModel.otpError = nil
        }
    }

    @ViewBuilder
    private var continueButton: some View {
        Button(action: handleContinueTap) {
            Group {
                if (viewModel.isCheckingIdentifier && step == .identifier)
                    || (viewModel.isSendingCode && step == .identifier)
                    || (viewModel.isVerifying && step == .otp) {
                    ProgressView()
                        .tint(.black)
                } else {
                    Text(step == .otp ? "SE CONNECTER" : "CONTINUER")
                        .font(.system(size: 20, weight: .black))
                }
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonBorderShape(.roundedRectangle(radius: 50))
        .liquidGlassButtonAppearance(.adaptive, cornerRadius: 50)
    }

    private var topSafeInset: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.top ?? 0
    }

    private var continueButtonsBottomInset: CGFloat {
        keyboardHeight > 0 ? max(10, keyboardHeight + 6) : MyfidpassOnboardingConstants.primaryCTABottomInset
    }

    private func handleContinueTap() {
        guard canContinueNow else { return }
        hapticManager.impact(.medium)
        switch step {
        case .identifier:
            Task { await handleIdentifierContinue() }
        case .otp:
            Task { await handleOtpSubmit() }
        }
    }

    private func handleIdentifierContinue() async {
        guard viewModel.isIdentifierValid else { return }
        viewModel.identifierError = nil
        FirstLaunchOnboarding.persistSignupEmail(viewModel.normalizedIdentifier)

        if !skipExistenceCheck {
            viewModel.isCheckingIdentifier = true
            defer { viewModel.isCheckingIdentifier = false }
            do {
                let exists = try await authService.checkAccountExists(identifier: viewModel.normalizedIdentifier)
                if !exists {
                    viewModel.identifierError = "Aucun compte avec cet e-mail. Créez un compte pour continuer."
                    return
                }
            } catch AuthError.apiMessage(let msg) {
                viewModel.identifierError = msg
                return
            } catch {
                viewModel.identifierError = "Impossible de vérifier l'e-mail. Réessayez."
                return
            }
        }

        viewModel.isSendingCode = true
        defer { viewModel.isSendingCode = false }
        do {
            try await authService.sendEmailOtp(email: viewModel.normalizedIdentifier)
            advanceToOtpStep()
        } catch AuthError.apiMessage(let msg) {
            viewModel.identifierError = msg
        } catch {
            viewModel.identifierError = "Impossible d'envoyer le code. Réessayez."
        }
    }

    private func advanceToOtpStep() {
        hapticManager.notification(.success)
        viewModel.otpCode = ""
        viewModel.otpError = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        previousStep = viewModel.currentStep
        withAnimation(.onboardingTransition) {
            viewModel.currentStep = AuthSignInStep.otp.rawValue
        }
    }

    private func handleOtpSubmit() async {
        guard viewModel.otpCode.filter(\.isNumber).count == 6 else { return }
        guard !viewModel.isVerifying, !viewModel.otpSubmitInFlight, !viewModel.otpShowSuccess else { return }

        viewModel.otpError = nil
        viewModel.isVerifying = true
        viewModel.otpSubmitInFlight = true

        do {
            let response = try await authService.performEmailOtpVerification(
                email: viewModel.normalizedIdentifier,
                code: viewModel.otpCode.filter(\.isNumber),
                isSignup: false
            )
            viewModel.isVerifying = false
            withAnimation(.spring(response: 0.46, dampingFraction: 0.74)) {
                viewModel.otpShowSuccess = true
            }
            hapticManager.notification(.success)
            try await Task.sleep(for: .milliseconds(820))
            authService.finalizeEmailOtpSignIn(response: response, isSignup: false)
        } catch AuthError.invalidCredentials {
            viewModel.isVerifying = false
            viewModel.otpShowSuccess = false
            viewModel.otpError = "Code incorrect ou expiré."
            viewModel.otpCode = ""
        } catch AuthError.apiMessage(let msg) {
            viewModel.isVerifying = false
            viewModel.otpShowSuccess = false
            viewModel.otpError = msg
        } catch {
            viewModel.isVerifying = false
            viewModel.otpShowSuccess = false
            viewModel.otpError = error.localizedDescription
        }
        viewModel.otpSubmitInFlight = false
    }

    private func goBack() {
        if viewModel.currentStep == 0 {
            onBack()
            return
        }
        viewModel.otpError = nil
        viewModel.otpCode = ""
        viewModel.otpShowSuccess = false
        viewModel.otpSubmitInFlight = false
        viewModel.isVerifying = false
        previousStep = viewModel.currentStep
        withAnimation(.onboardingTransition) {
            viewModel.currentStep -= 1
        }
    }

    @ViewBuilder
    private func stepContent(for step: AuthSignInStep) -> some View {
        switch step {
        case .identifier:
            ProcessEmailCaptureLayout {
                MerchantOnboardingEmailStepContent(
                    email: $viewModel.identifier,
                    fieldPrompt: "Entrez votre e-mail",
                    helperText: "Saisissez l'adresse liée à votre compte MyFidpass.",
                    keyboardType: .emailAddress,
                    textContentType: .username,
                    isChecking: viewModel.isCheckingIdentifier || viewModel.isSendingCode,
                    errorMessage: viewModel.identifierError
                )
            }
        case .otp:
            AuthEmailOtpVerificationView(
                code: $viewModel.otpCode,
                email: viewModel.normalizedIdentifier,
                isVerifying: viewModel.isVerifying,
                isSendingCode: viewModel.isSendingCode,
                showSuccessCelebration: viewModel.otpShowSuccess,
                interactionLocked: viewModel.otpSubmitInFlight,
                errorMessage: viewModel.otpError,
                onResend: {
                    Task {
                        viewModel.isSendingCode = true
                        defer { viewModel.isSendingCode = false }
                        do {
                            try await authService.sendEmailOtp(email: viewModel.normalizedIdentifier)
                            hapticManager.notification(.success)
                        } catch AuthError.apiMessage(let msg) {
                            viewModel.otpError = msg
                        } catch {
                            viewModel.otpError = "Impossible d'envoyer le code."
                        }
                    }
                },
                onCodeComplete: { Task { await handleOtpSubmit() } }
            )
        }
    }
}

#Preview {
    AuthSignInEmailFlowView(onBack: {})
        .environmentObject(AuthService())
}
