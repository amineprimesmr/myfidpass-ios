//
//  CommerceStatsMetricCards.swift
//  myfidpass
//

import SwiftUI

struct CommerceStatsLargeMetricCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let segments: [CommerceDonutSegment]
    var onTap: (() -> Void)? = nil

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { cardInner }
                    .buttonStyle(.plain)
            } else {
                cardInner
            }
        }
    }

    private var cardInner: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
            }
            CommerceStatsHorizontalBreakdownBar(segments: segments)
            CommerceStatsBreakdownLegend(segments: segments)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(CommerceStatisticsTheme.card)
        )
    }
}

struct CommerceStatsCompactMetricCard: View {
    let title: String
    let value: String
    let trendText: String?
    var trendPositive: Bool?
    var footnote: String?
    var bottom: AnyView

    init(
        title: String,
        value: String,
        trendText: String?,
        trendPositive: Bool? = nil,
        footnote: String? = nil,
        @ViewBuilder bottom: () -> some View
    ) {
        self.title = title
        self.value = value
        self.trendText = trendText
        self.trendPositive = trendPositive
        self.footnote = footnote
        self.bottom = AnyView(bottom())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            if let trendText, !trendText.isEmpty {
                HStack(spacing: 4) {
                    if let trendPositive {
                        Image(systemName: trendPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(trendPositive ? CommerceStatisticsTheme.positive : CommerceStatisticsTheme.negative)
                    }
                    Text(trendText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(trendColor)
                }
            }
            if let footnote, !footnote.isEmpty {
                Text(footnote)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CommerceStatisticsTheme.secondaryLabel.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            bottom
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(CommerceStatisticsTheme.card)
        )
    }

    private var trendColor: Color {
        guard let trendPositive else { return CommerceStatisticsTheme.secondaryLabel }
        return trendPositive ? CommerceStatisticsTheme.positive : CommerceStatisticsTheme.negative
    }
}

struct CommerceStatsOverviewCard: View {
    let title: String
    let value: String
    let legend: String
    var barColor: Color = CommerceStatisticsTheme.accentBlue
    var onTap: (() -> Void)? = nil

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { cardInner }
                    .buttonStyle(.plain)
            } else {
                cardInner
            }
        }
    }

    private var cardInner: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(CommerceStatisticsTheme.pillBackground)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(barColor)
                        .frame(width: g.size.width * 0.92)
                }
            }
            .frame(height: 6)
            HStack(spacing: 8) {
                Circle()
                    .fill(barColor)
                    .frame(width: 8, height: 8)
                Text(legend)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(CommerceStatisticsTheme.card)
        )
    }
}

struct CommerceStatsBackCircleButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(CommerceStatisticsTheme.pillBackground))
        }
        .buttonStyle(.plain)
    }
}
