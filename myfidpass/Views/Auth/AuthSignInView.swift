//
//  AuthSignInView.swift
//  myfidpass
//
//  Page de connexion dédiée : e-mail / identifiant + mot de passe, Google, Apple.
//

import AuthenticationServices
import Combine
import SwiftUI

struct AuthSignInView: View {
    @EnvironmentObject private var authService: AuthService
    var onBack: (() -> Void)? = nil

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var googleLoading = false
    @State private var appleLoading = false
    @State private var googleAlert: String?
    @State private var appleAlert: String?
    @State private var heroCarouselIndex = 0
    @State private var heroAppeared = false
    @State private var contentAppeared = false
    @State private var keyboardHeight: CGFloat = 0

    @FocusState private var focusedField: Field?
    private enum Field { case email, password }

    private static let heroAssets = ["5", "6", "7", "8"]

    private var normalizedIdentifier: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isEmailValid: Bool {
        let e = normalizedIdentifier
        guard e.count >= 5, e.contains("@") else { return false }
        let parts = e.split(separator: "@")
        guard parts.count == 2, let domain = parts.last, domain.contains(".") else { return false }
        return true
    }

    private var isStaffIdValid: Bool {
        let s = normalizedIdentifier
        guard !s.contains("@"), s.count >= 3, s.count <= 32 else { return false }
        return s.range(of: "^[a-z0-9][a-z0-9_-]{1,30}[a-z0-9]$", options: .regularExpression) != nil
    }

    private var isIdentifierValid: Bool {
        normalizedIdentifier.contains("@") ? isEmailValid : isStaffIdValid
    }

    private var hasStartedIdentifierTyping: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shouldRevealPasswordField: Bool {
        hasStartedIdentifierTyping || focusedField == .email || focusedField == .password
    }

    private var canSubmit: Bool {
        !isLoading && isIdentifierValid && !password.isEmpty
    }

    /// Fond **opaque** des champs (pas tertiarySystemFill, trop translucide sur le dégradé).
    private var fieldChromeBackground: Color {
        Color(red: 236 / 255, green: 236 / 255, blue: 238 / 255)
    }

    var body: some View {
        GeometryReader { geo in
            let fullW = geo.size.width
            let fullH = geo.size.height
            let heroHeight = fullH * 0.82
            let topSafe = geo.safeAreaInsets.top
            let bottomSafe = max(geo.safeAreaInsets.bottom, 12)

            ZStack(alignment: .bottom) {
                Color.white.ignoresSafeArea()

                TabView(selection: $heroCarouselIndex) {
                    ForEach(0..<Self.heroAssets.count, id: \.self) { i in
                        Image(Self.heroAssets[i])
                            .resizable()
                            .scaledToFill()
                            .frame(width: fullW, height: heroHeight, alignment: .top)
                            .clipped()
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: fullW, height: heroHeight, alignment: .top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
                .offset(y: -8)
                .scaleEffect(heroAppeared ? 1 : 1.02)
                .opacity(heroAppeared ? 1 : 0)
                .ignoresSafeArea(edges: .top)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                        VStack(spacing: 12) {
                            TextField(
                                "",
                                text: $email,
                                prompt: Text("E-mail ou identifiant").foregroundStyle(placeholderGray)
                            )
                            .textContentType(.username)
                            .keyboardType(.asciiCapable)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(.black)
                            .tint(.black)
                            .focused($focusedField, equals: .email)
                            .padding(16)
                            .background(
                                fieldChromeBackground,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .onChange(of: email) { _, newVal in
                                if errorMessage != nil { errorMessage = nil }
                                if newVal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    password = ""
                                    if focusedField == .password { focusedField = .email }
                                }
                            }

                            if shouldRevealPasswordField {
                                SecureField(
                                    "",
                                    text: $password,
                                    prompt: Text("Votre mot de passe").foregroundStyle(placeholderGray)
                                )
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                                .foregroundStyle(.black)
                                .tint(.black)
                                .padding(16)
                                .background(
                                    fieldChromeBackground,
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                                .onChange(of: password) { _, _ in if errorMessage != nil { errorMessage = nil } }
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                                    removal: .opacity.combined(with: .scale(scale: 0.98))
                                ))
                            }
                        }
                        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: shouldRevealPasswordField)

                        if !shouldRevealPasswordField {
                            VStack(spacing: 12) {
                                googleButton
                                appleButton
                            }
                            .padding(.top, 16)
                        }

                        if let msg = errorMessage, !msg.isEmpty {
                            Text(msg)
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.Colors.error)
                                .padding(.top, 12)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if shouldRevealPasswordField {
                            primaryButton(
                                title: "Se connecter",
                                enabled: canSubmit,
                                loading: isLoading
                            ) {
                                Task { await submit() }
                            }
                            .padding(.top, 14)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(contentAppeared ? 1 : 0)
                    .padding(.horizontal, 24)
                    .padding(.top, 0)
                    .padding(.bottom, keyboardHeight > 0 ? 8 : bottomSafe)
                    .background(Color.clear)
                }
                .scrollDismissesKeyboard(.interactively)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                    .background(Color.clear)
                }
                .padding(.top, 10)
                .padding(.bottom, keyboardHeight)
                .ignoresSafeArea(edges: .bottom)
            }
            .overlay(alignment: .topLeading) {
                Button {
                    onBack?()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.88))
                        .frame(width: 36, height: 36)
                }
                .buttonBorderShape(.circle)
                .controlSize(.regular)
                .liquidGlassButtonAppearance(.adaptive, cornerRadius: 18)
                .accessibilityLabel("Retour")
                .padding(EdgeInsets(top: max(topSafe, 44) + 8, leading: 16, bottom: 0, trailing: 0))
            }
            .animation(.easeOut(duration: 0.22), value: keyboardHeight)
            .frame(width: fullW, height: fullH)
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(edges: [.top, .bottom])
        .preferredColorScheme(.light)
        .onAppear {
            withAnimation(.spring(response: 0.72, dampingFraction: 0.88)) {
                heroAppeared = true
            }
            withAnimation(.spring(response: 0.52, dampingFraction: 0.86).delay(0.06)) {
                contentAppeared = true
            }
        }
        .onReceive(Timer.publish(every: 4.2, on: .main, in: .common).autoconnect()) { _ in
            guard heroAppeared else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                heroCarouselIndex = (heroCarouselIndex + 1) % Self.heroAssets.count
            }
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

    // MARK: - Subviews

    private var googleButton: some View {
        Button {
            startGoogle()
        } label: {
            HStack(spacing: 12) {
                if googleLoading {
                    ProgressView().tint(.white).scaleEffect(0.92)
                } else {
                    Image("GoogleGLogo")
                        .resizable().scaledToFit()
                        .frame(width: 20, height: 20)
                }
                Text(googleLoading ? "Connexion…" : "Continuer avec Google")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, 18)
            .background(Color.black, in: Capsule())
            .shadow(color: Color.black.opacity(0.14), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(googleLoading)
    }

    private var appleButton: some View {
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
                .strokeBorder(Color.black.opacity(0.18), lineWidth: 1)
        }
    }

    private func primaryButton(
        title: String,
        enabled: Bool,
        loading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if loading {
                    ProgressView().tint(.black).scaleEffect(1.05)
                } else {
                    Text(title).font(.system(size: 17, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle((enabled || loading) ? Color.black : Color.black.opacity(0.42))
        }
        .buttonBorderShape(.capsule)
        .liquidGlassButtonAppearance(.adaptive, cornerRadius: 999)
        .disabled(!enabled || loading)
    }

    private var placeholderGray: Color {
        Color(UIColor(white: 0.38, alpha: 1))
    }

    // MARK: - Actions

    private func submit() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.login(email: normalizedIdentifier, password: password)
        } catch AuthError.invalidCredentials {
            await MainActor.run { errorMessage = "E-mail ou mot de passe incorrect." }
        } catch AuthError.noAccountInLogiciel {
            await MainActor.run { errorMessage = "Aucun compte trouvé avec cet identifiant." }
        } catch AuthError.apiMessage(let msg) {
            await MainActor.run { errorMessage = msg }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func startGoogle() {
        googleLoading = true
        googleAlert = nil
        Task {
            defer { googleLoading = false }
            do {
                try await authService.startGoogleOAuthFlow()
            } catch AuthError.missingEstablishment {
                authService.rewindWelcomeMerchantPremisesAfterLostEstablishmentContext()
            } catch let api as APIError {
                if case .missingEstablishment(_) = api {
                    authService.rewindWelcomeMerchantPremisesAfterLostEstablishmentContext()
                } else {
                    googleAlert = api.localizedDescription
                }
            } catch AuthError.noAccountInLogiciel {
                googleAlert = "Aucun compte MyFidpass lié à cet identifiant Google. Créez un compte avec l'e-mail."
            } catch AuthError.notImplemented {
                googleAlert = "Google n'est pas disponible pour le moment. Utilisez l'e-mail."
            } catch {
                let ns = error as NSError
                if ns.domain == "com.apple.AuthenticationServices.WebAuthenticationSession", ns.code == 1 { return }
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
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                appleAlert = "Réponse Apple inattendue."
                return
            }
            let given = credential.fullName?.givenName
            let family = credential.fullName?.familyName
            let parts = [given, family].compactMap { $0 }.filter { !$0.isEmpty }
            let fullName = parts.isEmpty ? nil : parts.joined(separator: " ")
            appleLoading = true
            Task { @MainActor in
                defer { appleLoading = false }
                do {
                    try await authService.loginWithApple(
                        idToken: idToken,
                        name: fullName,
                        email: credential.email,
                        appleUserIdentifier: credential.user
                    )
                } catch AuthError.noAccountInLogiciel {
                    appleAlert = "Aucun compte MyFidpass lié à cet identifiant Apple. Créez un compte avec l'e-mail."
                } catch {
                    appleAlert = error.localizedDescription
                }
            }
        }
    }

    private func isAppleUserCancellation(_ error: Error) -> Bool {
        if let e = error as? ASAuthorizationError, e.code == .canceled { return true }
        let ns = error as NSError
        return ns.domain == ASAuthorizationError.errorDomain && ns.code == ASAuthorizationError.canceled.rawValue
    }
}

#Preview {
    AuthSignInView()
        .environmentObject(AuthService())
}
