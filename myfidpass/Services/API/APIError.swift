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
    /// HTTP 403 avec `code: business_quota_reached` — quota multi-commerce atteint.
    case businessQuotaReached
    /// HTTP 400 avec `code: missing_establishment` — inscription sans lieu / nom d’établissement (UserDefaults onboarding).
    case missingEstablishment(String)
    /// HTTP 409 avec `code: business_place_already_linked` — ce commerce est déjà rattaché à un autre compte.
    case businessPlaceAlreadyLinked(String)
    /// HTTP 422 avec `code: notification_icon_required` — envoi campagne sans icône notif personnalisée.
    case notificationIconRequired(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL invalide."
        case .noData: return "Réponse vide du serveur."
        case .decoding:
            return "Les données reçues sont incomplètes ou obsolètes. Synchronisez l’application puis réessayez."
        case .server(let code, let msg):
            // Ne jamais exposer les libellés bruts du backend pour les 404 (ex. « Ressource introuvable »).
            if code == 404 {
                return "Ce contenu n’est pas disponible pour le moment. Vérifiez le commerce sélectionné ou synchronisez depuis l’écran Compte."
            }
            return msg ?? "Erreur serveur (\(code))."
        case .network(let e):
            if let url = e as? URLError, url.code == .cancelled { return nil }
            return Self.friendlyNetworkDescription(e)
        case .unauthorized: return "Session expirée. Reconnectez-vous."
        case .notFound:
            return "Ce contenu n’est pas disponible pour le moment. Vérifiez le commerce sélectionné ou synchronisez depuis l’écran Compte."
        case .subscriptionRequired:
            return "Cette action nécessite un abonnement actif (ou une période d’essai gratuite encore en cours). Les nouveaux comptes ont 24 h d’accès complet ; après cette période, souscrivez via Stripe depuis l’écran d’abonnement."
        case .businessQuotaReached:
            return "Vous avez atteint la limite de commerces autorisés par votre formule actuelle. Passez à l’offre supérieure pour ajouter un commerce."
        case .noAccountInLogiciel:
            return "Aucun compte associé. Créez un compte via l’onglet « Inscription » dans l’app."
        case .missingEstablishment(let message):
            return message
        case .businessPlaceAlreadyLinked(let message):
            return message
        case .notificationIconRequired(let message):
            return message
        }
    }

    /// Réponses HTTP 404 (JSON → `server(404,…)`), ou ancien jeton `notFound` si encore présent.
    var isHTTPResourceMissing: Bool {
        switch self {
        case .notFound: return true
        case .server(let code, _): return code == 404
        default: return false
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
        return "Une erreur réseau est survenue. Vérifiez la connexion puis réessayez."
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
