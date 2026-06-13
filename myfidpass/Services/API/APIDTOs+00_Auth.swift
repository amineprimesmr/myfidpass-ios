//
//  APIDTOs+00_Auth.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

// MARK: - Auth (login, google, apple)

struct AuthLoginResponse: Decodable {
    let user: AuthUser
    let token: String
    let refreshToken: String?
    let businesses: [BusinessDTO]
    let subscription: SubscriptionDTO?
    let hasActiveSubscription: Bool?
    /// Abonnement encaissé (App Store / Stripe), pas l’essai gratuit seul.
    let hasPaidMerchantSubscription: Bool?
    /// Champ API historique (toujours `null` côté serveur) — ignoré par l’app.
    let merchantTrialEndsAt: String?
    let entitlements: MerchantEntitlementsDTO?

    enum CodingKeys: String, CodingKey {
        case user
        case token
        case refreshToken
        case businesses
        case subscription
        case hasActiveSubscription
        case hasPaidMerchantSubscription
        case merchantTrialEndsAt
        case entitlements
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        user = try c.decode(AuthUser.self, forKey: .user)
        token = try c.decode(String.self, forKey: .token)
        refreshToken = try c.decodeIfPresent(String.self, forKey: .refreshToken)
        businesses = try c.decodeIfPresent([BusinessDTO].self, forKey: .businesses) ?? []
        subscription = try c.decodeIfPresent(SubscriptionDTO.self, forKey: .subscription)
        hasActiveSubscription = decodeFlexibleOptionalBool(container: c, key: .hasActiveSubscription)
        hasPaidMerchantSubscription = decodeFlexibleOptionalBool(container: c, key: .hasPaidMerchantSubscription)
        merchantTrialEndsAt = try c.decodeIfPresent(String.self, forKey: .merchantTrialEndsAt)
        entitlements = try c.decodeIfPresent(MerchantEntitlementsDTO.self, forKey: .entitlements)
    }

    /// Assemblage après OAuth Google (callback) quand `/me` a déjà été décodé.
    init(
        user: AuthUser,
        token: String,
        refreshToken: String?,
        businesses: [BusinessDTO],
        subscription: SubscriptionDTO? = nil,
        hasActiveSubscription: Bool? = nil,
        hasPaidMerchantSubscription: Bool? = nil,
        merchantTrialEndsAt: String? = nil,
        entitlements: MerchantEntitlementsDTO? = nil
    ) {
        self.user = user
        self.token = token
        self.refreshToken = refreshToken
        self.businesses = businesses
        self.subscription = subscription
        self.hasActiveSubscription = hasActiveSubscription
        self.hasPaidMerchantSubscription = hasPaidMerchantSubscription
        self.merchantTrialEndsAt = merchantTrialEndsAt
        self.entitlements = entitlements
    }
}

struct MerchantEntitlementsDTO: Decodable {
    let allowedBusinesses: Int?
    let usedBusinesses: Int?
    let canCreateBusiness: Bool?
    let billingProvider: String?

    enum CodingKeys: String, CodingKey {
        case allowedBusinesses = "allowed_businesses"
        case usedBusinesses = "used_businesses"
        case canCreateBusiness = "can_create_business"
        case billingProvider = "billing_provider"
    }
}

struct AuthUser: Decodable {
    let id: String?
    let email: String?
    /// Compte employé sans e-mail : identifiant défini par le commerçant.
    let staffLogin: String?
    let name: String?
    /// Présent si le compte est lié à un numéro (connexion par SMS).
    let phone: String?
    /// Compte administrateur plateforme (`is_admin` côté API).
    let isAdmin: Bool?
    /// Rôle dans l’espace commerçant : `owner` | `manager` | `staff` (`workspace_role` API).
    let workspaceRole: String?

    enum CodingKeys: String, CodingKey {
        case id, email, name, phone, staffLogin, isAdmin, workspaceRole
        /// Variante backend (tolérance).
        case role
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        staffLogin = try c.decodeIfPresent(String.self, forKey: .staffLogin)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        phone = try c.decodeIfPresent(String.self, forKey: .phone)
        isAdmin = Self.decodeIsAdminFlag(from: decoder)
        if let w = try c.decodeIfPresent(String.self, forKey: .workspaceRole) {
            workspaceRole = w
        } else {
            workspaceRole = try c.decodeIfPresent(String.self, forKey: .role)
        }
    }

    /// `JSONDecoder.convertFromSnakeCase` attend `isAdmin` ; tolère aussi la clé brute `is_admin`.
    private static func decodeIsAdminFlag(from decoder: Decoder) -> Bool? {
        if let c = try? decoder.container(keyedBy: CodingKeys.self),
           let v = decodeFlexibleOptionalBool(container: c, key: .isAdmin) {
            return v
        }
        enum RawAdminKey: String, CodingKey { case is_admin }
        if let raw = try? decoder.container(keyedBy: RawAdminKey.self) {
            return decodeFlexibleOptionalBool(container: raw, key: .is_admin)
        }
        return nil
    }
}

struct BusinessDTO: Decodable {
    let id: String
    let name: String
    let slug: String
    let organizationName: String?
    let createdAt: String?
    let dashboardToken: String?
    /// Renseigné par `GET /api/admin/businesses` pour le switcher admin (logo enregistré côté commerce).
    let displayLogoUrl: String?
    /// Admin plateforme (`GET /api/admin/businesses`).
    let ownerEmail: String?
    let memberCount: Int?
    let ownerSubscriptionStatus: String?
    /// Réseau fidélité partagé (`loyalty_groups`) — plusieurs adresses, une carte client.
    let loyaltyGroupId: String?

    /// Tolère champs manquants / vides côté API (sinon toute la synchro échoue sur `GET /me`).
    private enum CodingKeys: String, CodingKey {
        case id, name, slug, organizationName, createdAt, dashboardToken, displayLogoUrl
        case ownerEmail, memberCount, ownerSubscriptionStatus, loyaltyGroupId
    }

    var ownerHasActiveSubscription: Bool {
        let st = (ownerSubscriptionStatus ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return st == "active" || st == "trialing" || st == "past_due"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var rawId = (try c.decodeIfPresent(String.self, forKey: .id) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if rawId.isEmpty { rawId = "legacy-\(UUID().uuidString)" }
        id = rawId
        var n = (try c.decodeIfPresent(String.self, forKey: .name) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if n.isEmpty { n = "Commerce" }
        name = n
        var s = (try c.decodeIfPresent(String.self, forKey: .slug) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { s = id }
        slug = s
        organizationName = try c.decodeIfPresent(String.self, forKey: .organizationName)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        dashboardToken = try c.decodeIfPresent(String.self, forKey: .dashboardToken)
        displayLogoUrl = try c.decodeIfPresent(String.self, forKey: .displayLogoUrl)
        ownerEmail = try c.decodeIfPresent(String.self, forKey: .ownerEmail)
        memberCount = Self.decodeFlexibleInt(c, forKey: .memberCount)
        ownerSubscriptionStatus = try c.decodeIfPresent(String.self, forKey: .ownerSubscriptionStatus)
        loyaltyGroupId = try c.decodeIfPresent(String.self, forKey: .loyaltyGroupId)
    }

    init(
        id: String,
        name: String,
        slug: String,
        organizationName: String? = nil,
        createdAt: String? = nil,
        dashboardToken: String? = nil,
        displayLogoUrl: String? = nil,
        ownerEmail: String? = nil,
        memberCount: Int? = nil,
        ownerSubscriptionStatus: String? = nil,
        loyaltyGroupId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.organizationName = organizationName
        self.createdAt = createdAt
        self.dashboardToken = dashboardToken
        self.displayLogoUrl = displayLogoUrl
        self.ownerEmail = ownerEmail
        self.memberCount = memberCount
        self.ownerSubscriptionStatus = ownerSubscriptionStatus
        self.loyaltyGroupId = loyaltyGroupId
    }

    var isInLoyaltyNetwork: Bool {
        let g = (loyaltyGroupId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !g.isEmpty
    }

    private static func decodeFlexibleInt(_ c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Int? {
        if let n = try? c.decodeIfPresent(Int.self, forKey: key) { return n }
        if let s = try? c.decodeIfPresent(String.self, forKey: key),
           let n = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) { return n }
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return Int(d) }
        return nil
    }

    /// Entrée minimale quand `GET /me` n’a pas encore le commerce créé : permet `selectBusiness` + synchro sans redémarrage.
    static func localPendingStub(slug: String, displayName: String, dashboardToken: String?) -> BusinessDTO {
        let s = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokenTrimmed: String? = {
            guard let raw = dashboardToken?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
            return raw
        }()
        return BusinessDTO(
            id: "pending-\(s)",
            name: n.isEmpty ? "Commerce" : n,
            slug: s,
            organizationName: nil,
            createdAt: nil,
            dashboardToken: tokenTrimmed
        )
    }
}

