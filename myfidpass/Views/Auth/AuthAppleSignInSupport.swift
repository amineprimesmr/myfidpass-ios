//
//  AuthAppleSignInSupport.swift
//  myfidpass
//
//  Traitement commun Sign in with Apple → AuthService.loginWithApple.
//

import AuthenticationServices
import Foundation

enum AuthAppleSignInSupport {
    /// `true` si l’utilisateur a annulé (ne pas afficher d’alerte).
    static func isUserCancellation(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == ASAuthorizationError.errorDomain, ns.code == ASAuthorizationError.canceled.rawValue {
            return true
        }
        if ns.domain.contains("AuthenticationServices"), ns.code == 1001 { return true }
        return false
    }

    @MainActor
    static func handleAuthorization(
        _ result: Result<ASAuthorization, Error>,
        intent: SocialSignInIntent,
        authService: AuthService
    ) async throws {
        switch result {
        case .failure(let error):
            throw error
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AuthError.apiMessage("Connexion Apple impossible (identifiants incomplets).")
            }
            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  !idToken.isEmpty
            else {
                throw AuthError.apiMessage("Connexion Apple impossible (jeton manquant).")
            }
            let name: String? = {
                guard let full = credential.fullName else { return nil }
                let parts = [full.givenName, full.familyName]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                return parts.isEmpty ? nil : parts.joined(separator: " ")
            }()
            let email = credential.email?.trimmingCharacters(in: .whitespacesAndNewlines)
            let authIntent: AuthIntentMode = intent == .signUp ? .signUp : .signIn
            try await authService.loginWithApple(
                idToken: idToken,
                name: name,
                email: email?.isEmpty == false ? email : nil,
                appleUserIdentifier: credential.user,
                intent: authIntent
            )
        }
    }
}
