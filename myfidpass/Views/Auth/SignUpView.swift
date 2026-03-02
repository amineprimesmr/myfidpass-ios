//
//  SignUpView.swift
//  myfidpass
//
//  Création de compte : redirection vers le site myfidpass.fr (pas de formulaire in-app).
//

import SwiftUI

struct SignUpView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var authService: AuthService

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xl) {
                headerSection
                openSiteSection
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
            Text("Créer un compte")
                .font(AppTheme.Fonts.largeTitle())
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("La création de compte se fait sur le site MyFidPass. Une fois votre compte créé, revenez ici pour vous connecter.")
                .font(AppTheme.Fonts.body())
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppTheme.Spacing.lg)
    }

    private var openSiteSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Button {
                openURL(AppWebURL.createAccount)
            } label: {
                Label("Créer mon compte sur myfidpass.fr", systemImage: "safari")
                    .font(AppTheme.Fonts.headline())
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.Spacing.md)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.primary)

            Button("Déjà un compte ? Se connecter") {
                authService.showLogin()
            }
            .font(AppTheme.Fonts.callout())
            .foregroundStyle(AppTheme.Colors.primary)
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .environmentObject(AuthService())
    }
}
