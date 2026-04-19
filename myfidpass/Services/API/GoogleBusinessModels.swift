//
//  GoogleBusinessModels.swift
//  myfidpass
//
//  DTOs pour les endpoints /api/businesses/:slug/dashboard/google-business/*.
//  Nomenclature snake_case (backend Node) convertie automatiquement par `convertFromSnakeCase`.
//

import Foundation

// MARK: - Status / Counts

struct GoogleBusinessStatusCounts: Decodable, Equatable {
    let total: Int
    let unreplied: Int
    let unseen: Int
    let starred: Int
    let negativesUnreplied: Int
    let averageRating: Double?
}

struct GoogleBusinessStatus: Decodable, Equatable {
    let connected: Bool
    let locationPending: Bool
    let locationTitle: String?
    let accountId: String?
    let locationId: String?
    let matchedPlaceId: String?
    /// Avis : notifications quasi instantanées via Pub/Sub (si le serveur est configuré).
    let pubsubLiveNotifications: Bool?
    let pubsubRegisteredAt: String?
    let pubsubLastError: String?
    let counts: GoogleBusinessStatusCounts
}

// MARK: - Reviews

struct GoogleBusinessReview: Decodable, Identifiable, Equatable {
    let reviewId: String
    let locationName: String?
    let rating: Int
    let authorName: String?
    let authorPhotoUrl: String?
    let comment: String?
    let replyComment: String?
    let replyUpdateTime: String?
    let createTime: String?
    let updateTime: String?
    let firstSeenAt: String?
    let starred: Bool
    let archived: Bool
    let seenByMerchant: Bool

    var id: String { reviewId }

    var hasReply: Bool {
        !(replyComment?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var createdDate: Date? {
        guard let s = createTime else { return nil }
        return GoogleBusinessDateParser.parse(s)
    }

    var updatedDate: Date? {
        guard let s = updateTime else { return nil }
        return GoogleBusinessDateParser.parse(s)
    }
}

struct GoogleBusinessReviewsResponse: Decodable {
    let reviews: [GoogleBusinessReview]
    let counts: GoogleBusinessStatusCounts
}

struct GoogleBusinessReviewReplyResponse: Decodable {
    let ok: Bool
    let review: GoogleBusinessReview?
}

struct GoogleBusinessReviewReplyAIResponse: Decodable {
    let ok: Bool
    let reply: String
    let source: String?
}

struct GoogleBusinessReviewsSyncResponse: Decodable {
    let ok: Bool
    let newCount: Int?
    let totalCount: Int?
    let counts: GoogleBusinessStatusCounts?
}

// MARK: - Posts

struct GoogleBusinessPost: Decodable, Identifiable, Equatable {
    let postId: String
    let name: String?
    let topicType: String?
    let summary: String?
    let languageCode: String?
    let mediaUrl: String?
    let ctaType: String?
    let ctaUrl: String?
    let eventTitle: String?
    let eventStart: String?
    let eventEnd: String?
    let offerCoupon: String?
    let offerRedeemOnlineUrl: String?
    let offerTerms: String?
    let state: String?
    let createTime: String?
    let updateTime: String?
    let searchUrl: String?

    var id: String { postId }
    var isLive: Bool { (state ?? "").uppercased() == "LIVE" }
    var topic: TopicKind {
        switch (topicType ?? "").uppercased() {
        case "EVENT": return .event
        case "OFFER": return .offer
        case "ALERT": return .alert
        default: return .standard
        }
    }

    enum TopicKind: String {
        case standard, event, offer, alert
    }
}

struct GoogleBusinessPostsResponse: Decodable {
    let posts: [GoogleBusinessPost]
}

// MARK: - Q & A

struct GoogleBusinessQuestion: Decodable, Identifiable, Equatable {
    let questionId: String
    let name: String?
    let text: String?
    let authorName: String?
    let authorPhotoUrl: String?
    let authorIsOwner: Bool
    let upvoteCount: Int
    let totalAnswerCount: Int
    let topAnswerText: String?
    let topAnswerAuthor: String?
    let topAnswerUpdateTime: String?
    let createTime: String?
    let updateTime: String?
    let answeredByOwner: Bool

    var id: String { questionId }
}

struct GoogleBusinessQuestionsResponse: Decodable {
    let questions: [GoogleBusinessQuestion]
}

// MARK: - Insights

struct GoogleBusinessInsightsSummary: Decodable, Equatable {
    let days: Int
    let impressionsTotal: Int
    let impressionsMaps: Int
    let impressionsSearch: Int
    let calls: Int
    let websiteClicks: Int
    let directions: Int
    let conversations: Int
    let bookings: Int
}

struct GoogleBusinessMetricPoint: Decodable, Equatable, Identifiable {
    let date: String
    let value: Double
    var id: String { date }
}

struct GoogleBusinessMetricSeries: Decodable, Equatable {
    let total: Double
    let series: [GoogleBusinessMetricPoint]
}

struct GoogleBusinessInsightsResponse: Decodable {
    let cached: Bool
    let summary: GoogleBusinessInsightsSummary
    let metrics: [String: GoogleBusinessMetricSeries]
    let generatedAt: String?
}

// MARK: - Location / Hours

/// Les structures suivantes reflètent l'API Business Information. Nested ; on les garde permissives
/// pour ne pas casser si Google ajoute des champs.
struct GoogleBusinessLocationInfo: Decodable, Equatable {
    let name: String?
    let title: String?
    let websiteUri: String?
    let storefrontAddress: GoogleBusinessAddress?
    let phoneNumbers: GoogleBusinessPhoneNumbers?
    let regularHours: GoogleBusinessRegularHours?
    let specialHours: GoogleBusinessSpecialHours?
    let categories: GoogleBusinessCategories?
    let profile: GoogleBusinessProfile?
    let openInfo: GoogleBusinessOpenInfo?
    let metadata: GoogleBusinessLocationMetadata?
    let latlng: GoogleBusinessLatLng?
}

struct GoogleBusinessLocationResponse: Decodable {
    let cached: Bool
    let location: GoogleBusinessLocationInfo
}

struct GoogleBusinessAddress: Decodable, Equatable {
    let addressLines: [String]?
    let locality: String?
    let postalCode: String?
    let administrativeArea: String?
    let regionCode: String?
}

struct GoogleBusinessPhoneNumbers: Decodable, Equatable {
    let primaryPhone: String?
}

struct GoogleBusinessLatLng: Decodable, Equatable {
    let latitude: Double?
    let longitude: Double?
}

struct GoogleBusinessCategories: Decodable, Equatable {
    let primaryCategory: GoogleBusinessCategory?
    let additionalCategories: [GoogleBusinessCategory]?
}

struct GoogleBusinessCategory: Decodable, Equatable {
    let name: String?
    let displayName: String?
}

struct GoogleBusinessProfile: Decodable, Equatable {
    let description: String?
}

struct GoogleBusinessOpenInfo: Decodable, Equatable {
    let status: String?
    let canReopen: Bool?
}

struct GoogleBusinessLocationMetadata: Decodable, Equatable {
    let mapsUri: String?
    let newReviewUri: String?
    let placeId: String?
}

/// Horaires hebdomadaires. Google renvoie `periods` au format {openDay, openTime, closeDay, closeTime}.
/// `Codable` pour permettre l'envoi d'un PATCH vers Business Information.
struct GoogleBusinessRegularHours: Codable, Equatable {
    var periods: [GoogleBusinessHourPeriod]
}

struct GoogleBusinessHourPeriod: Codable, Equatable, Identifiable {
    let openDay: String
    let openTime: GoogleBusinessHourTime?
    let closeDay: String?
    let closeTime: GoogleBusinessHourTime?

    var id: String { "\(openDay)-\(openTime?.hours ?? 0)-\(openTime?.minutes ?? 0)-\(closeTime?.hours ?? 0)-\(closeTime?.minutes ?? 0)" }
}

struct GoogleBusinessHourTime: Codable, Equatable {
    let hours: Int?
    let minutes: Int?
}

struct GoogleBusinessSpecialHours: Decodable, Equatable {
    let specialHourPeriods: [GoogleBusinessSpecialHourPeriod]?
}

struct GoogleBusinessSpecialHourPeriod: Decodable, Equatable {
    let startDate: GoogleBusinessDate?
    let endDate: GoogleBusinessDate?
    let closed: Bool?
}

struct GoogleBusinessDate: Codable, Equatable {
    let year: Int?
    let month: Int?
    let day: Int?
}

// MARK: - Media (photos)

struct GoogleBusinessMedia: Decodable, Identifiable, Equatable {
    let mediaId: String
    let name: String?
    let mediaFormat: String?
    let category: String?
    let googleUrl: String?
    let thumbnailUrl: String?
    let createTime: String?

    var id: String { mediaId }
}

struct GoogleBusinessMediaResponse: Decodable {
    let media: [GoogleBusinessMedia]
}

// MARK: - Status Payload (for markAllSeen, star, etc.)

struct GoogleBusinessOkResponse: Decodable {
    let ok: Bool
}

// MARK: - Date parsing helper

enum GoogleBusinessDateParser {
    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso8601Plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let sqlDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    static func parse(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = iso8601WithFractional.date(from: s) { return d }
        if let d = iso8601Plain.date(from: s) { return d }
        if let d = sqlDateFormatter.date(from: s) { return d }
        return nil
    }
}
