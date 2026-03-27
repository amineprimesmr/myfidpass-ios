//
//  APIClient.swift
//  myfidpass
//
//  Client HTTP pour l’API du logiciel. Production-ready avec gestion d’erreurs.
//

import Foundation

final class APIClient {
    static let shared = APIClient()

    /// Délai requête > 60 s pour les endpoints lourds (ex. envoi de notifications côté serveur).
    private static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 90
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession? = nil) {
        self.session = session ?? Self.makeDefaultSession()
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
        for (k, v) in endpoint.supplementalHeaders {
            request.setValue(v, forHTTPHeaderField: k)
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
            if endpoint.is404NoAccountLogin {
                throw APIError.noAccountInLogiciel
            }
            throw APIError.notFound
        default:
            throw APIError.server(statusCode: http.statusCode, message: parseServerErrorMessage(from: data))
        }
    }

    /// Récupère le body brut (ex. fichier .pkpass pour Apple Wallet). Pas de décodage JSON.
    func requestData(_ endpoint: APIEndpoint) async throws -> Data {
        var request = try endpoint.urlRequest(base: APIConfig.baseURL, encoder: encoder)
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        for (k, v) in endpoint.supplementalHeaders {
            request.setValue(v, forHTTPHeaderField: k)
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
            throw APIError.server(statusCode: http.statusCode, message: parseServerErrorMessage(from: data))
        }
    }

    /// Export CSV (membres, transactions) — réponse brute UTF-8.
    func requestCSV(_ endpoint: APIEndpoint) async throws -> Data {
        var request = try endpoint.urlRequest(base: APIConfig.baseURL, encoder: encoder)
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        for (k, v) in endpoint.supplementalHeaders {
            request.setValue(v, forHTTPHeaderField: k)
        }
        request.setValue("text/csv", forHTTPHeaderField: "Accept")

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
        default:
            throw APIError.server(statusCode: http.statusCode, message: parseServerErrorMessage(from: data))
        }
    }

    /// Extrait un message d’erreur API (`error`, `message`) ou un extrait du corps brut (HTML/JSON non standard).
    private func parseServerErrorMessage(from data: Data) -> String? {
        if let m = (try? decoder.decode(APIErrorMessage.self, from: data))?.resolvedMessage, !m.isEmpty {
            return m
        }
        guard let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if raw.count > 900 { return String(raw.prefix(900)) + "…" }
        return raw
    }
}

private struct APIErrorMessage: Decodable {
    let error: String?
    let message: String?

    var resolvedMessage: String? {
        let e = error?.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let e, !e.isEmpty { return e }
        if let m, !m.isEmpty { return m }
        return nil
    }
}

/// Pour les endpoints qui ne renvoient pas de body (ex. 204 No Content).
struct EmptyResponse: Decodable {}
