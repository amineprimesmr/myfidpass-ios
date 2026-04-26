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
    /// Si présent, affiche une barre unique actifs/inactifs dans la ligne.
    let audienceSplit: CommerceAudienceSplitData?
    /// Détail des récompenses échangées (ligne « Récompenses utilisées » uniquement).
    let rewardUsageLines: [RewardRedeemedBreakdownRowDTO]?

    init(
        id: String,
        title: String,
        subtitle: String,
        rightPrimary: String,
        rightSecondary: String,
        iconName: String,
        swatch: Color,
        audienceSplit: CommerceAudienceSplitData? = nil,
        rewardUsageLines: [RewardRedeemedBreakdownRowDTO]? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.rightPrimary = rightPrimary
        self.rightSecondary = rightSecondary
        self.iconName = iconName
        self.swatch = swatch
        self.audienceSplit = audienceSplit
        self.rewardUsageLines = rewardUsageLines
    }
}

struct CommerceAudienceSplitData: Hashable {
    let activeCount: Int
    let inactiveCount: Int

    var total: Int { max(1, activeCount + inactiveCount) }
    var activeFraction: Double { Double(activeCount) / Double(total) }
    var inactiveFraction: Double { Double(inactiveCount) / Double(total) }
}

struct CommerceBarWeekData: Identifiable, Hashable {
    let id: String
    let label: String
    let value: CGFloat
}

struct CommerceStatisticsPresentation {
    let panierMoyenEuro: Double?
    /// Panier moyen « repère » défini par le commerçant (€).
    let panierRepereEuro: Double?
    /// Si panier mesuré et repère > 0 : (mesuré − repère) / repère × 100.
    let panierMesureVsReperePct: Double?
    /// Visites (transactions) par membre actif sur la période.
    let frequenceParActif: Double?
    let trendPanierDeltaEuro: Double?
    let trendFrequenceDelta: Double?
    let donutSegments: [CommerceDonutSegment]
    /// Section « Plus d’indicateurs » (sans doublon avec la carte nouveaux membres, ni avis Google).
    let categoryRows: [CommerceCategoryRowData]
    /// Section dédiée « Avis Google ».
    let googleReviewsRows: [CommerceCategoryRowData]
    let barWeeksOperations: [CommerceBarWeekData]
    /// Courbe haute de la tuile **Membres** : **une** valeur normalisée [0,1] par semaine (API), préf. `membersCount`, sinon `operationsCount`. Pas les parts du donut.
    let membersWeeklySparkline: [CGFloat]
    let membersTotal: Int?
    let activeMembers: Int?
    let retentionPct: Double?
}

enum CommerceStatisticsDataBuilder {
    /// `panierRepereEuro` : repère commerçant (prioritaire sur `stats.baselineAvgBasketEur` si fourni).
    static func build(
        stats: BusinessStatsResponse?,
        evolution: [EvolutionWeekDTO],
        panierRepereEuro: Double? = nil
    ) -> CommerceStatisticsPresentation {
        let members = max(0, stats?.membersCount ?? 0)
        let inactive30Raw = max(0, stats?.inactiveMembers30Days ?? 0)
        let inactive30 = members > 0 ? min(members, inactive30Raw) : 0
        let active30 = members > 0 ? max(0, members - inactive30) : max(0, stats?.activeMembersInPeriod ?? 0)

        let points = CGFloat(stats?.pointsThisMonth ?? 0)
        let newM = CGFloat(stats?.newMembersInPeriod ?? stats?.newMembersLast30Days ?? 0)
        let active = CGFloat(active30)
        let sumActivity = max(1, points * 0.02 + newM * 2 + active * 0.5)
        let fPts = Double((points * 0.02) / sumActivity)
        let fNew = Double((newM * 2) / sumActivity)
        let fAct = Double((active * 0.5) / sumActivity)
        let fracSum = max(1e-6, fPts + fNew + fAct)

        let colors = CommerceStatisticsTheme.segmentColors
        let donut: [CommerceDonutSegment] = [
            .init(id: "pts", fraction: fPts / fracSum, color: colors[1], label: "Points"),
            .init(id: "new", fraction: fNew / fracSum, color: colors[2], label: "Nouveaux"),
            .init(id: "act", fraction: fAct / fracSum, color: colors[3], label: "Actifs"),
        ]

        let txI = stats?.transactionsThisMonth ?? 0
        let ptsI = stats?.pointsThisMonth ?? 0
        let actI = active30
        let rewardsN = stats?.rewardsRedeemedCount ?? 0
        let rewardBreakdown = stats?.rewardsRedeemedBreakdown?.filter { ($0.count) > 0 } ?? []
        let googleRev = stats?.googleReviewsNewInPeriod ?? 0
        let wPts = Double(ptsI) * 0.05
        let wAct = Double(actI)
        let wRew = Double(rewardsN) * 8
        let wG = Double(googleRev) * 15
        let inactiveN = inactive30
        let wInact = Double(inactiveN) * 0.4
        /// Poids relatifs uniquement pour la section « Plus d’indicateurs » (actifs, inactifs, points, récompenses).
        let twIndicators = max(1, wPts + wAct + wRew + wInact)
        func weightPctIndicator(_ w: Double) -> String {
            String(format: "%.0f %%", min(100, (w / twIndicators) * 100))
        }
        /// Part de l’avis Google affichée seule dans sa section (échelle interne cohérente avec l’ancien barème).
        let twGoogle = max(1, wG + wAct * 0.15 + wPts * 0.1)
        func weightPctGoogle(_ w: Double) -> String {
            String(format: "%.0f %%", min(100, (w / twGoogle) * 100))
        }

        let indicatorRows: [CommerceCategoryRowData] = [
            .init(
                id: "audienceSplit",
                title: "Clients actifs / inactifs (30 j)",
                subtitle: "Actif = au moins 1 passage · Inactif = 0",
                rightPrimary: "\(StatsFR.formatPct(Double(actI) / Double(max(1, members)))) actifs",
                rightSecondary: "\(StatsFR.formatPct(Double(inactiveN) / Double(max(1, members)))) inactifs",
                iconName: "person.2.fill",
                swatch: colors[3],
                audienceSplit: CommerceAudienceSplitData(activeCount: actI, inactiveCount: inactiveN)
            ),
            .init(
                id: "pts",
                title: "Points attribués",
                subtitle: "Fidélité",
                rightPrimary: "+\(StatsFR.formatInt(ptsI))",
                rightSecondary: weightPctIndicator(wPts),
                iconName: "star.fill",
                swatch: colors[1],
                audienceSplit: nil
            ),
            .init(
                id: "rewards",
                title: "Récompenses utilisées",
                subtitle: "Sur la période",
                rightPrimary: StatsFR.formatInt(rewardsN),
                rightSecondary: "",
                iconName: "gift.fill",
                swatch: Color(red: 0.98, green: 0.42, blue: 0.42),
                audienceSplit: nil,
                rewardUsageLines: rewardBreakdown.isEmpty ? nil : rewardBreakdown
            ),
        ]

        let googleReviewsRows: [CommerceCategoryRowData] = [
            .init(
                id: "grev",
                title: "Avis Google (nouveaux)",
                subtitle: "Détectés sur la période",
                rightPrimary: "+\(StatsFR.formatInt(googleRev))",
                rightSecondary: weightPctGoogle(wG),
                iconName: "star.bubble.fill",
                swatch: Color(red: 0.26, green: 0.52, blue: 0.96),
                audienceSplit: nil
            ),
        ]

        let panier: Double? = {
            guard let api = stats?.avgBasketEur, api > 0 else { return nil }
            return api
        }()
        let repere: Double? = {
            let raw = panierRepereEuro ?? stats?.baselineAvgBasketEur
            guard let b = raw, b > 0.009 else { return nil }
            return b
        }()
        let vsReperePct: Double? = {
            guard let m = panier, let r = repere, r > 0 else { return nil }
            return (m - r) / r * 100.0
        }()

        let freq: Double? = {
            if let api = stats?.avgVisitsPerActiveMember, api > 0 { return api }
            guard actI > 0, txI > 0 else { return nil }
            return Double(txI) / Double(actI)
        }()

        let opsSeries: [Int] = evolution.map { $0.operationsCount ?? 0 }
        let bars: [CommerceBarWeekData] = {
            let raw: [CGFloat] = opsSeries.map { CGFloat($0) }
            guard !raw.isEmpty else { return [] }
            return normalizedWeekBars(raw: raw)
        }()

        let membersSpark: [CGFloat] = normalizedMemberSparkline(from: evolution)

        let (dPanier, dFreq) = trendDeltas(evolution: evolution, stats: stats)

        return CommerceStatisticsPresentation(
            panierMoyenEuro: panier,
            panierRepereEuro: repere,
            panierMesureVsReperePct: vsReperePct,
            frequenceParActif: freq,
            trendPanierDeltaEuro: dPanier,
            trendFrequenceDelta: dFreq,
            donutSegments: donut,
            categoryRows: indicatorRows,
            googleReviewsRows: googleReviewsRows,
            barWeeksOperations: bars,
            membersWeeklySparkline: membersSpark,
            membersTotal: members,
            activeMembers: active30,
            retentionPct: stats?.retentionPct
        )
    }

    /// Barres d’**activité** (opérations) : min–max sur la période (sinon toutes semaines = même hauteur lisible).
    private static func normalizedWeekBars(raw: [CGFloat]) -> [CommerceBarWeekData] {
        let minV = raw.min() ?? 0
        let maxV = raw.max() ?? 0
        if maxV - minV < 1e-4 {
            return raw.enumerated().map { i, _ in
                .init(id: "w\(i)", label: segmentLabel(index: i, total: raw.count), value: 0.5)
            }
        }
        let span = maxV - minV
        return raw.enumerated().map { i, v in
            let norm = (v - minV) / span
            return .init(id: "w\(i)", label: segmentLabel(index: i, total: raw.count), value: min(1, max(0, norm)))
        }
    }

    /// Série hebdo pour la tuile **Membres** : privilégie `membersCount`, sinon repli `operationsCount` (même période que l’API).
    private static func normalizedMemberSparkline(from evolution: [EvolutionWeekDTO]) -> [CGFloat] {
        guard !evolution.isEmpty else { return [] }
        let mPresent = evolution.contains { $0.membersCount != nil }
        let mRaw: [CGFloat] = evolution.map { w in
            if mPresent, let m = w.membersCount { return CGFloat(m) }
            return CGFloat(w.operationsCount ?? 0)
        }
        let minV = mRaw.min() ?? 0
        let maxV = mRaw.max() ?? 0
        if maxV <= 0 { return mRaw.map { _ in 0.5 } }
        if maxV - minV < 1e-4 { return mRaw.map { _ in 0.5 } }
        let span = maxV - minV
        return mRaw.map { v in (v - minV) / span }
    }

    private static func segmentLabel(index: Int, total: Int) -> String {
        guard total > 1 else { return "S" }
        if total <= 5 {
            return "\(index + 1)"
        }
        if index == total - 1 { return "S" }
        return "\(index + 1)"
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

// MARK: - Mois civils (API `YYYY-MM`)

enum CommerceStatsMonthNavigator {
    private static let monthKeyPattern = #"^\d{4}-\d{2}$"#

    static func isCalendarMonthPeriod(_ s: String) -> Bool {
        s.range(of: monthKeyPattern, options: .regularExpression) != nil
    }

    /// `YYYY-MM` du mois civil contenant `date` (timezone calendrier grégorien courant).
    static func calendarMonthKey(for date: Date = Date()) -> String {
        let cal = Calendar(identifier: .gregorian)
        let day = cal.startOfDay(for: date)
        let y = cal.component(.year, from: day)
        let m = cal.component(.month, from: day)
        return String(format: "%04d-%02d", y, m)
    }

    /// Mois le plus récent en index 0, puis M-1 … M-5.
    static func sixMonthKeysEndingCurrentMonth(reference: Date = Date()) -> [String] {
        let cal = Calendar(identifier: .gregorian)
        let day = cal.startOfDay(for: reference)
        return (0..<6).compactMap { offset -> String? in
            guard let d = cal.date(byAdding: .month, value: -offset, to: day) else { return nil }
            let y = cal.component(.year, from: d)
            let m = cal.component(.month, from: d)
            return String(format: "%04d-%02d", y, m)
        }
    }

    /// Titre type « Avril 2026 ».
    static func displayTitle(forMonthKey key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2,
              let y = Int(parts[0]),
              let mo = Int(parts[1]),
              let date = Calendar.current.date(from: DateComponents(year: y, month: mo, day: 1))
        else { return key }
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "MMMM yyyy"
        let raw = f.string(from: date)
        guard let first = raw.first else { return key }
        return String(first).uppercased() + raw.dropFirst()
    }

    /// Titre type « Avril » (sans année).
    static func displayTitleMonthOnly(forMonthKey key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2,
              let y = Int(parts[0]),
              let mo = Int(parts[1]),
              let date = Calendar.current.date(from: DateComponents(year: y, month: mo, day: 1))
        else { return key }
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "MMMM"
        let raw = f.string(from: date)
        guard let first = raw.first else { return key }
        return String(first).uppercased() + raw.dropFirst()
    }

    /// Anciens paramètres (`6m`, `this_month`…) → mois courant pour l’API mois par mois.
    static func normalizeLegacyPeriodToMonthKey(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if isCalendarMonthPeriod(t) { return t }
        return sixMonthKeysEndingCurrentMonth().first ?? t
    }
}
