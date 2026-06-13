//
//  APIDTOs+09_GET.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

// MARK: - GET .../dashboard/stats/traffic

struct DashboardTrafficHourBucketDTO: Codable, Sendable {
    let hour: Int
    let count: Int
}

struct DashboardTrafficWeekdayBucketDTO: Codable, Sendable {
    let weekday: Int
    let label: String?
    let count: Int
}

struct DashboardTrafficPeakHourDTO: Codable, Sendable {
    let hour: Int
    let count: Int
    let pctOfTotal: Double?
}

struct DashboardTrafficPeakWeekdayDTO: Codable, Sendable {
    let weekday: Int
    let label: String?
    let count: Int
    let pctOfTotal: Double?
}

struct DashboardTrafficPatternsResponse: Codable, Sendable {
    let period: String?
    let periodKey: String?
    let timezoneNote: String?
    /// Ex. `points_add_and_reward_redeem` — crédits caisse + utilisations récompense.
    let basis: String?
    let totalEvents: Int?
    let byHour: [DashboardTrafficHourBucketDTO]?
    let byWeekday: [DashboardTrafficWeekdayBucketDTO]?
    let peakHour: DashboardTrafficPeakHourDTO?
    let peakWeekday: DashboardTrafficPeakWeekdayDTO?
}

