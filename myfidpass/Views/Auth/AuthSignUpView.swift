//
//  AuthSignUpView.swift
//  myfidpass
//
//  Création de compte : e-mail + mot de passe (après sélection du commerce dans l'onboarding).
//

import AuthenticationServices
import Combine
import SwiftUI

struct AuthSignUpView: View {
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
    @State private var formVisible = false
    @State private var keyboardHeight: CGFloat = 0

    @FocusState private var focusedField: Field?
    private enum Field { case email, password }

    private static let heroAssets = ["5", "6", "7", "8"]

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isEmailValid: Bool {
        let e = normalizedEmail
        guard e.count >= 5, e.contains("@") else { return false }
        let parts = e.split(separator: "@")
        guard parts.count == 2, let domain = parts.last, domain.contains(".") else { return false }
        return true
    }

    private var canSubmit: Bool {
        !isLoading && isEmailValid && password.count >= 12
    }

    private var hasStartedEmailTyping: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static let authSheetTopFadeHeight: CGFloat = 52

    private static var authSheetTopFade: some View {
        LinearGradient(
            stops: [
                .init(color: Color.white.opacity(0), location: 0),
                .init(color: Color.white.opacity(0.55), location: 0.55),
                .init(color: Color.white, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: authSheetTopFadeHeight)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }

    private var fieldChromeBackground: Color {
        Color(red: 236 / 255, green: 236 / 255, blue: 238 / 255)
    }

    var body: some View {
        GeometryReader { geo in
            let fullW = geo.size.width
            let fullH = geo.size.height
            let topSafe = geo.safeAreaInsets.top
            let bottomSafe = max(geo.safeAreaInsets.bottom, 12)

            ZStack(alignment: .bottom) {
                Color.white.ignoresSafeArea()

                TabView(selection: $heroCarouselIndex) {
                    ForEach(0..<Self.heroAssets.count, id: \.self) { i in
                        Image(Self.heroAssets[i])
                            .resizable()
                            .scaledToFill()
                            .frame(width: fullW, height: fullH, alignment: .top)
                            .clipped()
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: fullW, height: fullH)
                .scaleEffect(heroAppeared ? 1 : 1.02)
                .opacity(heroAppeared ? 1 : 0)
                .ignoresSafeArea(edges: .top)

                VStack(spacing: 0) {
                    Self.authSheetTopFade

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            VStack(spacing: 12) {
                                TextField(
                                    "",
                                    text: $email,
                                    prompt: Text("Votre e-mail").foregroundStyle(placeholderGray)
                                )
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
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

                                if hasStartedEmailTyping {
                                    SecureField(
                                        "",
                                        text: $password,
                                        prompt: Text("Au moins 12 caractères").foregroundStyle(placeholderGray)
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
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                                        removal: .opacity.combined(with: .scale(scale: 0.98))
                                    ))
                                }
                            }
                            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: hasStartedEmailTyping)

                            if !hasStartedEmailTyping {
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

                            Button {
                                Task { await submit() }
                            } label: {
                                Group {
                                    if isLoading {
                                        ProgressView().tint(.black).scaleEffect(1.02)
                                    } else {
                                        Text("CREER MON COMPTE")
                                            .font(.system(size: 20, weight: .black))
                                            .foregroundStyle(canSubmit ? Color.black : Color.black.opacity(0.42))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                            }
                            .buttonBorderShape(.roundedRectangle(radius: 50))
                            .liquidGlassButtonAppearance(.adaptive, cornerRadius: 50)
                            .padding(.top, 20)
                            .disabled(!canSubmit || isLoading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(formVisible ? 1 : 0)
                        .padding(.horizontal, 24)
                        .padding(.top, 14)
                        .padding(.bottom, keyboardHeight > 0 ? 8 : bottomSafe)
                        .background(Color.white)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(Color.white)
                }
                .background(Color.white)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 28,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 28,
                        style: .continuous
                    )
                )
                .shadow(color: Color.black.opacity(0.06), radius: 14, y: -6)
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
                .padding(EdgeInsets(top: topSafe + 8, leading: 16, bottom: 0, trailing: 0))
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
            withAnimation(.spring(response: 0.46, dampingFraction: 0.86).delay(0.06)) {
                formVisible = true
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
        .onReceive(Timer.publish(every: 4.2, on: .main, in: .common).autoconnect()) { _ in
            guard heroAppeared else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                heroCarouselIndex = (heroCarouselIndex + 1) % Self.heroAssets.count
            }
        }
        .alert("Inscription Google", isPresented: .init(
            get: { googleAlert != nil },
            set: { if !$0 { googleAlert = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let googleAlert { Text(googleAlert) }
        }
        .alert("Inscription Apple", isPresented: .init(
            get: { appleAlert != nil },
            set: { if !$0 { appleAlert = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let appleAlert { Text(appleAlert) }
        }
    }

    private var googleButton: some View {
        Button {
            googleLoading = true
            googleAlert = nil
            Task {
                defer { googleLoading = false }
                do {
                    try await authService.startGoogleOAuthFlow(intent: .signUp)
                } catch {
                    googleAlert = error.localizedDescription
                }
            }
        } label: {
            HStack(spacing: 12) {
                if googleLoading {
                    ProgressView().tint(.white).scaleEffect(0.92)
                } else {
                    Image("GoogleGLogo")
                        .resizable().scaledToFit()
                        .frame(width: 20, height: 20)
                }
                Text(googleLoading ? "Inscription…" : "Créer avec Google")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, 18)
            .background(Color.black, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(googleLoading)
    }

    private var appleButton: some View {
        AppleSignInRow(
            intent: .signUp,
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

    private var placeholderGray: Color {
        Color(UIColor(white: 0.38, alpha: 1))
    }

    private func submit() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.register(
                email: normalizedEmail,
                password: password,
                name: nil,
                googlePlaceId: nil,
                establishmentName: nil
            )
        } catch AuthError.emailAlreadyUsed {
            await MainActor.run {
                errorMessage = "Un compte existe déjà avec cet e-mail. Retournez à l'accueil pour vous connecter."
            }
        } catch AuthError.apiMessage(let msg) {
            await MainActor.run { errorMessage = msg }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
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
                        appleUserIdentifier: credential.user,
                        intent: .signUp
                    )
                } catch {
                    appleAlert = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    AuthSignUpView()
        .environmentObject(AuthService())
}
