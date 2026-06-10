//
//  MerchantInternalBenchAccess.swift
//  myfidpass
//
//  Combinaison plafonds scan (passages / points) → accès commerçant équivalent abonnement payant (app uniquement).
//

import Foundation

enum MerchantInternalBenchAccess {
    static let benchMaxPassesPerDay = 102
    static let benchMaxPointsPerOperation = 102
    /// Palier IAP max (5 commerces) — accès test complet via 102 / 102.
    static let benchMaxAllowedBusinesses = 5

    static func matchesBenchCombo(passes: Int, points: Int) -> Bool {
        passes == benchMaxPassesPerDay && points == benchMaxPointsPerOperation
    }

    static var isActive: Bool {
        AuthStorage.merchantScanBenchAccessActive
    }

    @discardableResult
    static func sync(passes: Int, points: Int) -> Bool {
        let active = matchesBenchCombo(passes: passes, points: points)
        AuthStorage.merchantScanBenchAccessActive = active
        return active
    }
}
