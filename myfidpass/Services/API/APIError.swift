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
    /// HTTP 400 avec `code: missing_establishment` — inscription sans lieu / nom d’établissement (UserDefaults onboarding).
    case missingEstablishment(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL invalide."
        case .noData: return "Réponse vide du serveur."
        case .decoding(let e): return "Données invalides: \(e.localizedDescription)"
        case .server(let code, let msg): return msg ?? "Erreur serveur (\(code))."
        case .network(let e):
            if let url = e as? URLError, url.code == .cancelled { return nil }
            return Self.friendlyNetworkDescription(e)
        case .unauthorized: return "Session expirée. Reconnectez-vous."
        case .notFound: return "Ressource introuvable."
        case .subscriptionRequired:
            return "Cette action nécessite un abonnement actif (ou une période d’essai gratuite encore en cours). Les nouveaux comptes ont 24 h d’accès complet ; après cette période, souscrivez via Stripe depuis l’écran d’abonnement."
        case .noAccountInLogiciel:
            return "Aucun compte associé. Créez un compte via l’onglet « Inscription » dans l’app."
        case .missingEstablishment(let message):
            return message
        }
    }

    /// Messages iOS peu parlants (« Application failed to respond », timeouts) → texte générique (pas lié aux seules notifications).
    private static func friendlyNetworkDescription(_ error: Error) -> String {
        let raw = error.localizedDescription
        if raw.localizedCaseInsensitiveContains("failed to respond")
            || raw.localizedCaseInsensitiveContains("couldn’t be completed")
            || raw.localizedCaseInsensitiveContains("could not be completed") {
            return "Le serveur n’a pas répondu à temps. Réessayez dans un instant. Si c’est une génération IA ou une grosse campagne, l’opération peut être longue : vérifiez aussi votre connexion."
        }
        if let url = error as? URLError {
            switch url.code {
            case .timedOut:
                return "Délai dépassé : le serveur n’a pas fini à temps (génération IA, synchronisation lourde, etc.). Réessayez dans un moment avec une bonne connexion ; si ça bloque souvent, contactez le support."
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

    /// Annulation iOS (nouvelle requête, fermeture d’écran) — ne pas traiter comme une vraie erreur métier.
    static func isBenignRequestCancellation(_ error: Error) -> Bool {
        if let url = error as? URLError, url.code == .cancelled { return true }
        if let api = error as? APIError, case .network(let underlying) = api {
            return (underlying as? URLError)?.code == .cancelled
        }
        return false
    }
}
