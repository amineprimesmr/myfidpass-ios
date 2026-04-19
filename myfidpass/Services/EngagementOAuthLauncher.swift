//
//  EngagementOAuthLauncher.swift
//  myfidpass
//
//  OAuth Meta / YouTube / TikTok — partagé entre Profil et SocialMetricsEngagementSection.
//

import AuthenticationServices
import Foundation
import UIKit

enum EngagementOAuthLauncher {
    enum Outcome {
        case success
        case failure(String)
        case cancelled
    }

    static func parseCallback(_ callbackURL: URL) -> Outcome {
        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let dict = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        if let err = dict["error"], !err.isEmpty {
            return .failure(Self.messageForOAuthErrorCode(err))
        }
        if dict["success"] == "1" {
            return .success
        }
        return .failure("Réponse de connexion inattendue.")
    }

    /// Messages lisibles pour les codes courts renvoyés par l’API (évite URLs trop longues dans le redirect).
    private static func messageForOAuthErrorCode(_ code: String) -> String {
        switch code {
        case "google_api_quota":
            return "Quota Google atteint (trop de requêtes). Réessayez plus tard ou augmentez les quotas des APIs « Google Business » dans Google Cloud."
        case "google_api_permission":
            return "Google a refusé l’accès. Vérifiez le compte connecté et les autorisations pour ce commerce."
        case "google_api_error":
            return "Erreur Google lors de la connexion. Réessayez plus tard."
        case "timeout":
            return "Délai dépassé. Vérifiez la connexion et réessayez."
        case "callback_failed":
            return "Erreur serveur lors de la connexion. Réessayez."
        case "save_failed":
            return "Impossible d’enregistrer la connexion. Réessayez."
        default:
            return "Connexion : \(code)"
        }
    }

    static func connectMeta() async -> Outcome {
        await runOAuth { .dashboardSocialOAuthMetaStart(slug: $0) }
    }

    static func connectYouTube() async -> Outcome {
        await runOAuth { .dashboardSocialOAuthGoogleYoutubeStart(slug: $0) }
    }

    /// Avis Google — Google Business Profile (données propriétaire, pas seulement le Place ID public).
    static func connectGoogleBusiness() async -> Outcome {
        await runOAuth { .dashboardSocialOAuthGoogleBusinessStart(slug: $0) }
    }

    static func connectTikTok() async -> Outcome {
        await runOAuth { .dashboardSocialOAuthTiktokStart(slug: $0) }
    }

    private static func runOAuth(_ makeEndpoint: (String) -> APIEndpoint) async -> Outcome {
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            return .failure("Commerce non chargé.")
        }
        do {
            let res: MetaOAuthStartResponse = try await APIClient.shared.request(makeEndpoint(slug))
            guard let authURL = URL(string: res.authUrl) else {
                return .failure("Lien de connexion invalide.")
            }
            let callbackURL = try await MetaOAuthWebAuth.run(url: authURL)
            return parseCallback(callbackURL)
        } catch {
            let ns = error as NSError
            if ns.domain.contains("AuthenticationServices"), ns.code == 1 {
                return .cancelled
            }
            return .failure("Connexion impossible. Réessayez.")
        }
    }
}

// MARK: - ASWebAuthenticationSession (schéma myfidpass)

private enum MetaOAuthWebAuth {
    static func run(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            Task { @MainActor in
                let lock = NSLock()
                var didResume = false
                func finish(_ action: () -> Void) {
                    lock.lock()
                    defer { lock.unlock() }
                    guard !didResume else { return }
                    didResume = true
                    action()
                }
                let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "myfidpass") { callbackURL, error in
                    if let error = error {
                        finish { continuation.resume(throwing: error) }
                        return
                    }
                    guard let callbackURL else {
                        finish { continuation.resume(throwing: NSError(domain: "MetaOAuth", code: -1)) }
                        return
                    }
                    finish { continuation.resume(returning: callbackURL) }
                }
                session.presentationContextProvider = MetaOAuthAnchor.shared
                session.prefersEphemeralWebBrowserSession = false
                guard session.start() else {
                    finish { continuation.resume(throwing: NSError(domain: "MetaOAuth", code: -2)) }
                    return
                }
            }
        }
    }
}

private final class MetaOAuthAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = MetaOAuthAnchor()

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
                if let w = scenes.flatMap(\.windows).first(where: { !$0.isHidden }) { return w }
                preconditionFailure("MyFidpass: aucune fenêtre pour OAuth.")
            }
        }
        if Thread.isMainThread {
            return anchor()
        }
        return DispatchQueue.main.sync(execute: anchor)
    }
}
