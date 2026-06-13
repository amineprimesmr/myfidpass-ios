//
//  CommerceStatisticsData.swift
//  myfidpass
//
//  Projection des DTO API vers les modèles d’affichage (indicateurs clés, panier réel, fréquence, segments).
//

import SwiftUI

enum CommerceStatsProgramKind {
    static func normalized(_ raw: String?) -> String {
        let t = (raw ?? "points").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t == "stamps" ? "stamps" : "points"
    }

    static func isStamps(_ programType: String?) -> Bool {
        normalized(programType) == "stamps"
    }

    static func loyaltyUnitLabel(programType: String?) -> String {
        isStamps(programType) ? "Tampons" : "Points"
    }

    static func attributedTitle(programType: String?) -> String {
        isStamps(programType) ? "Tampons attribués" : "Points attribués"
    }
}

struct CommerceDonutSegment: Identifiable, Hashable {
    let id: String
    let fraction: Double
    let color: Color
    let label: String
}

/// Données d’affichage « dashboard » pour la tuile **Points attribués** (courbe + tendance).
struct CommercePointsAttributedDetail: Hashable {
    /// Série normalisée [0, 1] (typiquement activité hebdo / passages).
    var sparkline: [CGFloat]
    /// Variation en % entre les deux dernières semaines de la série (activité).
    var trendPct: Double?
    var trendIsPositive: Bool
}

/// Données d’affichage pour la tuile **Fréquence d’achat** (courbe + tendance).
struct CommerceVisitFrequencyDetail: Hashable {
    var sparkline: [CGFloat]
    var trendPct: Double?
    var trendIsPositive: Bool
}

/// Ligne (style « in stock ») : chiffre + indicateur, nom de la récompense à droite.
struct CommerceRewardUsedLineItem: Hashable {
    let label: String
    let count: Int
    /// Part des échanges sur la période (0…100) — chiffre compact à côté de la flèche.
    let shareRounded: Int
    /// Flèche verte si la part est au moins la part « équitable » (100 % / nombre de types).
    let trendPositive: Bool
}

/// Mise en page type carte « in stock / low stock » pour **Récompenses utilisées** (`id == "rewards"`).
struct CommerceRewardsUsedDetail: Hashable {
    let items: [CommerceRewardUsedLineItem]
    let totalExchanges: Int
}

/// Détail d’impact des avis Google (période + volume) pour une carte dédiée.
struct CommerceGoogleReviewsDetail: Hashable {
    let monthKey: String?
    let newReviewsInPeriod: Int
}

/// Détail d’un réseau social (courbe + tendance) pour une carte dédiée.
struct CommerceSocialFollowsDetail: Hashable {
    let networkId: String   // "social-instagram" | "social-tiktok" | "social-facebook" | "social-twitter"
    var sparkline: [CGFloat]
    var trendPct: Double?
    var trendIsPositive: Bool
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
    /// Mise en page type « Order completion » pour **Points attribués** (ligne `id == "pts"`).
    let pointsAttributedDetail: CommercePointsAttributedDetail?
    /// Mise en page type « in stock / low stock » pour **Récompenses utilisées** (ligne `id == "rewards"`).
    let rewardsUsedDetail: CommerceRewardsUsedDetail?
    /// Carte dédiée « Avis Google » (impact mensuel + cumul local).
    let googleReviewsDetail: CommerceGoogleReviewsDetail?
    /// Carte « Fréquence d'achat » (section Plus de données).
    let visitFrequencyDetail: CommerceVisitFrequencyDetail?
    /// Carte dédiée réseau social (Instagram / TikTok / Facebook / X).
    let socialFollowsDetail: CommerceSocialFollowsDetail?
    /// Pseudo configuré (@…) — affiché sur la carte réseau.
    let socialHandle: String?

    init(
        id: String,
        title: String,
        subtitle: String,
        rightPrimary: String,
        rightSecondary: String,
        iconName: String,
        swatch: Color,
        audienceSplit: CommerceAudienceSplitData? = nil,
        rewardUsageLines: [RewardRedeemedBreakdownRowDTO]? = nil,
        pointsAttributedDetail: CommercePointsAttributedDetail? = nil,
        rewardsUsedDetail: CommerceRewardsUsedDetail? = nil,
        googleReviewsDetail: CommerceGoogleReviewsDetail? = nil,
        visitFrequencyDetail: CommerceVisitFrequencyDetail? = nil,
        socialFollowsDetail: CommerceSocialFollowsDetail? = nil,
        socialHandle: String? = nil
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
        self.pointsAttributedDetail = pointsAttributedDetail
        self.rewardsUsedDetail = rewardsUsedDetail
        self.googleReviewsDetail = googleReviewsDetail
        self.visitFrequencyDetail = visitFrequencyDetail
        self.socialFollowsDetail = socialFollowsDetail
        self.socialHandle = socialHandle
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
    /// Section « Plus de données » (fréquence, actifs, points, récompenses).
    let categoryRows: [CommerceCategoryRowData]
    /// Tuile KPI « Avis Google » (à côté du panier moyen).
    let googleReviewsNewInPeriod: Int
    /// Section « Engagement réseaux sociaux » (missions follow).
    let engagementRows: [CommerceCategoryRowData]
    let barWeeksOperations: [CommerceBarWeekData]
    /// Courbe haute de la tuile **Membres** : valeurs normalisées [0,1] (cumul inscriptions dans le mois).
    let membersWeeklySparkline: [CGFloat]
    /// Jalons jour affichés sous la courbe (alignés sur `dayOfMonth` API).
    let membersMonthAxisDays: [Int]
    /// Courbe tuile **Panier moyen** : évolution du panier cumulé dans le mois (normalisée [0,1]).
    let panierWeeklySparkline: [CGFloat]
    let panierMonthAxisDays: [Int]
    let membersTotal: Int?
    let activeMembers: Int?
    let retentionPct: Double?
}

enum CommerceStatisticsDataBuilder {
    /// `panierRepereEuro` : repère commerçant (prioritaire sur `stats.baselineAvgBasketEur` si fourni).
    static func build(
        stats: BusinessStatsResponse?,
        evolution: [EvolutionWeekDTO],
        panierRepereEuro: Double? = nil,
        programType: String = "points",
        configuredSocialHandles: [String: String] = [:]
    ) -> CommerceStatisticsPresentation {
        let isStamps = CommerceStatsProgramKind.isStamps(programType)
        let loyaltyLabel = CommerceStatsProgramKind.loyaltyUnitLabel(programType: programType)
        let attributedTitle = CommerceStatsProgramKind.attributedTitle(programType: programType)
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
            .init(id: "pts", fraction: fPts / fracSum, color: colors[1], label: loyaltyLabel),
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

        let opsSeriesForPoints = evolution.map { $0.operationsCount ?? 0 }
        let (ptsSpark, ptsTrend, ptsTrendPos) = Self.pointsRowSparklineAndTrend(opsSeries: opsSeriesForPoints)

        let indicatorRows: [CommerceCategoryRowData] = [
            .init(
                id: "audienceSplit",
                title: "Activité client (+1 visite /mois)",
                subtitle: "",
                rightPrimary: "\(StatsFR.formatInt(actI)) actifs",
                rightSecondary: "\(StatsFR.formatInt(inactiveN)) inactifs",
                iconName: "person.2.fill",
                swatch: CommerceStatisticsTheme.brandGreen,
                audienceSplit: CommerceAudienceSplitData(activeCount: actI, inactiveCount: inactiveN)
            ),
            .init(
                id: "pts",
                title: attributedTitle,
                subtitle: isStamps ? "Passages tampons" : "Fidélité",
                rightPrimary: "+\(StatsFR.formatInt(ptsI))",
                rightSecondary: weightPctIndicator(wPts),
                iconName: isStamps ? "seal.fill" : "star.fill",
                swatch: colors[1],
                audienceSplit: nil,
                pointsAttributedDetail: .init(
                    sparkline: ptsSpark,
                    trendPct: ptsTrend,
                    trendIsPositive: ptsTrendPos
                )
            ),
            .init(
                id: "rewards",
                title: "Récompenses utilisées",
                subtitle: "",
                rightPrimary: StatsFR.formatInt(rewardsN),
                rightSecondary: "",
                iconName: "gift.fill",
                swatch: Color(red: 0.98, green: 0.42, blue: 0.42),
                audienceSplit: nil,
                rewardUsageLines: nil,
                pointsAttributedDetail: nil,
                rewardsUsedDetail: Self.rewardsUsedDetailFrom(
                    breakdown: rewardBreakdown,
                    totalExchanges: max(0, rewardsN)
                )
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

        let freq: Double? = Self.resolvedPurchaseFrequency(stats: stats, activeMembers: actI, transactionsInPeriod: txI)

        let opsSeries: [Int] = evolution.map { $0.operationsCount ?? 0 }
        let bars: [CommerceBarWeekData] = {
            let raw: [CGFloat] = opsSeries.map { CGFloat($0) }
            guard !raw.isEmpty else { return [] }
            return normalizedWeekBars(raw: raw)
        }()

        let membersSpark: [CGFloat] = normalizedMemberSparkline(from: evolution)
        let membersAxisDays: [Int] = memberMonthAxisDays(from: evolution)
        let panierSpark: [CGFloat] = normalizedPanierSparkline(from: evolution)
        let panierAxisDays: [Int] = memberMonthAxisDays(from: evolution)

        let (dPanier, dFreq) = trendDeltas(evolution: evolution, stats: stats)

        let freqValueText: String = {
            guard let f = freq, f >= 1 else { return "—" }
            return "\(StatsFR.formatDoubleSmart(max(1, f))) visites"
        }()

        let frequencyRow = CommerceCategoryRowData(
            id: "freq",
            title: "Fréquence d'achat",
            subtitle: "/mois",
            rightPrimary: freqValueText,
            rightSecondary: "",
            iconName: "chart.line.uptrend.xyaxis",
            swatch: colors[1],
            audienceSplit: nil,
            visitFrequencyDetail: .init(
                sparkline: bars.map(\.value),
                trendPct: nil,
                trendIsPositive: true
            )
        )

        let detailCategoryRows: [CommerceCategoryRowData] = [
            frequencyRow,
        ] + indicatorRows

        let socialEngagementRows: [CommerceCategoryRowData] = {
            guard !configuredSocialHandles.isEmpty, let sf = stats?.socialFollowsClaimed else { return [] }
            let nets: [(id: String, label: String, icon: String, count: Int)] = [
                ("social-instagram", "Instagram", "camera.fill",      sf.instagram ?? 0),
                ("social-tiktok",    "TikTok",    "music.note",       sf.tiktok    ?? 0),
                ("social-facebook",  "Facebook",  "person.2.fill",    sf.facebook  ?? 0),
                ("social-twitter",   "X",         "bubble.left.fill", sf.twitter   ?? 0),
            ]
            return nets.compactMap { net in
                guard let handle = configuredSocialHandles[net.id]?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !handle.isEmpty else { return nil }
                let spark = Self.syntheticSocialSparkline(total: net.count)
                let atLabel = handle.hasPrefix("@") ? handle : "@\(handle)"
                return CommerceCategoryRowData(
                    id: net.id,
                    title: net.label,
                    subtitle: atLabel,
                    rightPrimary: "+\(StatsFR.formatInt(net.count))",
                    rightSecondary: "",
                    iconName: net.icon,
                    swatch: .blue,
                    socialFollowsDetail: CommerceSocialFollowsDetail(
                        networkId: net.id,
                        sparkline: spark,
                        trendPct: nil,
                        trendIsPositive: true
                    ),
                    socialHandle: handle.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
                )
            }
        }()

        let engagementRows = socialEngagementRows

        return CommerceStatisticsPresentation(
            panierMoyenEuro: panier,
            panierRepereEuro: repere,
            panierMesureVsReperePct: vsReperePct,
            frequenceParActif: freq,
            trendPanierDeltaEuro: dPanier,
            trendFrequenceDelta: dFreq,
            donutSegments: donut,
            categoryRows: detailCategoryRows,
            googleReviewsNewInPeriod: max(0, googleRev),
            engagementRows: engagementRows,
            barWeeksOperations: bars,
            membersWeeklySparkline: membersSpark,
            membersMonthAxisDays: membersAxisDays,
            panierWeeklySparkline: panierSpark,
            panierMonthAxisDays: panierAxisDays,
            membersTotal: members,
            activeMembers: active30,
            retentionPct: stats?.retentionPct
        )
    }

    /// Avant abonnement payant : conserve **donut + courbe** membres réels ; panier, fréquence et rangées détail depuis la maquette.
    static func paywallTeaserMerging(real: CommerceStatisticsPresentation, mock: CommerceStatisticsPresentation) -> CommerceStatisticsPresentation {
        CommerceStatisticsPresentation(
            panierMoyenEuro: mock.panierMoyenEuro,
            panierRepereEuro: mock.panierRepereEuro,
            panierMesureVsReperePct: mock.panierMesureVsReperePct,
            frequenceParActif: mock.frequenceParActif,
            trendPanierDeltaEuro: mock.trendPanierDeltaEuro,
            trendFrequenceDelta: mock.trendFrequenceDelta,
            donutSegments: real.donutSegments,
            categoryRows: mock.categoryRows,
            googleReviewsNewInPeriod: mock.googleReviewsNewInPeriod,
            engagementRows: mock.engagementRows,
            barWeeksOperations: mock.barWeeksOperations,
            membersWeeklySparkline: real.membersWeeklySparkline,
            membersMonthAxisDays: real.membersMonthAxisDays,
            panierWeeklySparkline: mock.panierWeeklySparkline,
            panierMonthAxisDays: mock.panierMonthAxisDays,
            membersTotal: real.membersTotal,
            activeMembers: real.activeMembers,
            retentionPct: mock.retentionPct
        )
    }

    /// Lignes type « in stock » : part des échanges (chiffre à côté de la flèche) et vert / rouge vs répartition équitable.
    private static func rewardsUsedDetailFrom(
        breakdown: [RewardRedeemedBreakdownRowDTO],
        totalExchanges: Int
    ) -> CommerceRewardsUsedDetail {
        let t = max(0, totalExchanges)
        if breakdown.isEmpty {
            if t == 0 {
                return CommerceRewardsUsedDetail(
                    items: [CommerceRewardUsedLineItem(
                        label: "Aucun échange",
                        count: 0,
                        shareRounded: 0,
                        trendPositive: true
                    )],
                    totalExchanges: 0
                )
            }
            return CommerceRewardsUsedDetail(
                items: [CommerceRewardUsedLineItem(
                    label: "Rachats (détail par type indisponible)",
                    count: t,
                    shareRounded: 100,
                    trendPositive: true
                )],
                totalExchanges: t
            )
        }
        let n = max(1, breakdown.count)
        let equalShare = 100.0 / Double(n)
        let denom = max(1, t)
        var items: [CommerceRewardUsedLineItem] = []
        for r in breakdown {
            let c = max(0, r.count)
            let share = (Double(c) / Double(denom)) * 100.0
            let sr = min(100, max(0, Int(round(share))))
            let positive = share + 0.15 >= equalShare
            let label = r.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let safeLabel = label.isEmpty ? "Récompense" : label
            items.append(
                CommerceRewardUsedLineItem(
                    label: safeLabel,
                    count: c,
                    shareRounded: sr,
                    trendPositive: positive
                )
            )
        }
        items.sort { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.label < rhs.label
        }
        return CommerceRewardsUsedDetail(items: items, totalExchanges: t)
    }

    /// Courbe + tendance (2 dernières semaines) pour la tuile **Points attribués** — série = activité caisse, alignée sur l’évolution API.
    private static func pointsRowSparklineAndTrend(opsSeries: [Int]) -> (spark: [CGFloat], trend: Double?, positive: Bool) {
        let raw: [CGFloat] = opsSeries.map { CGFloat($0) }
        let spark: [CGFloat]
        if raw.isEmpty {
            spark = [0.5, 0.52, 0.48, 0.55, 0.51, 0.5]
        } else {
            let minV = raw.min() ?? 0
            let maxV = raw.max() ?? 0
            if maxV - minV < 1e-3 {
                spark = raw.map { _ in 0.5 }
            } else {
                let span = maxV - minV
                spark = raw.map { ($0 - minV) / span }
            }
        }
        var trend: Double?
        let positive = true
        if let pair = operationsTrendPair(opsSeries), pair.prev > 0, pair.last > 0 {
            let d = Double(pair.last - pair.prev) / Double(pair.prev) * 100.0
            trend = StatsFR.displayableTrendPct(d)
        }
        return (spark, trend, positive)
    }

    /// Fréquence d’achat affichée : moyenne de passages par membre **acheteur** (≥ 1 quand il y a des passages).
    static func resolvedPurchaseFrequency(
        stats: BusinessStatsResponse?,
        activeMembers: Int,
        transactionsInPeriod: Int
    ) -> Double? {
        if let api = stats?.avgVisitsPerActiveMember, api > 0 {
            return max(1.0, api)
        }
        let visits = stats?.visitsInPeriod ?? transactionsInPeriod
        guard visits > 0 else { return nil }
        if let active = stats?.activeMembersInPeriod, active > 0, visits >= active {
            return max(1.0, Double(visits) / Double(active))
        }
        guard activeMembers > 0 else { return nil }
        return max(1.0, Double(visits) / Double(activeMembers))
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

    /// Courbe Membres : cumul d’inscriptions dans le mois (`newMembersInMonth`), alignée sur les jalons jour 1…30.
    private static let membersMonthMilestoneCount = 7
    private static let membersMonthSparklineFloor: CGFloat = 0.06

    private static func normalizedMemberSparkline(from evolution: [EvolutionWeekDTO]) -> [CGFloat] {
        guard !evolution.isEmpty else { return [] }

        let hasMonthSeries = evolution.contains { $0.newMembersInMonth != nil && $0.dayOfMonth != nil }
        if hasMonthSeries {
            let raw = evolution.map { CGFloat(max(0, $0.newMembersInMonth ?? 0)) }
            return sparklineFromMonthGrowth(raw)
        }

        // Rétrocompat (ancienne API 4 segments) : croissance relative du stock cumulé.
        let cumulative = evolution.map { CGFloat(max(0, $0.membersCount ?? $0.operationsCount ?? 0)) }
        guard let baseline = cumulative.first else { return [] }
        let growth = cumulative.map { max(0, $0 - baseline) }
        return sparklineFromMonthGrowth(growth)
    }

    private static func sparklineFromMonthGrowth(_ raw: [CGFloat]) -> [CGFloat] {
        guard !raw.isEmpty else { return [] }
        var monotonic = raw
        for i in 1 ..< monotonic.count where monotonic[i] < monotonic[i - 1] {
            monotonic[i] = monotonic[i - 1]
        }
        let maxV = max(monotonic.max() ?? 0, 0)
        if maxV < 1e-4 {
            return Array(repeating: membersMonthSparklineFloor, count: max(monotonic.count, membersMonthMilestoneCount))
        }
        return monotonic.map { v in
            let norm = v / maxV
            return min(1, max(membersMonthSparklineFloor, norm))
        }
    }

    private static func memberMonthAxisDays(from evolution: [EvolutionWeekDTO]) -> [Int] {
        let days = evolution.compactMap(\.dayOfMonth).filter { $0 > 0 }
        if !days.isEmpty { return days }
        return [1, 5, 10, 15, 20, 25, 30]
    }

    /// Cumul des ventes € du mois — courbe ascendante alignée sur les jours (comme « entrées d’argent »).
    private static func normalizedPanierSparkline(from evolution: [EvolutionWeekDTO]) -> [CGFloat] {
        guard !evolution.isEmpty else { return [] }
        var cumulative: CGFloat = 0
        let raw: [CGFloat] = evolution.map { point in
            if let total = point.basketTotalEurInMonth, total > 0 { return CGFloat(total) }
            let unit = point.avgBasketEurInInterval ?? point.avgBasketEurInMonth ?? 0
            let ops = CGFloat(max(0, point.operationsCount ?? 0))
            if unit > 0, ops > 0 {
                cumulative += CGFloat(unit) * ops
                return cumulative
            }
            return cumulative
        }
        guard let maxTotal = raw.max(), maxTotal > 0 else {
            return Array(repeating: membersMonthSparklineFloor, count: max(evolution.count, membersMonthMilestoneCount))
        }
        return raw.map { v in
            guard v > 0 else { return membersMonthSparklineFloor }
            let norm = v / maxTotal
            return min(1, max(membersMonthSparklineFloor + 0.08, membersMonthSparklineFloor + norm * 0.9))
        }
    }

    private static func segmentLabel(index: Int, total: Int) -> String {
        guard total > 1 else { return "S" }
        if total <= 5 {
            return "\(index + 1)"
        }
        if index == total - 1 { return "S" }
        return "\(index + 1)"
    }

    /// Courbe synthétique pour un réseau social (pas de données hebdo par réseau dans l’API).
    private static func syntheticSocialSparkline(total: Int) -> [CGFloat] {
        guard total > 0 else { return [0.08, 0.10, 0.09, 0.12, 0.10, 0.09] }
        return [0.28, 0.44, 0.58, 0.74, 0.88, 1.0]
    }

    /// Paire d’intervalles pour la tendance : évite −100 % quand le dernier jalon du mois en cours est encore vide (0 op.).
    private static func operationsTrendPair(_ ops: [Int]) -> (last: Int, prev: Int)? {
        guard ops.count >= 2 else { return nil }
        if ops.count >= 3, ops[ops.count - 1] == 0 {
            return (ops[ops.count - 2], ops[ops.count - 3])
        }
        return (ops[ops.count - 1], ops[ops.count - 2])
    }

    /// Tendance panier : variation € estimée entre deux jalons d’activité (hausse uniquement).
    /// Fréquence : pas de % comparatif ici (jalons opérations ≠ mois précédent).
    private static func trendDeltas(evolution: [EvolutionWeekDTO], stats: BusinessStatsResponse?) -> (Double?, Double?) {
        let ops = evolution.compactMap { $0.operationsCount }
        guard let pair = operationsTrendPair(ops), pair.prev > 0 else { return (nil, nil) }
        var dPanier: Double? = nil
        if let basket = stats?.avgBasketEur, basket > 0, pair.last > 0 {
            let raw = Double(pair.last - pair.prev) * basket
            dPanier = StatsFR.displayableTrendEuro(raw)
        }
        return (dPanier, nil)
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

    /// Titre carrousel stats : « En mai », « En septembre »…
    static func displayTitleInMonth(forMonthKey key: String) -> String {
        let month = displayTitleMonthOnly(forMonthKey: key)
        return "En \(month.lowercased())"
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

    /// `YYYY-MM` à partir de `created_at` API (ISO, SQLite `yyyy-MM-dd HH:mm:ss`, ou préfixe `YYYY-MM`).
    static func creationMonthKey(fromCreatedAt raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if raw.count >= 7 {
            let prefix7 = String(raw.prefix(7))
            if isCalendarMonthPeriod(prefix7) { return prefix7 }
        }
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()
        isoPlain.formatOptions = [.withInternetDateTime]
        if let d = isoFrac.date(from: raw) ?? isoPlain.date(from: raw) {
            return calendarMonthKey(for: d)
        }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        for pattern in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            df.dateFormat = pattern
            if let d = df.date(from: String(raw.prefix(19))) ?? df.date(from: raw) {
                return calendarMonthKey(for: d)
            }
        }
        return nil
    }

    private static func previousCalendarMonthKey(_ key: String) -> String? {
        let parts = key.split(separator: "-")
        guard parts.count == 2,
              let y = Int(parts[0]),
              let mo = Int(parts[1]),
              let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: y, month: mo, day: 1)),
              let prev = Calendar(identifier: .gregorian).date(byAdding: .month, value: -1, to: date)
        else { return nil }
        return calendarMonthKey(for: prev)
    }

    /// Mois depuis `creationMonthKey` (inclus) jusqu’au mois courant, max 6, plus récent en premier.
    /// Si `creationMonthKey` est nil ou invalide, renvoie les 6 derniers mois.
    static func monthKeys(from creationMonthKey: String?, reference: Date = Date()) -> [String] {
        let current = calendarMonthKey(for: reference)
        guard let creation = creationMonthKey, isCalendarMonthPeriod(creation) else {
            return sixMonthKeysEndingCurrentMonth(reference: reference)
        }
        if creation > current { return [current] }
        var keys: [String] = []
        var cursor = current
        while cursor >= creation, keys.count < 6 {
            keys.append(cursor)
            guard let prev = previousCalendarMonthKey(cursor) else { break }
            cursor = prev
        }
        return keys.isEmpty ? [current] : keys
    }

    /// Anciens paramètres (`6m`, `this_month`…) → mois courant pour l’API mois par mois.
    static func normalizeLegacyPeriodToMonthKey(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if isCalendarMonthPeriod(t) { return t }
        return sixMonthKeysEndingCurrentMonth().first ?? t
    }
}

// MARK: - Historique mensuel avis Google (tendance % vs mois précédent)

enum CommerceGoogleReviewsMonthHistory {
    static let storageKey = "myfidpass.stats.googleReviews.monthlyHistory.v1"

    static func parse(_ rawJSON: String) -> [String: Int] {
        guard let data = rawJSON.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        var out: [String: Int] = [:]
        for (k, v) in raw {
            if let n = v as? Int {
                out[k] = max(0, n)
            } else if let n = v as? NSNumber {
                out[k] = max(0, n.intValue)
            }
        }
        return out
    }

    static func encode(_ history: [String: Int]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: history, options: [.sortedKeys]),
              let s = String(data: data, encoding: .utf8)
        else { return "{}" }
        return s
    }

    static func normalizedMonthKey(_ raw: String?) -> String {
        let candidate = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if CommerceStatsMonthNavigator.isCalendarMonthPeriod(candidate) { return candidate }
        return CommerceStatsMonthNavigator.calendarMonthKey()
    }

    static func previousMonthKey(from key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]) else { return key }
        let cal = Calendar(identifier: .gregorian)
        guard let d = cal.date(from: DateComponents(year: y, month: m, day: 1)),
              let prev = cal.date(byAdding: .month, value: -1, to: d)
        else { return key }
        return CommerceStatsMonthNavigator.calendarMonthKey(for: prev)
    }

    static func trendPct(monthKey: String?, newReviews: Int, historyJSON: String) -> Double? {
        let key = normalizedMonthKey(monthKey)
        let hist = parse(historyJSON)
        guard let prev = hist[previousMonthKey(from: key)], prev > 0 else { return nil }
        let cur = max(0, newReviews)
        return (Double(cur - prev) / Double(prev)) * 100.0
    }

    static func trendText(monthKey: String?, newReviews: Int, historyJSON: String) -> String? {
        guard let delta = trendPct(monthKey: monthKey, newReviews: newReviews, historyJSON: historyJSON),
              delta > 0
        else { return nil }
        return "+\(StatsFR.formatDoubleSmart(delta))%"
    }

    static func trendIsPositive(monthKey: String?, newReviews: Int, historyJSON: String) -> Bool? {
        guard let delta = trendPct(monthKey: monthKey, newReviews: newReviews, historyJSON: historyJSON),
              delta > 0
        else { return nil }
        return true
    }

    /// Met à jour l’historique local si le mois courant a plus d’avis que la valeur enregistrée.
    static func persistIfNeeded(monthKey: String?, newReviews: Int, historyJSON: inout String) {
        let key = normalizedMonthKey(monthKey)
        let cur = max(0, newReviews)
        var hist = parse(historyJSON)
        let existing = hist[key] ?? 0
        guard cur > existing else { return }
        hist[key] = cur
        historyJSON = encode(hist)
    }
}
