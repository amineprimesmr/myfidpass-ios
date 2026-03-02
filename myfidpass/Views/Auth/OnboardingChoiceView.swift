//
//  OnboardingChoiceView.swift
//  myfidpass
//
//  Premier écran au lancement : "Déjà client MyFidPass ?" → Se connecter ou Créer un compte.
//

import SwiftUI
import AuthenticationServices

struct OnboardingChoiceView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var authService: AuthService
    @State private var appeared = false
    @State private var showGoogleComingSoon = false
    @State private var showNoAccountInLogiciel = false

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Spacer()

            logoSection
            titleSection
            choiceButtons
            socialSignInSection

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.background)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }

    private var logoSection: some View {
        Image(systemName: "creditcard.and.123")
            .font(.system(size: 64))
            .foregroundStyle(AppTheme.Colors.primary)
    }

    private var titleSection: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text("Bienvenue sur MyFidPass")
                .font(AppTheme.Fonts.largeTitle())
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Text("Déjà client MyFidPass ?")
                .font(AppTheme.Fonts.title3())
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    private var choiceButtons: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Button {
                authService.showLogin()
            } label: {
                Label("Se connecter", systemImage: "person.fill.checkmark")
                    .font(AppTheme.Fonts.headline())
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.Spacing.md)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.primary)

            Button {
                openURL(AppWebURL.createAccount)
            } label: {
                Label("Créer un compte", systemImage: "person.badge.plus")
                    .font(AppTheme.Fonts.headline())
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.Spacing.md)
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.Colors.primary)
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
    }

    private var socialSignInSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("ou continuer avec")
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
            .padding(.horizontal, AppTheme.Spacing.xl)

            Button {
                showGoogleComingSoon = true
            } label: {
                HStack {
                    Image(systemName: "globe")
                    Text("Continuer avec Google")
                }
                .font(AppTheme.Fonts.headline())
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.Colors.textPrimary)
            .padding(.horizontal, AppTheme.Spacing.xl)
        }
        .alert("Bientôt disponible", isPresented: $showGoogleComingSoon) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("La connexion avec Google sera disponible prochainement.")
        }
        .alert("Aucun compte associé", isPresented: $showNoAccountInLogiciel) {
            Button("Ouvrir le site") {
                openURL(AppWebURL.createAccount)
            }
            Button("Fermer", role: .cancel) {}
        } message: {
            Text("Aucun compte n’est rattaché à cet identifiant. Créez d’abord votre compte sur myfidpass.fr.")
        }
    }
}

#Preview {
    OnboardingChoiceView()
        .environmentObject(AuthService())
}
