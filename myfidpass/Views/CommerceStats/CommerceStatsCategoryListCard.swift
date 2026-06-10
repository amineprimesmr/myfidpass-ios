//
//  CommerceStatsCategoryListCard.swift
//  myfidpass
//

import Foundation
import SwiftUI
import UIKit

struct CommerceStatsCategoryListCard: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay

    let rows: [CommerceCategoryRowData]
    var onViewGoogleReviews: (() -> Void)? = nil
    var onRowTap: ((String) -> Void)? = nil

    /// Hauteur unique pour chaque bouton « Plus de données », alignée sur la carte « Votre récompense du mois ».
    private static let rowTileMinHeight: CGFloat = 200
    private static let rowSpacing: CGFloat = 12

    /// Fond 3D sur le conteneur « composite » (plusieurs `Button` internes), pas de `ButtonStyle` global.
    private func rowUseStatic3DSurface(_ row: CommerceCategoryRowData) -> Bool {
        if row.id == "audienceSplit", row.audienceSplit != nil { return true }
        if row.id == "freq", row.visitFrequencyDetail != nil { return true }
        if row.id == "pts", row.pointsAttributedDetail != nil { return true }
        if row.id == "rewards", row.rewardsUsedDetail != nil { return true }
        if row.id == "grev", row.googleReviewsDetail != nil { return true }
        if row.id.hasPrefix("social-"), row.socialFollowsDetail != nil { return true }
        return false
    }

    private func rowChartPinsToBottom(_ row: CommerceCategoryRowData) -> Bool {
        if row.id == "freq", row.visitFrequencyDetail != nil { return true }
        if row.id == "pts", row.pointsAttributedDetail != nil { return true }
        if row.id.hasPrefix("social-"), row.socialFollowsDetail != nil { return true }
        return false
    }

    private func rowTileMinHeight(for row: CommerceCategoryRowData) -> CGFloat {
        if row.id == "grev", row.googleReviewsDetail != nil { return 244 }
        return Self.rowTileMinHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            ForEach(rows) { row in
                rowShell(for: row)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: rowTileMinHeight(for: row),
                        alignment: rowChartPinsToBottom(row) ? .bottomLeading : .topLeading
                    )
                    .modifier(CommerceStatsDataTileModifier(
                        cornerRadius: CommerceStatsIndicatorLiquidGlass.kpiCornerRadius,
                        controlSize: .large,
                        useStatic3DSurface: rowUseStatic3DSurface(row)
                    ))
            }
        }
    }

    @ViewBuilder
    private func rowShell(for row: CommerceCategoryRowData) -> some View {
        if let split = row.audienceSplit, row.id == "audienceSplit" {
            CommerceStatsAudienceSplitListButtonRow(
                row: row,
                split: split,
                onRowTap: { onRowTap?(row.id) }
            )
        } else if let detail = row.googleReviewsDetail, row.id == "grev" {
            CommerceStatsGoogleReviewsDisplayRow(
                row: row,
                detail: detail,
                onViewReviews: { onViewGoogleReviews?() }
            )
        } else if let detail = row.visitFrequencyDetail, row.id == "freq" {
            let sanitizedValue: String = {
                let raw = row.rightPrimary.trimmingCharacters(in: .whitespacesAndNewlines)
                if raw.hasSuffix(" visites") { return String(raw.dropLast(8)) }
                return raw
            }()
            CommerceStatsLargeMetricCard(
                title: row.title,
                value: sanitizedValue,
                valueCaption: row.subtitle.isEmpty ? nil : row.subtitle,
                subtitle: nil,
                membersWeeklySparkline: detail.sparkline,
                segments: [],
                onTap: nil,
                chartLineColor: CommerceStatisticsTheme.accentBlue
            )
        } else if let detail = row.pointsAttributedDetail, row.id == "pts" {
            let sanitizedValue: String = {
                let raw = row.rightPrimary.trimmingCharacters(in: .whitespacesAndNewlines)
                if raw.hasPrefix("+") { return String(raw.dropFirst()) }
                return raw
            }()
            CommerceStatsLargeMetricCard(
                title: row.title,
                value: sanitizedValue,
                valueCaption: nil,
                subtitle: row.subtitle,
                membersWeeklySparkline: detail.sparkline,
                segments: [],
                onTap: nil,
                chartLineColor: CommerceStatisticsTheme.accentBlue
            )
        } else if let detail = row.rewardsUsedDetail, row.id == "rewards" {
            CommerceStatsRewardsUsedListButtonRow(
                row: row,
                detail: detail,
                onRowTap: { onRowTap?(row.id) }
            )
        } else if let detail = row.socialFollowsDetail, row.id.hasPrefix("social-") {
            let sanitizedValue: String = {
                let raw = row.rightPrimary.trimmingCharacters(in: .whitespacesAndNewlines)
                if raw.hasPrefix("+") { return String(raw.dropFirst()) }
                return raw
            }()
            let netColor = CommerceStatsSocialNetworkPalette.lineColor(for: detail.networkId)
            CommerceStatsLargeMetricCard(
                title: row.title,
                value: sanitizedValue,
                valueCaption: nil,
                subtitle: row.subtitle,
                membersWeeklySparkline: detail.sparkline,
                segments: [],
                onTap: onRowTap.map { handler in { handler(row.id) } },
                chartLineColor: netColor,
                headerIconAsset: CommerceStatsSocialNetworkPalette.assetName(for: detail.networkId),
                chartAreaGradientColors: CommerceStatsSocialNetworkPalette.areaColors(for: detail.networkId)
            )
        } else if onRowTap != nil {
            Button {
                onRowTap?(row.id)
            } label: {
                categoryRowContent(row: row)
            }
            .buttonStyle(.plain)
        } else {
            categoryRowContent(row: row)
        }
    }

    @ViewBuilder
    private func categoryRowContent(row: CommerceCategoryRowData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(CommerceStatisticsTheme.pillBackground)
                        .frame(width: 40, height: 40)
                    Image(systemName: row.iconName)
                        .font(CommerceStatisticsTheme.statsText(size: 16, weight: .semibold))
                        .foregroundStyle(row.swatch)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.title)
                        .font(CommerceStatisticsTheme.kpiTileTitleFont())
                        .foregroundStyle(CommerceStatisticsTheme.kpiTileTitleGradient(forGlassOverlay: commerceStatsGlassOverlay))
                    Text(row.subtitle)
                        .font(CommerceStatisticsTheme.statsText(size: 13, weight: .medium))
                        .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: commerceStatsGlassOverlay))
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(row.rightPrimary)
                        .font(CommerceStatisticsTheme.statisticNumbers(size: 17, weight: .semibold))
                        .foregroundStyle(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: commerceStatsGlassOverlay))
                    if !row.rightSecondary.isEmpty {
                        Text(row.rightSecondary)
                            .font(CommerceStatisticsTheme.statisticNumbers(size: 13, weight: .medium))
                            .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: commerceStatsGlassOverlay))
                    }
                }
            }
            if let split = row.audienceSplit {
                audienceSplitBar(split)
                    .padding(.leading, 54)
                    .padding(.top, 8)
            } else if let lines = row.rewardUsageLines, !lines.isEmpty {
                rewardUsageLinesBlock(lines)
                    .padding(.leading, 52)
                    .padding(.top, 8)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .padding(.leading, 16)
        .padding(.trailing, 14)
    }

    @ViewBuilder
    private func rewardUsageLinesBlock(_ lines: [RewardRedeemedBreakdownRowDTO]) -> some View {
        let g = commerceStatsGlassOverlay
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(line.label)
                        .font(CommerceStatisticsTheme.statsText(size: 13, weight: .medium))
                        .foregroundStyle(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: g))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 6)
                    Text(StatsFR.formatInt(line.count))
                        .font(CommerceStatisticsTheme.statisticNumbers(size: 13, weight: .semibold))
                        .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g))
                        .monospacedDigit()
                }
            }
        }
    }

    private func audienceSplitBar(_ split: CommerceAudienceSplitData) -> some View {
        let activeColor = Color(red: 0.36, green: 0.52, blue: 1.0)
        let inactiveColor = Color(red: 0.96, green: 0.32, blue: 0.32)
        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let w = max(0, geo.size.width)
                let activeWidth = max(6, w * split.activeFraction)
                let inactiveWidth = max(6, w * split.inactiveFraction)
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(activeColor)
                        .frame(width: activeWidth)
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(inactiveColor)
                        .frame(width: inactiveWidth)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .frame(height: 12)

            HStack(spacing: 10) {
                dot(activeColor, label: "Actifs \(StatsFR.formatInt(split.activeCount))")
                dot(inactiveColor, label: "Inactifs \(StatsFR.formatInt(split.inactiveCount))")
            }
        }
    }

    private func dot(_ color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(CommerceStatisticsTheme.statsText(size: 11, weight: .semibold))
                .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: commerceStatsGlassOverlay))
                .lineLimit(1)
        }
    }
}

private struct CommerceStatsDataTileModifier: ViewModifier {
    let cornerRadius: CGFloat
    let controlSize: ControlSize
    let useStatic3DSurface: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .commerceStatsLiquidGlassTileButton(
                cornerRadius: cornerRadius,
                controlSize: controlSize,
                useStatic3DSurface: useStatic3DSurface
            )
    }
}

// MARK: - Carte « Avis Google » (UX dédiée + impact mensuel persistant)

private struct CommerceStatsGoogleReviewsCard: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay

    let row: CommerceCategoryRowData
    let detail: CommerceGoogleReviewsDetail

    @AppStorage("myfidpass.stats.googleReviews.monthlyHistory.v1") private var monthlyHistoryJSON: String = "{}"
    @State private var cachedMonthHistory: [String: Int] = [:]

    private var g: Bool { commerceStatsGlassOverlay }
    private var accent: Color { Color(red: 0.36, green: 0.52, blue: 1.0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .padding(.bottom, 10)

            valueTrendRow
                .padding(.bottom, 14)

            impactBars
        }
        .padding(.top, 16)
        .padding(.bottom, 10)
        .padding(.leading, 18)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            cachedMonthHistory = parseMonthHistory(monthlyHistoryJSON)
            persistMonthValueIfNeeded()
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 8) {
            googleReviewsIcon
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(CommerceStatisticsTheme.kpiTileTitleFont())
                    .foregroundStyle(CommerceStatisticsTheme.kpiTileTitleGradient(forGlassOverlay: g))
                Text("Nouveaux avis Google")
                    .font(CommerceStatisticsTheme.statsText(size: 12, weight: .medium))
                    .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g))
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var googleReviewsIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))
            Image("avisgl")
                .resizable()
                .scaledToFit()
                .padding(5)
        }
        .frame(width: 42, height: 42)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    private var valueTrendRow: some View {
        let monthValue = max(0, detail.newReviewsInPeriod)
        let trend = monthTrendPct()
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("+\(StatsFR.formatInt(monthValue))")
                .font(CommerceStatisticsTheme.statisticNumbers(size: 30, weight: .bold))
                .foregroundStyle(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: g))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let t = trend {
                Text(impactTrendText(from: t))
                    .font(CommerceStatisticsTheme.statisticNumbers(size: 16, weight: .semibold))
                    .foregroundStyle(CommerceStatisticsTheme.kpiTrendPositiveGreen)
            }
            Spacer(minLength: 0)
        }
    }

    private var impactBars: some View {
        let monthValue = max(0, detail.newReviewsInPeriod)
        let maxMonth = max(monthValue, 1)

        return VStack(alignment: .leading, spacing: 10) {
            impactMetricRow(
                label: "Nouveaux avis Google",
                valueText: "+\(StatsFR.formatInt(monthValue))",
                ratio: CGFloat(Double(monthValue) / Double(maxMonth)),
                reveal: 1,
                tint: accent
            )
        }
    }

    private func impactMetricRow(label: String, valueText: String, ratio: CGFloat, reveal: CGFloat, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .font(CommerceStatisticsTheme.statsText(size: 12, weight: .semibold))
                    .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g))
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(valueText)
                    .font(CommerceStatisticsTheme.statisticNumbers(size: 14, weight: .semibold))
                    .foregroundStyle(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: g))
            }

            GeometryReader { geo in
                let w = max(0, geo.size.width)
                let clamped = min(1, max(0, ratio))
                let fillW = max(6, w * clamped * reveal)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.95), tint.opacity(0.72)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: fillW)
                            .overlay(alignment: .trailing) {
                                Circle()
                                    .fill(tint.opacity(0.22))
                                    .frame(width: 14, height: 14)
                                    .offset(x: 2)
                            }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            }
            .frame(height: 14)
        }
    }

    private func monthTrendPct() -> Double? {
        let key = normalizedMonthKey(detail.monthKey)
        guard let prev = cachedMonthHistory[previousMonthKey(from: key)], prev > 0 else { return nil }
        let cur = max(0, detail.newReviewsInPeriod)
        let delta = (Double(cur - prev) / Double(prev)) * 100.0
        guard delta > 0 else { return nil }
        return delta
    }

    private func impactTrendText(from delta: Double) -> String {
        "+\(StatsFR.formatDoubleSmart(delta))%"
    }

    private func persistMonthValueIfNeeded() {
        let key = normalizedMonthKey(detail.monthKey)
        let cur = max(0, detail.newReviewsInPeriod)
        var hist = cachedMonthHistory
        let existing = hist[key] ?? 0
        if cur > existing {
            hist[key] = cur
            cachedMonthHistory = hist
            monthlyHistoryJSON = historyJSONString(from: hist)
        }
    }

    private func monthHistory() -> [String: Int] {
        cachedMonthHistory
    }

    private func parseMonthHistory(_ rawJSON: String) -> [String: Int] {
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

    private func historyJSONString(from history: [String: Int]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: history, options: [.sortedKeys]),
              let s = String(data: data, encoding: .utf8)
        else { return "{}" }
        return s
    }

    private func normalizedMonthKey(_ raw: String?) -> String {
        let candidate = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if CommerceStatsMonthNavigator.isCalendarMonthPeriod(candidate) { return candidate }
        return CommerceStatsMonthNavigator.calendarMonthKey()
    }

    private func previousMonthKey(from key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]) else { return key }
        let cal = Calendar(identifier: .gregorian)
        guard let d = cal.date(from: DateComponents(year: y, month: m, day: 1)),
              let prev = cal.date(byAdding: .month, value: -1, to: d)
        else { return key }
        return CommerceStatsMonthNavigator.calendarMonthKey(for: prev)
    }

    private func monthLabelFromFirstHistory(defaultKey: String) -> String {
        let key = monthHistory().keys.sorted().first ?? defaultKey
        return CommerceStatsMonthNavigator.displayTitleMonthOnly(forMonthKey: key).lowercased()
    }
}

private struct CommerceStatsGoogleReviewsDisplayRow: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay

    let row: CommerceCategoryRowData
    let detail: CommerceGoogleReviewsDetail
    let onViewReviews: () -> Void

    private var g: Bool { commerceStatsGlassOverlay }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CommerceStatsGoogleReviewsCard(row: row, detail: detail)

            Button(action: onViewReviews) {
                    HStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(CommerceStatisticsTheme.statsText(size: 13, weight: .semibold))
                        Text("Voir les avis")
                            .font(CommerceStatisticsTheme.statsText(size: 14, weight: .semibold))
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(CommerceStatisticsTheme.statsText(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .accessibilityLabel("Voir les avis Google du commerce")
        }
    }
}

// MARK: - Carte « Clients actifs / inactifs » (UX alignée sur Points attribués)

private struct CommerceStatsAudienceSplitCard: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay

    let row: CommerceCategoryRowData
    let split: CommerceAudienceSplitData

    private var g: Bool { commerceStatsGlassOverlay }
    private let activeColor = CommerceStatisticsTheme.brandGreen
    private let inactiveColor = Color(red: 0.98, green: 0.42, blue: 0.42)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(row.title)
                .font(CommerceStatisticsTheme.kpiTileTitleFont())
                .foregroundStyle(CommerceStatisticsTheme.kpiTileTitleGradient(forGlassOverlay: g))
                .padding(.bottom, 14)

            audienceBarsBlock
        }
        .padding(.top, 16)
        .padding(.bottom, 14)
        .padding(.leading, 18)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var audienceBarsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            audienceMetricRow(
                label: "Clients actifs",
                count: split.activeCount,
                pct: split.activeFraction * 100,
                tint: activeColor,
                reveal: 1,
                glowOpacity: 0.34
            )
            audienceMetricRow(
                label: "Clients inactifs",
                count: split.inactiveCount,
                pct: split.inactiveFraction * 100,
                tint: inactiveColor,
                reveal: 1,
                glowOpacity: 0.28
            )
        }
    }

    private func audienceMetricRow(label: String, count: Int, pct: Double, tint: Color, reveal: CGFloat, glowOpacity: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .font(CommerceStatisticsTheme.statsText(size: 12, weight: .semibold))
                    .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g))
                Spacer(minLength: 6)
                Text(StatsFR.formatInt(count))
                    .font(CommerceStatisticsTheme.statisticNumbers(size: 14, weight: .semibold))
                    .foregroundStyle(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: g))
                compactPercentValue(
                    pct,
                    numberSize: 12,
                    percentSize: 9,
                    color: tint
                )
            }

            GeometryReader { geo in
                let w = max(0, geo.size.width)
                let target = CGFloat(min(1, max(0, pct / 100)))
                let filledW = max(6, w * target * reveal)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.95), tint.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: filledW)
                            .overlay(alignment: .trailing) {
                                Circle()
                                    .fill(tint.opacity(glowOpacity * 0.65))
                                    .frame(width: 14, height: 14)
                                    .offset(x: 2)
                            }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            }
            .frame(height: 14)
        }
    }

    private func compactPercentValue(_ value: Double, numberSize: CGFloat, percentSize: CGFloat, color: Color) -> some View {
        let n = StatsFR.formatPct(value).replacingOccurrences(of: " %", with: "")
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(n)
                .font(CommerceStatisticsTheme.statisticNumbers(size: numberSize, weight: .semibold))
            Text("%")
                .font(CommerceStatisticsTheme.statisticNumbers(size: percentSize, weight: .bold))
                .baselineOffset(1)
        }
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

private struct CommerceStatsAudienceSplitListButtonRow: View {
    let row: CommerceCategoryRowData
    let split: CommerceAudienceSplitData
    let onRowTap: () -> Void

    var body: some View {
        Button {
            onRowTap()
        } label: {
            CommerceStatsAudienceSplitCard(row: row, split: split)
        }
    }
}

struct CommerceStatsSectionHeader: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay

    let title: String
    var titleFontSize: CGFloat = 17
    var titleWeight: Font.Weight = .semibold
    var trailing: String? = nil
    /// Affiche le chevron seulement si la section est interactive (évite l’effet « menu » trompeur).
    var showsChevron: Bool = false
    var onManage: (() -> Void)? = nil

    @ViewBuilder
    var body: some View {
        let g = commerceStatsGlassOverlay
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 4) {
                Text(title)
                    .font(CommerceStatisticsTheme.statsChromeSectionTitle(size: titleFontSize, weight: titleWeight))
                    .foregroundStyle(CommerceStatisticsTheme.pageTitle(forGlassOverlay: g))
                if showsChevron {
                    Image(systemName: "chevron.down")
                        .font(CommerceStatisticsTheme.statsText(size: 11, weight: .bold))
                        .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g))
                }
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(CommerceStatisticsTheme.statsText(size: 14, weight: .medium))
                    .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g))
            }
            if let onManage {
                Button("Gérer", action: onManage)
                    .font(CommerceStatisticsTheme.statsText(size: 15, weight: .semibold))
                    .foregroundStyle(CommerceStatisticsTheme.accentBlue)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Connecter les réseaux

struct CommerceStatsConnectNetworksButton: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay

    let subtitle: String
    /// Réseaux déjà connectés (`instagram`, `tiktok`, `facebook`, `x`) — masqués dans la rangée d’icônes.
    var connectedNetworkIds: Set<String> = []
    var glassOverlayMode: Bool = false
    var isStampsProgram: Bool = false
    let action: () -> Void

    private var g: Bool { commerceStatsGlassOverlay || glassOverlayMode }
    private let cornerRadius = CommerceStatsIndicatorLiquidGlass.kpiCornerRadius

    struct NetworkBrand: Identifiable {
        let id: String
        let asset: String
        let cornerRadius: CGFloat
    }

    static let allNetworks: [NetworkBrand] = [
        NetworkBrand(id: "instagram", asset: "SocialInstagram", cornerRadius: 0),
        NetworkBrand(id: "tiktok", asset: "SocialTikTok", cornerRadius: 0),
        NetworkBrand(id: "facebook", asset: "SocialFacebook", cornerRadius: 0),
        NetworkBrand(id: "x", asset: "SocialX", cornerRadius: 7),
    ]

    private var pendingNetworks: [NetworkBrand] {
        Self.allNetworks.filter { !connectedNetworkIds.contains($0.id) }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                if !pendingNetworks.isEmpty {
                    HStack(spacing: 14) {
                        ForEach(pendingNetworks) { net in
                            brandIcon(net)
                        }
                        Spacer(minLength: 0)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(subtitle)
                        .font(CommerceStatisticsTheme.statsText(size: 14, weight: .semibold))
                        .foregroundStyle(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: g))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if isStampsProgram {
                        Text("1 tampon offert au total pour tous les réseaux")
                            .font(CommerceStatisticsTheme.statsText(size: 12, weight: .medium))
                            .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g))
                    }
                }

                Text("Connecter mes réseaux")
                    .font(CommerceStatisticsTheme.statsText(size: 16, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black)
                    )
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .commerceStatsLiquidGlassTileButton(
            cornerRadius: cornerRadius,
            controlSize: .large,
            useStatic3DSurface: true
        )
        .accessibilityLabel("Connecter mes réseaux")
        .accessibilityHint(subtitle)
    }

    @ViewBuilder
    private func brandIcon(_ net: NetworkBrand) -> some View {
        Group {
            if UIImage(named: net.asset) != nil {
                Image(net.asset)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "network")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.55))
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(RoundedRectangle(cornerRadius: net.cornerRadius, style: .continuous))
    }
}
