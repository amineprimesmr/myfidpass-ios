//
//  APIClient.swift
//  myfidpass
//
//  Client HTTP pour l’API du logiciel. Production-ready avec gestion d’erreurs.
//

import Foundation

final class APIClient {
    static let shared = APIClient()
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    /// Token d’authentification (Bearer). Nil = non connecté.
    var authToken: String? {
        get { AuthStorage.authToken }
        set { AuthStorage.authToken = newValue }
    }

    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type = T.self
    ) async throws -> T {
        var request = try endpoint.urlRequest(base: APIConfig.baseURL, encoder: encoder)
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        switch http.statusCode {
        case 200...299:
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            guard !data.isEmpty else { throw APIError.noData }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decoding(error)
            }
        case 401:
            AuthStorage.authToken = nil
            throw APIError.unauthorized
        case 404:
            if endpoint.isAuth {
                throw APIError.noAccountInLogiciel
            }
            throw APIError.notFound
        default:
            let message = (try? decoder.decode(APIErrorMessage.self, from: data))?.error
            throw APIError.server(statusCode: http.statusCode, message: message)
        }
    }

    /// Récupère le body brut (ex. fichier .pkpass pour Apple Wallet). Pas de décodage JSON.
    func requestData(_ endpoint: APIEndpoint) async throws -> Data {
        var request = try endpoint.urlRequest(base: APIConfig.baseURL, encoder: encoder)
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if endpoint.method == "POST" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            AuthStorage.authToken = nil
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        default:
            let message = (try? decoder.decode(APIErrorMessage.self, from: data))?.error
            throw APIError.server(statusCode: http.statusCode, message: message)
        }
    }
}

private struct APIErrorMessage: Decodable {
    let error: String?
}

/// Pour les endpoints qui ne renvoient pas de body (ex. 204 No Content).
struct EmptyResponse: Decodable {}
