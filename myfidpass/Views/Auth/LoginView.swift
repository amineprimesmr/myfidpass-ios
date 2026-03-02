//
//  LoginView.swift
//  myfidpass
//
//  Connexion : email + mot de passe, Apple, Google. Prêt pour branchement API.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var googleError: String?
    @State private var isGoogleLoading = false
    @State private var showNoAccountInLogiciel = false
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xl) {
                headerSection
                formSection
                if let msg = errorMessage {
                    Text(msg)
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(AppTheme.Colors.error)
                }
                submitSection
            }
            .padding(AppTheme.Spacing.lg)
        }
        .background(AppTheme.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Retour") {
                    authService.showWelcome()
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text("Connexion")
                .font(AppTheme.Fonts.largeTitle())
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("Connectez-vous à votre compte commerçant")
                .font(AppTheme.Fonts.body())
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppTheme.Spacing.lg)
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Email")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                TextField("votre@email.fr", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .email)
            }
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Mot de passe")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                SecureField("••••••••", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .password)
            }
        }
    }

    private var submitSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Button {
                submitLogin()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Se connecter")
                    }
                }
                .font(AppTheme.Fonts.headline())
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.md)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.primary)
            .disabled(isLoading || email.isEmpty)

            socialSignInSection

            Button("Créer un compte") {
                openURL(AppWebURL.createAccount)
            }
            .font(AppTheme.Fonts.callout())
            .foregroundStyle(AppTheme.Colors.primary)
        }
        .padding(.top, AppTheme.Spacing.md)
        .alert("Aucun compte associé", isPresented: $showNoAccountInLogiciel) {
            Button("Ouvrir le site") {
                openURL(AppWebURL.createAccount)
            }
            Button("Fermer", role: .cancel) {}
        } message: {
            Text("Aucun compte n’est rattaché. Créez d’abord votre compte sur myfidpass.fr.")
        }
        .alert("Connexion Google", isPresented: .init(get: { googleError != nil }, set: { if !$0 { googleError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let msg = googleError { Text(msg) }
        }
    }

    private var socialSignInSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("ou")
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                          let tokenData = credential.identityToken,
                          let idToken = String(data: tokenData, encoding: .utf8) else { return }
                    let name: String? = {
                        guard let given = credential.fullName?.givenName else { return nil }
                        let family = credential.fullName?.familyName ?? ""
                        return "\(given) \(family)".trimmingCharacters(in: .whitespaces)
                    }()
                    Task {
                        do {
                            try await authService.loginWithApple(idToken: idToken, name: name, email: credential.email)
                        } catch AuthError.noAccountInLogiciel {
                            showNoAccountInLogiciel = true
                        } catch { }
                    }
                case .failure:
                    break
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .frame(maxWidth: 375)

            Button {
                startGoogleSignIn()
            } label: {
                HStack(spacing: 10) {
                    if isGoogleLoading {
                        ProgressView()
                            .tint(AppTheme.Colors.primary)
                        Text("Ouverture de Google…")
                            .font(AppTheme.Fonts.callout())
                            .foregroundStyle(AppTheme.Colors.primary)
                    } else {
                        Image(systemName: "globe")
                        Text("Continuer avec Google")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
            }
            .font(AppTheme.Fonts.callout())
            .foregroundStyle(AppTheme.Colors.primary)
            .buttonStyle(.bordered)
            .disabled(isGoogleLoading)
        }
    }

    private func startGoogleSignIn() {
        isGoogleLoading = true
        googleError = nil
        Task {
            do {
                try await authService.startGoogleOAuthFlow()
            } catch AuthError.notImplemented {
                googleError = "La connexion avec Google sera disponible prochainement."
            } catch AuthError.noAccountInLogiciel {
                showNoAccountInLogiciel = true
            } catch {
                let ns = error as NSError
                if ns.domain == "com.apple.AuthenticationServices.WebAuthenticationSession" && ns.code == 1 {
                    googleError = "Connexion annulée. Si la fenêtre ne s’est pas ouverte (iPad), réessayez."
                } else {
                    googleError = error.localizedDescription
                }
            }
            isGoogleLoading = false
        }
    }

    private func submitLogin() {
        errorMessage = nil
        focusedField = nil
        isLoading = true
        Task {
            do {
                try await authService.login(email: email, password: password)
            } catch AuthError.noAccountInLogiciel {
                showNoAccountInLogiciel = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AuthService())
    }
}
