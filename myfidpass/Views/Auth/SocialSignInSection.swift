//
//  SocialSignInSection.swift
//  myfidpass
//
//  Apple + Google sur l’écran Connexion / Inscription (intention explicite).
//

import AuthenticationServices
import SwiftUI

/// Connexion sociale : affichée seulement quand l’utilisateur a choisi « Se connecter » ou « Inscription ».
enum SocialSignInIntent: Equatable {
    case signIn
    case signUp
}

struct SocialSignInSection: View {
    @EnvironmentObject private var authService: AuthService
    var intent: SocialSignInIntent

    @State private var googleError: String?
    @State private var appleError: String?
    @State private var isGoogleLoading = false
    @State private var isAppleLoading = false

    private var caption: String {
        switch intent {
        case .signIn:
            return "Connectez-vous avec Apple ou Google si vous avez déjà un compte MyFidpass."
        case .signUp:
            return "Créez un compte avec Apple ou Google — aucun mot de passe à saisir ici."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text(caption)
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            AppleSignInRow(intent: intent, isLoading: isAppleLoading, onAuthorization: handleAppleAuthorization)
            Text("ou")
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity)

            GoogleSignInButton(isLoading: isGoogleLoading) {
                startGoogleSignIn()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert(googleAlertTitle, isPresented: .init(
            get: { googleError != nil },
            set: { if !$0 { googleError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let msg = googleError { Text(msg) }
        }
        .alert(appleAlertTitle, isPresented: .init(
            get: { appleError != nil },
            set: { if !$0 { appleError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let msg = appleError { Text(msg) }
        }
    }

    private var googleAlertTitle: String {
        intent == .signUp ? "Inscription Google" : "Connexion Google"
    }

    private var appleAlertTitle: String {
        intent == .signUp ? "Inscription Apple" : "Connexion Apple"
    }

    /// Message si l’API indique l’absence de compte (uniquement pertinent en mode connexion).
    private var noAccountMessage: String {
        switch intent {
        case .signIn:
            return "Aucun compte MyFidpass n’est lié à cet identifiant. Passez à l’onglet « Inscription » pour créer un compte, ou réessayez."
        case .signUp:
            return "La connexion n’a pas pu aboutir. Réessayez dans un instant, ou créez un compte avec e-mail et mot de passe ci-dessus."
        }
    }

    private func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            if isAppleUserCancellation(error) { return }
            appleError = error.localizedDescription
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                appleError = "Réponse Apple inattendue."
                return
            }
            guard let tokenData = appleIDCredential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                appleError = "Jeton Apple indisponible. Réessayez."
                return
            }
            let given = appleIDCredential.fullName?.givenName
            let family = appleIDCredential.fullName?.familyName
            let parts = [given, family].compactMap { $0 }.filter { !$0.isEmpty }
            let fullName = parts.joined(separator: " ")
            let nameOpt = fullName.isEmpty ? nil : fullName
            isAppleLoading = true
            Task { @MainActor in
                defer { isAppleLoading = false }
                do {
                    try await authService.loginWithApple(
                        idToken: idToken,
                        name: nameOpt,
                        email: appleIDCredential.email,
                        appleUserIdentifier: appleIDCredential.user
                    )
                } catch AuthError.noAccountInLogiciel {
                    appleError = noAccountMessage
                } catch {
                    appleError = error.localizedDescription
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

    private func startGoogleSignIn() {
        isGoogleLoading = true
        googleError = nil
        Task {
            defer { isGoogleLoading = false }
            do {
                try await authService.startGoogleOAuthFlow()
            } catch AuthError.notImplemented {
                googleError = "La connexion Google n’est pas configurée sur ce serveur. Utilisez l’e-mail et le mot de passe."
            } catch AuthError.noAccountInLogiciel {
                googleError = noAccountMessage
            } catch {
                let ns = error as NSError
                if ns.domain == "com.apple.AuthenticationServices.WebAuthenticationSession" && ns.code == 1 {
                    googleError = "Connexion annulée."
                } else {
                    googleError = error.localizedDescription
                }
            }
        }
    }
}
