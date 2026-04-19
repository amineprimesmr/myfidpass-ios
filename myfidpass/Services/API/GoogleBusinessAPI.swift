//
//  GoogleBusinessAPI.swift
//  myfidpass
//
//  Client HTTP dédié aux endpoints /dashboard/google-business/*. Réutilise AuthStorage
//  (Bearer + X-Dashboard-Token), convertit snake_case → camelCase, remonte des erreurs lisibles.
//
//  Pourquoi ne pas tout passer par APIEndpoint ?
//  — On aurait 15+ cases supplémentaires dans un enum déjà volumineux. Ce client isole une
//    « ressource » (Google Business Profile) et peut évoluer indépendamment (Pub/Sub, etc.).
//

import Foundation

actor GoogleBusinessAPI {
    static let shared = GoogleBusinessAPI()

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = e
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = d
    }

    private struct EmptyBody: Encodable {}

    // MARK: - STATUS

    func status(slug: String) async throws -> GoogleBusinessStatus {
        try await get(slug: slug, path: "/status", type: GoogleBusinessStatus.self)
    }

    /// Enregistre (ou ré-enregistre) le topic Pub/Sub auprès de Google pour ce compte Business Profile.
    func registerPubSubNotifications(slug: String) async throws {
        _ = try await post(
            slug: slug,
            path: "/notifications/pubsub/register",
            body: EmptyBody(),
            type: GoogleBusinessOkResponse.self
        )
    }

    // MARK: - REVIEWS

    struct ReviewsQuery {
        var sort: String = "recent"
        var minRating: Int? = nil
        var maxRating: Int? = nil
        var limit: Int = 50
        var offset: Int = 0
        var includeArchived: Bool = false
    }

    func reviews(slug: String, query: ReviewsQuery = .init()) async throws -> GoogleBusinessReviewsResponse {
        var items: [URLQueryItem] = [
            .init(name: "sort", value: query.sort),
            .init(name: "limit", value: String(query.limit)),
            .init(name: "offset", value: String(query.offset)),
        ]
        if let m = query.minRating { items.append(.init(name: "min_rating", value: String(m))) }
        if let m = query.maxRating { items.append(.init(name: "max_rating", value: String(m))) }
        if query.includeArchived { items.append(.init(name: "include_archived", value: "1")) }
        return try await get(slug: slug, path: "/reviews", query: items, type: GoogleBusinessReviewsResponse.self)
    }

    func syncReviews(slug: String) async throws -> GoogleBusinessReviewsSyncResponse {
        try await post(slug: slug, path: "/reviews/sync", body: EmptyBody(), type: GoogleBusinessReviewsSyncResponse.self)
    }

    func markAllReviewsSeen(slug: String) async throws {
        _ = try await post(slug: slug, path: "/reviews/mark-all-seen", body: EmptyBody(), type: GoogleBusinessOkResponse.self)
    }

    func markReviewSeen(slug: String, reviewId: String) async throws {
        _ = try await post(slug: slug, path: "/reviews/\(urlSeg(reviewId))/seen", body: EmptyBody(), type: GoogleBusinessOkResponse.self)
    }

    func starReview(slug: String, reviewId: String, starred: Bool) async throws {
        struct StarBody: Encodable { let starred: Bool }
        _ = try await post(slug: slug, path: "/reviews/\(urlSeg(reviewId))/star", body: StarBody(starred: starred), type: GoogleBusinessOkResponse.self)
    }

    func archiveReview(slug: String, reviewId: String, archived: Bool) async throws {
        struct ArchiveBody: Encodable { let archived: Bool }
        _ = try await post(slug: slug, path: "/reviews/\(urlSeg(reviewId))/archive", body: ArchiveBody(archived: archived), type: GoogleBusinessOkResponse.self)
    }

    func replyToReview(slug: String, reviewId: String, comment: String) async throws -> GoogleBusinessReview? {
        struct ReplyBody: Encodable { let comment: String }
        let r = try await post(slug: slug, path: "/reviews/\(urlSeg(reviewId))/reply", body: ReplyBody(comment: comment), type: GoogleBusinessReviewReplyResponse.self)
        return r.review
    }

    func deleteReviewReply(slug: String, reviewId: String) async throws -> GoogleBusinessReview? {
        let r = try await delete(slug: slug, path: "/reviews/\(urlSeg(reviewId))/reply", type: GoogleBusinessReviewReplyResponse.self)
        return r.review
    }

    func generateReplyAI(slug: String, reviewId: String, tone: String, extraContext: String?) async throws -> GoogleBusinessReviewReplyAIResponse {
        struct AIBody: Encodable { let tone: String; let extraContext: String? }
        return try await post(
            slug: slug,
            path: "/reviews/\(urlSeg(reviewId))/reply-ai",
            body: AIBody(tone: tone, extraContext: extraContext),
            type: GoogleBusinessReviewReplyAIResponse.self
        )
    }

    // MARK: - POSTS

    func listPosts(slug: String) async throws -> [GoogleBusinessPost] {
        try await get(slug: slug, path: "/posts", type: GoogleBusinessPostsResponse.self).posts
    }

    struct CreatePostPayload: Encodable {
        var topicType: String = "STANDARD"
        var languageCode: String = "fr"
        var summary: String
        var mediaUrl: String?
        var ctaType: String?
        var ctaUrl: String?
        var eventTitle: String?
        var eventStart: String?
        var eventEnd: String?
        var offerCoupon: String?
        var offerRedeemOnlineUrl: String?
        var offerTerms: String?
    }

    func createPost(slug: String, payload: CreatePostPayload) async throws -> [GoogleBusinessPost] {
        struct Resp: Decodable { let posts: [GoogleBusinessPost] }
        return try await post(slug: slug, path: "/posts", body: payload, type: Resp.self).posts
    }

    func deletePost(slug: String, postId: String) async throws {
        _ = try await delete(slug: slug, path: "/posts/\(urlSeg(postId))", type: GoogleBusinessOkResponse.self)
    }

    // MARK: - Q & A

    func listQuestions(slug: String) async throws -> [GoogleBusinessQuestion] {
        try await get(slug: slug, path: "/questions", type: GoogleBusinessQuestionsResponse.self).questions
    }

    func answerQuestion(slug: String, questionId: String, text: String) async throws {
        struct AnswerBody: Encodable { let text: String }
        _ = try await post(slug: slug, path: "/questions/\(urlSeg(questionId))/answer", body: AnswerBody(text: text), type: DecodableDynamic.self)
    }

    func deleteAnswer(slug: String, questionId: String) async throws {
        _ = try await delete(slug: slug, path: "/questions/\(urlSeg(questionId))/answer", type: DecodableDynamic.self)
    }

    // MARK: - INSIGHTS

    func insights(slug: String, days: Int = 30, forceFresh: Bool = false) async throws -> GoogleBusinessInsightsResponse {
        var items: [URLQueryItem] = [.init(name: "days", value: String(days))]
        if forceFresh { items.append(.init(name: "fresh", value: "1")) }
        return try await get(slug: slug, path: "/insights", query: items, type: GoogleBusinessInsightsResponse.self)
    }

    // MARK: - LOCATION

    func location(slug: String, forceFresh: Bool = false) async throws -> GoogleBusinessLocationResponse {
        var items: [URLQueryItem] = []
        if forceFresh { items.append(.init(name: "fresh", value: "1")) }
        return try await get(slug: slug, path: "/location", query: items, type: GoogleBusinessLocationResponse.self)
    }

    struct LocationPatchPayload: Encodable {
        var websiteUri: String?
        var regularHours: GoogleBusinessRegularHours?
        var profile: ProfileDescription?

        struct ProfileDescription: Encodable {
            let description: String
        }

        enum CodingKeys: String, CodingKey {
            case websiteUri
            case regularHours
            case profile
        }
    }

    func patchLocation(slug: String, patch: LocationPatchPayload) async throws -> GoogleBusinessLocationInfo {
        struct Resp: Decodable {
            let ok: Bool
            let location: GoogleBusinessLocationInfo
        }
        return try await patchRequest(slug: slug, path: "/location", body: patch, type: Resp.self).location
    }

    // MARK: - MEDIA

    func listMedia(slug: String) async throws -> [GoogleBusinessMedia] {
        try await get(slug: slug, path: "/media", type: GoogleBusinessMediaResponse.self).media
    }

    func createMedia(slug: String, sourceUrl: String, category: String = "ADDITIONAL") async throws -> [GoogleBusinessMedia] {
        struct MediaBody: Encodable { let sourceUrl: String; let category: String }
        struct Resp: Decodable { let media: [GoogleBusinessMedia] }
        return try await post(slug: slug, path: "/media", body: MediaBody(sourceUrl: sourceUrl, category: category), type: Resp.self).media
    }

    func deleteMedia(slug: String, mediaId: String) async throws {
        _ = try await delete(slug: slug, path: "/media/\(urlSeg(mediaId))", type: GoogleBusinessOkResponse.self)
    }

    // MARK: - Internals

    /// Pour décoder les réponses 200 OK au format libre sans les utiliser. Toujours successful.
    private struct DecodableDynamic: Decodable {
        init(from decoder: Decoder) throws { /* accepte n'importe quel JSON */ }
        init() {}
    }

    private func baseURL(slug: String, path: String, query: [URLQueryItem] = []) throws -> URL {
        guard var comps = URLComponents(url: APIConfig.baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        comps.path = "/api/businesses/\(urlSeg(slug))/dashboard/google-business\(path)"
        if !query.isEmpty {
            comps.queryItems = query
        }
        guard let u = comps.url else { throw APIError.invalidURL }
        return u
    }

    private func urlSeg(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func makeRequest(slug: String, method: String, path: String, query: [URLQueryItem] = [], body: Data? = nil) throws -> URLRequest {
        var req = URLRequest(url: try baseURL(slug: slug, path: path, query: query))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let tok = AuthStorage.authToken, !tok.isEmpty {
            req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }
        if let dash = AuthStorage.dashboardToken(forSlug: slug), !dash.isEmpty {
            req.setValue(dash, forHTTPHeaderField: "X-Dashboard-Token")
        }
        req.timeoutInterval = 60
        return req
    }

    private func get<T: Decodable>(slug: String, path: String, query: [URLQueryItem] = [], type: T.Type) async throws -> T {
        let req = try makeRequest(slug: slug, method: "GET", path: path, query: query)
        return try await execute(req, type: type)
    }

    private func post<B: Encodable, T: Decodable>(slug: String, path: String, body: B, type: T.Type) async throws -> T {
        let data = try encoder.encode(body)
        let req = try makeRequest(slug: slug, method: "POST", path: path, body: data)
        return try await execute(req, type: type)
    }

    private func patchRequest<B: Encodable, T: Decodable>(slug: String, path: String, body: B, type: T.Type) async throws -> T {
        let data = try encoder.encode(body)
        let req = try makeRequest(slug: slug, method: "PATCH", path: path, body: data)
        return try await execute(req, type: type)
    }

    private func delete<T: Decodable>(slug: String, path: String, type: T.Type) async throws -> T {
        let req = try makeRequest(slug: slug, method: "DELETE", path: path)
        return try await execute(req, type: type)
    }

    private func execute<T: Decodable>(_ request: URLRequest, type: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.server(statusCode: 0, message: "invalid_response")
        }
        switch http.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decoding(error)
            }
        case 401:
            throw APIError.unauthorized
        case 409:
            throw APIError.server(statusCode: 409, message: parseErrorMessage(from: data) ?? "google_business_not_connected")
        default:
            throw APIError.server(statusCode: http.statusCode, message: parseErrorMessage(from: data))
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        struct E: Decodable { let error: String?; let message: String? }
        if let e = try? JSONDecoder().decode(E.self, from: data) {
            return (e.message?.isEmpty == false ? e.message : e.error) ?? nil
        }
        return String(data: data, encoding: .utf8)
    }
}
