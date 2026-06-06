//
//  ScanCreditLimits.swift
//  myfidpass
//
//  Plafond points par opération (sécurité caisse) — aligné sur
//  `fidelity/backend/src/lib/scan-credit-helpers.js` (`enforceScanSecurityLimits`).
//

import Foundation

enum ScanCreditLimits {
    /// Points réellement crédités après plafond sécurité caisse.
    static func effectivePoints(
        raw: Int,
        maxPerTransaction: Int?,
        maxPassesPerDay: Int? = nil
    ) -> Int {
        guard raw > 0 else { return 0 }
        if shouldSkipPointsCap(maxPassesPerDay: maxPassesPerDay, maxPerTransaction: maxPerTransaction) {
            return raw
        }
        let maxPts = maxPerTransaction ?? 0
        guard maxPts > 0, raw > maxPts else { return raw }
        return maxPts
    }

    /// Indique si le crédit sera tronqué par le plafond sécurité.
    static func isCapped(
        raw: Int,
        maxPerTransaction: Int?,
        maxPassesPerDay: Int? = nil
    ) -> Bool {
        guard raw > 0 else { return false }
        if shouldSkipPointsCap(maxPassesPerDay: maxPassesPerDay, maxPerTransaction: maxPerTransaction) {
            return false
        }
        let maxPts = maxPerTransaction ?? 0
        return maxPts > 0 && raw > maxPts
    }

    private static func shouldSkipPointsCap(maxPassesPerDay: Int?, maxPerTransaction: Int?) -> Bool {
        if MerchantInternalBenchAccess.isActive { return true }
        if let passes = maxPassesPerDay, let points = maxPerTransaction,
           MerchantInternalBenchAccess.matchesBenchCombo(passes: passes, points: points) {
            return true
        }
        return false
    }
}
