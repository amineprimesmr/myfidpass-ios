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
    /// Refresh token présent mais `POST /auth/refresh` inaccessible (réseau, 5xx) — session locale conservée.
    case sessionRefreshTransient

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL invalide."
        case .noData: return "Réponse vide du serveur."
        case .decoding:
            return "Les données reçues sont incomplètes ou obsolètes. Synchronisez l’application puis réessayez."
        case .server(let code, let msg):
            if code == 404 {
                let trimmed = msg?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !trimmed.isEmpty { return trimmed }
                return "Ce contenu n’est pas disponible pour le moment. Vérifiez le commerce sélectionné ou synchronisez depuis l’écran Compte."
            }
            if let friendly = Self.friendlyServerDescription(statusCode: code, message: msg) {
                return friendly
            }
            return msg ?? "Erreur serveur (\(code))."
        case .network(let e):
            if let url = e as? URLError, url.code == .cancelled { return nil }
            return Self.friendlyNetworkDescription(e)
        case .unauthorized: return "Session expirée. Reconnectez-vous."
        case .notFound:
            return "Ce contenu n’est pas disponible pour le moment. Vérifiez le commerce sélectionné ou synchronisez depuis l’écran Compte."
        case .subscriptionRequired:
            return "Cette action nécessite un abonnement MyFidpass Pro actif. Souscrivez depuis l’écran d’abonnement (App Store ou Stripe)."
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
        case .sessionRefreshTransient:
            return "Connexion instable lors du renouvellement de session. Réessayez dans un instant, ou déconnectez-vous puis reconnectez-vous avec Apple."
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

    /// Texte français pour alertes commerçant (évite « The request timed out. » brut d’iOS).
    static func merchantFacingMessage(from error: Error) -> String? {
        if isBenignRequestCancellation(error) { return nil }
        if let api = error as? APIError, case .subscriptionRequired = api { return nil }
        if let api = error as? APIError, let msg = api.errorDescription, !msg.isEmpty { return msg }
        if let wrapped = error as? APIError, case .network(let underlying) = wrapped {
            return friendlyNetworkDescription(underlying)
        }
        return friendlyNetworkDescription(error)
    }

    /// Messages iOS peu parlants (« Application failed to respond », timeouts) → texte générique (pas lié aux seules notifications).
    private static func friendlyNetworkDescription(_ error: Error) -> String {
        let raw = error.localizedDescription
        if raw.localizedCaseInsensitiveContains("timed out")
            || raw.localizedCaseInsensitiveContains("time out")
            || raw.localizedCaseInsensitiveContains("délai dépassé") {
            return "La connexion a pris trop de temps. Vérifiez le réseau puis réessayez."
        }
        if raw.localizedCaseInsensitiveContains("failed to respond")
            || raw.localizedCaseInsensitiveContains("couldn’t be completed")
            || raw.localizedCaseInsensitiveContains("could not be completed") {
            return "Le serveur n’a pas répondu à temps. Réessayez dans un instant. Si c’est une génération IA ou une grosse campagne, l’opération peut être longue : vérifiez aussi votre connexion."
        }
        if let url = error as? URLError {
            let custom = (url.userInfo[NSLocalizedDescriptionKey] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !custom.isEmpty,
               !custom.localizedCaseInsensitiveContains("couldn"),
               !custom.localizedCaseInsensitiveContains("failed to respond") {
                return custom
            }
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

    /// 502/503/504 Railway ou proxy (« Application failed to respond ») — réessai possible.
    static func isTransientInfrastructureFailure(_ error: Error) -> Bool {
        if isBenignRequestCancellation(error) { return false }
        if let api = error as? APIError {
            switch api {
            case .sessionRefreshTransient, .network:
                return true
            case .server(let code, let msg):
                if [502, 503, 504].contains(code) { return true }
                let raw = msg?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return raw.localizedCaseInsensitiveContains("failed to respond")
                    || raw.localizedCaseInsensitiveContains("bad gateway")
                    || raw.localizedCaseInsensitiveContains("service unavailable")
            default:
                return false
            }
        }
        if let url = error as? URLError {
            switch url.code {
            case .timedOut, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }
        return false
    }

    /// Texte lisible pour pannes infra (Railway 502, etc.) — pas le message brut anglais du proxy.
    private static func friendlyServerDescription(statusCode: Int, message: String?) -> String? {
        let raw = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isGateway = [502, 503, 504].contains(statusCode)
        if isGateway
            || raw.localizedCaseInsensitiveContains("failed to respond")
            || raw.localizedCaseInsensitiveContains("bad gateway")
            || raw.localizedCaseInsensitiveContains("service unavailable") {
            return "Le serveur MyFidpass est momentanément indisponible. Attendez quelques secondes puis réessayez le scan."
        }
        return nil
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
