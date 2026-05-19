//
//  AuthSignInView.swift
//  myfidpass
//
//  Connexion : héros + Google ; saisie e-mail / identifiant dans une sheet.
//

import AuthenticationServices
import Combine
import SwiftUI

struct AuthSignInView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var onBack: () -> Void = {}

    @State private var showEmailSheet = false
    @State private var googleLoading = false
    @State private var appleLoading = false
    @State private var googleAlert: String?
    @State private var heroCarouselIndex = 0
    @State private var heroAppeared = false
    @State private var contentAppeared = false

    private static let heroAssets = ["5", "6", "7", "8"]

    var body: some View {
        GeometryReader { geo in
            let fullW = geo.size.width
            let fullH = geo.size.height
            let heroHeight = fullH * AuthResponsiveLayout.authStackedHeroHeightFraction(
                width: fullW,
                horizontalSizeClass: horizontalSizeClass
            )
            let heroWidth = AuthResponsiveLayout.authStackedHeroImageWidth(
                containerWidth: fullW,
                horizontalSizeClass: horizontalSizeClass
            )
            let heroContained = AuthResponsiveLayout.authStackedHeroUsesContainedImage(
                width: fullW,
                horizontalSizeClass: horizontalSizeClass
            )
            let heroTopPadding = AuthResponsiveLayout.authStackedHeroTopPadding(
                width: fullW,
                horizontalSizeClass: horizontalSizeClass,
                safeTop: geo.safeAreaInsets.top
            )
            let topSafe = geo.safeAreaInsets.top
            let bottomSafe = max(geo.safeAreaInsets.bottom, 12)

            ZStack(alignment: .bottom) {
                Color.white.ignoresSafeArea()

                TabView(selection: $heroCarouselIndex) {
                    ForEach(0..<Self.heroAssets.count, id: \.self) { i in
                        Image(Self.heroAssets[i])
                            .resizable()
                            .aspectRatio(contentMode: heroContained ? .fit : .fill)
                            .frame(width: heroWidth, height: heroHeight, alignment: .top)
                            .clipped()
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: heroWidth, height: heroHeight, alignment: .top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, heroTopPadding)
                .clipped()
                .scaleEffect(heroAppeared ? 1 : 1.02)
                .opacity(heroAppeared ? 1 : 0)

                VStack(spacing: 12) {
                    appleSignInButton
                    googleButton
                    emailPrimaryButton
                    AuthLegalFooterView()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, bottomSafe + 16)
                .background(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.75),
                            Color.white,
                        ],
                        startPoint: UnitPoint(x: 0.5, y: 0),
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                )
                .opacity(contentAppeared ? 1 : 0)
            }
            .overlay(alignment: .topLeading) {
                Button {
                    onBack()
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
            .frame(width: fullW, height: fullH)
        }
        .ignoresSafeArea(edges: [.top, .bottom])
        .preferredColorScheme(.light)
        .sheet(isPresented: $showEmailSheet) {
            AuthSignInEmailSheet(isPresented: $showEmailSheet)
                .environmentObject(authService)
        }
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
        .alert("Connexion Google", isPresented: .init(
            get: { googleAlert != nil },
            set: { if !$0 { googleAlert = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let googleAlert { Text(googleAlert) }
        }
    }

    private var emailPrimaryButton: some View {
        Button {
            showEmailSheet = true
        } label: {
            Text("Connexion avec l'e-mail")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(Color.black)
        }
        .buttonBorderShape(.capsule)
        .liquidGlassButtonAppearance(.adaptive, cornerRadius: 999)
        .disabled(socialAuthBusy)
    }

    private var socialAuthBusy: Bool {
        googleLoading || appleLoading
    }

    private var appleSignInButton: some View {
        AppleSignInRow(
            intent: .signIn,
            isLoading: appleLoading,
            styleOverride: .black,
            cornerRadius: 26,
            onAuthorization: { result in
                handleAppleAuthorization(result)
            }
        )
        .frame(minHeight: 52)
    }

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
        .disabled(socialAuthBusy)
    }

    private func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            if AuthAppleSignInSupport.isUserCancellation(error) { return }
            googleAlert = error.localizedDescription
        case .success:
            appleLoading = true
            googleAlert = nil
            Task {
                defer { appleLoading = false }
                do {
                    try await AuthAppleSignInSupport.handleAuthorization(
                        result,
                        intent: .signIn,
                        authService: authService
                    )
                } catch AuthError.missingEstablishment {
                    authService.rewindWelcomeMerchantPremisesAfterLostEstablishmentContext()
                } catch AuthError.noAccountInLogiciel {
                    googleAlert = "Aucun compte MyFidpass lié à cet identifiant Apple. Créez un compte avec l’e-mail ou Google."
                } catch AuthError.apiMessage(let msg) {
                    googleAlert = msg
                } catch {
                    googleAlert = error.localizedDescription
                }
            }
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
}

// MARK: - Sheet

/// Hauteur fixe du sheet : le système le remonte au-dessus du clavier. Éviter clavier+hauteur (≈ plein écran).
private enum AuthEmailSheetPresentation {
    static let detentHeight: CGFloat = 284
}

private struct AuthSignInEmailSheet: View {
    @EnvironmentObject private var authService: AuthService
    @Binding var isPresented: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    @FocusState private var focused: Field?
    private enum Field { case email, password }

    private var fieldChromeBackground: Color {
        Color(red: 236 / 255, green: 236 / 255, blue: 238 / 255)
    }

    private var placeholderGray: Color {
        Color(UIColor(white: 0.38, alpha: 1))
    }

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

    private var canSubmit: Bool {
        !isLoading && isIdentifierValid && !password.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 12) {
                TextField(
                    "",
                    text: $email,
                    prompt: Text("E-mail ou identifiant").foregroundStyle(placeholderGray)
                )
                .textContentType(.username)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused, equals: .email)
                .submitLabel(.next)
                .padding(14)
                .background(fieldChromeBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onChange(of: email) { _, _ in
                    if errorMessage != nil { errorMessage = nil }
                }

                SecureField(
                    "",
                    text: $password,
                    prompt: Text("Mot de passe").foregroundStyle(placeholderGray)
                )
                .textContentType(.password)
                .focused($focused, equals: .password)
                .submitLabel(.go)
                .padding(14)
                .background(fieldChromeBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onChange(of: password) { _, _ in
                    if errorMessage != nil { errorMessage = nil }
                }
                .onSubmit {
                    if canSubmit { Task { await submit() } }
                }

                if let msg = errorMessage, !msg.isEmpty {
                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Colors.error)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(4)
                }

                Button {
                    Task { await submit() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.black).scaleEffect(1.02)
                        } else {
                            Text("Se connecter")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle((canSubmit || isLoading) ? Color.black : Color.black.opacity(0.4))
                }
                .buttonBorderShape(.capsule)
                .liquidGlassButtonAppearance(.adaptive, cornerRadius: 999)
                .disabled(!canSubmit || isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.height(AuthEmailSheetPresentation.detentHeight)])
        .presentationDragIndicator(.hidden)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                focused = .email
            }
        }
    }

    private func submit() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.login(email: normalizedIdentifier, password: password)
            await MainActor.run { isPresented = false }
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
}

#Preview {
    AuthSignInView()
        .environmentObject(AuthService())
}
