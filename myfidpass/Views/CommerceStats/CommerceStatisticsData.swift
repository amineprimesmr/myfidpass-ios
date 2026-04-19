//
//  CommerceStatisticsData.swift
//  myfidpass
//
//  Projection des DTO API vers les modèles d’affichage (indicateurs clés, panier réel, fréquence, segments).
//

import SwiftUI

struct CommerceDonutSegment: Identifiable, Hashable {
    let id: String
    let fraction: Double
    let color: Color
    let label: String
}

struct CommerceCategoryRowData: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let rightPrimary: String
    let rightSecondary: String
    let iconName: String
    let swatch: Color
}

struct CommerceBarWeekData: Identifiable, Hashable {
    let id: String
    let label: String
    let value: CGFloat
}

struct CommerceStatisticsPresentation {
    let panierMoyenEuro: Double?
    /// Visites (transactions) par membre actif sur la période.
    let frequenceParActif: Double?
    let trendPanierDeltaEuro: Double?
    let trendFrequenceDelta: Double?
    let donutSegments: [CommerceDonutSegment]
    let categoryRows: [CommerceCategoryRowData]
    let barWeeksOperations: [CommerceBarWeekData]
    let membersTotal: Int?
    let activeMembers: Int?
    let retentionPct: Double?
}

enum CommerceStatisticsDataBuilder {
    static func build(stats: BusinessStatsResponse?, evolution: [EvolutionWeekDTO]) -> CommerceStatisticsPresentation {
        let tx = CGFloat(stats?.transactionsThisMonth ?? 0)
        let points = CGFloat(stats?.pointsThisMonth ?? 0)
        let newM = CGFloat(stats?.newMembersInPeriod ?? stats?.newMembersLast30Days ?? 0)
        let active = CGFloat(stats?.activeMembersInPeriod ?? 0)
        let members = stats?.membersCount
        let sumActivity = max(1, tx + points * 0.02 + newM * 2 + active * 0.5)
        let fTx = Double(tx / sumActivity)
        let fPts = Double((points * 0.02) / sumActivity)
        let fNew = Double((newM * 2) / sumActivity)
        let fAct = Double((active * 0.5) / sumActivity)
        let fracSum = max(1e-6, fTx + fPts + fNew + fAct)

        let colors = CommerceStatisticsTheme.segmentColors
        let donut: [CommerceDonutSegment] = [
            .init(id: "tx", fraction: fTx / fracSum, color: colors[0], label: "Transactions"),
            .init(id: "pts", fraction: fPts / fracSum, color: colors[1], label: "Points"),
            .init(id: "new", fraction: fNew / fracSum, color: colors[2], label: "Nouveaux"),
            .init(id: "act", fraction: fAct / fracSum, color: colors[3], label: "Actifs"),
        ]

        let txI = stats?.transactionsThisMonth ?? 0
        let ptsI = stats?.pointsThisMonth ?? 0
        let newI = stats?.newMembersLast30Days ?? 0
        let newInPeriod = stats?.newMembersInPeriod ?? newI
        let actI = stats?.activeMembersInPeriod ?? 0
        let rewardsN = stats?.rewardsRedeemedCount ?? 0
        let ptsRedeemed = stats?.pointsRedeemedInPeriod ?? 0
        let googleRev = stats?.googleReviewsNewInPeriod ?? 0
        let wTx = Double(txI)
        let wPts = Double(ptsI) * 0.05
        let wNew = Double(newInPeriod) * 3
        let wAct = Double(actI)
        let wRew = Double(rewardsN) * 8
        let wPtsOut = Double(ptsRedeemed) * 0.05
        let wG = Double(googleRev) * 15
        let inactiveN = stats?.inactiveMembers30Days ?? 0
        let wInact = Double(inactiveN) * 0.4
        let tw = max(1, wTx + wPts + wNew + wAct + wRew + wPtsOut + wG + wInact)
        func weightPct(_ w: Double) -> String {
            String(format: "%.0f %%", min(100, (w / tw) * 100))
        }

        let rows: [CommerceCategoryRowData] = [
            .init(
                id: "tx",
                title: "Transactions",
                subtitle: txI == 1 ? "1 opération" : "\(StatsFR.formatInt(txI)) opérations",
                rightPrimary: "+\(StatsFR.formatInt(txI))",
                rightSecondary: weightPct(wTx),
                iconName: "arrow.left.arrow.right",
                swatch: colors[0]
            ),
            .init(
                id: "pts",
                title: "Points attribués",
                subtitle: "Fidélité",
                rightPrimary: "+\(StatsFR.formatInt(ptsI))",
                rightSecondary: weightPct(wPts),
                iconName: "star.fill",
                swatch: colors[1]
            ),
            .init(
                id: "new",
                title: "Nouveaux membres",
                subtitle: "Inscriptions sur la période",
                rightPrimary: "+\(StatsFR.formatInt(newInPeriod))",
                rightSecondary: weightPct(wNew),
                iconName: "person.badge.plus",
                swatch: colors[2]
            ),
            .init(
                id: "act",
                title: "Clients actifs",
                subtitle: "≥ 1 passage sur la période",
                rightPrimary: StatsFR.formatInt(actI),
                rightSecondary: weightPct(wAct),
                iconName: "person.3.fill",
                swatch: colors[3]
            ),
            .init(
                id: "inact",
                title: "Clients inactifs",
                subtitle: "Aucun passage depuis 30 j.",
                rightPrimary: StatsFR.formatInt(inactiveN),
                rightSecondary: weightPct(wInact),
                iconName: "moon.zzz.fill",
                swatch: Color(red: 0.55, green: 0.55, blue: 0.62)
            ),
            .init(
                id: "rewards",
                title: "Récompenses utilisées",
                subtitle: rewardsN == 1 ? "1 échange" : "\(StatsFR.formatInt(rewardsN)) échanges",
                rightPrimary: StatsFR.formatInt(rewardsN),
                rightSecondary: weightPct(wRew),
                iconName: "gift.fill",
                swatch: Color(red: 0.98, green: 0.42, blue: 0.42)
            ),
            .init(
                id: "ptsout",
                title: "Points dépensés",
                subtitle: "Fidélité",
                rightPrimary: StatsFR.formatInt(ptsRedeemed),
                rightSecondary: weightPct(wPtsOut),
                iconName: "arrow.down.circle.fill",
                swatch: Color(red: 0.55, green: 0.65, blue: 0.98)
            ),
            .init(
                id: "grev",
                title: "Avis Google (nouveaux)",
                subtitle: "Détectés sur la période",
                rightPrimary: "+\(StatsFR.formatInt(googleRev))",
                rightSecondary: weightPct(wG),
                iconName: "star.bubble.fill",
                swatch: Color(red: 0.26, green: 0.52, blue: 0.96)
            ),
        ]

        let panier: Double? = {
            guard let api = stats?.avgBasketEur, api > 0 else { return nil }
            return api
        }()

        let freq: Double? = {
            if let api = stats?.avgVisitsPerActiveMember, api > 0 { return api }
            guard actI > 0, txI > 0 else { return nil }
            return Double(txI) / Double(actI)
        }()

        let opsSeries: [Int] = evolution.compactMap { $0.operationsCount }
        let bars: [CommerceBarWeekData] = {
            let raw: [CGFloat] = opsSeries.map { CGFloat($0) }
            let maxV = max(raw.max() ?? 1, 1)
            return raw.enumerated().map { i, v in
                .init(id: "w\(i)", label: segmentLabel(index: i, total: raw.count), value: v / maxV)
            }
        }()

        let (dPanier, dFreq) = trendDeltas(evolution: evolution, stats: stats)

        return CommerceStatisticsPresentation(
            panierMoyenEuro: panier,
            frequenceParActif: freq,
            trendPanierDeltaEuro: dPanier,
            trendFrequenceDelta: dFreq,
            donutSegments: donut,
            categoryRows: rows,
            barWeeksOperations: bars.isEmpty ? defaultPlaceholderBars() : bars,
            membersTotal: members,
            activeMembers: stats?.activeMembersInPeriod,
            retentionPct: stats?.retentionPct
        )
    }

    private static func segmentLabel(index: Int, total: Int) -> String {
        guard total > 1 else { return "S" }
        if total <= 5 {
            return "\(index + 1)"
        }
        if index == total - 1 { return "S" }
        return "\(index + 1)"
    }

    private static func defaultPlaceholderBars() -> [CommerceBarWeekData] {
        let heights: [CGFloat] = [0.35, 0.85, 0.5, 0.4, 0.2]
        return (0..<5).map { i in
            .init(id: "p\(i)", label: "\(i + 1)", value: heights[i])
        }
    }

    /// Tendance grossière : compare les deux dernières valeurs d’évolution (opérations).
    private static func trendDeltas(evolution: [EvolutionWeekDTO], stats: BusinessStatsResponse?) -> (Double?, Double?) {
        let ops = evolution.compactMap { $0.operationsCount }
        guard ops.count >= 2 else { return (nil, nil) }
        let last = ops[ops.count - 1]
        let prev = ops[ops.count - 2]
        guard prev > 0 else { return (nil, nil) }
        let freqDelta = (Double(last - prev) / Double(prev)) * 100
        var dPanier: Double? = nil
        if let basket = stats?.avgBasketEur, basket > 0 {
            dPanier = Double(last - prev) * basket
        }
        return (dPanier, freqDelta)
    }
}
