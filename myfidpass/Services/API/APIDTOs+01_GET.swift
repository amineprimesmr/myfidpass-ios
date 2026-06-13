//
//  APIDTOs+01_GET.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

// MARK: - GET /api/auth/config

struct AuthConfigResponse: Decodable {
    let googleClientId: String?
}

