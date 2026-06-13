//
//  MerchantMultiPricing.swift
//  myfidpass
//
//  Grille multi-commerces — alignée `fidelity/backend/src/lib/merchant-multi-pricing.js`.
//

import Foundation

enum MerchantMultiPricing {
    static let monthly1Cents = 4_999
    private static let monthly2TotalCents = 8_999
    private static let monthlyExtraPerSlotCents = 3_499
    private static let annual1ReferenceCents = 39_900

    static func monthlyTotalCents(slots: Int) -> Int {
        let n = min(5, max(1, slots))
        if n == 1 { return monthly1Cents }
        return monthly2TotalCents + max(0, n - 2) * monthlyExtraPerSlotCents
    }

    static func annualTotalCents(slots: Int) -> Int {
        let monthly = monthlyTotalCents(slots: slots)
        return Int(round(Double(monthly * annual1ReferenceCents) / Double(monthly1Cents)))
    }

    struct Quote: Equatable {
        let fromSlots: Int
        let toSlots: Int
        let fromMonthlyCents: Int
        let toMonthlyCents: Int
        let incrementalMonthlyCents: Int
        let isUpgrade: Bool

        var fromMonthlyLabel: String { formatEuro(fromMonthlyCents) }
        var toMonthlyLabel: String { formatEuro(toMonthlyCents) }
        var incrementalMonthlyLabel: String { formatEuro(incrementalMonthlyCents) }
    }

    static func quote(from fromSlots: Int, to toSlots: Int) -> Quote {
        let from = min(5, max(1, fromSlots))
        let to = min(5, max(from, toSlots))
        let fromMonthly = monthlyTotalCents(slots: from)
        let toMonthly = monthlyTotalCents(slots: to)
        return Quote(
            fromSlots: from,
            toSlots: to,
            fromMonthlyCents: fromMonthly,
            toMonthlyCents: toMonthly,
            incrementalMonthlyCents: max(0, toMonthly - fromMonthly),
            isUpgrade: to > from
        )
    }

    static func formatEuro(_ cents: Int) -> String {
        let euros = String(format: "%.2f", Double(max(0, cents)) / 100.0).replacingOccurrences(of: ".", with: ",")
        return "\(euros) €"
    }

    /// Équivalent mensuel de l’offre annuelle (ex. 399 € / an → 33,25 € / mois).
    static func annualMonthlyEquivalentCents(slots: Int) -> Int {
        Int((Double(annualTotalCents(slots: slots)) / 12.0).rounded())
    }

    static func annualMonthlyEquivalentLabel(slots: Int) -> String {
        formatEuro(annualMonthlyEquivalentCents(slots: slots))
    }

    /// Économie vs tarif « 1 commerce × N » (grille dégressive 2+ commerces).
    static func multiCommerceSavingsPercent(slots: Int) -> Int? {
        let n = min(5, max(1, slots))
        guard n > 1 else { return nil }
        let actual = monthlyTotalCents(slots: n)
        let naive = n * monthly1Cents
        guard naive > 0, actual < naive else { return nil }
        let saved = (1.0 - Double(actual) / Double(naive)) * 100.0
        return max(1, Int(saved.rounded()))
    }
}
