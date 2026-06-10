//
//  CommerceStatsMetricCards.swift
//  myfidpass
//

import SwiftUI
import UIKit

// MARK: - Liquid glass tuiles KPI (déclaré ici pour rester dans la cible Xcode si l’app n’inclut pas tous les fichiers du dossier)

enum CommerceStatsIndicatorLiquidGlass {
    static let kpiCornerRadius: CGFloat = 26
}

// MARK: - Tuiles KPI (relief 3D, noir profond — `CommerceStatsSculpted3DTileStyle`)

extension View {
    /// Tuiles **Membres / Panier / Fréquence** et listes : relief sculpté, ombre, liseré.
    /// - `useStatic3DSurface` : conteneur non-`Button` (ex. `ZStack` avec plusieurs `Button` internes).
    /// Surface carte simple (fond blanc + ombre légère) — évite `glassEffect` instable sur l’onglet Stats.
    func commerceStatsLiquidGlassTileButton(
        cornerRadius: CGFloat,
        controlSize: ControlSize = .large,
        useStatic3DSurface: Bool = false
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 4)
            )
            .controlSize(controlSize)
    }

    func commerceStatsKpiLiquidGlassButton(
        action: @escaping () -> Void = {},
        cornerRadius: CGFloat = CommerceStatsIndicatorLiquidGlass.kpiCornerRadius,
        controlSize: ControlSize = .large
    ) -> some View {
        Button(action: action) {
            self
        }
        .commerceStatsLiquidGlassTileButton(
            cornerRadius: cornerRadius,
            controlSize: controlSize,
            useStatic3DSurface: false
        )
    }

    func commerceStatsDarkLiquidGlassCard(cornerRadius: CGFloat) -> some View {
        glassEffectRegularDark(cornerRadius: cornerRadius)
    }
}

// MARK: - Sparkline Membres (tracé + néon)

private enum MembersSparklinePlotMetrics {
    static let topInset: CGFloat = 4
    static let bottomLabelBand: CGFloat = 20
    static let lineWidth: CGFloat = 4
    /// Marge réservée aux chiffres de l’axe X uniquement (courbe / aire bord à bord sur la carte).
    static let axisLabelHorizontalInset: CGFloat = 10

    static func plotHeight(totalHeight: CGFloat) -> CGFloat {
        max(1, totalHeight - topInset - bottomLabelBand)
    }

    static func y(forNormalized value: CGFloat, totalHeight: CGFloat) -> CGFloat {
        let plotH = plotHeight(totalHeight: totalHeight)
        return topInset + plotH - (value * plotH * 0.92)
    }

    /// Position X des points de courbe — pleine largeur de la tuile (sans marge latérale).
    static func x(
        at index: Int,
        dayLabels: [Int],
        pointCount: Int,
        width: CGFloat
    ) -> CGFloat {
        guard pointCount > 0 else { return 0 }
        if dayLabels.count == pointCount,
           let minDay = dayLabels.first,
           let maxDay = dayLabels.last,
           maxDay > minDay,
           index < dayLabels.count {
            let day = dayLabels[index]
            return CGFloat(day - minDay) / CGFloat(maxDay - minDay) * width
        }
        if pointCount == 1 { return width * 0.5 }
        return CGFloat(index) / CGFloat(pointCount - 1) * width
    }

    /// Position X des libellés jour sous la courbe (léger retrait pour éviter la coupure au bord).
    static func xAxisLabel(
        at index: Int,
        dayLabels: [Int],
        width: CGFloat
    ) -> CGFloat {
        let labels = dayLabels.filter { $0 > 0 }
        guard !labels.isEmpty else { return 0 }
        if labels.count == 1 { return width * 0.5 }
        let minDay = labels[0]
        let maxDay = labels[labels.count - 1]
        guard maxDay > minDay, index < labels.count else {
            return x(at: index, dayLabels: [], pointCount: labels.count, width: width)
        }
        let day = labels[index]
        let usableW = max(1, width - axisLabelHorizontalInset * 2)
        return axisLabelHorizontalInset + CGFloat(day - minDay) / CGFloat(maxDay - minDay) * usableW
    }

    static func plottedPoints(
        values: [CGFloat],
        dayLabels: [Int],
        in rect: CGRect
    ) -> [CGPoint] {
        let w = max(1, rect.width)
        let h = max(1, rect.height)
        return values.enumerated().map { idx, value in
            CGPoint(
                x: x(at: idx, dayLabels: dayLabels, pointCount: values.count, width: w),
                y: y(forNormalized: value, totalHeight: h)
            )
        }
    }

    /// Courbe lissée avec coins arrondis (quad curves entre les points).
    static func addSmoothCurve(to path: inout Path, through plotted: [CGPoint]) {
        guard let first = plotted.first else { return }
        path.move(to: first)
        if plotted.count == 1 { return }
        if plotted.count == 2 {
            path.addLine(to: plotted[1])
            return
        }
        for i in 1 ..< plotted.count - 1 {
            let cur = plotted[i]
            let next = plotted[i + 1]
            let mid = CGPoint(x: (cur.x + next.x) * 0.5, y: (cur.y + next.y) * 0.5)
            path.addQuadCurve(to: mid, control: cur)
        }
        path.addQuadCurve(to: plotted[plotted.count - 1], control: plotted[plotted.count - 2])
    }
}

private struct MembersSparklineLineShape: Shape {
    var points: [CGFloat]
    var dayLabels: [Int] = []
    var trimEnd: CGFloat

    var animatableData: CGFloat {
        get { trimEnd }
        set { trimEnd = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let plotted = MembersSparklinePlotMetrics.plottedPoints(
            values: points,
            dayLabels: dayLabels,
            in: rect
        )
        MembersSparklinePlotMetrics.addSmoothCurve(to: &path, through: plotted)
        return path.trimmedPath(from: 0, to: max(0, min(1, trimEnd)))
    }
}

private struct MembersSparklineAreaShape: Shape {
    let points: [CGFloat]
    var dayLabels: [Int] = []

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let plotted = MembersSparklinePlotMetrics.plottedPoints(
            values: points,
            dayLabels: dayLabels,
            in: rect
        )
        guard !plotted.isEmpty else { return path }

        let yBase = rect.maxY
        path.move(to: CGPoint(x: 0, y: yBase))
        path.addLine(to: plotted[0])
        if plotted.count == 1 {
            path.addLine(to: CGPoint(x: rect.width, y: yBase))
            path.closeSubpath()
            return path
        }
        if plotted.count == 2 {
            path.addLine(to: plotted[1])
        } else {
            for i in 1 ..< plotted.count - 1 {
                let cur = plotted[i]
                let next = plotted[i + 1]
                let mid = CGPoint(x: (cur.x + next.x) * 0.5, y: (cur.y + next.y) * 0.5)
                path.addQuadCurve(to: mid, control: cur)
            }
            path.addQuadCurve(to: plotted[plotted.count - 1], control: plotted[plotted.count - 2])
        }
        path.addLine(to: CGPoint(x: rect.width, y: yBase))
        path.closeSubpath()
        return path
    }
}

struct CommerceStatsLargeMetricCard: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay

    let title: String
    let value: String
    /// Petit libellé sous la valeur (ex. « cartes au total »).
    var valueCaption: String? = nil
    var subtitle: String? = nil
    /// Série hebdo [0,1] alignée sur l’API (membres ou repli opérations) — **pas** les parts du donut.
    var membersWeeklySparkline: [CGFloat] = []
    let segments: [CommerceDonutSegment]
    var onTap: (() -> Void)? = nil
    /// Couleur principale de la courbe/zone.
    var chartLineColor: Color = CommerceStatisticsTheme.brandGreen
    /// Logo PNG en tête de carte (réseaux sociaux).
    var headerIconAsset: String? = nil
    /// Dégradé sous la courbe ; repli sur `chartLineColor` si absent.
    var chartAreaGradientColors: [Color]? = nil
    /// Axe X « jour du mois » sous la courbe (tuile Membres).
    var showsMonthDayAxis: Bool = false
    /// Jalons API (`day_of_month`) ; repli 1…30 si vide.
    var monthDayAxisLabels: [Int] = []

    private static let defaultMonthDayAxisLabels = [1, 5, 10, 15, 20, 25, 30]

    private var resolvedMonthDayAxisLabels: [Int] {
        let labels = monthDayAxisLabels.filter { $0 > 0 }
        return labels.isEmpty ? Self.defaultMonthDayAxisLabels : labels
    }

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    membersMetricCardLabel
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: CommerceStatsIndicatorLiquidGlass.kpiCornerRadius,
                        style: .continuous
                    )
                )
                .commerceStatsLiquidGlassTileButton(
                    cornerRadius: CommerceStatsIndicatorLiquidGlass.kpiCornerRadius,
                    controlSize: .large
                )
            } else {
                membersMetricCardLabel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .commerceStatsLiquidGlassTileButton(
                        cornerRadius: CommerceStatsIndicatorLiquidGlass.kpiCornerRadius,
                        controlSize: .large,
                        useStatic3DSurface: true
                    )
            }
        }
    }

    private var membersMetricCardLabel: some View {
        let lineColor = chartLineColor
        return VStack(spacing: 0) {
            cardHeader(lineColor: lineColor)
                .padding(.top, 16)
                .padding(.leading, 18)
                .padding(.trailing, 16)

            Spacer(minLength: 0)

            membersAreaChart(lineColor: lineColor)
                .frame(height: 104)
                .frame(maxWidth: .infinity)
                .drawingGroup(opaque: false, colorMode: .nonLinear)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: CommerceStatsIndicatorLiquidGlass.kpiCornerRadius,
                        bottomTrailingRadius: CommerceStatsIndicatorLiquidGlass.kpiCornerRadius,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func cardHeader(lineColor: Color) -> some View {
        let g = commerceStatsGlassOverlay
        let primary = CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: g)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                if let headerIconAsset, UIImage(named: headerIconAsset) != nil {
                    Image(headerIconAsset)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                Text(title)
                    .font(CommerceStatisticsTheme.kpiTileTitleFont())
                    .foregroundStyle(CommerceStatisticsTheme.kpiTileTitleGradient(forGlassOverlay: g))
            }

            Text(value)
                .font(CommerceStatisticsTheme.statisticNumbers(size: 30, weight: .bold))
                .foregroundStyle(primary)
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            HStack(spacing: 6) {
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(CommerceStatisticsTheme.statsText(size: 13, weight: .semibold))
                        .foregroundStyle(lineColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                if let valueCaption, !valueCaption.isEmpty {
                    Text(valueCaption)
                        .font(CommerceStatisticsTheme.statsText(size: 16, weight: .semibold))
                        .foregroundStyle(lineColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(lineColor.opacity(0.18))
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func membersAreaChart(lineColor: Color) -> some View {
        let points = chartPoints
        let dayLabels = showsMonthDayAxis ? resolvedMonthDayAxisLabels : []
        let lineWidth = MembersSparklinePlotMetrics.lineWidth
        let gradientColors = chartAreaGradientColors ?? [lineColor.opacity(0.42), lineColor.opacity(0.10)]

        return GeometryReader { geo in
            let w = max(1, geo.size.width)
            let hTotal = max(1, geo.size.height)

            ZStack(alignment: .topLeading) {
                MembersSparklineAreaShape(points: points, dayLabels: dayLabels)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                MembersSparklineLineShape(points: points, dayLabels: dayLabels, trimEnd: 1)
                    .stroke(
                        lineColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )

                if showsMonthDayAxis {
                    membersMonthDayAxisOverlay(
                        width: w,
                        height: hTotal,
                        days: dayLabels
                    )
                }
            }
            .frame(width: w, height: hTotal, alignment: .topLeading)
        }
    }

    private func membersMonthDayAxisOverlay(width: CGFloat, height: CGFloat, days: [Int]) -> some View {
        let g = commerceStatsGlassOverlay
        let labels = days.filter { $0 > 0 }
        return ZStack {
            ForEach(Array(labels.enumerated()), id: \.element) { index, day in
                let x = MembersSparklinePlotMetrics.xAxisLabel(
                    at: index,
                    dayLabels: labels,
                    width: width
                )
                Text("\(day)")
                    .font(CommerceStatisticsTheme.statsText(size: 10, weight: .semibold))
                    .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g).opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .position(x: x, y: height - 10)
            }
        }
        .allowsHitTesting(false)
    }

    private var chartPoints: [CGFloat] {
        if !membersWeeklySparkline.isEmpty { return membersWeeklySparkline }
        let floor: CGFloat = 0.06
        if showsMonthDayAxis {
            return Array(repeating: floor, count: max(resolvedMonthDayAxisLabels.count, 7))
        }
        return Array(repeating: floor, count: 5)
    }
}

struct CommerceStatsCompactMetricCard: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay

    let title: String
    let value: String
    var valueFontSize: CGFloat = 30
    var valueSubline: String? = nil
    var valueSublineFontSize: CGFloat = 13
    /// Pastille sous la valeur (ex. « /mois » sur Fréquence d’achat).
    var valueBadge: String? = nil
    var valueBadgeColor: Color = CommerceStatisticsTheme.accentBlue
    let trendText: String?
    var trendPositive: Bool?
    /// Toujours vert pour la tendance (ex. Avis Google — jamais de rouge).
    var forcePositiveTrendColor: Bool = false
    var footnote: String?
    /// Icône à gauche du titre (ex. panier moyen).
    var leadingIconAsset: String? = nil
    var leadingIconSize: CGFloat = 28
    /// Icône décorative en haut à droite.
    var trailingIconAsset: String? = nil
    var trailingIconSize: CGFloat = 42
    /// Tap sur toute la tuile (ex. panier repère).
    var onCardTap: (() -> Void)? = nil
    /// Courbe bas de carte bord à bord (comme la tuile Membres).
    var edgeToEdgeBottomChart: Bool = false
    var bottomChartHeight: CGFloat = 52
    var bottom: AnyView

    init(
        title: String,
        value: String,
        valueFontSize: CGFloat = 30,
        valueSubline: String? = nil,
        valueSublineFontSize: CGFloat = 13,
        valueBadge: String? = nil,
        valueBadgeColor: Color = CommerceStatisticsTheme.accentBlue,
        trendText: String?,
        trendPositive: Bool? = nil,
        forcePositiveTrendColor: Bool = false,
        footnote: String? = nil,
        leadingIconAsset: String? = nil,
        leadingIconSize: CGFloat = 28,
        trailingIconAsset: String? = nil,
        trailingIconSize: CGFloat = 42,
        onCardTap: (() -> Void)? = nil,
        edgeToEdgeBottomChart: Bool = false,
        bottomChartHeight: CGFloat = 52,
        @ViewBuilder bottom: () -> some View
    ) {
        self.title = title
        self.value = value
        self.valueFontSize = valueFontSize
        self.valueSubline = valueSubline
        self.valueSublineFontSize = valueSublineFontSize
        self.valueBadge = valueBadge
        self.valueBadgeColor = valueBadgeColor
        self.trendText = trendText
        self.trendPositive = trendPositive
        self.forcePositiveTrendColor = forcePositiveTrendColor
        self.footnote = footnote
        self.leadingIconAsset = leadingIconAsset
        self.leadingIconSize = leadingIconSize
        self.trailingIconAsset = trailingIconAsset
        self.trailingIconSize = trailingIconSize
        self.onCardTap = onCardTap
        self.edgeToEdgeBottomChart = edgeToEdgeBottomChart
        self.bottomChartHeight = bottomChartHeight
        self.bottom = AnyView(bottom())
    }

    var body: some View {
        let g = commerceStatsGlassOverlay
        let stack = Group {
            if edgeToEdgeBottomChart {
                VStack(spacing: 0) {
                    compactCardHeader(glass: g)
                        .padding(.top, 16)
                        .padding(.leading, 18)
                        .padding(.trailing, 12)
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                    Spacer(minLength: 0)

                    bottom
                        .frame(height: bottomChartHeight)
                        .frame(maxWidth: .infinity)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: CommerceStatsIndicatorLiquidGlass.kpiCornerRadius,
                                bottomTrailingRadius: CommerceStatsIndicatorLiquidGlass.kpiCornerRadius,
                                topTrailingRadius: 0,
                                style: .continuous
                            )
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    compactCardHeader(glass: g)
                    Spacer(minLength: 0)
                    bottom
                }
                .padding(.top, 16)
                .padding(.leading, 18)
                .padding(.trailing, 12)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }

        return Group {
            if let onCardTap {
                stack.commerceStatsKpiLiquidGlassButton(action: onCardTap, controlSize: .large)
            } else {
                stack.commerceStatsKpiLiquidGlassButton(controlSize: .large)
            }
        }
    }

    private func compactCardHeader(glass g: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    if let leadingIconAsset, UIImage(named: leadingIconAsset) != nil {
                        Image(leadingIconAsset)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: leadingIconSize, height: leadingIconSize)
                            .clipShape(RoundedRectangle(cornerRadius: leadingIconSize * 0.24, style: .continuous))
                            .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
                            .accessibilityHidden(true)
                    }
                    Text(title)
                        .font(CommerceStatisticsTheme.kpiTileTitleFont())
                        .foregroundStyle(CommerceStatisticsTheme.kpiTileTitleGradient(forGlassOverlay: g))
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)
                }
                Text(value)
                    .font(CommerceStatisticsTheme.statisticNumbers(size: valueFontSize, weight: .bold))
                    .foregroundStyle(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: g))
                    .minimumScaleFactor(0.62)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let valueSubline, !valueSubline.isEmpty {
                    Text(valueSubline)
                        .font(CommerceStatisticsTheme.statsText(size: valueSublineFontSize, weight: .semibold))
                        .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g).opacity(0.98))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
                if let valueBadge, !valueBadge.isEmpty {
                    Text(valueBadge)
                        .font(CommerceStatisticsTheme.statsText(size: 13, weight: .semibold))
                        .foregroundStyle(valueBadgeColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(valueBadgeColor.opacity(0.18))
                        )
                }
                if let trendText, !trendText.isEmpty {
                    Text(trendText)
                        .font(CommerceStatisticsTheme.statisticNumbers(size: 17, weight: .semibold))
                        .foregroundStyle(trendColor(glass: g))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                if let footnote, !footnote.isEmpty {
                    Text(footnote)
                        .font(CommerceStatisticsTheme.statsText(size: 12, weight: .medium))
                        .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g).opacity(0.95))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .minimumScaleFactor(0.78)
                        .fixedSize(horizontal: false, vertical: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let trailingIconAsset, UIImage(named: trailingIconAsset) != nil {
                Image(trailingIconAsset)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: trailingIconSize, height: trailingIconSize)
                    .clipShape(RoundedRectangle(cornerRadius: trailingIconSize * 0.24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 3)
                    .accessibilityHidden(true)
            }
        }
    }

    private func trendColor(glass _: Bool) -> Color {
        if forcePositiveTrendColor { return CommerceStatisticsTheme.kpiTrendPositiveGreen }
        if let trendText, trendText.hasPrefix("+") { return CommerceStatisticsTheme.kpiTrendPositiveGreen }
        if trendPositive == false { return CommerceStatisticsTheme.negative }
        return CommerceStatisticsTheme.kpiTrendPositiveGreen
    }
}

// MARK: - Pied KPI Avis Google (« Voir les avis » intégré à la tuile)

struct CommerceStatsGoogleReviewsKpiFooter: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "map.fill")
                .font(CommerceStatisticsTheme.statsText(size: 11, weight: .semibold))
            Text("Voir les avis")
                .font(CommerceStatisticsTheme.statsText(size: 12, weight: .semibold))
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(CommerceStatisticsTheme.statsText(size: 10, weight: .bold))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// MARK: - Courbe Panier moyen (cumul ventes du mois — une ligne + point au dernier jour)

private enum PanierSparklinePlotMetrics {
    static let topInset: CGFloat = 10
    static let bottomInset: CGFloat = 12
    static let lineWidth: CGFloat = 3.4
    static let endDotDiameter: CGFloat = 8

    static func plotHeight(totalHeight: CGFloat) -> CGFloat {
        max(1, totalHeight - topInset - bottomInset)
    }

    static func y(forNormalized value: CGFloat, totalHeight: CGFloat) -> CGFloat {
        let plotH = plotHeight(totalHeight: totalHeight)
        return topInset + plotH - (value * plotH * 0.88)
    }

    static func x(at index: Int, dayLabels: [Int], pointCount: Int, width: CGFloat) -> CGFloat {
        MembersSparklinePlotMetrics.x(
            at: index,
            dayLabels: dayLabels,
            pointCount: pointCount,
            width: width
        )
    }

    static func plottedPoints(values: [CGFloat], dayLabels: [Int], in size: CGSize) -> [CGPoint] {
        let w = max(1, size.width)
        let h = max(1, size.height)
        return values.enumerated().map { idx, value in
            CGPoint(
                x: x(at: idx, dayLabels: dayLabels, pointCount: values.count, width: w),
                y: y(forNormalized: value, totalHeight: h)
            )
        }
    }
}

private struct PanierSparklineLineShape: Shape {
    var values: [CGFloat]
    var dayLabels: [Int]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !values.isEmpty else { return path }
        let plotted = PanierSparklinePlotMetrics.plottedPoints(values: values, dayLabels: dayLabels, in: rect.size)
        MembersSparklinePlotMetrics.addSmoothCurve(to: &path, through: plotted)
        return path
    }
}

struct CommerceStatsPanierEvolutionChart: View {
    let values: [CGFloat]
    let dayLabels: [Int]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let days = dayLabels.count == values.count ? dayLabels : Array(1 ... max(1, values.count))
            let points = PanierSparklinePlotMetrics.plottedPoints(values: values, dayLabels: days, in: size)
            let endIndex = points.indices.last { idx in
                idx < values.count && values[idx] > 0.12
            } ?? points.indices.last
            let endPoint = endIndex.map { points[$0] }

            ZStack {
                PanierSparklineLineShape(values: values, dayLabels: days)
                    .stroke(
                        Color.black.opacity(0.9),
                        style: StrokeStyle(
                            lineWidth: PanierSparklinePlotMetrics.lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )

                if let endPoint {
                    Circle()
                        .fill(Color.black)
                        .frame(
                            width: PanierSparklinePlotMetrics.endDotDiameter,
                            height: PanierSparklinePlotMetrics.endDotDiameter
                        )
                        .position(endPoint)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .bottomLeading)
        }
        .accessibilityLabel("Évolution des ventes du mois pour le panier moyen")
    }
}

struct CommerceStatsOverviewCard: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay

    let title: String
    let value: String
    let legend: String
    var barColor: Color = CommerceStatisticsTheme.accentBlue
    var onTap: (() -> Void)? = nil

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { overviewCardLabel }
                    .commerceStatsLiquidGlassTileButton(
                        cornerRadius: CommerceStatsIndicatorLiquidGlass.kpiCornerRadius,
                        controlSize: .large
                    )
            } else {
                overviewCardLabel
                    .commerceStatsKpiLiquidGlassButton(controlSize: .large)
            }
        }
    }

    private var overviewCardLabel: some View {
        let g = commerceStatsGlassOverlay
        let bar = g ? CommerceStatisticsTheme.neutralChartAccent(forGlassOverlay: true) : barColor
        return VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(CommerceStatisticsTheme.statsText(size: 13, weight: .medium))
                .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g))
            Text(value)
                .font(CommerceStatisticsTheme.statisticNumbers(size: 30, weight: .bold))
                .foregroundStyle(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: g))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(CommerceStatisticsTheme.pillBackground)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(bar)
                        .frame(width: geo.size.width * 0.92)
                }
            }
            .frame(height: 6)
            HStack(spacing: 8) {
                Circle()
                    .fill(bar)
                    .frame(width: 8, height: 8)
                Text(legend)
                    .font(CommerceStatisticsTheme.statsText(size: 12, weight: .medium))
                    .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CommerceStatsBackCircleButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(CommerceStatisticsTheme.statsText(size: 15, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 34, height: 34)
        }
        .background(Circle().fill(Color.white))
        .overlay(
            Circle()
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        )
        .buttonStyle(.plain)
        .accessibilityLabel("Retour")
    }
}
