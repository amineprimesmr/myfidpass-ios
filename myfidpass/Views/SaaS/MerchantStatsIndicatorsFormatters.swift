import Foundation

// MARK: - Formatters FR

enum StatsFR {
    private static let intFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "fr_FR")
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }()

    private static let euroFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "fr_FR")
        f.groupingSeparator = " "
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    /// Montants de transaction (fil d’activité, fiche membre) — toujours 2 décimales (ex. 13,90 €, pas 13,9 €).
    private static let transactionEuroFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "fr_FR")
        f.groupingSeparator = " "
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    static func formatInt(_ n: Int) -> String {
        intFormatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    static func formatEuro(_ n: Double) -> String {
        euroFormatter.string(from: NSNumber(value: n)) ?? String(format: "%.2f", n)
    }

    static func formatTransactionEuro(_ n: Double) -> String {
        transactionEuroFormatter.string(from: NSNumber(value: abs(n)))
            ?? String(format: "%.2f", abs(n))
    }

    static func formatPct(_ pct: Double) -> String {
        String(format: "%.0f %%", pct)
    }

    /// Tendance affichable : jamais de valeur négative ou nulle (rien plutôt qu’un −%).
    static func displayableTrendPct(_ raw: Double?) -> Double? {
        guard let raw, raw > 0.05 else { return nil }
        return raw
    }

    /// Variation € affichable : uniquement les hausses.
    static func displayableTrendEuro(_ raw: Double?) -> Double? {
        guard let raw, raw > 0.009 else { return nil }
        return raw
    }

    static func positiveTrendPctText(_ pct: Double) -> String {
        let formatted = formatPct(pct).replacingOccurrences(of: " %", with: "%")
        return "+\(formatted)"
    }

    static func formatDoubleSmart(_ v: Double) -> String {
        let rounded = v.rounded()
        if abs(v - rounded) < 1e-9 {
            return intFormatter.string(from: NSNumber(value: Int(rounded))) ?? "\(Int(rounded))"
        }
        // 1 decimal maximum (ex: points moyens)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "fr_FR")
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        f.groupingSeparator = " "
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }
}

