//
//  AuthService.swift
//  myfidpass
//
//  Connexion via l’API MyFidpass (login, Apple, Google). Création de compte → myfidpass.fr.
//

import Foundation
import Combine

enum AppWebURL {
    static let createAccount = URL(string: "https://myfidpass.fr")!
}

enum AuthScreen: Equatable {
    case welcome
    case login
    case authenticated
}

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var currentScreen: AuthScreen = .welcome
    @Published private(set) var currentUserEmail: String?

    init() {
        loadFromStorage()
    }

    private func loadFromStorage() {
        if AuthStorage.isLoggedIn {
            currentUserEmail = AuthStorage.userEmail
            currentScreen = .authenticated
        } else {
            currentScreen = .welcome
        }
    }

    func showLogin() {
        currentScreen = .login
    }

    func showWelcome() {
        currentScreen = .welcome
    }

    private func applyAuthSuccess(_ response: AuthLoginResponse) {
        AuthStorage.isLoggedIn = true
        AuthStorage.userEmail = response.user.email
        AuthStorage.authToken = response.token
        if let first = response.businesses.first {
            AuthStorage.currentBusinessSlug = first.slug
        }
        currentUserEmail = AuthStorage.userEmail
        currentScreen = .authenticated
    }

    /// Connexion email/mot de passe. POST /api/auth/login.
    func login(email: String, password: String) async throws {
        guard !email.isEmpty else { throw AuthError.invalidCredentials }
        do {
            let response: AuthLoginResponse = try await APIClient.shared.request(.authLogin(email: email, password: password))
            applyAuthSuccess(response)
        } catch APIError.noAccountInLogiciel {
            throw AuthError.noAccountInLogiciel
        } catch APIError.unauthorized {
            throw AuthError.invalidCredentials
        } catch APIError.network {
            throw AuthError.networkError
        } catch {
            throw AuthError.networkError
        }
    }

    /// Connexion Apple. POST /api/auth/apple avec idToken (JWT). L’app envoie credential.identityToken.
    func loginWithApple(idToken: String, name: String?, email: String?) async throws {
        do {
            let response: AuthLoginResponse = try await APIClient.shared.request(.authApple(idToken: idToken, name: name, email: email))
            AuthStorage.authProvider = .apple
            applyAuthSuccess(response)
            currentUserEmail = response.user.email ?? email ?? "Compte Apple"
        } catch APIError.noAccountInLogiciel {
            throw AuthError.noAccountInLogiciel
        } catch APIError.unauthorized {
            throw AuthError.noAccountInLogiciel
        } catch APIError.network {
            throw AuthError.networkError
        } catch {
            throw AuthError.networkError
        }
    }

    /// Connexion Google. POST /api/auth/google avec idToken. À brancher quand SDK Google est intégré.
    func loginWithGoogle(idToken: String) async throws {
        let response: AuthLoginResponse = try await APIClient.shared.request(.authGoogle(idToken: idToken))
        AuthStorage.authProvider = .google
        applyAuthSuccess(response)
    }

    func logout() {
        AuthStorage.clearSession()
        currentUserEmail = nil
        currentScreen = .welcome
    }
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case networkError
    case notImplemented
    case noAccountInLogiciel

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Email ou mot de passe incorrect."
        case .networkError: return "Erreur réseau. Réessayez."
        case .notImplemented: return "Connexion Google bientôt disponible."
        case .noAccountInLogiciel: return "Aucun compte associé. Créez d’abord votre compte sur myfidpass.fr."
        }
    }
}
