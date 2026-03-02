//
//  AuthService.swift
//  myfidpass
//
//  Connexion via l’API MyFidpass (login, Apple, Google). Création de compte → myfidpass.fr.
//

import Foundation
import Combine
import AuthenticationServices
import UIKit

enum AppWebURL {
    static let createAccount = URL(string: "https://myfidpass.fr")!
}

enum AuthScreen: Equatable {
    case welcome
    case login
    case authenticated
}

@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published private(set) var currentScreen: AuthScreen = .welcome
    @Published private(set) var currentUserEmail: String?

    override init() {
        super.init()
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

    /// Connexion Google. POST /api/auth/google avec idToken.
    func loginWithGoogle(idToken: String) async throws {
        let response: AuthLoginResponse = try await APIClient.shared.request(.authGoogle(idToken: idToken))
        AuthStorage.authProvider = .google
        applyAuthSuccess(response)
    }

    /// Applique le JWT reçu après le redirect OAuth Google (myfidpass://auth?token=xxx), appelle /me puis met à jour la session.
    func applyTokenFromGoogleOAuthCallback(token: String) async throws {
        AuthStorage.authToken = token
        AuthStorage.authProvider = .google
        let me: AuthMeResponse = try await APIClient.shared.request(.authMe)
        let response = AuthLoginResponse(user: me.user, token: token, businesses: me.businesses)
        applyAuthSuccess(response)
    }

    /// Lance le flux OAuth Google (ouverture navigateur → redirect myfidpass://auth?token=…). En cas d’erreur ou d’annulation, throw.
    func startGoogleOAuthFlow() async throws {
        let config: AuthConfigResponse = try await APIClient.shared.request(.authConfig)
        guard let clientId = config.googleClientId, !clientId.isEmpty else {
            throw AuthError.notImplemented
        }
        let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let redirectUri = "\(base)/api/auth/google-oauth-callback"
        let scope = "openid email profile"
        var comp = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comp.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
        ]
        guard let authURL = comp.url else { throw AuthError.networkError }
        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "myfidpass"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url = callbackURL else {
                    continuation.resume(throwing: AuthError.networkError)
                    return
                }
                continuation.resume(returning: url)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
            // Sur iPad (et simulateur), la fenêtre OAuth peut ne pas s'afficher : après 12 s on annule pour débloquer l'UI.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(12))
                session.cancel()
            }
        }
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        guard let token = components?.queryItems?.first(where: { $0.name == "token" })?.value, !token.isEmpty else {
            let query = components?.query ?? ""
            if query.contains("error=no_email") || query.contains("error=no_account") { throw AuthError.noAccountInLogiciel }
            throw AuthError.networkError
        }
        try await applyTokenFromGoogleOAuthCallback(token: token)
    }

    func logout() {
        AuthStorage.clearSession()
        currentUserEmail = nil
        currentScreen = .welcome
    }
}

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        func anchor() -> ASPresentationAnchor {
            MainActor.assumeIsolated {
                let scenes = UIApplication.shared.connectedScenes
                let windowScenes = scenes.compactMap { $0 as? UIWindowScene }
                for ws in windowScenes {
                    if let w = ws.windows.first(where: { $0.isKeyWindow }) ?? ws.windows.first {
                        return w
                    }
                }
                // Toujours utiliser init(windowScene:) pour éviter la dépréciation iOS 26 de UIWindow().
                if let w = windowScenes.flatMap({ Array($0.windows) }).first {
                    return w
                }
                if let scene = windowScenes.first {
                    return UIWindow(windowScene: scene)
                }
                // Fallback extrême (aucune scène) : requis par le protocole.
                return UIWindow()
            }
        }
        // Ne jamais faire main.sync depuis le main thread → deadlock puis SIGTERM/watchdog.
        if Thread.isMainThread {
            return anchor()
        }
        return DispatchQueue.main.sync(execute: anchor)
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
