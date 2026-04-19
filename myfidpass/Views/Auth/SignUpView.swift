//
//  SignUpView.swift
//  myfidpass
//
//  Inscription native (même API que LoginView).
//  L’établissement est défini dans l’onboarding premier lancement uniquement.
//

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xl) {
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text("Créer un compte")
                        .font(AppTheme.Fonts.largeTitle())
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("Après l’introduction, saisissez votre e-mail et votre mot de passe. Votre établissement est déjà enregistré.")
                        .font(AppTheme.Fonts.body())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, AppTheme.Spacing.lg)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text("Email")
                            .font(AppTheme.Fonts.caption())
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        TextField("votre@email.fr", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                    }
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text("Mot de passe (12 caractères min.)")
                            .font(AppTheme.Fonts.caption())
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        SecureField("••••••••••••", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                if let msg = errorMessage {
                    Text(msg)
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(AppTheme.Colors.error)
                }

                Button {
                    submit()
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Créer mon compte")
                        }
                    }
                    .font(AppTheme.Fonts.headline())
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.Spacing.md)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.primary)
                .disabled(
                    isLoading
                        || email.trimmingCharacters(in: .whitespaces).isEmpty
                        || password.count < 12
                        || !hasOnboardingEstablishmentForRegister
                )

                Button("Déjà un compte ? Se connecter") {
                    authService.showLogin()
                }
                .font(AppTheme.Fonts.callout())
                .foregroundStyle(AppTheme.Colors.primary)

                LegalDocumentLinksView()
                    .padding(.top, AppTheme.Spacing.md)
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

    private var hasOnboardingEstablishmentForRegister: Bool {
        let p = FirstLaunchOnboarding.readPendingEstablishment()
        return p.relax || p.placeId != nil
    }

    private func submit() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                try await authService.register(
                    email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                    password: password,
                    name: nil,
                    googlePlaceId: nil,
                    establishmentName: nil
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .environmentObject(AuthService())
    }
}
