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

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL invalide."
        case .noData: return "Réponse vide du serveur."
        case .decoding(let e): return "Données invalides: \(e.localizedDescription)"
        case .server(let code, let msg): return msg ?? "Erreur serveur (\(code))."
        case .network(let e): return "Réseau: \(e.localizedDescription)"
        case .unauthorized: return "Session expirée. Reconnectez-vous."
        case .notFound: return "Ressource introuvable."
        case .noAccountInLogiciel: return "Aucun compte associé. Créez d’abord votre compte sur myfidpass.fr."
        }
    }
}
