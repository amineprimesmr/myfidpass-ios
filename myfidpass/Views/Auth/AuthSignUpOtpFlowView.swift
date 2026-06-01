//
//  AuthSignUpOtpFlowView.swift
//  myfidpass
//
//  Inscription finale : code OTP e-mail (commerce + e-mail déjà saisis à l’onboarding).
//

import Combine
import SwiftUI
import UIKit

@MainActor
private final class AuthSignUpOtpViewModel: ObservableObject {
    @Published var code = ""
    @Published var isVerifying = false
    @Published var isSendingCode = false
    @Published var errorMessage: String?
    @Published var didSendInitialCode = false
    @Published var otpShowSuccess = false
    @Published var otpSubmitInFlight = false

    func markInitialCodeSent() {
        didSendInitialCode = true
    }
}

struct AuthSignUpOtpFlowView: View {
    var onBack: () -> Void

    @EnvironmentObject private var authService: AuthService
    @StateObject private var viewModel = AuthSignUpOtpViewModel()
    @StateObject private var hapticManager = HapticManager.shared

    private var signupEmail: String? {
        FirstLaunchOnboarding.readSignupEmail()
    }

    private var commerceTitle: String? {
        SignUpPendingCommerceDisplay.primaryTitle()
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

            AnimatedOnboardingGlow(currentStep: 0, visitedStepsCount: 3, totalStepsForFlow: 3)
                .opacity(0.22)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

            if let email = signupEmail {
                AuthEmailOtpVerificationView(
                    code: $viewModel.code,
                    email: email,
                    commerceTitle: commerceTitle,
                    isVerifying: viewModel.isVerifying,
                    isSendingCode: viewModel.isSendingCode,
                    showSuccessCelebration: viewModel.otpShowSuccess,
                    interactionLocked: viewModel.otpSubmitInFlight,
                    errorMessage: viewModel.errorMessage,
                    onResend: { Task { await resendCode() } },
                    onCodeComplete: submitVerification
                )
                .padding(.top, 60)
            } else {
                VStack {
                    Spacer()
                    Text("E-mail manquant. Revenez à l'étape précédente.")
                        .font(AppTheme.Fonts.caption2())
                        .foregroundStyle(AppTheme.Colors.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
                .padding(.top, 60)
            }

            VStack {
                HStack(spacing: 12) {
                    Button(action: {
                        hapticManager.impact(.light)
                        onBack()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.primary.opacity(0.88))
                            .frame(width: 34, height: 34)
                    }
                    .glassStyle()
                    .buttonBorderShape(.circle)

                    OnboardingSegmentedProgressBar(
                        filledSegments: 3,
                        totalSegments: 3,
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
        .task {
            await sendInitialCodeIfNeeded()
        }
        .onChange(of: viewModel.code) { _, _ in
            viewModel.errorMessage = nil
        }
    }

    private var topSafeInset: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.top ?? 0
    }

    private func sendInitialCodeIfNeeded() async {
        guard !viewModel.didSendInitialCode else { return }
        guard let email = signupEmail?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else { return }
        viewModel.isSendingCode = true
        defer { viewModel.isSendingCode = false }
        do {
            try await authService.sendEmailOtp(email: email)
            viewModel.markInitialCodeSent()
        } catch AuthError.apiMessage(let msg) {
            viewModel.errorMessage = msg
        } catch {
            viewModel.errorMessage = "Impossible d'envoyer le code. Réessayez."
        }
    }

    private func resendCode() async {
        guard let email = signupEmail?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else { return }
        viewModel.errorMessage = nil
        viewModel.isSendingCode = true
        defer { viewModel.isSendingCode = false }
        do {
            try await authService.sendEmailOtp(email: email)
            hapticManager.notification(.success)
        } catch AuthError.apiMessage(let msg) {
            viewModel.errorMessage = msg
        } catch {
            viewModel.errorMessage = "Impossible d'envoyer le code. Réessayez."
        }
    }

    private func submitVerification() {
        guard viewModel.code.filter(\.isNumber).count == 6,
              !viewModel.isVerifying,
              let email = signupEmail else { return }
        hapticManager.impact(.medium)
        Task {
            viewModel.errorMessage = nil
            viewModel.isVerifying = true
            viewModel.otpSubmitInFlight = true
            defer {
                viewModel.isVerifying = false
                viewModel.otpSubmitInFlight = false
            }
            do {
                let response = try await authService.performEmailOtpVerification(
                    email: email,
                    code: viewModel.code.filter(\.isNumber)
                )
                withAnimation(.spring(response: 0.46, dampingFraction: 0.74)) {
                    viewModel.otpShowSuccess = true
                }
                hapticManager.notification(.success)
                try await Task.sleep(for: .milliseconds(820))
                authService.finalizeEmailOtpSignIn(response: response, isSignup: true)
            } catch AuthError.invalidCredentials {
                viewModel.otpShowSuccess = false
                viewModel.errorMessage = "Code incorrect ou expiré."
                viewModel.code = ""
            } catch AuthError.missingEstablishment(let msg) {
                viewModel.otpShowSuccess = false
                viewModel.errorMessage = msg
            } catch AuthError.apiMessage(let msg) {
                viewModel.otpShowSuccess = false
                viewModel.errorMessage = msg
            } catch {
                viewModel.otpShowSuccess = false
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Célébration succès OTP

private enum AuthOtpPalette {
    static let green = Color(red: 0.10, green: 0.78, blue: 0.44)
}

private struct AuthOtpCheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.midY + rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.40, y: rect.maxY - rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.minY + rect.height * 0.16))
        return path
    }
}

struct AuthOtpSuccessCelebrationView: View {
    @State private var circleScale: CGFloat = 0.5
    @State private var circleOpacity: Double = 0
    @State private var checkProgress: CGFloat = 0
    @State private var haloScale: CGFloat = 0.72
    @State private var haloOpacity: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(AuthOtpPalette.green.opacity(0.28), lineWidth: 2.5)
                .frame(width: 92, height: 92)
                .scaleEffect(haloScale)
                .opacity(haloOpacity)

            Circle()
                .fill(AuthOtpPalette.green.opacity(0.16))
                .frame(width: 84, height: 84)
                .scaleEffect(circleScale)

            Circle()
                .fill(AuthOtpPalette.green)
                .frame(width: 64, height: 64)
                .scaleEffect(circleScale)
                .opacity(circleOpacity)
                .shadow(color: AuthOtpPalette.green.opacity(0.42), radius: 18, y: 8)

            AuthOtpCheckmarkShape()
                .trim(from: 0, to: checkProgress)
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 28, height: 22)
                .opacity(circleOpacity)
        }
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        withAnimation(.spring(response: 0.44, dampingFraction: 0.70)) {
            circleScale = 1
            circleOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.34).delay(0.10)) {
            checkProgress = 1
        }
        withAnimation(.spring(response: 0.62, dampingFraction: 0.58).delay(0.06)) {
            haloScale = 1.14
            haloOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.38).delay(0.42)) {
            haloScale = 1
            haloOpacity = 0.55
        }
    }
}

// MARK: - OTP verification UI (shared signup + sign-in)

struct AuthEmailOtpVerificationView: View {
    @Binding var code: String
    let email: String
    var commerceTitle: String? = nil
    let isVerifying: Bool
    let isSendingCode: Bool
    var showSuccessCelebration: Bool = false
    var interactionLocked: Bool = false
    let errorMessage: String?
    let onResend: () -> Void
    var onCodeComplete: (() -> Void)? = nil

    @State private var resendCountdown = 60
    @State private var resendTimer: Timer?
    @State private var cursorVisible = true
    @State private var cursorTimerTask: Task<Void, Never>?
    @State private var verifyPulse = false
    @FocusState private var otpFieldFocused: Bool

    private let boxCount = 6

    private var contentDimmed: Bool {
        isVerifying || showSuccessCelebration
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 28) {
                    headerBlock
                    otpBoxesRow
                    if !showSuccessCelebration {
                        resendBlock
                    }
                    if let errorMessage, !errorMessage.isEmpty, !showSuccessCelebration {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 0.85, green: 0.22, blue: 0.22))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .opacity(contentDimmed ? 0.35 : 1)
                .scaleEffect(showSuccessCelebration ? 0.94 : (isVerifying ? 0.98 : 1))
                .blur(radius: showSuccessCelebration ? 3 : 0)
                .animation(.spring(response: 0.48, dampingFraction: 0.82), value: showSuccessCelebration)
                .animation(.easeInOut(duration: 0.22), value: isVerifying)

                Spacer(minLength: 0)
            }

            if showSuccessCelebration {
                AuthOtpSuccessCelebrationView()
                    .transition(.scale(scale: 0.82).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: showSuccessCelebration)
        .onAppear {
            startResendCountdown()
            startCursorBlink()
            focusOtpField()
        }
        .onDisappear {
            resendTimer?.invalidate()
            cursorTimerTask?.cancel()
        }
        .onChange(of: isVerifying) { _, verifying in
            if verifying {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    verifyPulse = true
                }
            } else {
                verifyPulse = false
                if !showSuccessCelebration {
                    focusOtpField()
                }
            }
        }
        .onChange(of: showSuccessCelebration) { _, success in
            if success {
                otpFieldFocused = false
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .onChange(of: interactionLocked) { _, locked in
            if !locked, !showSuccessCelebration, !isVerifying {
                focusOtpField()
            }
        }
        .onChange(of: errorMessage) { _, message in
            guard let message, !message.isEmpty, !showSuccessCelebration else { return }
            focusOtpField(after: 0.12)
        }
        .onChange(of: code) { _, newValue in
            guard !showSuccessCelebration else { return }
            let filtered = String(newValue.filter(\.isNumber).prefix(boxCount))
            if filtered != newValue {
                code = filtered
                return
            }
            guard filtered.count == boxCount, !interactionLocked, !isVerifying else { return }
            onCodeComplete?()
        }
    }

    private var headerBlock: some View {
        VStack(spacing: 10) {
            Text(showSuccessCelebration ? "Code validé" : "Entrez le code")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(red: 0.08, green: 0.08, blue: 0.1))
                .animation(.easeInOut(duration: 0.25), value: showSuccessCelebration)

            if !showSuccessCelebration {
                Text(subtitleText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    private var subtitleText: String {
        if let commerceTitle, !commerceTitle.isEmpty {
            return "Nous avons envoyé un code à 6 chiffres à \(email) pour \(commerceTitle)."
        }
        return "Nous avons envoyé un code à 6 chiffres à \(email)."
    }

    private var otpBoxesRow: some View {
        ZStack {
            HStack(spacing: 10) {
                ForEach(0..<boxCount, id: \.self) { index in
                    otpDigitBox(index: index)
                }
            }
            .padding(.horizontal, 24)
            .allowsHitTesting(false)

            if !showSuccessCelebration {
                TextField("", text: $code)
                    .textContentType(.oneTimeCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numberPad)
                    .focused($otpFieldFocused)
                    .disabled(isVerifying || interactionLocked)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .opacity(0.015)
                    .accessibilityLabel("Code de vérification à six chiffres")
                    .accessibilityHint("Saisissez le code reçu par e-mail ou choisissez la suggestion au-dessus du clavier.")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !showSuccessCelebration, !isVerifying else { return }
            focusOtpField()
        }
    }

    private func otpDigitBox(index: Int) -> some View {
        let digits = Array(code)
        let char: Character? = index < digits.count ? digits[index] : nil
        let isActive = index == digits.count && digits.count < boxCount && !contentDimmed

        return ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(boxFill(for: index, hasChar: char != nil))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            boxBorder(for: index, isActive: isActive),
                            lineWidth: isActive ? 2 : 1
                        )
                )
                .frame(width: 48, height: 56)
                .scaleEffect(isVerifying && verifyPulse && char != nil ? 1.04 : 1)

            if let char {
                Text(String(char))
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(red: 0.08, green: 0.08, blue: 0.1))
            } else if isActive && cursorVisible {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.1))
                    .frame(width: 2, height: 24)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: char != nil)
    }

    private func boxFill(for index: Int, hasChar: Bool) -> Color {
        if showSuccessCelebration && hasChar {
            return AuthOtpPalette.green.opacity(0.14)
        }
        if isVerifying && hasChar {
            return Color(red: 0.94, green: 0.97, blue: 0.95)
        }
        return Color(red: 0.96, green: 0.96, blue: 0.97)
    }

    private func boxBorder(for index: Int, isActive: Bool) -> Color {
        if showSuccessCelebration {
            return AuthOtpPalette.green.opacity(0.55)
        }
        if isActive {
            return Color(red: 0.08, green: 0.08, blue: 0.1)
        }
        return Color(red: 0.88, green: 0.88, blue: 0.9)
    }

    private var resendBlock: some View {
        Group {
            if isVerifying {
                Text("Vérification…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.5))
            } else if resendCountdown > 0 {
                Text("Renvoyer le code dans \(resendCountdown)s")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.55, green: 0.55, blue: 0.58))
            } else {
                Button {
                    guard !isSendingCode else { return }
                    onResend()
                    startResendCountdown()
                    focusOtpField(after: 0.1)
                } label: {
                    if isSendingCode {
                        ProgressView()
                            .tint(Color(red: 0.08, green: 0.08, blue: 0.1))
                    } else {
                        Text("Renvoyer le code")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(red: 0.08, green: 0.08, blue: 0.1))
                    }
                }
                .disabled(isSendingCode)
            }
        }
    }

    private func focusOtpField(after delay: TimeInterval = 0.05) {
        guard !showSuccessCelebration else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            otpFieldFocused = true
        }
    }

    private func startResendCountdown() {
        resendTimer?.invalidate()
        resendCountdown = 60
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                resendTimer?.invalidate()
            }
        }
    }

    private func startCursorBlink() {
        cursorTimerTask?.cancel()
        cursorTimerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(530))
                await MainActor.run {
                    cursorVisible.toggle()
                }
            }
        }
    }
}

private enum SignUpPendingCommerceDisplay {
    static func primaryTitle() -> String? {
        let p = FirstLaunchOnboarding.readPendingEstablishment()
        if p.relax { return nil }
        let desc = p.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !desc.isEmpty else { return nil }
        let parts = desc.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        let title = parts.first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? desc
        return title.isEmpty ? nil : title
    }
}

#Preview {
    AuthSignUpOtpFlowView(onBack: {})
        .environmentObject(AuthService())
}
