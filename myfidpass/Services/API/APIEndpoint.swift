//
//  APIEndpoint.swift
//  myfidpass
//
//  Endpoints alignés sur la doc API MyFidpass (api.myfidpass.fr).
//

import Foundation

enum APIEndpoint {
    // MARK: - Auth
    case authLogin(email: String, password: String)
    case authGoogle(idToken: String)
    case authApple(idToken: String, name: String?, email: String?)
    case authMe
    case authConfig

    // MARK: - Sync (par business slug)
    case businessSettings(slug: String)
    case businessStats(slug: String)
    case businessMembers(slug: String, limit: Int?, offset: Int?)
    case businessTransactions(slug: String, limit: Int?, offset: Int?)
    case businessCategories(slug: String)
    case createCategory(slug: String, name: String, colorHex: String?)
    case updateCategory(slug: String, categoryId: String, name: String?, colorHex: String?, sortOrder: Int?)
    case deleteCategory(slug: String, categoryId: String)
    case updateMemberCategories(slug: String, memberId: String, categoryIds: [String])

    // MARK: - Scan
    case scan(slug: String, barcode: String, visit: Bool, points: Int?, amountEur: Double?)

    // MARK: - Notifications
    case deviceRegister(token: String)

    // MARK: - Wallet (pass Apple Wallet)
    /// GET .../members/:memberId/pass — optionnellement avec design (organization_name, background_color, foreground_color, stamp_emoji, required_stamps) pour que le pass reflète la carte affichée.
    case walletPass(slug: String, memberId: String, design: WalletPassDesign?)

    // MARK: - Notifier les clients (message push / changeMessage)
    /// categoryIds: si nil ou vide = tous les membres ; sinon envoi limité à ces catégories.
    case notifyClients(slug: String, message: String, categoryIds: [String]?)

    // MARK: - Mise à jour carte (Ma Carte → SaaS)
    case updateCardSettings(slug: String, organizationName: String, backgroundColor: String, foregroundColor: String, requiredStamps: Int, logoBase64: String?, logoUrl: String?, locationAddress: String?, stampEmoji: String?, cardBackgroundBase64: String?)

    // MARK: - Membre : ajouter des points (caisse)
    case addMemberPoints(slug: String, memberId: String, points: Int)

    var path: String {
        switch self {
        case .authLogin: return "/api/auth/login"
        case .authGoogle: return "/api/auth/google"
        case .authApple: return "/api/auth/apple"
        case .authMe: return "/api/auth/me"
        case .authConfig: return "/api/auth/config"
        case .businessSettings(let slug): return "/api/businesses/\(slug)/dashboard/settings"
        case .businessStats(let slug): return "/api/businesses/\(slug)/dashboard/stats"
        case .businessMembers(let slug, _, _): return "/api/businesses/\(slug)/dashboard/members"
        case .businessTransactions(let slug, _, _): return "/api/businesses/\(slug)/dashboard/transactions"
        case .businessCategories(let slug): return "/api/businesses/\(slug)/dashboard/categories"
        case .createCategory(let slug, _, _): return "/api/businesses/\(slug)/dashboard/categories"
        case .updateCategory(let slug, let categoryId, _, _, _): return "/api/businesses/\(slug)/dashboard/categories/\(categoryId)"
        case .deleteCategory(let slug, let categoryId): return "/api/businesses/\(slug)/dashboard/categories/\(categoryId)"
        case .updateMemberCategories(let slug, let memberId, _): return "/api/businesses/\(slug)/dashboard/members/\(memberId)/categories"
        case .scan(let slug, _, _, _, _): return "/api/businesses/\(slug)/integration/scan"
        case .deviceRegister: return "/api/device/register"
        case .walletPass(let slug, let memberId, _): return "/api/businesses/\(slug)/members/\(memberId)/pass"
        case .notifyClients(let slug, _, _): return "/api/businesses/\(slug)/notify"
        case .updateCardSettings(let slug, _, _, _, _, _, _, _, _, _): return "/api/businesses/\(slug)/dashboard/settings"
        case .addMemberPoints(let slug, let memberId, _): return "/api/businesses/\(slug)/members/\(memberId)/points"
        }
    }

    var method: String {
        switch self {
        case .authLogin, .authGoogle, .authApple, .scan, .deviceRegister, .notifyClients, .createCategory, .updateMemberCategories, .addMemberPoints: return "POST"
        case .updateCardSettings, .updateCategory: return "PATCH"
        case .deleteCategory: return "DELETE"
        case .authMe, .authConfig, .businessSettings, .businessStats, .businessMembers, .businessTransactions, .businessCategories, .walletPass: return "GET"
        }
    }

    var isAuth: Bool {
        switch self {
        case .authLogin, .authGoogle, .authApple: return true
        default: return false
        }
    }

    func urlRequest(base: URL, encoder: JSONEncoder) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: base) else { throw APIError.invalidURL }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        switch self {
        case .businessMembers(_, let limit, let offset):
            var items: [URLQueryItem] = []
            if let l = limit { items.append(URLQueryItem(name: "limit", value: "\(l)")) }
            if let o = offset { items.append(URLQueryItem(name: "offset", value: "\(o)")) }
            components.queryItems = items.isEmpty ? nil : items
        case .businessTransactions(_, let limit, let offset):
            var items: [URLQueryItem] = []
            if let l = limit { items.append(URLQueryItem(name: "limit", value: "\(l)")) }
            if let o = offset { items.append(URLQueryItem(name: "offset", value: "\(o)")) }
            components.queryItems = items.isEmpty ? nil : items
        case .walletPass(_, _, let design):
            let template = design?.template.flatMap { $0.isEmpty ? nil : $0 } ?? "classic"
            var items = [URLQueryItem(name: "template", value: template)]
            if let d = design {
                if !d.organizationName.isEmpty { items.append(URLQueryItem(name: "organization_name", value: d.organizationName)) }
                if !d.backgroundColor.isEmpty { items.append(URLQueryItem(name: "background_color", value: d.backgroundColor)) }
                if !d.foregroundColor.isEmpty { items.append(URLQueryItem(name: "foreground_color", value: d.foregroundColor)) }
                if !d.stampEmoji.isEmpty { items.append(URLQueryItem(name: "stamp_emoji", value: d.stampEmoji)) }
                if d.requiredStamps > 0 { items.append(URLQueryItem(name: "required_stamps", value: "\(d.requiredStamps)")) }
            }
            components.queryItems = items
        default: break
        }
        guard let finalURL = components.url else { throw APIError.invalidURL }
        var bodyData: Data?
        switch self {
        case .authLogin(let email, let password):
            bodyData = try encoder.encode(LoginPayload(email: email, password: password))
        case .authGoogle(let idToken):
            bodyData = try encoder.encode(GooglePayload(idToken: idToken))
        case .authApple(let idToken, let name, let email):
            bodyData = try encoder.encode(ApplePayload(idToken: idToken, name: name, email: email))
        case .scan(_, let barcode, let visit, let points, let amountEur):
            bodyData = try encoder.encode(ScanPayload(barcode: barcode, visit: visit, points: points, amount_eur: amountEur))
        case .deviceRegister(let token):
            bodyData = try encoder.encode(DeviceRegisterPayload(deviceToken: token))
        case .notifyClients(_, let message, let categoryIds):
            bodyData = try encoder.encode(NotifyClientsPayload(message: message, categoryIds: categoryIds))
        case .createCategory(_, let name, let colorHex):
            bodyData = try encoder.encode(CreateCategoryPayload(name: name, colorHex: colorHex))
        case .updateCategory(_, _, let name, let colorHex, let sortOrder):
            bodyData = try encoder.encode(UpdateCategoryPayload(name: name, colorHex: colorHex, sortOrder: sortOrder))
        case .updateMemberCategories(_, _, let categoryIds):
            bodyData = try encoder.encode(UpdateMemberCategoriesPayload(categoryIds: categoryIds))
        case .addMemberPoints(_, _, let points):
            bodyData = try encoder.encode(AddMemberPointsPayload(points: points))
        case .updateCardSettings(_, let organizationName, let backgroundColor, let foregroundColor, let requiredStamps, let logoBase64, let logoUrl, let locationAddress, let stampEmoji, let cardBackgroundBase64):
            bodyData = try encoder.encode(UpdateCardSettingsPayload(
                organizationName: organizationName,
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor,
                requiredStamps: requiredStamps,
                logoBase64: logoBase64,
                logoUrl: logoUrl,
                locationAddress: locationAddress,
                stampEmoji: stampEmoji,
                cardBackgroundBase64: cardBackgroundBase64
            ))
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
}

private struct UpdateCategoryPayload: Encodable {
    let name: String?
    let colorHex: String?
    let sortOrder: Int?
}

private struct UpdateMemberCategoriesPayload: Encodable {
    let categoryIds: [String]
}

private struct AddMemberPointsPayload: Encodable {
    let points: Int
}

private struct UpdateCardSettingsPayload: Encodable {
    let organizationName: String
    let backgroundColor: String
    let foregroundColor: String
    let requiredStamps: Int
    let logoBase64: String?
    let logoUrl: String?
    let locationAddress: String?
    let stampEmoji: String?
    let cardBackgroundBase64: String?
}

/// Design à envoyer au backend pour que le pass généré reflète la carte affichée (couleurs, nom, emoji, tampons).
struct WalletPassDesign {
    var organizationName: String
    var backgroundColor: String
    var foregroundColor: String
    var stampEmoji: String
    var requiredStamps: Int
    /// Template pass : "cafe" pour style Café des Arts (tampons + libellés café).
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
