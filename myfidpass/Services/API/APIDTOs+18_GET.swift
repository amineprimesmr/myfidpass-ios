//
//  APIDTOs+18_GET.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

// MARK: - GET /api/admin/* (plateforme)

struct AdminOverviewResponse: Decodable {
    let usersCount: Int?
    let businessesCount: Int?
    let merchantOwnersCount: Int?
    let teamMemberAccountsCount: Int?
    let platformAdminAccountsCount: Int?
    let orphanAccountsCount: Int?
    let activeSubscriptionsCount: Int?
}

struct AdminUsersListResponse: Decodable {
    let users: [AdminUserRow]
}

struct AdminUserRow: Decodable, Identifiable {
    let id: String
    let email: String?
    let name: String?
    let createdAt: String?
    /// SQLite : 0/1
    let isAdmin: Int?

    var isAdminFlag: Bool { (isAdmin ?? 0) != 0 }
}

struct AdminBusinessesListResponse: Decodable {
    let businesses: [AdminBusinessRow]
}

/// URLs médias commerce pour la console admin (fallback client si l’API n’expose pas encore `display_logo_url`).
enum AdminBusinessMediaURL {
    static func resourceURL(slug: String, resource: String) -> URL? {
        let trimmed = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trimmed
        return APIConfig.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("businesses")
            .appendingPathComponent(encoded)
            .appendingPathComponent(resource)
    }

    /// Ordre d’essai : icône notif → logo carré → bandeau carte.
    static func logoLoadCandidates(for business: AdminBusinessRow) -> [URL] {
        var seen = Set<String>()
        var out: [URL] = []
        func append(_ raw: String?) {
            let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !t.isEmpty, let url = APIResourceURL.resolved(from: t) else { return }
            let key = url.absoluteString
            guard seen.insert(key).inserted else { return }
            out.append(url)
        }
        append(business.displayLogoUrl)
        append(business.notificationIconUrl)
        append(business.logoIconUrl)
        append(business.logoUrl)
        for resource in ["notification-icon", "logo-icon", "logo"] {
            if let url = resourceURL(slug: business.slug, resource: resource) {
                let key = url.absoluteString
                guard seen.insert(key).inserted else { continue }
                out.append(url)
            }
        }
        return out
    }
}

struct AdminBusinessRow: Decodable, Identifiable, Hashable {
    let id: String
    let slug: String
    let name: String?
    let organizationName: String?
    let userId: String?
    let createdAt: String?
    let ownerEmail: String?
    let memberCount: Int?
    let ownerSubscriptionStatus: String?
    let ownerPlanId: String?
    let dashboardToken: String?
    let logoUrl: String?
    let logoIconUrl: String?
    let notificationIconUrl: String?
    let displayLogoUrl: String?
    let logoUpdatedAt: String?
    let logoIconUpdatedAt: String?
    let notificationIconUpdatedAt: String?

    private enum CodingKeys: String, CodingKey {
        case id, slug, name, organizationName, userId, createdAt
        case ownerEmail, memberCount, ownerSubscriptionStatus, ownerPlanId
        case dashboardToken, logoUrl, logoIconUrl, notificationIconUrl
        case displayLogoUrl, logoUpdatedAt, logoIconUpdatedAt, notificationIconUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try c.decodeIfPresent(String.self, forKey: .id) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        slug = (try c.decodeIfPresent(String.self, forKey: .slug) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        organizationName = try c.decodeIfPresent(String.self, forKey: .organizationName)
        userId = try c.decodeIfPresent(String.self, forKey: .userId)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        ownerEmail = try c.decodeIfPresent(String.self, forKey: .ownerEmail)
        memberCount = Self.decodeFlexibleInt(c, forKey: .memberCount)
        ownerSubscriptionStatus = try c.decodeIfPresent(String.self, forKey: .ownerSubscriptionStatus)
        ownerPlanId = try c.decodeIfPresent(String.self, forKey: .ownerPlanId)
        dashboardToken = try c.decodeIfPresent(String.self, forKey: .dashboardToken)
        logoUrl = try c.decodeIfPresent(String.self, forKey: .logoUrl)
        logoIconUrl = try c.decodeIfPresent(String.self, forKey: .logoIconUrl)
        notificationIconUrl = try c.decodeIfPresent(String.self, forKey: .notificationIconUrl)
        displayLogoUrl = try c.decodeIfPresent(String.self, forKey: .displayLogoUrl)
        logoUpdatedAt = try c.decodeIfPresent(String.self, forKey: .logoUpdatedAt)
        logoIconUpdatedAt = try c.decodeIfPresent(String.self, forKey: .logoIconUpdatedAt)
        notificationIconUpdatedAt = try c.decodeIfPresent(String.self, forKey: .notificationIconUpdatedAt)
    }

    private static func decodeFlexibleInt(_ c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Int? {
        if let n = try? c.decodeIfPresent(Int.self, forKey: key) { return n }
        if let s = try? c.decodeIfPresent(String.self, forKey: key),
           let n = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) { return n }
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return Int(d) }
        return nil
    }

    /// URL affichable dans la liste admin (notif > carré > bandeau).
    var resolvedDisplayLogoURL: String? {
        let candidates = [displayLogoUrl, notificationIconUrl, logoIconUrl, logoUrl]
        for raw in candidates {
            let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !t.isEmpty { return t }
        }
        return AdminBusinessMediaURL.resourceURL(slug: slug, resource: "notification-icon")?.absoluteString
            ?? AdminBusinessMediaURL.resourceURL(slug: slug, resource: "logo-icon")?.absoluteString
            ?? AdminBusinessMediaURL.resourceURL(slug: slug, resource: "logo")?.absoluteString
    }

    var displayName: String {
        let n = organizationName?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? name?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        return n.isEmpty ? slug : n
    }

    /// Abonnement propriétaire opérationnel (`active`, `trialing`, `past_due`).
    var ownerHasActiveSubscription: Bool {
        let st = (ownerSubscriptionStatus ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return st == "active" || st == "trialing" || st == "past_due"
    }

    func asBusinessDTO() -> BusinessDTO {
        let display = organizationName?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? name?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? slug
        let tokenTrimmed = dashboardToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        return BusinessDTO(
            id: id,
            name: display.isEmpty ? slug : display,
            slug: slug,
            organizationName: organizationName,
            createdAt: createdAt,
            dashboardToken: (tokenTrimmed?.isEmpty == false) ? tokenTrimmed : nil,
            displayLogoUrl: resolvedDisplayLogoURL,
            ownerEmail: ownerEmail,
            memberCount: memberCount,
            ownerSubscriptionStatus: ownerSubscriptionStatus
        )
    }
}

struct AdminEventsListResponse: Decodable {
    let events: [AdminEventRow]
}

struct AdminDeleteBusinessBody: Encodable {
    let confirm: String

    static let confirmToken = "SUPPRIMER"

    static var wipe: AdminDeleteBusinessBody {
        AdminDeleteBusinessBody(confirm: confirmToken)
    }
}

struct AdminDeleteUserBody: Encodable {
    let confirm: String

    static let confirmToken = "SUPPRIMER"

    static var wipe: AdminDeleteUserBody {
        AdminDeleteUserBody(confirm: confirmToken)
    }
}

struct AdminDeleteSuccessResponse: Decodable {
    let ok: Bool?
}

struct AdminCreateMerchantAccountBody: Encodable {
    let email: String
    let businessName: String
    let ownerName: String?
    let slug: String?
    let organizationName: String?
    let password: String?

    enum CodingKeys: String, CodingKey {
        case email
        case businessName = "business_name"
        case ownerName = "owner_name"
        case slug
        case organizationName = "organization_name"
        case password
    }
}

struct AdminCreateMerchantAccountResponse: Decodable {
    let ok: Bool?
    let userCreated: Bool?
    let user: AdminProvisionedUserRow?
    let business: AdminBusinessRow?
}

struct AdminProvisionedUserRow: Decodable {
    let id: String
    let email: String?
    let name: String?
}

struct AdminEventRow: Decodable, Identifiable {
    let id: String
    let eventType: String
    let payloadJson: String?
    let stripeEventId: String?
    let createdAt: String?
}

