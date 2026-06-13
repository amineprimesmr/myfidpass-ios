//
//  APIDTOs+14_POST.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

// MARK: - POST .../members/:memberId/redeem

struct RedeemResponse: Decodable {
    let ok: Bool?
    let type: String?
    let newPoints: Int?
    let previousPoints: Int?
    let pointsDeducted: Int?
    let message: String?
}

