//
//  CommerceStatsCategoryListCard.swift
//  myfidpass
//

import SwiftUI

struct CommerceStatsCategoryListCard: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay

    let rows: [CommerceCategoryRowData]
    var onRowTap: ((String) -> Void)? = nil

    /// Hauteur unique pour chaque pastille (ligne audience avec barre + légende = cas le plus haut).
    private static let rowTileMinHeight: CGFloat = 148
    private static let rowSpacing: CGFloat = 12

    private func rowTileMinHeight(for row: CommerceCategoryRowData) -> CGFloat {
        guard let lines = row.rewardUsageLines, !lines.isEmpty else { return Self.rowTileMinHeight }
        let extra = CGFloat(lines.count) * 22 + 14
        return max(Self.rowTileMinHeight, 96 + extra)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            ForEach(rows) { row in
                Button {
                    onRowTap?(row.id)
                } label: {
                    categoryRowContent(row: row)
                        .frame(maxWidth: .infinity, minHeight: rowTileMinHeight(for: row), alignment: .topLeading)
                }
                .buttonStyle(.plain)
                .commerceStatsLiquidGlassTileButton(
                    cornerRadius: CommerceStatsIndicatorLiquidGlass.kpiCornerRadius,
                    controlSize: .large,
                    backgroundFillOpacity: CommerceStatisticsTheme.kpiClusterTileBackgroundOpacity
                )
            }
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
                        .font(CommerceStatisticsTheme.statsText(size: 15, weight: .semibold))
                        .foregroundStyle(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: commerceStatsGlassOverlay))
                    Text(row.subtitle)
                        .font(CommerceStatisticsTheme.statsText(size: 12, weight: .medium))
                        .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: commerceStatsGlassOverlay))
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(row.rightPrimary)
                        .font(CommerceStatisticsTheme.statisticNumbers(size: 15, weight: .semibold))
                        .foregroundStyle(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: commerceStatsGlassOverlay))
                    if !row.rightSecondary.isEmpty {
                        Text(row.rightSecondary)
                            .font(CommerceStatisticsTheme.statisticNumbers(size: 12, weight: .medium))
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
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
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
                .animation(.spring(response: 0.35, dampingFraction: 0.88), value: split.activeCount)
                .animation(.spring(response: 0.35, dampingFraction: 0.88), value: split.inactiveCount)
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
