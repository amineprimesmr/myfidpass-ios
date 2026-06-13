//
//  APIDTOs+15_POST.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

// MARK: - POST .../members/:memberId/points/remove

struct RemoveMemberPointsResponse: Decodable {
    let id: String?
    let points: Int?
    let pointsRemoved: Int?
}

