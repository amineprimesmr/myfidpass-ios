//
//  CommerceStatisticDetailTopic.swift
//  myfidpass
//
//  Drill-down « style Revolut » depuis le tableau de bord statistiques Commerce.
//

import Foundation
import SwiftUI

enum CommerceStatisticDetailTopic: String, Hashable {
    case activeClients
    case newMembers
    case cardsIssued

    var screenTitle: String {
        switch self {
        case .activeClients: return "Clients actifs"
        case .newMembers: return "Nouveaux membres"
        case .cardsIssued: return "Cartes émises"
        }
    }

    func primaryMetric(from stats: BusinessStatsResponse?) -> String {
        switch self {
        case .activeClients:
            guard let audience = normalizedMonthlyAudience(from: stats) else { return "—" }
            let n = audience.active
            return StatsFR.formatInt(n)
        case .newMembers:
            guard let n = stats?.newMembersInPeriod ?? stats?.newMembersLast30Days else { return "—" }
            return StatsFR.formatInt(n)
        case .cardsIssued:
            guard let n = stats?.membersCount else { return "—" }
            return StatsFR.formatInt(n)
        }
    }

    /// Série affichée dans le graphique (échelle cohérente avec le libellé `chartFootnote`).
    func chartValues(from evolution: [EvolutionWeekDTO]) -> [Int] {
        switch self {
        case .activeClients:
            return evolution.compactMap { $0.operationsCount }
        case .newMembers:
            let m = evolution.compactMap { $0.membersCount }
            guard m.count >= 2 else { return m }
            var deltas: [Int] = []
            for i in 1..<m.count {
                deltas.append(max(0, m[i] - m[i - 1]))
            }
            return deltas.isEmpty ? m : deltas
        case .cardsIssued:
            return evolution.compactMap { $0.membersCount }
        }
    }

    var chartFootnote: String {
        switch self {
        case .activeClients:
            return "Courbe : opérations par intervalle — indicateur de fréquentation magasin."
        case .newMembers:
            return "Courbe : variation du nombre de membres entre intervalles (approximation des inscriptions)."
        case .cardsIssued:
            return "Courbe : membres cumulés (fin de chaque intervalle)."
        }
    }

    func breakdownRows(stats: BusinessStatsResponse?) -> [CommerceCategoryRowData] {
        guard let s = stats else { return [] }
        let total = max(s.membersCount ?? 1, 1)
        let colors = CommerceStatisticsTheme.segmentColors
        let audience = normalizedMonthlyAudience(from: stats)

        switch self {
        case .newMembers:
            let newP = s.newMembersInPeriod ?? s.newMembersLast30Days ?? 0
            let act = audience?.active ?? 0
            let inact = audience?.inactive30 ?? 0
            let m = s.membersCount ?? 0
            let pctNew = m > 0 ? min(100, (Double(newP) / Double(m)) * 100) : 0
            let pctAct = m > 0 ? min(100, (Double(act) / Double(m)) * 100) : 0
            let pctInact = m > 0 ? min(100, (Double(inact) / Double(m)) * 100) : 0
            return [
                .init(
                    id: "new",
                    title: "Nouveaux membres",
                    subtitle: "Inscriptions sur la période",
                    rightPrimary: "+\(StatsFR.formatInt(newP))",
                    rightSecondary: String(format: "%.0f %%", pctNew),
                    iconName: "person.badge.plus",
                    swatch: colors[2]
                ),
                .init(
                    id: "act",
                    title: "Clients actifs",
                    subtitle: "≥ 1 passage sur 30 j.",
                    rightPrimary: StatsFR.formatInt(act),
                    rightSecondary: String(format: "%.0f %%", pctAct),
                    iconName: "person.3.fill",
                    swatch: colors[3]
                ),
                .init(
                    id: "inact",
                    title: "Inactifs (30 j.)",
                    subtitle: "Sans passage récent",
                    rightPrimary: StatsFR.formatInt(inact),
                    rightSecondary: String(format: "%.0f %%", pctInact),
                    iconName: "moon.zzz.fill",
                    swatch: Color(red: 0.55, green: 0.55, blue: 0.62)
                ),
            ]
        case .activeClients:
            let act = audience?.active ?? 0
            let newP = s.newMembersInPeriod ?? s.newMembersLast30Days ?? 0
            let inact = audience?.inactive30 ?? 0
            let pctAct = min(100, (Double(act) / Double(total)) * 100)
            let pctNew = min(100, (Double(newP) / Double(total)) * 100)
            let pctInact = min(100, (Double(inact) / Double(total)) * 100)
            return [
                .init(
                    id: "act",
                    title: "Clients actifs",
                    subtitle: "≥ 1 passage sur 30 j.",
                    rightPrimary: StatsFR.formatInt(act),
                    rightSecondary: String(format: "%.0f %%", pctAct),
                    iconName: "person.3.fill",
                    swatch: colors[3]
                ),
                .init(
                    id: "new",
                    title: "Nouveaux membres",
                    subtitle: "Inscriptions sur la période",
                    rightPrimary: "+\(StatsFR.formatInt(newP))",
                    rightSecondary: String(format: "%.0f %%", pctNew),
                    iconName: "person.badge.plus",
                    swatch: colors[2]
                ),
                .init(
                    id: "inact",
                    title: "Inactifs (30 j.)",
                    subtitle: "Sans passage récent",
                    rightPrimary: StatsFR.formatInt(inact),
                    rightSecondary: String(format: "%.0f %%", pctInact),
                    iconName: "moon.zzz.fill",
                    swatch: Color(red: 0.55, green: 0.55, blue: 0.62)
                ),
            ]
        case .cardsIssued:
            let act = audience?.active ?? 0
            let newP = s.newMembersInPeriod ?? s.newMembersLast30Days ?? 0
            let m = s.membersCount ?? 0
            let pctAct = m > 0 ? min(100, (Double(act) / Double(m)) * 100) : 0
            let pctNew = m > 0 ? min(100, (Double(newP) / Double(m)) * 100) : 0
            return [
                .init(
                    id: "cards",
                    title: "Cartes actives",
                    subtitle: "Membres inscrits",
                    rightPrimary: StatsFR.formatInt(m),
                    rightSecondary: "100 %",
                    iconName: "creditcard.fill",
                    swatch: CommerceStatisticsTheme.accentBlue
                ),
                .init(
                    id: "act",
                    title: "Dont actifs",
                    subtitle: "Sur 30 jours",
                    rightPrimary: StatsFR.formatInt(act),
                    rightSecondary: String(format: "%.0f %%", pctAct),
                    iconName: "person.3.fill",
                    swatch: colors[3]
                ),
                .init(
                    id: "new",
                    title: "Nouveaux",
                    subtitle: "Inscriptions période",
                    rightPrimary: "+\(StatsFR.formatInt(newP))",
                    rightSecondary: String(format: "%.0f %%", pctNew),
                    iconName: "person.badge.plus",
                    swatch: colors[2]
                ),
            ]
        }
    }
}

private extension CommerceStatisticDetailTopic {
    func normalizedMonthlyAudience(from stats: BusinessStatsResponse?) -> (members: Int, active: Int, inactive30: Int)? {
        guard let s = stats else { return nil }
        let members = max(0, s.membersCount ?? 0)
        guard members > 0 else { return nil }
        let inactive = min(members, max(0, s.inactiveMembers30Days ?? 0))
        let active = max(0, members - inactive)
        return (members, active, inactive)
    }
}
