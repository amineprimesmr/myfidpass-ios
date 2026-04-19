//
//  CommerceStatisticsDashboardView.swift
//  myfidpass
//
//  Page « Outils d’analyse » — composition type Revolut (cartes, donut, listes, campagnes).
//

import SwiftUI

struct CommerceStatisticsDashboardView: View {
    @ObservedObject var vm: MerchantStatsIndicatorsViewModel
    @Binding var periodTab: CommerceStatsPeriodTab
    let organizationName: String
    let onClose: () -> Void
    /// Bouton retour discret (navigation / tab bar masqués sur l’écran statistiques).
    var showsInlineCloseButton: Bool = true
    /// Ouvre l’écran détail type Revolut pour un indicateur.
    var onOpenStatisticDetail: ((CommerceStatisticDetailTopic) -> Void)? = nil

    @State private var carouselPage = 0

    private var presentation: CommerceStatisticsPresentation {
        CommerceStatisticsDataBuilder.build(stats: vm.stats, evolution: vm.evolution)
    }

    private var periodRightLabel: String {
        if let p = vm.stats?.period?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
            return p
        }
        switch periodTab {
        case .oneWeek: return "7 jours"
        case .oneMonth: return "Ce mois-ci"
        case .sixMonths: return "6 mois"
        case .oneYear: return "12 mois"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                statisticsTopChrome

                CommerceStatsLargeMetricCard(
                    title: "Clients actifs",
                    value: activeClientsFormatted,
                    subtitle: activeClientsSubtitle,
                    segments: presentation.donutSegments,
                    onTap: onOpenStatisticDetail.map { fn in { fn(.activeClients) } }
                )

                carouselBlock

                pageIndicatorDots

                Text("Vue d’ensemble")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 4)

                CommerceStatsOverviewCard(
                    title: "Cartes émises",
                    value: presentation.membersTotal.map { StatsFR.formatInt($0) } ?? "—",
                    legend: "Clients avec carte",
                    barColor: CommerceStatisticsTheme.accentBlue,
                    onTap: onOpenStatisticDetail.map { fn in { fn(.cardsIssued) } }
                )

                Text("Activité")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                activityBars

                CommerceStatsSectionHeader(title: "Par indicateur", onManage: {})

                CommerceStatsCategoryListCard(rows: presentation.categoryRows)

                if !notificationCampaignRows.isEmpty {
                    Text("Campagnes notif.")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Retours = passage en caisse dans les 7 jours après l’envoi (estimation).")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)

                    CommerceStatsCategoryListCard(rows: notificationCampaignRows)
                }

                Text("Outils")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                toolsCard

                if let err = vm.errorMessage, !err.isEmpty {
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(CommerceStatisticsTheme.negative.opacity(0.9))
                        .padding(.vertical, 8)
                }

                Color.clear.frame(height: 52)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .background(CommerceStatisticsTheme.background.ignoresSafeArea())
        .overlay(alignment: .top) {
            if vm.isLoading {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 8)
            }
        }
        .onChange(of: periodTab) { _, newTab in
            Task { await vm.load(period: newTab.rawValue) }
        }
    }

    private var trimmedOrganizationName: String {
        organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Une seule zone de contrôle : retour + période (pas de barre système, pas de doublon avec la tab bar).
    private var statisticsTopChrome: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                if showsInlineCloseButton {
                    CommerceStatsBackCircleButton(action: onClose)
                }
                Spacer(minLength: 0)
            }
            CommerceStatsSegmentedPeriodControl(selection: $periodTab)
            if !trimmedOrganizationName.isEmpty {
                HStack(spacing: 6) {
                    Text(trimmedOrganizationName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                    Text("·")
                        .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
                    Text(periodRightLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CommerceStatisticsTheme.accentBlue)
                }
            }
        }
        .padding(.top, 4)
    }

    private var activeClientsFormatted: String {
        guard let n = presentation.activeMembers else { return "—" }
        return StatsFR.formatInt(n)
    }

    private var activeClientsSubtitle: String? {
        guard let total = presentation.membersTotal, total > 0 else { return nil }
        return "Sur \(StatsFR.formatInt(total)) membres avec carte"
    }

    private var carouselBlock: some View {
        TabView(selection: $carouselPage) {
            CommerceStatsCompactMetricCard(
                title: "Panier moyen",
                value: panierText,
                trendText: panierTrendText,
                trendPositive: panierTrendPositive,
                footnote: panierFootnote
            ) {
                CommerceStatsMiniBarChart(weeks: presentation.barWeeksOperations, barColor: CommerceStatisticsTheme.positive)
            }
            .tag(0)

            CommerceStatsCompactMetricCard(
                title: "Fréquence d’achat",
                value: frequenceText,
                trendText: freqTrendText,
                trendPositive: presentation.trendFrequenceDelta.map { $0 >= 0 }
            ) {
                CommerceStatsDualToneMiniBars(
                    topFraction: freqTopBar,
                    bottomFraction: freqBottomBar
                )
            }
            .tag(1)

            CommerceStatsCompactMetricCard(
                title: "Points attribués",
                value: pointsGivenText,
                trendText: "Sur \(periodRightLabel)",
                trendPositive: nil
            ) {
                CommerceStatsMiniBarChart(weeks: presentation.barWeeksOperations, barColor: CommerceStatisticsTheme.accentBlue)
            }
            .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 196)
    }

    private var pageIndicatorDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i == carouselPage ? Color.white : Color.white.opacity(0.22))
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var activityBars: some View {
        let ops = vm.evolution.compactMap { $0.operationsCount }
        let mid = max(1, ops.count / 2)
        let first = ops.prefix(mid).reduce(0, +)
        let second = ops.suffix(max(1, ops.count - mid)).reduce(0, +)
        return VStack(alignment: .leading, spacing: 12) {
            CommerceStatsActivityBarChart(
                primaryValue: CGFloat(first),
                secondaryValue: CGFloat(second),
                primaryLabel: "\(first)",
                secondaryLabel: "\(second)",
                axisCaption: "Opérations cumulées (début vs fin de série)"
            )
        }
    }

    private var toolsCard: some View {
        VStack(spacing: 0) {
            toolRow(
                icon: "clock.badge.checkmark",
                title: "Fuseau des périodes",
                subtitle: "Calcul serveur UTC — comparez au même calendrier pour vos clôtures."
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(CommerceStatisticsTheme.card)
        )
    }

    private func toolRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(CommerceStatisticsTheme.pillBackground)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CommerceStatisticsTheme.secondaryLabel.opacity(0.7))
        }
        .padding(16)
    }

    private var pointsGivenText: String {
        let p = vm.stats?.pointsThisMonth ?? 0
        return StatsFR.formatInt(p)
    }

    private var panierText: String {
        guard let p = presentation.panierMoyenEuro else { return "—" }
        return StatsFR.formatEuro(p) + " €"
    }

    private var frequenceText: String {
        guard let f = presentation.frequenceParActif else { return "—" }
        return StatsFR.formatDoubleSmart(f) + " visites / actif"
    }

    private var panierTrendPositive: Bool? {
        presentation.trendPanierDeltaEuro.map { $0 >= 0 }
    }

    private var panierTrendText: String? {
        guard let d = presentation.trendPanierDeltaEuro else { return nil }
        let sign = d >= 0 ? "+" : "−"
        return "série : \(sign)\(StatsFR.formatEuro(abs(d))) €"
    }

    private var panierFootnote: String? {
        presentation.panierMoyenEuro == nil
            ? "Saisissez des montants € (caisse / ticket) pour obtenir un panier moyen."
            : nil
    }

    private var freqTrendText: String? {
        guard let d = presentation.trendFrequenceDelta else { return nil }
        let arrow = d >= 0 ? "\u{25B2}" : "\u{25BC}"
        return "\(arrow) \(StatsFR.formatPct(abs(d))) · \(periodRightLabel)"
    }

    private var freqTopBar: CGFloat {
        let f = presentation.frequenceParActif ?? 0
        return CGFloat(min(1, max(0.2, f / max(2, f + 1))))
    }

    private var freqBottomBar: CGFloat {
        let r = presentation.retentionPct.map { CGFloat($0 / 100) } ?? 0.35
        return min(1, max(0.15, 1 - r))
    }

    private var notificationCampaignRows: [CommerceCategoryRowData] {
        guard let camps = vm.stats?.notificationCampaigns, !camps.isEmpty else { return [] }
        return camps.prefix(10).map { c in
            let title = (c.triggerName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? (c.triggerName ?? "Campagne")
                : "Campagne"
            let rec = c.recipientsDistinct ?? 0
            let ret = c.returnedWithin7d ?? 0
            let pct: Double = rec > 0 ? (Double(ret) / Double(rec)) * 100 : 0
            let dateStr = Self.shortDateLabel(c.createdAt)
            return CommerceCategoryRowData(
                id: c.batchId,
                title: title,
                subtitle: "\(StatsFR.formatInt(rec)) destinataires · \(dateStr)",
                rightPrimary: "\(StatsFR.formatInt(ret)) retours",
                rightSecondary: String(format: "%.0f %%", min(100, pct)),
                iconName: "bell.and.waves.left.and.right",
                swatch: CommerceStatisticsTheme.accentBlue
            )
        }
    }

    private static func shortDateLabel(_ iso: String?) -> String {
        guard let iso, !iso.isEmpty else { return "—" }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var d = f.date(from: iso)
        if d == nil {
            f.formatOptions = [.withInternetDateTime]
            d = f.date(from: iso)
        }
        guard let date = d else { return "—" }
        let out = DateFormatter()
        out.locale = Locale(identifier: "fr_FR")
        out.dateStyle = .short
        out.timeStyle = .short
        return out.string(from: date)
    }
}
