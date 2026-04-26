//
//  OnboardingChoiceView.swift
//  myfidpass
//
//  Accueil auth : héros (carrousel images 5–8), dégradé, boutons ancrés en bas, animations fluides.
//

import AuthenticationServices
import Combine
import SwiftUI
import UIKit

// MARK: - Feedback tactile & pression

private enum AuthLandingHaptics {
    static func lightTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

/// Pression douce type iOS (léger ressort).
private struct AuthLandingPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

/// Apparition en cascade des boutons (léger décalage + fondu).
private struct AuthLandingStaggerModifier: ViewModifier {
    let index: Int
    let revealed: Bool

    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 22)
            .animation(
                .spring(response: 0.52, dampingFraction: 0.86)
                    .delay(0.1 + Double(index) * 0.078),
                value: revealed
            )
    }
}

struct OnboardingChoiceView: View {
    @EnvironmentObject private var authService: AuthService

    /// Feuille unique e-mail / mot de passe (connexion ou inscription selon l’API).
    @State private var showEmailAuthSheet = false
    @State private var emailAuthSheetDetent: PresentationDetent = .fraction(0.46)
    /// Lieu + nom d’établissement (depuis « Choisir mon établissement » dans la feuille e-mail ou SMS).
    @State private var showEstablishmentOnboarding = false
    @State private var googleLoading = false
    @State private var appleLoading = false
    @State private var googleAlert: String?
    @State private var appleAlert: String?

    /// Entrée écran : héros puis boutons en cascade.
    @State private var heroAppeared = false
    @State private var actionsAppeared = false
    @State private var heroCarouselIndex = 0

    private static let heroSlideAssetNames = ["5", "6", "7", "8"]

    var body: some View {
        GeometryReader { geo in
            let bottomPad = max(geo.safeAreaInsets.bottom, 12)
            let fullW = geo.size.width
            let fullH = geo.size.height

            ZStack(alignment: .bottom) {
                Color.white.ignoresSafeArea()

                TabView(selection: $heroCarouselIndex) {
                    ForEach(0..<Self.heroSlideAssetNames.count, id: \.self) { i in
                        Image(Self.heroSlideAssetNames[i])
                            .resizable()
                            .scaledToFill()
                            .frame(width: fullW, height: fullH)
                            .clipped()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .tag(i)
                            .accessibilityLabel("Visuel \(i + 1) sur \(Self.heroSlideAssetNames.count)")
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: fullW, height: fullH)
                .ignoresSafeArea(edges: .all)
                .scaleEffect(heroAppeared ? 1 : 1.02)
                .opacity(heroAppeared ? 1 : 0)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.45),
                            Color.white.opacity(0.92),
                            Color.white,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: min(420, fullH * 0.52))
                }
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 16) {
                    HStack(spacing: 6) {
                        ForEach(0..<Self.heroSlideAssetNames.count, id: \.self) { i in
                            Capsule()
                                .fill(i == heroCarouselIndex ? Color.black.opacity(0.85) : Color.black.opacity(0.22))
                                .frame(width: i == heroCarouselIndex ? 22 : 6, height: 6)
                                .animation(.spring(response: 0.35, dampingFraction: 0.78), value: heroCarouselIndex)
                        }
                    }

                    bottomAuthSection(bottomSafePadding: bottomPad)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .background(Color.white)
        .preferredColorScheme(.light)
        .onAppear {
            withAnimation(.spring(response: 0.72, dampingFraction: 0.88)) {
                heroAppeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
                    actionsAppeared = true
                }
            }
        }
        .onReceive(Timer.publish(every: 4.2, on: .main, in: .common).autoconnect()) { _ in
            guard heroAppeared else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                heroCarouselIndex = (heroCarouselIndex + 1) % Self.heroSlideAssetNames.count
            }
        }
        .sheet(isPresented: $showEmailAuthSheet) {
            NavigationStack {
                LoginView(
                    presentationAsSheet: true,
                    onOpenEstablishment: {
                        showEmailAuthSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showEstablishmentOnboarding = true
                        }
                    },
                    onSheetNeedsTallLayout: { needsTall in
                        withAnimation(.easeInOut(duration: 0.28)) {
                            emailAuthSheetDetent = needsTall ? .large : .fraction(0.46)
                        }
                    }
                )
                .environmentObject(authService)
            }
            .presentationDragIndicator(.hidden)
            .presentationDetents([.fraction(0.46), .large], selection: $emailAuthSheetDetent)
            .presentationCornerRadius(22)
        }
        .onChange(of: showEmailAuthSheet) { _, open in
            if open {
                emailAuthSheetDetent = .fraction(0.46)
            }
        }
        .fullScreenCover(isPresented: $showEstablishmentOnboarding) {
            MyfidpassMerchantOnboardingRootView(
                onComplete: { showEstablishmentOnboarding = false },
                onAlreadyHaveAccount: { showEstablishmentOnboarding = false }
            )
        }
        .alert("Connexion Google", isPresented: .init(
            get: { googleAlert != nil },
            set: { if !$0 { googleAlert = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let googleAlert { Text(googleAlert) }
        }
        .alert("Connexion Apple", isPresented: .init(
            get: { appleAlert != nil },
            set: { if !$0 { appleAlert = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let appleAlert { Text(appleAlert) }
        }
    }

    private func bottomAuthSection(bottomSafePadding: CGFloat) -> some View {
        VStack(spacing: 13) {
            landingGoogleButton
                .modifier(AuthLandingStaggerModifier(index: 0, revealed: actionsAppeared))
            landingAppleButton
                .modifier(AuthLandingStaggerModifier(index: 1, revealed: actionsAppeared))
            landingEmailButton
                .modifier(AuthLandingStaggerModifier(index: 2, revealed: actionsAppeared))
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, bottomSafePadding + 10)
    }

    private var landingGoogleButton: some View {
        Button {
            AuthLandingHaptics.lightTap()
            startGoogle()
        } label: {
            HStack(spacing: 12) {
                if googleLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.95)
                } else {
                    Image("GoogleGLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                }
                Text(googleLoading ? "Connexion…" : "Continuer avec Google")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .padding(.horizontal, 18)
            .background(Color.black, in: Capsule())
            .shadow(color: Color.black.opacity(0.18), radius: 12, y: 5)
        }
        .buttonStyle(AuthLandingPressStyle())
        .disabled(googleLoading)
        .accessibilityLabel("Continuer avec Google")
    }

    private var landingAppleButton: some View {
        AppleSignInRow(
            intent: .signIn,
            isLoading: appleLoading,
            styleOverride: .white,
            cornerRadius: 26,
            onAuthorization: handleAppleAuthorization
        )
        .frame(maxWidth: .infinity)
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.black.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 10, y: 4)
    }

    private var landingEmailButton: some View {
        Button {
            AuthLandingHaptics.lightTap()
            showEmailAuthSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 17, weight: .regular))
                Text("Continuer avec l’e-mail")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Color.primary.opacity(0.92))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(AuthLandingPressStyle())
        .accessibilityLabel("Continuer avec l’e-mail")
    }

    private func startGoogle() {
        googleLoading = true
        googleAlert = nil
        Task {
            defer { googleLoading = false }
            do {
                try await authService.startGoogleOAuthFlow()
            } catch let api as APIError {
                if case .unauthorized = api {
                    googleAlert = "Le serveur n’a pas validé la session juste après Google (réseau ou incident temporaire). Réessayez « Continuer avec Google », ou « Continuer avec l’e-mail »."
                } else {
                    googleAlert = api.localizedDescription
                }
            } catch AuthError.notImplemented {
                googleAlert = "La connexion Google n’est pas disponible. Utilisez « Continuer avec l’e-mail »."
            } catch AuthError.noAccountInLogiciel {
                googleAlert = "Aucun compte MyFidpass lié à ce Google. Utilisez « Continuer avec l’e-mail » sur l’écran d’accueil pour créer un compte."
            } catch {
                let ns = error as NSError
                if ns.domain == "com.apple.AuthenticationServices.WebAuthenticationSession", ns.code == 1 {
                    return
                }
                googleAlert = error.localizedDescription
            }
        }
    }

    private func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            if isAppleUserCancellation(error) { return }
            appleAlert = error.localizedDescription
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                appleAlert = "Réponse Apple inattendue."
                return
            }
            guard let tokenData = appleIDCredential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                appleAlert = "Jeton Apple indisponible."
                return
            }
            let given = appleIDCredential.fullName?.givenName
            let family = appleIDCredential.fullName?.familyName
            let parts = [given, family].compactMap { $0 }.filter { !$0.isEmpty }
            let fullName = parts.joined(separator: " ")
            let nameOpt = fullName.isEmpty ? nil : fullName
            appleLoading = true
            Task { @MainActor in
                defer { appleLoading = false }
                do {
                    try await authService.loginWithApple(
                        idToken: idToken,
                        name: nameOpt,
                        email: appleIDCredential.email,
                        appleUserIdentifier: appleIDCredential.user
                    )
                } catch AuthError.noAccountInLogiciel {
                    appleAlert = "Aucun compte MyFidpass lié à Apple. Utilisez « Continuer avec l’e-mail » sur l’écran d’accueil pour créer un compte."
                } catch {
                    appleAlert = error.localizedDescription
                }
            }
        }
    }

    private func isAppleUserCancellation(_ error: Error) -> Bool {
        if let e = error as? ASAuthorizationError, e.code == .canceled {
            return true
        }
        let ns = error as NSError
        return ns.domain == ASAuthorizationError.errorDomain && ns.code == ASAuthorizationError.canceled.rawValue
    }
}

// MARK: - Feuille : téléphone + code SMS

private struct PhoneAuthPrimaryButtonStyle: ButtonStyle {
    var enabled: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(enabled ? (configuration.isPressed ? 0.82 : 1) : 0.35))
            )
    }
}

private struct PhoneAuthSheetFlow: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    /// Après alerte « établissement requis » : ouvrir le flux lieu + nom (écran plein).
    var onOpenEstablishment: () -> Void = {}

    private enum Step {
        case enterPhone
        case enterCode
    }

    @FocusState private var focused: Field?
    private enum Field {
        case phone
        case code
    }

    @State private var step: Step = .enterPhone
    @State private var phoneRaw = ""
    @State private var otp = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showEstablishmentRequiredAlert = false

    private var digits: String {
        phoneRaw.filter(\.isNumber)
    }

    /// Aligné sur l’API : mobile FR 06/07 ou 33… sans +
    private func phoneForAPI() -> String {
        let d = digits
        if d.count == 11, d.hasPrefix("33") { return "+\(d)" }
        if d.count == 10, d.hasPrefix("0") {
            return "+33\(d.dropFirst())"
        }
        return phoneRaw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSendCode: Bool {
        let d = digits
        if d.count == 10 { return d.hasPrefix("06") || d.hasPrefix("07") }
        if d.count == 11 { return d.hasPrefix("33") }
        return false
    }

    private var canVerify: Bool {
        otp.count == 6 && !isLoading
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SheetDismissBar { dismiss() }

                    switch step {
                    case .enterPhone:
                        Text("Votre numéro")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        TextField("06 12 34 56 78", text: $phoneRaw)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                            .focused($focused, equals: .phone)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .onChange(of: phoneRaw) { _, new in
                                let d = new.filter(\.isNumber)
                                phoneRaw = String(d.prefix(11))
                            }

                        if let msg = errorMessage {
                            Text(msg)
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.Colors.error)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Button {
                            Task { await sendCode() }
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.95)
                                } else {
                                    Text("Recevoir le code")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PhoneAuthPrimaryButtonStyle(enabled: canSendCode || isLoading))
                        .disabled(!canSendCode || isLoading)

                    case .enterCode:
                        Text("Code SMS")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        if !FirstLaunchOnboarding.hasCompletePendingEstablishmentForRegistration() {
                            Text(
                                "Nouveau compte : choisissez d’abord votre établissement via « Continuer avec l’e-mail », puis revenez ici pour le SMS."
                            )
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }

                        TextField("000000", text: $otp)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                            .focused($focused, equals: .code)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .onChange(of: otp) { _, new in
                                let f = new.filter(\.isNumber)
                                otp = String(f.prefix(6))
                            }

                        if let msg = errorMessage {
                            Text(msg)
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.Colors.error)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Button {
                            Task { await verify() }
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.95)
                                } else {
                                    Text("Continuer")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PhoneAuthPrimaryButtonStyle(enabled: canVerify || isLoading))
                        .disabled(!canVerify || isLoading)

                        Button {
                            step = .enterPhone
                            otp = ""
                            errorMessage = nil
                        } label: {
                            Text("Modifier le numéro")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppTheme.Colors.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.Colors.background)
            .onAppear {
                if step == .enterPhone { focused = .phone }
            }
            .onChange(of: step) { _, new in
                if new == .enterCode { focused = .code }
            }
            .alert("Établissement requis", isPresented: $showEstablishmentRequiredAlert) {
                Button("Choisir mon établissement") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onOpenEstablishment()
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(
                    "Pour créer un compte avec le téléphone, il faut avoir indiqué le lieu et le nom de votre établissement. Utilisez « Continuer avec l’e-mail » pour choisir l’établissement, puis revenez au numéro de téléphone."
                )
            }
        }
        .sheetHideNavigationBar()
        .environmentObject(authService)
        .preferredColorScheme(.light)
    }

    private func sendCode() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.sendPhoneOtp(phone: phoneForAPI())
            await MainActor.run {
                step = .enterCode
                otp = ""
                focused = .code
            }
        } catch {
            await MainActor.run {
                errorMessage = Self.messageForPhoneAuth(error)
            }
        }
    }

    private func verify() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.verifyPhoneAndSignIn(phone: phoneForAPI(), code: otp)
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run {
                if let api = error as? APIError, case .missingEstablishment = api {
                    errorMessage = api.localizedDescription
                    showEstablishmentRequiredAlert = true
                } else {
                    errorMessage = Self.messageForPhoneAuth(error)
                }
            }
        }
    }

    /// Affiche le message renvoyé par l’API (ex. Twilio trial, mauvais numéro).
    private static func messageForPhoneAuth(_ error: Error) -> String {
        if let api = error as? APIError {
            return api.localizedDescription
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

#Preview {
    OnboardingChoiceView()
        .environmentObject(AuthService())
}
