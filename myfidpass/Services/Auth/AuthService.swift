//
//  AuthService.swift
//  myfidpass
//
//  Connexion via l’API MyFidpass (login, Apple, Google). Inscription native dans l’app.
//

import Foundation
import Combine
import AuthenticationServices
import UIKit

enum AuthScreen: Equatable {
    case welcome
    case login
    case authenticated
}

@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published private(set) var currentScreen: AuthScreen = .welcome
    @Published private(set) var currentUserEmail: String?
    @Published private(set) var businesses: [BusinessDTO] = []
    /// Si vrai au prochain affichage de `LoginView`, l’onglet « Inscription » est présélectionné (consommé par `consumeLoginOpensInRegisterMode()`).
    private var loginOpensInRegisterMode = false

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
        loginOpensInRegisterMode = false
        currentScreen = .login
    }

    /// Inscription : même écran que la connexion, mode « Inscription » (Guideline 4 — pas de Safari pour créer un compte).
    func showSignUp() {
        loginOpensInRegisterMode = true
        currentScreen = .login
    }

    @discardableResult
    func consumeLoginOpensInRegisterMode() -> Bool {
        let v = loginOpensInRegisterMode
        loginOpensInRegisterMode = false
        return v
    }

    func showWelcome() {
        currentScreen = .welcome
    }

    /// Recharge la liste des commerces (ex. au retour de l’app).
    func refreshBusinessesIfNeeded() async {
        guard AuthStorage.isLoggedIn, APIClient.shared.authToken != nil else { return }
        do {
            let me: AuthMeResponse = try await APIClient.shared.request(.authMe)
            businesses = me.businesses
            if let saved = AuthStorage.currentBusinessSlug,
               businesses.contains(where: { $0.slug == saved }) {
                return
            }
            AuthStorage.currentBusinessSlug = businesses.first?.slug
        } catch {}
    }

    private func applyAuthSuccess(_ response: AuthLoginResponse) {
        AuthStorage.isLoggedIn = true
        AuthStorage.userEmail = response.user.email
        AuthStorage.authToken = response.token
        businesses = response.businesses
        if let saved = AuthStorage.currentBusinessSlug,
           response.businesses.contains(where: { $0.slug == saved }) {
            // conserve le commerce déjà choisi
        } else if let first = response.businesses.first {
            AuthStorage.currentBusinessSlug = first.slug
        } else {
            AuthStorage.currentBusinessSlug = nil
        }
        currentUserEmail = AuthStorage.userEmail
        currentScreen = .authenticated
    }

    /// Change le commerce actif (multi-cartes).
    func selectBusiness(slug: String) {
        guard businesses.contains(where: { $0.slug == slug }) else { return }
        ScanFlowSettingsCache.clearAll()
        AuthStorage.currentBusinessSlug = slug
    }

    /// Inscription native — alignée sur POST /api/auth/register (optionnel : lieu Google → 1er commerce créé côté API).
    func register(
        email: String,
        password: String,
        name: String?,
        googlePlaceId: String? = nil,
        establishmentName: String? = nil
    ) async throws {
        guard !email.isEmpty, password.count >= 8 else { throw AuthError.invalidCredentials }
        do {
            let response: AuthLoginResponse = try await APIClient.shared.request(
                .authRegister(
                    email: email,
                    password: password,
                    name: name,
                    googlePlaceId: googlePlaceId,
                    establishmentName: establishmentName
                )
            )
            applyAuthSuccess(response)
        } catch let e as APIError {
            if case .server(let code, _) = e, code == 409 {
                throw AuthError.emailAlreadyUsed
            }
            if case .unauthorized = e {
                throw AuthError.invalidCredentials
            }
            throw AuthError.networkError
        } catch {
            throw AuthError.networkError
        }
    }

    /// Demande de lien de réinitialisation (email transactionnel).
    func forgotPassword(email: String) async throws {
        let emailNorm = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !emailNorm.isEmpty else { throw AuthError.invalidCredentials }
        _ = try await APIClient.shared.request(.authForgotPassword(email: emailNorm)) as ForgotPasswordAPIResponse
    }

    /// Connexion email/mot de passe. POST /api/auth/login.
    func login(email: String, password: String) async throws {
        let emailNorm = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !emailNorm.isEmpty else { throw AuthError.invalidCredentials }
        do {
            let response: AuthLoginResponse = try await APIClient.shared.request(.authLogin(email: emailNorm, password: password))
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
    func loginWithApple(idToken: String, name: String?, email: String?, appleUserIdentifier: String? = nil) async throws {
        do {
            let response: AuthLoginResponse = try await APIClient.shared.request(.authApple(idToken: idToken, name: name, email: email))
            AuthStorage.authProvider = .apple
            if let uid = appleUserIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines), !uid.isEmpty {
                AuthStorage.appleUserIdentifier = uid
            }
            applyAuthSuccess(response)
            currentUserEmail = response.user.email ?? email ?? "Compte Apple"
        } catch APIError.noAccountInLogiciel {
            throw AuthError.noAccountInLogiciel
        } catch APIError.unauthorized {
            throw AuthError.networkError
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
            let lock = NSLock()
            var didResume = false
            func finish(_ action: () -> Void) {
                lock.lock()
                defer { lock.unlock() }
                guard !didResume else { return }
                didResume = true
                action()
            }
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "myfidpass"
            ) { callbackURL, error in
                if let error = error {
                    finish { continuation.resume(throwing: error) }
                    return
                }
                guard let url = callbackURL else {
                    finish { continuation.resume(throwing: AuthError.networkError) }
                    return
                }
                finish { continuation.resume(returning: url) }
            }
            session.presentationContextProvider = self
            // Session d’auth dédiée (feuille in-app) — évite l’ouverture du navigateur externe quand c’est supporté.
            session.prefersEphemeralWebBrowserSession = true
            guard session.start() else {
                finish { continuation.resume(throwing: AuthError.networkError) }
                return
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
        Task { await HomeScanLiveActivityController.end() }
        AuthenticatedMediaLoader.clearMemoryCache()
        CardLogoStorage.removeAllLocalCardAssets()
        CardPreviewDisplaySnapshotStore.clearAllSnapshots()
        AuthStorage.clearSession()
        currentUserEmail = nil
        businesses = []
        currentScreen = .welcome
    }

    /// Supprime définitivement le compte (appel API + déconnexion).
    func deleteAccount() async throws {
        _ = try await APIClient.shared.request(APIEndpoint.authDeleteAccount) as EmptyResponse
        logout()
    }
}

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        func anchor() -> ASPresentationAnchor {
            MainActor.assumeIsolated {
                let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                func activationRank(_ state: UIScene.ActivationState) -> Int {
                    switch state {
                    case .foregroundActive: return 0
                    case .foregroundInactive: return 1
                    case .background: return 2
                    case .unattached: return 3
                    @unknown default: return 4
                    }
                }
                let ordered = scenes.sorted { activationRank($0.activationState) < activationRank($1.activationState) }
                for scene in ordered {
                    if let w = scene.windows.first(where: { $0.isKeyWindow }) { return w }
                }
                for scene in ordered {
                    if let w = scene.windows.first(where: { !$0.isHidden && $0.alpha > 0.01 }) { return w }
                }
                if let w = ordered.first?.windows.first { return w }
                assertionFailure("MyFidpass: aucune UIWindow pour ASWebAuthenticationSession")
                if let w = scenes.flatMap(\.windows).first(where: { !$0.isHidden }) { return w }
                preconditionFailure("MyFidpass: aucune fenêtre pour la connexion Google.")
            }
        }
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
    case emailAlreadyUsed

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "E-mail ou mot de passe incorrect. Utilisez « Continuer avec Apple » ou « Continuer avec Google » si votre compte a été créé ainsi, ou réinitialisez votre mot de passe (Paramètres → Tableau de bord web, page ouverte dans l’app)."
        case .networkError: return "Erreur réseau. Réessayez."
        case .notImplemented: return "Connexion Google bientôt disponible."
        case .noAccountInLogiciel:
            return "Aucun compte associé à cet identifiant. Utilisez l’onglet « Inscription » dans l’app pour créer un compte."
        case .emailAlreadyUsed: return "Un compte existe déjà avec cet email."
        }
    }
}
