//
//  APIEndpoint.swift
//  myfidpass
//
//  Endpoints alignés sur l’API MyFidpass / fidelity (dashboard, membres, jeux, engagement).
//

import Foundation

enum APIEndpoint {
    // MARK: - Auth
    case authLogin(email: String, password: String)
    case authRegister(email: String, password: String, name: String?, googlePlaceId: String?, establishmentName: String?)
    /// Recherche d'établissements Google (même logique que le SaaS) — sans JWT.
    case placesAutocomplete(input: String)
    case authForgotPassword(email: String)
    case authResetPassword(token: String, newPassword: String)
    case authGoogle(idToken: String)
    case authApple(idToken: String, name: String?, email: String?)
    case authMe
    case authConfig
    case authDeleteAccount

    // MARK: - Commerce (JWT)
    case createBusiness(payload: CreateBusinessPayload)
    case paymentCheckout(planId: String?)

    // MARK: - Sync (dashboard / slug)
    case businessSettings(slug: String)
    case businessStats(slug: String, period: String?)
    case businessEvolution(slug: String, weeks: Int?, period: String?)
    case businessMembers(slug: String, limit: Int?, offset: Int?, search: String?, filter: String?, sort: String?)
    case businessMembersExport(slug: String, search: String?, filter: String?, sort: String?)
    case businessTransactions(slug: String, limit: Int?, offset: Int?, memberId: String?, days: Int?, type: String?)
    case businessTransactionsExport(slug: String, days: Int?, type: String?)
    case businessCategories(slug: String)
    case createCategory(slug: String, name: String, colorHex: String?, sortOrder: Int?)
    case updateCategory(slug: String, categoryId: String, name: String?, colorHex: String?, sortOrder: Int?)
    case deleteCategory(slug: String, categoryId: String)
    case updateMemberCategories(slug: String, memberId: String, categoryIds: [String])

    // MARK: - Jeux & engagement (dashboard)
    case dashboardGames(slug: String)
    case dashboardPatchGame(slug: String, gameCode: String, body: PatchGameBody)
    case dashboardGameRewardsGet(slug: String, gameCode: String)
    case dashboardGameRewardsPut(slug: String, gameCode: String, body: PutGameRewardsBody)

    // MARK: - Notifications dashboard
    case dashboardNotificationSend(slug: String, body: NotificationSendPayload)
    case dashboardNotificationSegments(slug: String)
    case dashboardNotificationStats(slug: String)
    case dashboardTestPasskit(slug: String)
    case dashboardRemoveTestDevice(slug: String)

    // MARK: - Scan
    case scanLookup(slug: String, barcode: String)
    case scan(slug: String, barcode: String, visit: Bool, points: Int?, amountEur: Double?)

    case deviceRegister(token: String)

    case walletPass(slug: String, memberId: String, design: WalletPassDesign?)

    case notifyClients(slug: String, message: String, categoryIds: [String]?)

    case patchDashboardSettings(slug: String, patch: FullDashboardSettingsPatch)
    /// Préférences flyer QR (sync avec le SaaS).
    case dashboardFlyerGet(slug: String)
    case updateLocationSettings(
        slug: String,
        locationLat: Double?,
        locationLng: Double?,
        locationRadiusMeters: Int?,
        locationRelevantText: String?,
        locationAddress: String?,
        walletPassIncludeLocations: Bool?
    )

    /// Crédit membre (points directs, montant €, et/ou passage) — aligné POST .../members/:id/points.
    case creditMember(slug: String, memberId: String, points: Int?, amountEur: Double?, visit: Bool)
    /// Retrait de points (correction erreur de caisse) — POST .../members/:id/points/remove.
    case removeMemberPoints(slug: String, memberId: String, points: Int)
    case redeemReward(slug: String, memberId: String, type: RedeemType)

    // MARK: - Membres (import, détail public, tickets, récompenses)
    case membersImport(slug: String, payload: MembersImportPayload)
    case createMember(slug: String, email: String, name: String)
    case memberPublic(slug: String, memberId: String)
    case memberTickets(slug: String, memberId: String)
    case memberTicketsConvert(slug: String, memberId: String, pointsToConvert: Int, idempotencyKey: String?)
    case memberRewardsList(slug: String, memberId: String)
    case claimMemberReward(slug: String, memberId: String, grantId: String)
    case googleWalletMemberUrl(slug: String, memberId: String)

    var path: String {
        switch self {
        case .authLogin: return "/api/auth/login"
        case .authRegister: return "/api/auth/register"
        case .placesAutocomplete: return "/api/places/autocomplete"
        case .authForgotPassword: return "/api/auth/forgot-password"
        case .authResetPassword: return "/api/auth/reset-password"
        case .authGoogle: return "/api/auth/google"
        case .authApple: return "/api/auth/apple"
        case .authMe: return "/api/auth/me"
        case .authConfig: return "/api/auth/config"
        case .authDeleteAccount: return "/api/auth/account"
        case .createBusiness: return "/api/businesses"
        case .paymentCheckout: return "/api/payment/create-checkout-session"
        case .businessSettings(let slug): return "/api/businesses/\(slug)/dashboard/settings"
        case .businessStats(let slug, _): return "/api/businesses/\(slug)/dashboard/stats"
        case .businessEvolution(let slug, _, _): return "/api/businesses/\(slug)/dashboard/evolution"
        case .businessMembers(let slug, _, _, _, _, _): return "/api/businesses/\(slug)/dashboard/members"
        case .businessMembersExport(let slug, _, _, _): return "/api/businesses/\(slug)/dashboard/members/export"
        case .businessTransactions(let slug, _, _, _, _, _): return "/api/businesses/\(slug)/dashboard/transactions"
        case .businessTransactionsExport(let slug, _, _): return "/api/businesses/\(slug)/dashboard/transactions/export"
        case .businessCategories(let slug): return "/api/businesses/\(slug)/dashboard/categories"
        case .createCategory(let slug, _, _, _): return "/api/businesses/\(slug)/dashboard/categories"
        case .updateCategory(let slug, let categoryId, _, _, _): return "/api/businesses/\(slug)/dashboard/categories/\(categoryId)"
        case .deleteCategory(let slug, let categoryId): return "/api/businesses/\(slug)/dashboard/categories/\(categoryId)"
        case .updateMemberCategories(let slug, let memberId, _): return "/api/businesses/\(slug)/dashboard/members/\(memberId)/categories"
        case .dashboardGames(let slug): return "/api/businesses/\(slug)/dashboard/games"
        case .dashboardPatchGame(let slug, let gameCode, _): return "/api/businesses/\(slug)/dashboard/games/\(gameCode)"
        case .dashboardGameRewardsGet(let slug, let gameCode): return "/api/businesses/\(slug)/dashboard/games/\(gameCode)/rewards"
        case .dashboardGameRewardsPut(let slug, let gameCode, _): return "/api/businesses/\(slug)/dashboard/games/\(gameCode)/rewards"
        case .dashboardNotificationSend(let slug, _): return "/api/businesses/\(slug)/dashboard/notifications/send"
        case .dashboardNotificationSegments(let slug): return "/api/businesses/\(slug)/dashboard/notifications/campaign-segments"
        case .dashboardNotificationStats(let slug): return "/api/businesses/\(slug)/dashboard/notifications/stats"
        case .dashboardTestPasskit(let slug): return "/api/businesses/\(slug)/dashboard/notifications/test-passkit"
        case .dashboardRemoveTestDevice(let slug): return "/api/businesses/\(slug)/dashboard/notifications/remove-test-device"
        case .scanLookup(let slug, _): return "/api/businesses/\(slug)/integration/lookup"
        case .scan(let slug, _, _, _, _): return "/api/businesses/\(slug)/integration/scan"
        case .deviceRegister: return "/api/device/register"
        case .walletPass(let slug, let memberId, _): return "/api/businesses/\(slug)/members/\(memberId)/pass"
        case .notifyClients(let slug, _, _): return "/api/businesses/\(slug)/notify"
        case .patchDashboardSettings(let slug, _): return "/api/businesses/\(slug)/dashboard/settings"
        case .dashboardFlyerGet(let slug): return "/api/businesses/\(slug)/dashboard/flyer"
        case .updateLocationSettings(let slug, _, _, _, _, _, _): return "/api/businesses/\(slug)/dashboard/settings"
        case .creditMember(let slug, let memberId, _, _, _): return "/api/businesses/\(slug)/members/\(memberId)/points"
        case .removeMemberPoints(let slug, let memberId, _): return "/api/businesses/\(slug)/members/\(memberId)/points/remove"
        case .redeemReward(let slug, let memberId, _): return "/api/businesses/\(slug)/members/\(memberId)/redeem"
        case .membersImport(let slug, _): return "/api/businesses/\(slug)/members/import"
        case .createMember(let slug, _, _): return "/api/businesses/\(slug)/members"
        case .memberPublic(let slug, let memberId): return "/api/businesses/\(slug)/members/\(memberId)"
        case .memberTickets(let slug, let memberId): return "/api/businesses/\(slug)/members/\(memberId)/tickets"
        case .memberTicketsConvert(let slug, let memberId, _, _): return "/api/businesses/\(slug)/members/\(memberId)/tickets/convert"
        case .memberRewardsList(let slug, let memberId): return "/api/businesses/\(slug)/members/\(memberId)/rewards"
        case .claimMemberReward(let slug, let memberId, let grantId): return "/api/businesses/\(slug)/members/\(memberId)/rewards/\(grantId)/claim"
        case .googleWalletMemberUrl(let slug, let memberId): return "/api/businesses/\(slug)/members/\(memberId)/google-wallet-url"
        }
    }

    var isAuth: Bool {
        switch self {
        case .authLogin, .authGoogle, .authApple, .authRegister, .authForgotPassword, .authResetPassword:
            return true
        default:
            return false
        }
    }

    /// En-têtes additionnels (ex. idempotency).
    var supplementalHeaders: [String: String] {
        switch self {
        case .memberTicketsConvert(_, _, _, let key):
            if let key, !key.isEmpty { return ["Idempotency-Key": key] }
            return [:]
        default:
            return [:]
        }
    }

    var method: String {
        switch self {
        case .authLogin, .authRegister, .authForgotPassword, .authResetPassword, .authGoogle, .authApple,
             .scan, .deviceRegister, .notifyClients, .createCategory, .updateMemberCategories, .creditMember,
             .removeMemberPoints, .redeemReward, .createBusiness, .paymentCheckout, .dashboardNotificationSend, .dashboardRemoveTestDevice,
             .membersImport, .createMember, .memberTicketsConvert, .claimMemberReward:
            return "POST"
        case .patchDashboardSettings, .updateCategory, .updateLocationSettings, .dashboardPatchGame:
            return "PATCH"
        case .deleteCategory, .authDeleteAccount:
            return "DELETE"
        case .dashboardGameRewardsPut:
            return "PUT"
        default:
            return "GET"
        }
    }

    func urlRequest(base: URL, encoder: JSONEncoder) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: base) else { throw APIError.invalidURL }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        switch self {
        case .businessStats(_, let period):
            if let period, !period.isEmpty {
                components.queryItems = [URLQueryItem(name: "period", value: period)]
            }
        case .businessEvolution(_, let weeks, let period):
            var items: [URLQueryItem] = []
            if let w = weeks { items.append(URLQueryItem(name: "weeks", value: "\(w)")) }
            if let p = period, !p.isEmpty { items.append(URLQueryItem(name: "period", value: p)) }
            components.queryItems = items.isEmpty ? nil : items
        case .businessMembers(_, let limit, let offset, let search, let filter, let sort):
            var items: [URLQueryItem] = []
            if let l = limit { items.append(URLQueryItem(name: "limit", value: "\(l)")) }
            if let o = offset { items.append(URLQueryItem(name: "offset", value: "\(o)")) }
            if let s = search, !s.isEmpty { items.append(URLQueryItem(name: "search", value: s)) }
            if let f = filter, !f.isEmpty { items.append(URLQueryItem(name: "filter", value: f)) }
            if let so = sort, !so.isEmpty { items.append(URLQueryItem(name: "sort", value: so)) }
            components.queryItems = items.isEmpty ? nil : items
        case .businessMembersExport(_, let search, let filter, let sort):
            var items: [URLQueryItem] = []
            if let s = search, !s.isEmpty { items.append(URLQueryItem(name: "search", value: s)) }
            if let f = filter, !f.isEmpty { items.append(URLQueryItem(name: "filter", value: f)) }
            if let so = sort, !so.isEmpty { items.append(URLQueryItem(name: "sort", value: so)) }
            components.queryItems = items.isEmpty ? nil : items
        case .businessTransactions(_, let limit, let offset, let memberId, let days, let type):
            var items: [URLQueryItem] = []
            if let l = limit { items.append(URLQueryItem(name: "limit", value: "\(l)")) }
            if let o = offset { items.append(URLQueryItem(name: "offset", value: "\(o)")) }
            if let m = memberId, !m.isEmpty { items.append(URLQueryItem(name: "memberId", value: m)) }
            if let d = days { items.append(URLQueryItem(name: "days", value: "\(d)")) }
            if let t = type, !t.isEmpty { items.append(URLQueryItem(name: "type", value: t)) }
            components.queryItems = items.isEmpty ? nil : items
        case .businessTransactionsExport(_, let days, let type):
            var items: [URLQueryItem] = []
            if let d = days { items.append(URLQueryItem(name: "days", value: "\(d)")) }
            if let t = type, !t.isEmpty { items.append(URLQueryItem(name: "type", value: t)) }
            components.queryItems = items.isEmpty ? nil : items
        case .placesAutocomplete(let input):
            components.queryItems = [URLQueryItem(name: "input", value: input)]
        case .scanLookup(_, let barcode):
            components.queryItems = [URLQueryItem(name: "barcode", value: barcode)]
        case .walletPass(_, _, let design):
            let template = design?.template.flatMap { $0.isEmpty ? nil : $0 } ?? "classic"
            var items = [URLQueryItem(name: "template", value: template)]
            if let d = design {
                if !d.organizationName.isEmpty { items.append(URLQueryItem(name: "organization_name", value: d.organizationName)) }
                if !d.backgroundColor.isEmpty { items.append(URLQueryItem(name: "background_color", value: d.backgroundColor)) }
                if !d.foregroundColor.isEmpty { items.append(URLQueryItem(name: "foreground_color", value: d.foregroundColor)) }
                if let pt = d.programType, !pt.isEmpty { items.append(URLQueryItem(name: "program_type", value: pt)) }
                if let sc = d.stripColor, !sc.isEmpty { items.append(URLQueryItem(name: "strip_color", value: sc)) }
                if let mode = d.stripDisplayMode, !mode.isEmpty { items.append(URLQueryItem(name: "strip_display_mode", value: mode)) }
                if let st = d.stripText, !st.isEmpty { items.append(URLQueryItem(name: "strip_text", value: st)) }
                if !d.stampEmoji.isEmpty { items.append(URLQueryItem(name: "stamp_emoji", value: d.stampEmoji)) }
                if d.requiredStamps > 0 { items.append(URLQueryItem(name: "required_stamps", value: "\(d.requiredStamps)")) }
            }
            components.queryItems = items
        default:
            break
        }
        guard let finalURL = components.url else { throw APIError.invalidURL }
        var bodyData: Data?
        switch self {
        case .authLogin(let email, let password):
            bodyData = try encoder.encode(LoginPayload(email: email, password: password))
        case .authRegister(let email, let password, let name, let googlePlaceId, let establishmentName):
            bodyData = try encoder.encode(
                AuthRegisterPayload(email: email, password: password, name: name, googlePlaceId: googlePlaceId, establishmentName: establishmentName)
            )
        case .authForgotPassword(let email):
            bodyData = try encoder.encode(ForgotPasswordPayload(email: email))
        case .authResetPassword(let token, let newPassword):
            bodyData = try encoder.encode(ResetPasswordPayload(token: token, newPassword: newPassword))
        case .authGoogle(let idToken):
            bodyData = try encoder.encode(GooglePayload(idToken: idToken))
        case .authApple(let idToken, let name, let email):
            bodyData = try encoder.encode(ApplePayload(idToken: idToken, name: name, email: email))
        case .createBusiness(let payload):
            bodyData = try encoder.encode(payload)
        case .paymentCheckout(let planId):
            bodyData = try encoder.encode(CheckoutSessionPayload(planId: planId))
        case .scan(_, let barcode, let visit, let points, let amountEur):
            bodyData = try encoder.encode(ScanPayload(barcode: barcode, visit: visit, points: points, amount_eur: amountEur))
        case .deviceRegister(let token):
            bodyData = try encoder.encode(DeviceRegisterPayload(deviceToken: token))
        case .notifyClients(_, let message, let categoryIds):
            bodyData = try encoder.encode(NotifyClientsPayload(message: message, categoryIds: categoryIds))
        case .createCategory(_, let name, let colorHex, let sortOrder):
            bodyData = try encoder.encode(CreateCategoryPayload(name: name, colorHex: colorHex, sortOrder: sortOrder))
        case .updateCategory(_, _, let name, let colorHex, let sortOrder):
            bodyData = try encoder.encode(UpdateCategoryPayload(name: name, colorHex: colorHex, sortOrder: sortOrder))
        case .updateMemberCategories(_, _, let categoryIds):
            bodyData = try encoder.encode(UpdateMemberCategoriesPayload(categoryIds: categoryIds))
        case .creditMember(_, _, let points, let amountEur, let visit):
            bodyData = try encoder.encode(CreditMemberBody(points: points, amountEur: amountEur, visit: visit))
        case .removeMemberPoints(_, _, let points):
            bodyData = try encoder.encode(RemoveMemberPointsBody(points: points))
        case .redeemReward(_, _, let type):
            bodyData = try encoder.encode(RedeemPayload(type: type))
        case .updateLocationSettings(_, let locationLat, let locationLng, let locationRadiusMeters, let locationRelevantText, let locationAddress, let walletPassIncludeLocations):
            bodyData = try encoder.encode(UpdateLocationSettingsPayload(
                locationLat: locationLat,
                locationLng: locationLng,
                locationRadiusMeters: locationRadiusMeters,
                locationRelevantText: locationRelevantText,
                locationAddress: locationAddress,
                walletPassIncludeLocations: walletPassIncludeLocations
            ))
        case .patchDashboardSettings(_, let patch):
            bodyData = try encoder.encode(patch)
        case .dashboardPatchGame(_, _, let body):
            bodyData = try encoder.encode(body)
        case .dashboardGameRewardsPut(_, _, let body):
            bodyData = try encoder.encode(body)
        case .dashboardNotificationSend(_, let body):
            bodyData = try encoder.encode(body)
        case .membersImport(_, let payload):
            bodyData = try encoder.encode(payload)
        case .createMember(_, let email, let name):
            bodyData = try encoder.encode(CreateMemberPayload(email: email, name: name))
        case .memberTicketsConvert(_, _, let pointsToConvert, _):
            bodyData = try encoder.encode(MemberTicketsConvertBody(pointsToConvert: pointsToConvert))
        default:
            break
        }
        var request = URLRequest(url: finalURL)
        request.httpMethod = method
        request.httpBody = bodyData
        return request
    }
}

private struct LoginPayload: Encodable {
    let email: String
    let password: String
}

private struct GooglePayload: Encodable {
    let idToken: String
}

private struct ApplePayload: Encodable {
    let idToken: String
    let name: String?
    let email: String?
}

private struct DeviceRegisterPayload: Encodable {
    let deviceToken: String
}

private struct NotifyClientsPayload: Encodable {
    let message: String
    let categoryIds: [String]?
}

private struct CreateCategoryPayload: Encodable {
    let name: String
    let colorHex: String?
    let sortOrder: Int?
}

private struct UpdateCategoryPayload: Encodable {
    let name: String?
    let colorHex: String?
    let sortOrder: Int?
}

private struct UpdateMemberCategoriesPayload: Encodable {
    let categoryIds: [String]
}

private struct CreditMemberBody: Encodable {
    let points: Int?
    let amountEur: Double?
    let visit: Bool?

    enum CodingKeys: String, CodingKey {
        case points
        case amountEur = "amount_eur"
        case visit
    }

    init(points: Int?, amountEur: Double?, visit: Bool) {
        self.points = points
        self.amountEur = amountEur
        self.visit = visit ? true : nil
    }
}

private struct RemoveMemberPointsBody: Encodable {
    let points: Int
}

private struct MemberTicketsConvertBody: Encodable {
    let pointsToConvert: Int

    enum CodingKeys: String, CodingKey {
        case pointsToConvert = "points_to_convert"
    }
}

enum RedeemType {
    case stamps
    case points(pointsToDeduct: Int)
}

private struct RedeemPayload: Encodable {
    let type: String
    let points: Int?

    init(type: RedeemType) {
        switch type {
        case .stamps:
            self.type = "stamps"
            self.points = nil
        case .points(let n):
            self.type = "points"
            self.points = n
        }
    }
}

struct PointsRewardTierPayload: Encodable {
    let points: Int
    let label: String
}

/// Body PATCH emplacement — clés snake_case comme le backend (`dashboard.js`).
private struct UpdateLocationSettingsPayload: Encodable {
    let locationLat: Double?
    let locationLng: Double?
    let locationRadiusMeters: Int?
    let locationRelevantText: String?
    let locationAddress: String?
    let walletPassIncludeLocations: Bool?

    enum CK: String, CodingKey {
        case locationLat = "location_lat"
        case locationLng = "location_lng"
        case locationRadiusMeters = "location_radius_meters"
        case locationRelevantText = "location_relevant_text"
        case locationAddress = "location_address"
        case walletPassIncludeLocations = "wallet_pass_include_locations"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CK.self)
        try c.encodeIfPresent(locationLat, forKey: .locationLat)
        try c.encodeIfPresent(locationLng, forKey: .locationLng)
        try c.encodeIfPresent(locationRadiusMeters, forKey: .locationRadiusMeters)
        try c.encodeIfPresent(locationRelevantText, forKey: .locationRelevantText)
        try c.encodeIfPresent(locationAddress, forKey: .locationAddress)
        if let w = walletPassIncludeLocations {
            try c.encode(w ? 1 : 0, forKey: .walletPassIncludeLocations)
        }
    }
}

struct WalletPassDesign {
    var organizationName: String
    var backgroundColor: String
    var foregroundColor: String
    var stampEmoji: String
    var requiredStamps: Int
    var programType: String?
    var stripColor: String?
    var stripDisplayMode: String?
    var stripText: String?
    var template: String?
}

private struct ScanPayload: Encodable {
    let barcode: String
    let visit: Bool?
    let points: Int?
    let amount_eur: Double?

    init(barcode: String, visit: Bool, points: Int?, amount_eur: Double?) {
        self.barcode = barcode
        self.visit = visit ? true : nil
        self.points = points
        self.amount_eur = amount_eur
    }
}
