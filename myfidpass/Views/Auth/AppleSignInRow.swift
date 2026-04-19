//
//  AppleSignInRow.swift
//  myfidpass
//
//  Continuer avec Apple via `ASAuthorizationAppleIDButton` (type `.continue`) + `ASAuthorizationController` avec
//  `presentationContextProvider` explicite (comportement fiable sur iPad / App Review).
//

import AuthenticationServices
import SwiftUI
import UIKit

struct AppleSignInRow: View {
    @Environment(\.colorScheme) private var colorScheme
    var intent: SocialSignInIntent
    var isLoading: Bool
    /// Si non-nil, remplace le choix automatique clair/sombre (ex. bouton blanc + texte noir sur fond gris).
    var styleOverride: ASAuthorizationAppleIDButton.Style? = nil
    var cornerRadius: CGFloat = 8
    var onAuthorization: (Result<ASAuthorization, Error>) -> Void

    private let minHeight: CGFloat = 52

    var body: some View {
        ZStack {
            AppleSignInUIKitRepresentable(
                intent: intent,
                colorScheme: colorScheme,
                styleOverride: styleOverride,
                cornerRadius: cornerRadius,
                isLoading: isLoading,
                onAuthorization: onAuthorization
            )
            .frame(height: minHeight)
            .frame(maxWidth: .infinity)

            if isLoading {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(UIColor.secondarySystemFill))
                    .frame(height: minHeight)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        ProgressView()
                            .tint(colorScheme == .dark ? .white : .black)
                    }
                    .allowsHitTesting(true)
            }
        }
        .disabled(isLoading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isLoading ? "Connexion Apple en cours" : "Continuer avec Apple")
        .accessibilityHint("Authentification sécurisée avec votre identifiant Apple.")
    }
}

// MARK: - UIKit (présentation explicite pour iPad)

private struct AppleSignInUIKitRepresentable: UIViewRepresentable {
    var intent: SocialSignInIntent
    var colorScheme: ColorScheme
    var styleOverride: ASAuthorizationAppleIDButton.Style?
    var cornerRadius: CGFloat
    var isLoading: Bool
    var onAuthorization: (Result<ASAuthorization, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onAuthorization: onAuthorization)
    }

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        // `.continue` = libellé « Continuer avec Apple » (localisé) — pas « Se connecter avec Apple ».
        let type: ASAuthorizationAppleIDButton.ButtonType = {
            switch intent {
            case .signUp: return .signUp
            case .signIn: return .continue
            }
        }()
        let style: ASAuthorizationAppleIDButton.Style = {
            if let styleOverride { return styleOverride }
            return colorScheme == .dark ? .white : .black
        }()
        let button = ASAuthorizationAppleIDButton(type: type, style: style)
        button.cornerRadius = cornerRadius
        button.addTarget(context.coordinator, action: #selector(Coordinator.didTapButton), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        uiView.isEnabled = !isLoading
        uiView.cornerRadius = cornerRadius
        context.coordinator.onAuthorization = onAuthorization
    }
}

private final class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var onAuthorization: (Result<ASAuthorization, Error>) -> Void

    init(onAuthorization: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.onAuthorization = onAuthorization
    }

    @objc func didTapButton() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        Self.presentationWindow()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        deliver(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        deliver(.failure(error))
    }

    private func deliver(_ result: Result<ASAuthorization, Error>) {
        DispatchQueue.main.async { [onAuthorization] in
            onAuthorization(result)
        }
    }

    /// Même logique que `AuthService` pour Google OAuth : fenêtre active (iPad, multi-fenêtre).
    private static func presentationWindow() -> ASPresentationAnchor {
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
        if let w = scenes.flatMap(\.windows).first(where: { !$0.isHidden }) { return w }
        // Dernier recours (multi-fenêtre / scène pas encore attachée) : ancrage minimal pour `ASAuthorizationController`.
        // Mieux qu’un `fatalError` qui crashe l’app sur iPad / cold start rare.
        if let scene = ordered.first ?? scenes.first {
            let w = UIWindow(windowScene: scene)
            w.windowLevel = .normal
            w.rootViewController = UIViewController()
            w.rootViewController?.view.backgroundColor = .clear
            w.isHidden = false
            w.makeKeyAndVisible()
            return w
        }
        return UIWindow()
    }
}
