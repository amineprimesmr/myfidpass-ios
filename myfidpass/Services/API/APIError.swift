//
//  APIError.swift
//  myfidpass
//
//  Erreurs réseau et API pour une gestion propre en production.
//

import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decoding(Error)
    case server(statusCode: Int, message: String?)
    case network(Error)
    case unauthorized
    case notFound
    case noAccountInLogiciel
    /// HTTP 403 avec `code: subscription_required` — abonnement Stripe inactif côté serveur.
    case subscriptionRequired

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL invalide."
        case .noData: return "Réponse vide du serveur."
        case .decoding(let e): return "Données invalides: \(e.localizedDescription)"
        case .server(let code, let msg): return msg ?? "Erreur serveur (\(code))."
        case .network(let e): return Self.friendlyNetworkDescription(e)
        case .unauthorized: return "Session expirée. Reconnectez-vous."
        case .notFound: return "Ressource introuvable."
        case .subscriptionRequired:
            return "Cette action nécessite une offre active (scan, points, campagnes…). La configuration reste accessible sans abonnement — souscrivez via Stripe depuis le bandeau « Mode découverte »."
        case .noAccountInLogiciel:
            return "Aucun compte associé. Créez un compte via l’onglet « Inscription » dans l’app."
        }
    }

    /// Messages iOS peu parlants (« Application failed to respond », timeouts) → texte actionnable pour le commerçant.
    private static func friendlyNetworkDescription(_ error: Error) -> String {
        let raw = error.localizedDescription
        if raw.localizedCaseInsensitiveContains("failed to respond")
            || raw.localizedCaseInsensitiveContains("couldn’t be completed")
            || raw.localizedCaseInsensitiveContains("could not be completed") {
            return "Le serveur n’a pas répondu à temps (souvent : campagne « tous les inscrits » avec beaucoup de cartes Wallet). Réessayez dans un instant, ou testez d’abord « sur mon iPhone », ou ciblez un segment plus petit."
        }
        if let url = error as? URLError {
            switch url.code {
            case .timedOut:
                return "Délai dépassé : l’envoi des notifications peut prendre plus d’une minute. Réessayez ; si le problème continue, évitez « tous les inscrits » en un seul envoi ou contactez le support."
            case .notConnectedToInternet:
                return "Pas de connexion Internet."
            case .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return "Connexion interrompue ou serveur injoignable. Vérifiez le réseau et réessayez."
            default:
                break
            }
        }
        return "Réseau : \(raw)"
    }
}
