//
//  APIClient.swift
//  myfidpass
//
//  Client HTTP pour l’API du logiciel. Production-ready avec gestion d’erreurs.
//

import Foundation

/// Une seule rotation refresh à la fois. Sinon : deux 401 parallèles envoient le même refresh token ;
/// le serveur invalide le 1er, le 2e reçoit 401 et l’app effaçait tous les tokens (faux « session expirée »).
/// `actor` : pas de `NSLock` dans un contexte `async` (warnings Swift 6) ; pas de `===` sur `Task` (struct).
private actor RefreshTokenSerialGate {
    private var inFlight: Task<String?, Never>?

    func run(operation: @escaping @Sendable () async -> String?) async -> String? {
        if let existing = inFlight {
            return await existing.value
        }
        let task = Task { await operation() }
        inFlight = task
        let result = await task.value
        inFlight = nil
        return result
    }
}

/// Déduplique les requêtes HTTP idempotentes identiques en cours (même méthode+URL+headers utiles).
/// Réduit les rafales au retour/focus quand plusieurs vues déclenchent le même GET en parallèle.
private actor RequestInFlightCoalescer {
    private var inFlight: [String: Task<(Data, URLResponse), Error>] = [:]

    func run(
        key: String,
        operation: @escaping @Sendable () async throws -> (Data, URLResponse)
    ) async throws -> (Data, URLResponse) {
        if let existing = inFlight[key] {
            return try await existing.value
        }
        let task = Task { try await operation() }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        return try await task.value
    }
}

private enum JWTAccessExpiry {
    /// Champ `exp` du JWT (secondes depuis 1970), sans vérifier la signature — uniquement pour anticiper le refresh.
    static func expirationDate(of jwt: String) -> Date? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
        let rem = payload.count % 4
        if rem > 0 { payload.append(String(repeating: "=", count: 4 - rem)) }
        payload = payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let seconds: TimeInterval?
        if let i = json["exp"] as? Int { seconds = TimeInterval(i) }
        else if let d = json["exp"] as? Double { seconds = d }
        else { seconds = nil }
        guard let s = seconds else { return nil }
        return Date(timeIntervalSince1970: s)
    }
}

struct GooglePlaceAvailabilityResult: Sendable {
    let placeAvailable: Bool
    /// Texte d’erreur API lorsque `placeAvailable` est false.
    let userFacingMessage: String?
}

final class APIClient: @unchecked Sendable {
    static let shared = APIClient()

    private let refreshGate = RefreshTokenSerialGate()
    private let requestCoalescer = RequestInFlightCoalescer()
    /// Évite deux rotations refresh rapprochées (app native + WKWebView paiement) qui invalident l’autre session.
    private var lastRefreshSuccessAt: Date?
    private let minRefreshInterval: TimeInterval = 2.5

    /// Session : plafond large ; les timeouts fins sont sur `URLRequest` (ex. 300 s pour POST campagne).
    private static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 360
        return URLSession(configuration: config)
    }

    private let session: URLSession

    /// `JSONDecoder` n’est pas thread-safe : un décodeur partagé + requêtes `async let` parallèles
    /// peut corrompre le tas (`freed pointer was not the last allocation`). Un décodeur par appel.
    private static func makeJSONDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    /// Même principe que le décodeur si plusieurs encodages concurrents.
    private static func makeJSONEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }

    init(session: URLSession? = nil) {
        self.session = session ?? Self.makeDefaultSession()
    }

    /// Token d’authentification (Bearer). Nil = non connecté.
    var authToken: String? {
        get { AuthStorage.authToken }
        set { AuthStorage.authToken = newValue }
    }

    /// Exécute la requête réseau avec coalescing pour les GET (même endpoint + même contexte auth).
    private func performNetworkData(for request: URLRequest) async throws -> (Data, URLResponse) {
        let method = request.httpMethod?.uppercased() ?? "GET"
        guard method == "GET", request.httpBody == nil else {
            return try await session.data(for: request)
        }
        let key = requestCoalescingKey(for: request)
        return try await requestCoalescer.run(key: key) { [session] in
            try await session.data(for: request)
        }
    }

    /// Clé de coalescing: méthode + URL + en-têtes qui changent la réponse (`Authorization`, dashboard token, accept).
    private func requestCoalescingKey(for request: URLRequest) -> String {
        let method = request.httpMethod?.uppercased() ?? "GET"
        let url = request.url?.absoluteString ?? ""
        let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
        let dashboard = request.value(forHTTPHeaderField: "X-Dashboard-Token") ?? ""
        let accept = request.value(forHTTPHeaderField: "Accept") ?? ""
        return [method, url, auth, dashboard, accept].joined(separator: "|")
    }

    /// True si le JWT access en mémoire n’est pas expiré (marge 30 s) — évite logout brutal sur refresh concurrent.
    private static func accessTokenStillWithinValidityWindow() -> Bool {
        guard let token = AuthStorage.authToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty,
              let exp = JWTAccessExpiry.expirationDate(of: token) else { return false }
        return exp.timeIntervalSinceNow > 30
    }

    /// Efface les jetons et notifie l’app : `AuthService` appelle `logout()` (sinon `isLoggedIn` reste vrai alors que le serveur a refusé la session — ex. reset BDD / compte supprimé).
    private func terminateSessionAfterAuthFailure() {
        AuthStorage.authToken = nil
        AuthStorage.refreshToken = nil
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .myfidpassSessionInvalidated, object: nil)
        }
    }

    private func terminateSessionAfterAuthFailureIfAppropriate() {
        if Self.accessTokenStillWithinValidityWindow() { return }
        terminateSessionAfterAuthFailure()
    }

    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type = T.self
    ) async throws -> T {
        if !endpoint.skipsClientSessionBootstrap {
            await ensureValidAccessToken()
        }
        var request = try endpoint.urlRequest(base: APIConfig.baseURL, encoder: Self.makeJSONEncoder())
        if !endpoint.skipsClientSessionBootstrap, let token = authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        for (k, v) in endpoint.supplementalHeaders {
            request.setValue(v, forHTTPHeaderField: k)
        }
        applyDashboardTokenHeaderIfNeeded(to: &request, endpoint: endpoint)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await performNetworkData(for: request)
        } catch {
            throw APIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        switch http.statusCode {
        case 200...299:
            if let empty = EmptyResponse() as? T {
                return empty
            }
            guard !data.isEmpty else { throw APIError.noData }
            do {
                return try Self.makeJSONDecoder().decode(T.self, from: data)
            } catch {
                throw APIError.decoding(error)
            }
        case 401:
            // Tenter un refresh avant de déconnecter
            if let newToken = await tryRefreshToken() {
                var retryRequest = try endpoint.urlRequest(base: APIConfig.baseURL, encoder: Self.makeJSONEncoder())
                if !endpoint.skipsClientSessionBootstrap {
                    retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                }
                for (k, v) in endpoint.supplementalHeaders {
                    retryRequest.setValue(v, forHTTPHeaderField: k)
                }
                applyDashboardTokenHeaderIfNeeded(to: &retryRequest, endpoint: endpoint)
                retryRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                retryRequest.setValue("application/json", forHTTPHeaderField: "Accept")
                let (retryData, retryResponse): (Data, URLResponse)
                do {
                    (retryData, retryResponse) = try await performNetworkData(for: retryRequest)
                } catch {
                    throw APIError.network(error)
                }
                guard let retryHttp = retryResponse as? HTTPURLResponse else { throw APIError.noData }
                if retryHttp.statusCode == 401 {
                    if !endpoint.skipsClientSessionBootstrap {
                        terminateSessionAfterAuthFailureIfAppropriate()
                    }
                    throw APIError.unauthorized
                }
                if retryHttp.statusCode >= 200, retryHttp.statusCode < 300 {
                    if let empty = EmptyResponse() as? T { return empty }
                    guard !retryData.isEmpty else { throw APIError.noData }
                    return try Self.makeJSONDecoder().decode(T.self, from: retryData)
                }
                throw Self.resolveNonSuccessHTTPError(statusCode: retryHttp.statusCode, data: retryData)
            }
            // Refresh impossible : ne pas effacer la session si l’access JWT est encore dans sa fenêtre de validité
            // (course native ↔ WebView paiement qui a pu consommer l’ancien refresh).
            if !endpoint.skipsClientSessionBootstrap,
               AuthStorage.authToken != nil || AuthStorage.refreshToken != nil {
                terminateSessionAfterAuthFailureIfAppropriate()
            }
            throw APIError.unauthorized
        case 404:
            if endpoint.is404NoAccountLogin {
                throw APIError.noAccountInLogiciel
            }
            let msg404 = Self.parseServerErrorMessage(from: data)
            throw APIError.server(statusCode: 404, message: msg404)
        default:
            throw Self.resolveNonSuccessHTTPError(statusCode: http.statusCode, data: data)
        }
    }

    /// 403 abonnement ou erreur serveur classique.
    private static func resolveNonSuccessHTTPError(statusCode: Int, data: Data) -> APIError {
        if statusCode == 403, isSubscriptionRequiredPayload(data) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .myfidpassSubscriptionRequiredByAPI, object: nil)
            }
            return APIError.subscriptionRequired
        }
        if statusCode == 403, isBusinessQuotaReachedPayload(data) {
            return APIError.businessQuotaReached
        }
        if let auth = parseAuthStructuredError(statusCode: statusCode, from: data) {
            return auth
        }
        return APIError.server(statusCode: statusCode, message: Self.parseServerErrorMessage(from: data))
    }

    /// Erreurs métier JSON (`code` + `error`) — ex. inscription téléphone sans établissement.
    private static func parseAuthStructuredError(statusCode: Int, from data: Data) -> APIError? {
        struct Body: Decodable {
            let code: String?
            let error: String?
        }
        guard let b = try? JSONDecoder().decode(Body.self, from: data),
              let raw = b.code?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        let msg = b.error?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw == "missing_establishment" {
            let fallback = "Sélectionnez d’abord votre établissement avant de créer votre compte."
            return .missingEstablishment(msg.isEmpty ? fallback : msg)
        }
        if statusCode == 409, raw == "business_place_already_linked" {
            let fallback = "Ce commerce est déjà utilisé. Connectez-vous au compte existant ou choisissez un autre commerce."
            return .businessPlaceAlreadyLinked(msg.isEmpty ? fallback : msg)
        }
        if raw == "notification_icon_required" {
            let fallback = "Ajoutez une icône de notification (image) dans l’onglet Notifications avant d’envoyer des messages aux clients."
            return .notificationIconRequired(msg.isEmpty ? fallback : msg)
        }
        return nil
    }

    private static func isSubscriptionRequiredPayload(_ data: Data) -> Bool {
        struct Body: Decodable {
            let code: String?
        }
        guard let b = try? Self.makeJSONDecoder().decode(Body.self, from: data) else { return false }
        return b.code == "subscription_required"
    }

    private static func isBusinessQuotaReachedPayload(_ data: Data) -> Bool {
        struct Body: Decodable {
            let code: String?
        }
        guard let b = try? Self.makeJSONDecoder().decode(Body.self, from: data) else { return false }
        return b.code == "business_quota_reached"
    }

    /// Rafraîchit l’access token avant expiration (appelée avant les requêtes authentifiées et au retour au premier plan).
    func ensureValidAccessToken() async {
        guard let refresh = AuthStorage.refreshToken, !refresh.isEmpty else { return }
        guard let token = AuthStorage.authToken, !token.isEmpty else {
            _ = await tryRefreshToken()
            return
        }
        guard let exp = JWTAccessExpiry.expirationDate(of: token) else {
            // Pas de claim `exp` dans le JWT (session sans expiration côté serveur) : ne pas refresh à chaque requête.
            return
        }
        // Marge avant `exp` : trop large → refresh avant chaque requête (dont juste après OAuth).
        // Trop étroite → risque de 401 si l’horloge client/serveur diverge légèrement.
        let leewayBeforeExpiry: TimeInterval = 120
        guard exp.timeIntervalSinceNow < leewayBeforeExpiry else { return }
        _ = await tryRefreshToken()
    }

    /// Tente de renouveler l'access token (sérialisé — une seule rotation à la fois). Retourne le nouveau token ou nil.
    @discardableResult
    func tryRefreshToken() async -> String? {
        await refreshGate.run { await self.exchangeRefreshTokenBody() }
    }

    private func exchangeRefreshTokenBody() async -> String? {
        if let last = lastRefreshSuccessAt,
           Date().timeIntervalSince(last) < minRefreshInterval,
           let existing = AuthStorage.authToken?.trimmingCharacters(in: .whitespacesAndNewlines),
           !existing.isEmpty {
            return existing
        }
        guard let refreshToken = AuthStorage.refreshToken, !refreshToken.isEmpty else { return nil }
        do {
            var req = try APIEndpoint.authRefresh(refreshToken: refreshToken)
                .urlRequest(base: APIConfig.baseURL, encoder: Self.makeJSONEncoder())
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else { return nil }
            guard http.statusCode == 200 else {
                if http.statusCode == 401 {
                    // Révoquer seulement le refresh : l’access JWT peut encore être valide (ex. refresh
                    // absent ou invalide en base après migration, double appareil). Effacer aussi l’access
                    // provoquait des requêtes sans Bearer → 401 sur DELETE /api/auth/account, etc.
                    AuthStorage.refreshToken = nil
                } else {
                    AuthStorage.authToken = nil
                    AuthStorage.refreshToken = nil
                }
                return nil
            }
            // Le serveur a déjà invalidé l’ancien refresh : si le décodage échoue, extraire au moins token + refresh.
            if let refreshed = try? Self.makeJSONDecoder().decode(AuthRefreshResponse.self, from: data) {
                Self.applyRefreshedTokens(refreshed, rawData: data)
                lastRefreshSuccessAt = Date()
                return refreshed.token
            }
            guard let recovered = Self.recoverTokensFromRefreshResponseBody(data) else { return nil }
            AuthStorage.authToken = recovered.access
            if let r = recovered.refresh, !r.isEmpty { AuthStorage.refreshToken = r }
            NotificationCenter.default.post(name: .myfidpassAuthTokensUpdated, object: nil)
            lastRefreshSuccessAt = Date()
            return recovered.access
        } catch {
            return nil
        }
    }

    /// Extraction tolérante si la forme JSON évolue (évite client avec refresh révoqué côté serveur mais jetons non sauvés).
    private static func recoverTokensFromRefreshResponseBody(_ data: Data) -> (access: String, refresh: String?)? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let rawAccess = (obj["token"] as? String) ?? (obj["access_token"] as? String)
        let access = rawAccess?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !access.isEmpty else { return nil }
        let rawRt = (obj["refreshToken"] as? String) ?? (obj["refresh_token"] as? String)
        let refresh = rawRt.flatMap { s -> String? in
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        return (access, refresh)
    }

    private static func applyRefreshedTokens(_ refreshed: AuthRefreshResponse, rawData: Data) {
        AuthStorage.authToken = refreshed.token
        if let newRefresh = refreshed.refreshToken, !newRefresh.isEmpty {
            AuthStorage.refreshToken = newRefresh
        } else if let recovered = recoverTokensFromRefreshResponseBody(rawData), let r = recovered.refresh, !r.isEmpty {
            AuthStorage.refreshToken = r
        }
        NotificationCenter.default.post(name: .myfidpassAuthTokensUpdated, object: nil)
        let subStatus = refreshed.subscription?.status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let derivedActive =
            refreshed.hasActiveSubscription == true
            || subStatus == "active"
            || subStatus == "trialing"
            || subStatus == "past_due"
        if refreshed.hasActiveSubscription != nil || !subStatus.isEmpty {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .myfidpassMerchantSubscriptionFromRefresh,
                    object: nil,
                    userInfo: ["hasActive": derivedActive]
                )
            }
        }
    }

    /// Récupère le body brut (ex. fichier .pkpass pour Apple Wallet). Pas de décodage JSON.
    func requestData(_ endpoint: APIEndpoint) async throws -> Data {
        if !endpoint.skipsClientSessionBootstrap {
            await ensureValidAccessToken()
        }
        var request = try endpoint.urlRequest(base: APIConfig.baseURL, encoder: Self.makeJSONEncoder())
        if !endpoint.skipsClientSessionBootstrap, let token = authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        for (k, v) in endpoint.supplementalHeaders {
            request.setValue(v, forHTTPHeaderField: k)
        }
        applyDashboardTokenHeaderIfNeeded(to: &request, endpoint: endpoint)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if endpoint.method == "POST" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await performNetworkData(for: request)
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
            if let newToken = await tryRefreshToken() {
                var retryRequest = try endpoint.urlRequest(base: APIConfig.baseURL, encoder: Self.makeJSONEncoder())
                if !endpoint.skipsClientSessionBootstrap {
                    retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                }
                for (k, v) in endpoint.supplementalHeaders { retryRequest.setValue(v, forHTTPHeaderField: k) }
                applyDashboardTokenHeaderIfNeeded(to: &retryRequest, endpoint: endpoint)
                retryRequest.setValue("application/json", forHTTPHeaderField: "Accept")
                if endpoint.method == "POST" { retryRequest.setValue("application/json", forHTTPHeaderField: "Content-Type") }
                let (retryData, retryResponse) = try await performNetworkData(for: retryRequest)
                guard let retryHttp = retryResponse as? HTTPURLResponse else { throw APIError.noData }
                if retryHttp.statusCode >= 200, retryHttp.statusCode < 300 { return retryData }
                if retryHttp.statusCode == 401 {
                    if !endpoint.skipsClientSessionBootstrap {
                        terminateSessionAfterAuthFailureIfAppropriate()
                    }
                    throw APIError.unauthorized
                }
                throw APIError.server(statusCode: retryHttp.statusCode, message: Self.parseServerErrorMessage(from: retryData))
            }
            if !endpoint.skipsClientSessionBootstrap,
               AuthStorage.authToken != nil || AuthStorage.refreshToken != nil {
                terminateSessionAfterAuthFailureIfAppropriate()
            }
            throw APIError.unauthorized
        case 404:
            throw APIError.server(statusCode: 404, message: Self.parseServerErrorMessage(from: data))
        default:
            throw APIError.server(statusCode: http.statusCode, message: Self.parseServerErrorMessage(from: data))
        }
    }

    /// Corps + `HTTPURLResponse` pour codes **200…299** (ex. **202 Accepted** avec `job_id`), sans interpréter le JSON.
    func requestSuccessfulDataWithHTTPResponse(_ endpoint: APIEndpoint) async throws -> (Data, HTTPURLResponse) {
        if !endpoint.skipsClientSessionBootstrap {
            await ensureValidAccessToken()
        }
        var request = try endpoint.urlRequest(base: APIConfig.baseURL, encoder: Self.makeJSONEncoder())
        if !endpoint.skipsClientSessionBootstrap, let token = authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        for (k, v) in endpoint.supplementalHeaders {
            request.setValue(v, forHTTPHeaderField: k)
        }
        applyDashboardTokenHeaderIfNeeded(to: &request, endpoint: endpoint)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if endpoint.method == "POST" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await performNetworkData(for: request)
        } catch {
            throw APIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        switch http.statusCode {
        case 200...299:
            return (data, http)
        case 401:
            if let newToken = await tryRefreshToken() {
                var retryRequest = try endpoint.urlRequest(base: APIConfig.baseURL, encoder: Self.makeJSONEncoder())
                if !endpoint.skipsClientSessionBootstrap {
                    retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                }
                for (k, v) in endpoint.supplementalHeaders { retryRequest.setValue(v, forHTTPHeaderField: k) }
                applyDashboardTokenHeaderIfNeeded(to: &retryRequest, endpoint: endpoint)
                retryRequest.setValue("application/json", forHTTPHeaderField: "Accept")
                if endpoint.method == "POST" { retryRequest.setValue("application/json", forHTTPHeaderField: "Content-Type") }
                let (retryData, retryResponse) = try await performNetworkData(for: retryRequest)
                guard let retryHttp = retryResponse as? HTTPURLResponse else { throw APIError.noData }
                if retryHttp.statusCode >= 200, retryHttp.statusCode < 300 { return (retryData, retryHttp) }
                if retryHttp.statusCode == 401 {
                    if !endpoint.skipsClientSessionBootstrap {
                        terminateSessionAfterAuthFailureIfAppropriate()
                    }
                    throw APIError.unauthorized
                }
                throw APIError.server(statusCode: retryHttp.statusCode, message: Self.parseServerErrorMessage(from: retryData))
            }
            if !endpoint.skipsClientSessionBootstrap,
               AuthStorage.authToken != nil || AuthStorage.refreshToken != nil {
                terminateSessionAfterAuthFailureIfAppropriate()
            }
            throw APIError.unauthorized
        case 404:
            throw APIError.server(statusCode: 404, message: Self.parseServerErrorMessage(from: data))
        default:
            throw APIError.server(statusCode: http.statusCode, message: Self.parseServerErrorMessage(from: data))
        }
    }

    /// Export CSV (membres, transactions) — réponse brute UTF-8.
    func requestCSV(_ endpoint: APIEndpoint) async throws -> Data {
        if !endpoint.skipsClientSessionBootstrap {
            await ensureValidAccessToken()
        }
        var request = try endpoint.urlRequest(base: APIConfig.baseURL, encoder: Self.makeJSONEncoder())
        if !endpoint.skipsClientSessionBootstrap, let token = authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        for (k, v) in endpoint.supplementalHeaders {
            request.setValue(v, forHTTPHeaderField: k)
        }
        applyDashboardTokenHeaderIfNeeded(to: &request, endpoint: endpoint)
        request.setValue("text/csv", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await performNetworkData(for: request)
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
            if let newToken = await tryRefreshToken() {
                var retryRequest = try endpoint.urlRequest(base: APIConfig.baseURL, encoder: Self.makeJSONEncoder())
                if !endpoint.skipsClientSessionBootstrap {
                    retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                }
                for (k, v) in endpoint.supplementalHeaders { retryRequest.setValue(v, forHTTPHeaderField: k) }
                applyDashboardTokenHeaderIfNeeded(to: &retryRequest, endpoint: endpoint)
                retryRequest.setValue("text/csv", forHTTPHeaderField: "Accept")
                let (retryData, retryResponse) = try await performNetworkData(for: retryRequest)
                guard let retryHttp = retryResponse as? HTTPURLResponse else { throw APIError.noData }
                if retryHttp.statusCode >= 200, retryHttp.statusCode < 300 { return retryData }
                if retryHttp.statusCode == 401 {
                    if !endpoint.skipsClientSessionBootstrap {
                        terminateSessionAfterAuthFailureIfAppropriate()
                    }
                    throw APIError.unauthorized
                }
                throw APIError.server(statusCode: retryHttp.statusCode, message: Self.parseServerErrorMessage(from: retryData))
            }
            if !endpoint.skipsClientSessionBootstrap,
               AuthStorage.authToken != nil || AuthStorage.refreshToken != nil {
                terminateSessionAfterAuthFailureIfAppropriate()
            }
            throw APIError.unauthorized
        default:
            throw APIError.server(statusCode: http.statusCode, message: Self.parseServerErrorMessage(from: data))
        }
    }

    /// Jeton `dashboard_token` du commerce (réponses login/me) — requis par le backend si le JWT ne matche pas `business.user_id` (ex. refresh corrompu).
    private func applyDashboardTokenHeaderIfNeeded(to request: inout URLRequest, endpoint: APIEndpoint) {
        let path = endpoint.path
        guard path.hasPrefix("/api/businesses/") else { return }
        let prefix = "/api/businesses/"
        let rest = String(path.dropFirst(prefix.count))
        guard let slash = rest.firstIndex(of: "/") else { return }
        var seg = String(rest[..<slash])
        seg = seg.removingPercentEncoding ?? seg
        guard let tok = AuthStorage.dashboardToken(forSlug: seg), !tok.isEmpty else { return }
        request.setValue(tok, forHTTPHeaderField: "X-Dashboard-Token")
    }

    // MARK: - Compte existe ? (check-email / check-identifier)

    /// Lieu Google encore disponible pour une nouvelle inscription (`place_available` dans la réponse JSON).
    func fetchGooglePlaceAvailability(googlePlaceId: String) async throws -> GooglePlaceAvailabilityResult {
        let norm = googlePlaceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !norm.isEmpty else { throw APIError.noData }
        let endpoint = APIEndpoint.authCheckGooglePlace(googlePlaceId: norm)
        var req = try endpoint.urlRequest(base: APIConfig.baseURL, encoder: Self.makeJSONEncoder())
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        applyDashboardTokenHeaderIfNeeded(to: &req, endpoint: endpoint)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await performNetworkData(for: req)
        } catch {
            throw APIError.network(error)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.noData }
        guard (200...299).contains(http.statusCode) else {
            throw Self.resolveNonSuccessHTTPError(statusCode: http.statusCode, data: data)
        }
        guard !data.isEmpty else { throw APIError.noData }
        return try Self.parseGooglePlaceAvailability(from: data)
    }

    /// Vérifie `account_exists` sans `Decodable` strict (évite les échecs si le JSON varie ou si le décodage rejette un type mineur).
    func fetchAccountExistsProbe(identifier: String) async throws -> Bool {
        let norm = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !norm.isEmpty else { throw APIError.noData }
        if norm.contains("@") {
            do {
                return try await fetchAccountExistsPOST(.authCheckEmail(email: norm))
            } catch {
                return try await fetchAccountExistsPOST(.authCheckIdentifier(identifier: norm))
            }
        }
        return try await fetchAccountExistsPOST(.authCheckIdentifier(identifier: norm))
    }

    private func fetchAccountExistsPOST(_ endpoint: APIEndpoint) async throws -> Bool {
        var req = try endpoint.urlRequest(base: APIConfig.baseURL, encoder: Self.makeJSONEncoder())
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        applyDashboardTokenHeaderIfNeeded(to: &req, endpoint: endpoint)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await performNetworkData(for: req)
        } catch {
            throw APIError.network(error)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.noData }
        guard (200...299).contains(http.statusCode) else {
            throw Self.resolveNonSuccessHTTPError(statusCode: http.statusCode, data: data)
        }
        guard !data.isEmpty else { throw APIError.noData }
        return try Self.parseBoolAccountExists(from: data)
    }

    private static func parseGooglePlaceAvailability(from data: Data) throws -> GooglePlaceAvailabilityResult {
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = obj as? [String: Any] else {
            throw APIError.decoding(
                NSError(domain: "myfidpass.googlePlaceAvailability", code: 0, userInfo: [NSLocalizedDescriptionKey: "Réponse JSON inattendue"])
            )
        }
        let raw = dict["place_available"] ?? dict["placeAvailable"]
        let available: Bool
        if let b = raw as? Bool {
            available = b
        } else if let i = raw as? Int {
            available = i != 0
        } else if let n = raw as? NSNumber {
            available = n.boolValue
        } else if let s = raw as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["true", "1", "yes"].contains(t) { available = true }
            else if ["false", "0", "no"].contains(t) { available = false }
            else { available = true }
        } else {
            available = true
        }
        let err = (dict["error"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let msg = (dict["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let userMsg: String?
        if let e = err, !e.isEmpty { userMsg = e }
        else if let m = msg, !m.isEmpty { userMsg = m }
        else { userMsg = nil }
        return GooglePlaceAvailabilityResult(placeAvailable: available, userFacingMessage: userMsg)
    }

    private static func parseBoolAccountExists(from data: Data) throws -> Bool {
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = obj as? [String: Any] else {
            throw APIError.decoding(
                NSError(domain: "myfidpass.accountExists", code: 0, userInfo: [NSLocalizedDescriptionKey: "Réponse JSON inattendue"])
            )
        }
        let raw = dict["account_exists"] ?? dict["accountExists"]
        if let b = raw as? Bool { return b }
        if let i = raw as? Int { return i != 0 }
        if let n = raw as? NSNumber { return n.boolValue }
        if let s = raw as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["true", "1", "yes"].contains(t) { return true }
            if ["false", "0", "no"].contains(t) { return false }
        }
        throw APIError.decoding(
            NSError(domain: "myfidpass.accountExists", code: 1, userInfo: [NSLocalizedDescriptionKey: "Champ account_exists absent ou illisible"])
        )
    }

    /// Extrait un message d’erreur API (`error`, `message`) ou un extrait du corps brut (HTML/JSON non standard).
    private static func parseServerErrorMessage(from data: Data) -> String? {
        if let m = (try? Self.makeJSONDecoder().decode(APIErrorMessage.self, from: data))?.resolvedMessage, !m.isEmpty {
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
        // Préférer `message` (texte lisible) quand les deux sont présents (ex. error = code snake_case).
        if let m, !m.isEmpty { return m }
        if let e, !e.isEmpty { return e }
        return nil
    }
}

/// Pour les endpoints qui ne renvoient pas de body (ex. 204 No Content).
struct EmptyResponse: Decodable {}
