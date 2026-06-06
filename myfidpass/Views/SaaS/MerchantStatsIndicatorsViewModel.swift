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
    private static let isoWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    @Published private(set) var stats: BusinessStatsResponse?
    @Published private(set) var evolution: [EvolutionWeekDTO] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    /// Icône de notification (URL `…/notification-icon`) — même source que l’onglet Campagnes.
    @Published private(set) var statsNotificationIconURL: String?
    /// Dernier mois (`YYYY-MM`) pour lequel `stats` / sections détail sont à jour (hors chargement).
    @Published private(set) var lastSuccessfullyLoadedPeriod: String?
    /// Panier moyen « repère » commerçant (€) — aligné sur `GET …/dashboard/stats` puis saisie locale / PATCH.
    @Published private(set) var baselinePanierRepereEUR: Double?
    /// `points` ou `stamps` — pilote libellés stats et KPI (panier vs tampons).
    @Published private(set) var loyaltyProgramType: String = "points"
    /// Réseaux sociaux configurés (`social-instagram` → pseudo sans @).
    @Published private(set) var configuredSocialHandles: [String: String] = [:]

    /// Prévisualisation locale : glissement mois par mois sans rappeler l’API.
    @Published private(set) var isDemoSixMonthPreviewActive: Bool = false

    private var demoPayloadsByMonth: [String: CommerceStatisticsPreviewMonthPayload] = [:]

    private struct MonthStatsSnapshot {
        let stats: BusinessStatsResponse
        let evolution: [EvolutionWeekDTO]
    }

    /// Cache navigation process-wide (évite refetch quand la vue stats est recréée rapidement).
    private static let navigationCacheLock = NSLock()
    private static var navigationSnapshotsBySlugPeriod: [String: MonthStatsSnapshot] = [:]
    private static var navigationLastFetchAtBySlugPeriod: [String: Date] = [:]
    private static var navigationFetchEpochBySlugPeriod: [String: Int] = [:]
    /// Invalidation intelligente: incrémentée lors d’une mutation stats; force un refetch même dans le TTL.
    private static var navigationInvalidationEpochBySlug: [String: Int] = [:]

    /// Données API déjà reçues par mois — alimente le carrousel KPI sans dupliquer l’état affiché.
    private var monthSnapshots: [String: MonthStatsSnapshot] = [:]
    /// Évite les doubles fetch concurrents sur le même mois (task + notification sync).
    private var inFlightPeriods: Set<String> = []
    /// Date de dernier fetch API réussi par mois (throttle court).
    private var lastSuccessfulFetchAtByPeriod: [String: Date] = [:]
    private let fastReloadThrottle: TimeInterval = 18
    /// Retour arrière rapide (ouvrir/fermer stats) : ne pas relancer le réseau si déjà frais.
    private let navigationReuseTTL: TimeInterval = 55

    /// Campagnes issues de `GET .../notifications/stats` (souvent renseigné quand `.../dashboard/stats` n’expose pas encore `notification_campaigns`).
    @Published private(set) var notificationCampaignsFromStatsEndpoint: [NotificationCampaignInsightDTO] = []

    /// Liste fusionnée (stats + endpoint notif + historique local d’envoi), sans entrées vides.
    var notificationCampaignsForPresentation: [NotificationCampaignInsightDTO] {
        if isDemoSixMonthPreviewActive, let s = stats {
            return Self.filterMeaningfulNotificationCampaigns(s.notificationCampaigns ?? [])
                .sorted { (a, b) in (a.createdAt ?? "") > (b.createdAt ?? "") }
        }
        guard let slug = AuthStorage.currentBusinessSlug, !slug.isEmpty else { return [] }
        var byId: [String: NotificationCampaignInsightDTO] = [:]
        for c in stats?.notificationCampaigns ?? [] { byId[c.batchId] = c }
        for c in notificationCampaignsFromStatsEndpoint {
            if let existing = byId[c.batchId] {
                byId[c.batchId] = existing.mergedWith(c)
            } else {
                byId[c.batchId] = c
            }
        }
        var list = Array(byId.values)
        let local = NotificationSendLocalHistoryStore.asCampaignInsights(
            NotificationSendLocalHistoryStore.entries(for: slug)
        )
        for l in local {
            if byId[l.batchId] != nil { continue }
            if Self.localSendLooksLikeDuplicateOfAPI(l, in: list) { continue }
            list.append(l)
        }
        return Self.filterMeaningfulNotificationCampaigns(list)
            .sorted { a, b in (a.createdAt ?? "") > (b.createdAt ?? "") }
    }

    private static func localSendLooksLikeDuplicateOfAPI(
        _ local: NotificationCampaignInsightDTO,
        in api: [NotificationCampaignInsightDTO]
    ) -> Bool {
        let lm = local.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !lm.isEmpty else { return false }
        for a in api {
            let am = a.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if am == lm, sameCalendarDay(a.createdAt, b: local.createdAt) { return true }
        }
        return false
    }

    private static func sameCalendarDay(_ a: String?, b: String?) -> Bool {
        guard let da = parseISOToDate(a), let db = parseISOToDate(b) else { return false }
        return Calendar.current.isDate(da, inSameDayAs: db)
    }

    private static func parseISOToDate(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        if let d = isoWithFractional.date(from: s) { return d }
        return isoBasic.date(from: s)
    }

    private static func filterMeaningfulNotificationCampaigns(
        _ raw: [NotificationCampaignInsightDTO]
    ) -> [NotificationCampaignInsightDTO] {
        raw.filter { c in
            let r = c.recipientsDistinct ?? 0
            let s = c.sentTotal ?? 0
            let t = c.notificationTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let m = c.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if r > 0 || s > 0 { return true }
            if !t.isEmpty || !m.isEmpty { return true }
            return false
        }
    }

    private func refreshStatsNotificationIcon(slug: String) async {
        if let c = ScanFlowSettingsCache.cached(for: slug) {
            let u = c.notificationIconUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
            statsNotificationIconURL = (u?.isEmpty == false) ? u : nil
            loyaltyProgramType = CommerceStatsProgramKind.normalized(c.programType)
            return
        }
        do {
            let s: BusinessSettingsResponse = try await APIClient.shared.request(.businessSettings(slug: slug))
            ScanFlowSettingsCache.store(s, for: slug)
            let u = s.notificationIconUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
            statsNotificationIconURL = (u?.isEmpty == false) ? u : nil
            loyaltyProgramType = CommerceStatsProgramKind.normalized(s.programType)
        } catch {
            statsNotificationIconURL = nil
        }
    }

    func updateConfiguredSocialHandles(_ handles: [String: String]) {
        configuredSocialHandles = handles
    }

    private func normalizedMonthlyAudience(from s: BusinessStatsResponse) -> (members: Int, active: Int, inactive30: Int)? {
        let members = max(0, s.membersCount ?? 0)
        guard members > 0 else { return nil }
        let inactive = min(members, max(0, s.inactiveMembers30Days ?? 0))
        let active = max(0, members - inactive)
        return (members, active, inactive)
    }

    /// `GET .../notifications/stats` — ne fait pas échouer l’écran stats si l’endpoint est indisponible ou le JSON partiel.
    private func fetchNotificationStatsPayload(slug: String) async -> NotificationStatsEndpointPayload? {
        do {
            return try await APIClient.shared.request(.dashboardNotificationStats(slug: slug))
        } catch {
            return nil
        }
    }

    /// Hydrate la mémoire depuis le cache disque pour tous les mois du carrousel, puis le mois affiché.
    func prepareMonthNavigation(slug: String, allMonthKeys: [String], focusPeriod: String) {
        guard !slug.isEmpty else { return }
        for key in allMonthKeys where monthSnapshots[key] == nil {
            if let c = MerchantStatisticsDiskCache.load(slug: slug, period: key) {
                monthSnapshots[key] = MonthStatsSnapshot(
                    stats: c.stats,
                    evolution: c.evolution
                )
            }
        }
        _ = applyCachedMonthIfAvailable(period: focusPeriod)
    }

    func load(period: String, forceRefresh: Bool = false) async {
        isDemoSixMonthPreviewActive = false
        demoPayloadsByMonth = [:]

        guard let slug = AuthStorage.currentBusinessSlug, !slug.isEmpty else {
            stats = nil
            evolution = []
            monthSnapshots = [:]
            notificationCampaignsFromStatsEndpoint = []
            lastSuccessfullyLoadedPeriod = nil
            baselinePanierRepereEUR = nil
            statsNotificationIconURL = nil
            errorMessage = "Aucun commerce sélectionné."
            return
        }

        // Cache mémoire partagé process (écran stats recréé) avant disque.
        if monthSnapshots[period] == nil,
           let shared = Self.navigationSharedSnapshot(slug: slug, period: period) {
            monthSnapshots[period] = shared
        }

        // Cache disque pour ce mois si le carrousel n’a pas déjà tout hydraté.
        if monthSnapshots[period] == nil,
           let c = MerchantStatisticsDiskCache.load(slug: slug, period: period) {
            monthSnapshots[period] = MonthStatsSnapshot(
                stats: c.stats,
                evolution: c.evolution
            )
        }
        _ = applyCachedMonthIfAvailable(period: period)

        if inFlightPeriods.contains(period) {
            return
        }
        if !forceRefresh,
           let last = lastSuccessfulFetchAtByPeriod[period],
           Date().timeIntervalSince(last) < fastReloadThrottle,
           monthSnapshots[period] != nil {
            return
        }

        let currentEpoch = Self.navigationInvalidationEpoch(slug: slug)
        if !forceRefresh,
           let lastSharedFetch = Self.navigationSharedLastFetch(slug: slug, period: period),
           let fetchEpoch = Self.navigationSharedFetchEpoch(slug: slug, period: period),
           Date().timeIntervalSince(lastSharedFetch) < navigationReuseTTL,
           monthSnapshots[period] != nil,
           fetchEpoch == currentEpoch {
            lastSuccessfulFetchAtByPeriod[period] = lastSharedFetch
            return
        }

        let hasWarmUIForPeriod = monthSnapshots[period] != nil
            || (stats != nil && Self.monthKey(stats!, matches: period))

        errorMessage = nil
        if notificationCampaignsFromStatsEndpoint.isEmpty {
            let disk = NotificationStatsEndpointCache.load(slug: slug)
            if !disk.isEmpty { notificationCampaignsFromStatsEndpoint = disk }
        }
        // Pas de spinner plein écran tant qu’on peut afficher des agrégés (mémoire ou disque).
        isLoading = !hasWarmUIForPeriod
        inFlightPeriods.insert(period)
        defer {
            isLoading = false
            inFlightPeriods.remove(period)
        }

        do {
            let weeks = Self.weeksToRequest(for: period)
            let shouldRefreshNotificationPayload = forceRefresh || notificationCampaignsFromStatsEndpoint.isEmpty
            async let gotStats: BusinessStatsResponse = try await APIClient.shared.request(.businessStats(slug: slug, period: period))
            async let gotEv: DashboardEvolutionResponse = try await APIClient.shared.request(
                .businessEvolution(slug: slug, weeks: weeks, period: period)
            )
            async let notifPayload: NotificationStatsEndpointPayload? = shouldRefreshNotificationPayload
                ? fetchNotificationStatsPayload(slug: slug)
                : nil
            if isDemoSixMonthPreviewActive { return }
            let (a, b, n) = try await (gotStats, gotEv, notifPayload)
            stats = a
            baselinePanierRepereEUR = a.baselineAvgBasketEur
            evolution = b.evolution
            if let notifPayload = n {
                let notifCamps = notifPayload.campaigns
                notificationCampaignsFromStatsEndpoint = notifCamps
                NotificationStatsEndpointCache.save(slug: slug, campaigns: notifCamps)
            }
            Task { @MainActor in
                await refreshStatsNotificationIcon(slug: slug)
            }
            let snap = MonthStatsSnapshot(stats: a, evolution: b.evolution)
            monthSnapshots[period] = snap
            lastSuccessfullyLoadedPeriod = period
            lastSuccessfulFetchAtByPeriod[period] = Date()
            Self.navigationStoreSnapshot(snap, slug: slug, period: period, fetchedAt: Date(), epoch: currentEpoch)
            MerchantStatisticsDiskCache.save(
                slug: slug,
                period: period,
                snapshot: MerchantStatisticsDiskCache.CachedMonth(
                    stats: a,
                    evolution: b.evolution,
                    traffic: nil
                )
            )
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            if notificationCampaignsFromStatsEndpoint.isEmpty {
                let disk = NotificationStatsEndpointCache.load(slug: slug)
                if !disk.isEmpty { notificationCampaignsFromStatsEndpoint = disk }
            }
            if stats == nil {
                evolution = []
            }
        }
    }

    /// Mutation métier (ex. repère panier, paramètres impactant stats): invalide le TTL navigation.
    func markStatsMutation(slug: String, period: String? = nil) {
        let cleanSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanSlug.isEmpty else { return }
        Self.navigationInvalidate(slug: cleanSlug, period: period)
        if let period {
            lastSuccessfulFetchAtByPeriod.removeValue(forKey: period)
            monthSnapshots.removeValue(forKey: period)
        } else {
            lastSuccessfulFetchAtByPeriod.removeAll(keepingCapacity: true)
        }
    }

    private static func slugPeriodKey(slug: String, period: String) -> String {
        "\(slug.lowercased())|\(period)"
    }

    private static func navigationSharedSnapshot(slug: String, period: String) -> MonthStatsSnapshot? {
        navigationCacheLock.lock()
        defer { navigationCacheLock.unlock() }
        return navigationSnapshotsBySlugPeriod[slugPeriodKey(slug: slug, period: period)]
    }

    private static func navigationSharedLastFetch(slug: String, period: String) -> Date? {
        navigationCacheLock.lock()
        defer { navigationCacheLock.unlock() }
        return navigationLastFetchAtBySlugPeriod[slugPeriodKey(slug: slug, period: period)]
    }

    private static func navigationStoreSnapshot(_ snap: MonthStatsSnapshot, slug: String, period: String, fetchedAt: Date, epoch: Int) {
        navigationCacheLock.lock()
        defer { navigationCacheLock.unlock() }
        let key = slugPeriodKey(slug: slug, period: period)
        navigationSnapshotsBySlugPeriod[key] = snap
        navigationLastFetchAtBySlugPeriod[key] = fetchedAt
        navigationFetchEpochBySlugPeriod[key] = epoch
    }

    private static func navigationSharedFetchEpoch(slug: String, period: String) -> Int? {
        navigationCacheLock.lock()
        defer { navigationCacheLock.unlock() }
        return navigationFetchEpochBySlugPeriod[slugPeriodKey(slug: slug, period: period)]
    }

    private static func navigationInvalidationEpoch(slug: String) -> Int {
        navigationCacheLock.lock()
        defer { navigationCacheLock.unlock() }
        return navigationInvalidationEpochBySlug[slug.lowercased()] ?? 0
    }

    private static func navigationInvalidate(slug: String, period: String?) {
        navigationCacheLock.lock()
        defer { navigationCacheLock.unlock() }
        let s = slug.lowercased()
        navigationInvalidationEpochBySlug[s] = (navigationInvalidationEpochBySlug[s] ?? 0) + 1
        if let period {
            let key = slugPeriodKey(slug: s, period: period)
            navigationLastFetchAtBySlugPeriod.removeValue(forKey: key)
            navigationSnapshotsBySlugPeriod.removeValue(forKey: key)
            navigationFetchEpochBySlugPeriod.removeValue(forKey: key)
        } else {
            let prefix = "\(s)|"
            navigationLastFetchAtBySlugPeriod.keys.filter { $0.hasPrefix(prefix) }.forEach { navigationLastFetchAtBySlugPeriod.removeValue(forKey: $0) }
            navigationSnapshotsBySlugPeriod.keys.filter { $0.hasPrefix(prefix) }.forEach { navigationSnapshotsBySlugPeriod.removeValue(forKey: $0) }
            navigationFetchEpochBySlugPeriod.keys.filter { $0.hasPrefix(prefix) }.forEach { navigationFetchEpochBySlugPeriod.removeValue(forKey: $0) }
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
        if let audience = normalizedMonthlyAudience(from: s) {
            audienceCards.append(
                .init(
                    id: "actives",
                    title: "Actifs",
                    value: StatsFR.formatInt(audience.active),
                    subtitle: nil,
                    kind: .value,
                    ratioPercent: nil,
                    accessibilityLabel: "Actifs sur 30 jours, \(StatsFR.formatInt(audience.active))"
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

        if let audience = normalizedMonthlyAudience(from: s) {
            let pct = (Double(audience.active) / Double(audience.members)) * 100
            audienceCards.append(
                .init(
                    id: "activeRate",
                    title: "Taux d'actifs",
                    value: StatsFR.formatPct(pct),
                    subtitle: "Actifs 30 j / Membres",
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
        if let audience = normalizedMonthlyAudience(from: s) {
            acquisitionCards.append(
                .init(
                    id: "inactive30",
                    title: "Inactifs (30 j)",
                    value: StatsFR.formatInt(audience.inactive30),
                    subtitle: nil,
                    kind: .value,
                    ratioPercent: nil,
                    accessibilityLabel: "Inactifs sur 30 jours, \(StatsFR.formatInt(audience.inactive30))"
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

        if let audience = normalizedMonthlyAudience(from: s) {
            let churnPct = (Double(audience.inactive30) / Double(audience.members)) * 100
            acquisitionCards.append(
                .init(
                    id: "churn30Rate",
                    title: "Churn (30 j)",
                    value: StatsFR.formatPct(churnPct),
                    subtitle: "Inactifs 30 j / Membres",
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

        if let audience = normalizedMonthlyAudience(from: s) {
            let churnPct = (Double(audience.inactive30) / Double(audience.members)) * 100
            let kind: (String, String, String) = {
                if churnPct <= 10 { return ("sparkles", "Churn faible", "Conserver la dynamique") }
                if churnPct <= 20 { return ("wand.and.rays", "Churn modéré", "Cibler les contacts à réactiver") }
                return ("slowdown", "Churn élevé", "Accélérer le réengagement")
            }()
            callouts.append(
                .init(
                    icon: kind.0,
                    title: kind.1,
                    dataLine: "Inactifs (30 j) : \(StatsFR.formatInt(audience.inactive30)) — \(StatsFR.formatPct(churnPct))",
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
        if period.range(of: #"^\d{4}-\d{2}$"#, options: .regularExpression) != nil {
            return 4
        }
        switch period {
        case "7d": return 2
        case "30d": return 8
        case "this_month": return 8
        case "6m": return 16
        case "12m", "1y": return 26
        default: return 4
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

extension MerchantStatsIndicatorsViewModel {
    /// 6 mois de démo : une série par mois civil ; utiliser `applyDemoPayload(forMonthKey:)` au glissement.
    func applySixMonthsPreviewDemo(monthKeys: [String], displayMonthKey: String) {
        monthSnapshots = [:]
        demoPayloadsByMonth = CommerceStatisticsPreviewMock.payloadsByMonthKeys(monthKeys)
        isDemoSixMonthPreviewActive = true
        applyDemoPayload(forMonthKey: displayMonthKey)
    }

    /// Quitte le mode simulation et réinitialise l'état pour un rechargement réel.
    func deactivateDemoPreview() {
        isDemoSixMonthPreviewActive = false
        demoPayloadsByMonth = [:]
        monthSnapshots = [:]
        stats = nil
        evolution = []
        errorMessage = nil
        lastSuccessfullyLoadedPeriod = nil
    }

    /// Met à jour le repère panier (après saisie stats ou en attendant un `load`).
    func setBaselinePanierRepereEUR(_ value: Double?) {
        baselinePanierRepereEUR = value
    }

    func applyDemoPayload(forMonthKey key: String) {
        guard isDemoSixMonthPreviewActive, let p = demoPayloadsByMonth[key] else { return }
        stats = p.stats
        baselinePanierRepereEUR = p.stats.baselineAvgBasketEur
        evolution = p.evolution
        errorMessage = nil
        isLoading = false
        lastSuccessfullyLoadedPeriod = key
        if let slug = AuthStorage.currentBusinessSlug, !slug.isEmpty {
            Task { await self.refreshStatsNotificationIcon(slug: slug) }
        }
    }

    /// Réaffiche instantanément un mois déjà chargé (API), en attendant un éventuel rafraîchissement.
    @discardableResult
    func applyCachedMonthIfAvailable(period: String) -> Bool {
        guard let snap = monthSnapshots[period] else { return false }
        stats = snap.stats
        baselinePanierRepereEUR = snap.stats.baselineAvgBasketEur
        evolution = snap.evolution
        errorMessage = nil
        lastSuccessfullyLoadedPeriod = period
        return true
    }

    func presentationForMonthCarousel(monthKey: String) -> CommerceStatisticsPresentation {
        let rep = baselinePanierRepereEUR
        let program = loyaltyProgramType
        let social = configuredSocialHandles
        if isDemoSixMonthPreviewActive, let p = demoPayloadsByMonth[monthKey] {
            return CommerceStatisticsDataBuilder.build(
                stats: p.stats,
                evolution: p.evolution,
                panierRepereEuro: rep,
                programType: program,
                configuredSocialHandles: social
            )
        }
        if let snap = monthSnapshots[monthKey] {
            return CommerceStatisticsDataBuilder.build(
                stats: snap.stats,
                evolution: snap.evolution,
                panierRepereEuro: rep,
                programType: program,
                configuredSocialHandles: social
            )
        }
        if let s = stats, Self.monthKey(s, matches: monthKey) {
            return CommerceStatisticsDataBuilder.build(
                stats: s,
                evolution: evolution,
                panierRepereEuro: rep,
                programType: program,
                configuredSocialHandles: social
            )
        }
        return CommerceStatisticsDataBuilder.build(
            stats: nil,
            evolution: [],
            panierRepereEuro: rep,
            programType: program,
            configuredSocialHandles: social
        )
    }

    func businessStats(forMonthKey monthKey: String) -> BusinessStatsResponse? {
        if isDemoSixMonthPreviewActive { return demoPayloadsByMonth[monthKey]?.stats }
        if let s = monthSnapshots[monthKey]?.stats { return s }
        if let s = stats, Self.monthKey(s, matches: monthKey) { return s }
        return nil
    }

    private static func monthKey(_ stats: BusinessStatsResponse, matches key: String) -> Bool {
        if let pk = stats.periodKey, pk == key { return true }
        if let p = stats.period, p == key { return true }
        return false
    }
}
