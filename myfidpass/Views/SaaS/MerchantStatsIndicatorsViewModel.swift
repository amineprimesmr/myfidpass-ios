import Foundation
import SwiftUI
import Combine

// MARK: - UI Models

struct MerchantStatsKpiCardModel: Identifiable, Hashable {
    enum Kind: Hashable {
        case value
        case ratio
    }

    let id: String
    let title: String
    let value: String
    let subtitle: String?
    let kind: Kind
    let ratioPercent: Double?
    let accessibilityLabel: String
}

struct MerchantStatsKpiSectionModel: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let cards: [MerchantStatsKpiCardModel]
}

struct MerchantStatsInsightCalloutModel: Identifiable, Hashable {
    let id = UUID()
    let icon: String
    let title: String
    let dataLine: String
    let nextStep: String
    let accessibilityLabel: String
}

// MARK: - ViewModel

@MainActor
final class MerchantStatsIndicatorsViewModel: ObservableObject {
    @Published private(set) var stats: BusinessStatsResponse?
    @Published private(set) var evolution: [EvolutionWeekDTO] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    func load(period: String) async {
        guard let slug = AuthStorage.currentBusinessSlug, !slug.isEmpty else {
            stats = nil
            evolution = []
            errorMessage = "Aucun commerce sélectionné."
            return
        }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let weeks = Self.weeksToRequest(for: period)
            let gotStats: BusinessStatsResponse = try await APIClient.shared.request(.businessStats(slug: slug, period: period))
            let gotEv: DashboardEvolutionResponse = try await APIClient.shared.request(
                .businessEvolution(slug: slug, weeks: weeks, period: period)
            )
            stats = gotStats
            evolution = gotEv.evolution
        } catch {
            // Ne pas casser l’UI sur un échec : on garde l’état courant si présent.
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            if stats == nil { evolution = [] }
        }
    }

    var kpiSections: [MerchantStatsKpiSectionModel] {
        guard let s = stats else { return [] }

        var audienceCards: [MerchantStatsKpiCardModel] = []
        if let members = s.membersCount {
            audienceCards.append(
                .init(
                    id: "members",
                    title: "Membres",
                    value: StatsFR.formatInt(members),
                    subtitle: nil,
                    kind: .value,
                    ratioPercent: nil,
                    accessibilityLabel: "Membres, \(StatsFR.formatInt(members))"
                )
            )
        }
        if let actives = s.activeMembersInPeriod {
            audienceCards.append(
                .init(
                    id: "actives",
                    title: "Actifs",
                    value: StatsFR.formatInt(actives),
                    subtitle: nil,
                    kind: .value,
                    ratioPercent: nil,
                    accessibilityLabel: "Actifs, \(StatsFR.formatInt(actives))"
                )
            )
        }
        if let recurrent = s.recurrentMembersInPeriod {
            audienceCards.append(
                .init(
                    id: "recurrent",
                    title: "Fidèles",
                    value: StatsFR.formatInt(recurrent),
                    subtitle: "≥ 10 visites / période",
                    kind: .value,
                    ratioPercent: nil,
                    accessibilityLabel: "Fidèles, \(StatsFR.formatInt(recurrent)), au moins dix visites sur la période"
                )
            )
        }

        if let members = s.membersCount, let actives = s.activeMembersInPeriod, members > 0 {
            let pct = (Double(actives) / Double(members)) * 100
            audienceCards.append(
                .init(
                    id: "activeRate",
                    title: "Taux d'actifs",
                    value: StatsFR.formatPct(pct),
                    subtitle: "Actifs / Membres",
                    kind: .ratio,
                    ratioPercent: pct,
                    accessibilityLabel: "Taux d'actifs, \(StatsFR.formatPct(pct))"
                )
            )
        }

        if let actives = s.activeMembersInPeriod, let recurrent = s.recurrentMembersInPeriod, actives > 0 {
            let pct = (Double(recurrent) / Double(actives)) * 100
            audienceCards.append(
                .init(
                    id: "recurrentRate",
                    title: "Fidèles / actifs",
                    value: StatsFR.formatPct(pct),
                    subtitle: "≥ 10 visites / période",
                    kind: .ratio,
                    ratioPercent: pct,
                    accessibilityLabel: "Part de fidèles parmi les actifs, \(StatsFR.formatPct(pct))"
                )
            )
        }

        var acquisitionCards: [MerchantStatsKpiCardModel] = []
        if let new7 = s.newMembersLast7Days {
            acquisitionCards.append(
                .init(
                    id: "new7",
                    title: "Nouveaux (7 j)",
                    value: StatsFR.formatInt(new7),
                    subtitle: nil,
                    kind: .value,
                    ratioPercent: nil,
                    accessibilityLabel: "Nouveaux sur 7 jours, \(StatsFR.formatInt(new7))"
                )
            )
        }
        if let new30 = s.newMembersLast30Days {
            acquisitionCards.append(
                .init(
                    id: "new30",
                    title: "Nouveaux (30 j)",
                    value: StatsFR.formatInt(new30),
                    subtitle: nil,
                    kind: .value,
                    ratioPercent: nil,
                    accessibilityLabel: "Nouveaux sur 30 jours, \(StatsFR.formatInt(new30))"
                )
            )
        }
        if let inact30 = s.inactiveMembers30Days {
            acquisitionCards.append(
                .init(
                    id: "inactive30",
                    title: "Inactifs (30 j)",
                    value: StatsFR.formatInt(inact30),
                    subtitle: nil,
                    kind: .value,
                    ratioPercent: nil,
                    accessibilityLabel: "Inactifs sur 30 jours, \(StatsFR.formatInt(inact30))"
                )
            )
        }
        if let inact90 = s.inactiveMembers90Days {
            acquisitionCards.append(
                .init(
                    id: "inactive90",
                    title: "Inactifs (90 j)",
                    value: StatsFR.formatInt(inact90),
                    subtitle: nil,
                    kind: .value,
                    ratioPercent: nil,
                    accessibilityLabel: "Inactifs sur 90 jours, \(StatsFR.formatInt(inact90))"
                )
            )
        }

        if let members = s.membersCount, let inact30 = s.inactiveMembers30Days, members > 0 {
            let churnPct = (Double(inact30) / Double(members)) * 100
            acquisitionCards.append(
                .init(
                    id: "churn30Rate",
                    title: "Churn (30 j)",
                    value: StatsFR.formatPct(churnPct),
                    subtitle: "Inactifs / Membres",
                    kind: .ratio,
                    ratioPercent: churnPct,
                    accessibilityLabel: "Churn sur 30 jours, \(StatsFR.formatPct(churnPct))"
                )
            )
        }

        var engagementCards: [MerchantStatsKpiCardModel] = []
        if let retention = s.retentionPct {
            engagementCards.append(
                .init(
                    id: "retention",
                    title: "Rétention",
                    value: StatsFR.formatPct(retention),
                    subtitle: "Taux de retour",
                    kind: .ratio,
                    ratioPercent: retention,
                    accessibilityLabel: "Rétention, \(StatsFR.formatPct(retention))"
                )
            )
        }
        if let points = s.pointsThisMonth {
            engagementCards.append(
                .init(
                    id: "points",
                    title: "Points",
                    value: StatsFR.formatInt(points),
                    subtitle: "Ce mois",
                    kind: .value,
                    ratioPercent: nil,
                    accessibilityLabel: "Points, \(StatsFR.formatInt(points))"
                )
            )
        }
        if let tx = s.transactionsThisMonth {
            engagementCards.append(
                .init(
                    id: "transactions",
                    title: "Transactions",
                    value: StatsFR.formatInt(tx),
                    subtitle: "Ce mois",
                    kind: .value,
                    ratioPercent: nil,
                    accessibilityLabel: "Transactions, \(StatsFR.formatInt(tx))"
                )
            )
        }
        if let avg = s.pointsAveragePerMember {
            engagementCards.append(
                .init(
                    id: "avgPointsPerMember",
                    title: "Points moyens / membre",
                    value: StatsFR.formatDoubleSmart(avg),
                    subtitle: nil,
                    kind: .value,
                    ratioPercent: nil,
                    accessibilityLabel: "Points moyens par membre, \(StatsFR.formatDoubleSmart(avg))"
                )
            )
        }

        var monetizationCards: [MerchantStatsKpiCardModel] = []
        if let avg = s.avgBasketEur, avg > 0 {
            monetizationCards.append(
                .init(
                    id: "avgBasketReal",
                    title: "Panier moyen",
                    value: StatsFR.formatEuro(avg),
                    subtitle: "Montants € saisis",
                    kind: .value,
                    ratioPercent: nil,
                    accessibilityLabel: "Panier moyen, \(StatsFR.formatEuro(avg))"
                )
            )
        }

        var sections: [MerchantStatsKpiSectionModel] = []
        if !audienceCards.isEmpty {
            sections.append(.init(title: "Audience", cards: audienceCards))
        }
        if !acquisitionCards.isEmpty {
            sections.append(.init(title: "Acquisition & churn", cards: acquisitionCards))
        }
        if !engagementCards.isEmpty {
            sections.append(.init(title: "Engagement & performance", cards: engagementCards))
        }
        if !monetizationCards.isEmpty {
            sections.append(.init(title: "Panier", cards: monetizationCards))
        }

        return sections
    }

    var insightCallouts: [MerchantStatsInsightCalloutModel] {
        guard let s = stats else { return [] }

        var callouts: [MerchantStatsInsightCalloutModel] = []

        if let retention = s.retentionPct {
            let kind: (String, String, String) = {
                if retention >= 65 { return ("checkmark.seal.fill", "Rétention solide", "À conserver") }
                if retention >= 45 { return ("hand.thumbsup.fill", "Rétention correcte", "Optimiser") }
                return ("exclamationmark.triangle.fill", "Rétention à renforcer", "Prioriser le réengagement")
            }()
            callouts.append(
                .init(
                    icon: kind.0,
                    title: kind.1,
                    dataLine: "Rétention : \(StatsFR.formatPct(retention))",
                    nextStep: "Proposez une relance ciblée aux profils proches du départ. (À partir de vos segments actuels)",
                    accessibilityLabel: "\(kind.1). \(StatsFR.formatPct(retention))"
                )
            )
        }

        if let members = s.membersCount, let inact30 = s.inactiveMembers30Days, members > 0 {
            let churnPct = (Double(inact30) / Double(members)) * 100
            let kind: (String, String, String) = {
                if churnPct <= 10 { return ("sparkles", "Churn faible", "Conserver la dynamique") }
                if churnPct <= 20 { return ("wand.and.rays", "Churn modéré", "Cibler les contacts à réactiver") }
                return ("slowdown", "Churn élevé", "Accélérer le réengagement")
            }()
            callouts.append(
                .init(
                    icon: kind.0,
                    title: kind.1,
                    dataLine: "Inactifs (30 j) : \(StatsFR.formatInt(inact30)) — \(StatsFR.formatPct(churnPct))",
                    nextStep: "Lancez une campagne segmentée pour réveiller les profils inactifs (ex. dernière visite).",
                    accessibilityLabel: "\(kind.1). \(StatsFR.formatPct(churnPct))"
                )
            )
        }

        // Audience trend from evolution (members preferred, fallback to operations).
        let trend = Self.computeTrend(in: evolution)
        if let trend {
            let title: String
            let icon: String
            if trend.deltaPct >= 10 {
                title = "Audience en reprise"
                icon = "arrow.up.right.circle.fill"
            } else if trend.deltaPct <= -10 {
                title = "Audience en baisse"
                icon = "arrow.down.left.circle.fill"
            } else {
                title = "Audience en plateau"
                icon = "minus.circle.fill"
            }
            callouts.append(
                .init(
                    icon: icon,
                    title: title,
                    dataLine: "Tendance : \(trend.deltaSign)\(StatsFR.formatPct(abs(trend.deltaPct))) (à partir des dernières semaines)",
                    nextStep: "Si la tendance stagne : testez 1 levier (offre, message, fréquence) et suivez l’évolution sur la période.",
                    accessibilityLabel: "\(title). \(trend.deltaPct)"
                )
            )
        }

        // Conserver un max 3 callouts pour la lisibilité.
        return Array(callouts.prefix(3))
    }

    var isEmptyForPeriod: Bool {
        (stats == nil || kpiSections.isEmpty) && evolution.isEmpty
    }

    private static func weeksToRequest(for period: String) -> Int {
        switch period {
        case "7d": return 2
        case "30d": return 8
        case "this_month": return 8
        case "6m": return 16
        case "12m", "1y": return 26
        default: return 8
        }
    }

    private static func computeTrend(in evolution: [EvolutionWeekDTO]) -> (deltaPct: Double, deltaSign: String)? {
        // Prefer membersCount; if missing, fallback to operationsCount.
        let membersValues: [Int] = evolution.compactMap { $0.membersCount }
        let opsValues: [Int] = evolution.compactMap { $0.operationsCount }

        if let last = membersValues.last, let prev = membersValues.dropLast().last {
            return Self.trendFrom(prev: prev, last: last)
        }
        if let last = opsValues.last, let prev = opsValues.dropLast().last {
            return Self.trendFrom(prev: prev, last: last)
        }
        return nil
    }

    private static func trendFrom(prev: Int, last: Int) -> (deltaPct: Double, deltaSign: String)? {
        guard prev != 0 else {
            // Si précédent à 0 : on ne calcule pas une % trompeuse.
            let delta = Double(last - prev)
            if delta == 0 { return (0, "") }
            return (delta > 0 ? 100 : -100, delta > 0 ? "+" : "-")
        }
        let deltaPct = (Double(last - prev) / Double(prev)) * 100
        return (deltaPct, deltaPct >= 0 ? "+" : "-")
    }
}

