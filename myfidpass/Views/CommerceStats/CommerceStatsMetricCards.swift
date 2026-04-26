//
//  CommerceStatsMetricCards.swift
//  myfidpass
//

import SwiftUI

// MARK: - Liquid glass tuiles KPI (déclaré ici pour rester dans la cible Xcode si l’app n’inclut pas tous les fichiers du dossier)

enum CommerceStatsIndicatorLiquidGlass {
    static let kpiCornerRadius: CGFloat = 22
}

// MARK: - Liquid Glass indicateurs (même chaîne que le reste de l’app / Process : `glassStyle` + forme)

extension View {
    /// Boutons-tuiles KPI / listes : verre sombre natif `glassStyleDark` + forme (API `Glass.regular.tint`).
    func commerceStatsLiquidGlassTileButton(
        cornerRadius: CGFloat,
        controlSize: ControlSize = .large,
        backgroundFillOpacity: CGFloat = 0.92
    ) -> some View {
        self
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(CommerceStatisticsTheme.cardElevated.opacity(backgroundFillOpacity))
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .buttonBorderShape(.roundedRectangle(radius: cornerRadius))
            .controlSize(controlSize)
    }

    func commerceStatsKpiLiquidGlassButton(
        action: @escaping () -> Void = {},
        cornerRadius: CGFloat = CommerceStatsIndicatorLiquidGlass.kpiCornerRadius,
        controlSize: ControlSize = .large,
        backgroundFillOpacity: CGFloat = CommerceStatisticsTheme.kpiClusterTileBackgroundOpacity
    ) -> some View {
        Button(action: action) {
            self
        }
        .commerceStatsLiquidGlassTileButton(
            cornerRadius: cornerRadius,
            controlSize: controlSize,
            backgroundFillOpacity: backgroundFillOpacity
        )
    }

    func commerceStatsDarkLiquidGlassCard(cornerRadius: CGFloat) -> some View {
        glassEffectRegularDark(cornerRadius: cornerRadius)
    }
}

// MARK: - Sparkline Membres (tracé + néon)

private struct MembersSparklineLineShape: Shape {
    var points: [CGFloat]
    var trimEnd: CGFloat

    var animatableData: CGFloat {
        get { trimEnd }
        set { trimEnd = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = max(1, rect.width)
        let hTotal = max(1, rect.height)
        let lineWidth: CGFloat = 4
        let topInset: CGFloat = 2
        let bottomInset = lineWidth * 0.5
        let h = max(1, hTotal - topInset - bottomInset)
        let yFor: (CGFloat) -> CGFloat = { p in topInset + h - (p * h * 0.92) }

        var path = Path()
        guard !points.isEmpty else { return path }
        let plotted: [CGPoint] = points.enumerated().map { idx, p in
            let x = CGFloat(idx) / CGFloat(max(1, points.count - 1)) * w
            return CGPoint(x: x, y: yFor(p))
        }
        if plotted.count == 1 {
            path.move(to: plotted[0])
            return path
        }
        path.move(to: plotted[0])
        if plotted.count == 2 {
            path.addLine(to: plotted[1])
            return path.trimmedPath(from: 0, to: max(0, min(1, trimEnd)))
        }

        // Lissage doux des angles avec courbes quadratiques.
        for idx in 1 ..< plotted.count - 1 {
            let prev = plotted[idx]
            let next = plotted[idx + 1]
            let mid = CGPoint(x: (prev.x + next.x) * 0.5, y: (prev.y + next.y) * 0.5)
            path.addQuadCurve(to: mid, control: prev)
        }
        path.addQuadCurve(to: plotted[plotted.count - 1], control: plotted[plotted.count - 2])
        return path.trimmedPath(from: 0, to: max(0, min(1, trimEnd)))
    }
}

private struct MembersSparklineAreaShape: Shape {
    let points: [CGFloat]

    func path(in rect: CGRect) -> Path {
        let w = max(1, rect.width)
        let hTotal = max(1, rect.height)
        let lineWidth: CGFloat = 4
        let topInset: CGFloat = 2
        let bottomInset = lineWidth * 0.5
        let h = max(1, hTotal - topInset - bottomInset)
        let yFor: (CGFloat) -> CGFloat = { p in topInset + h - (p * h * 0.92) }

        var path = Path()
        guard !points.isEmpty else { return path }
        var plotted: [CGPoint] = []
        for (idx, p) in points.enumerated() {
            let x = CGFloat(idx) / CGFloat(max(1, points.count - 1)) * w
            plotted.append(CGPoint(x: x, y: yFor(p)))
        }
        let yBase = rect.maxY
        path.move(to: CGPoint(x: 0, y: yBase))
        if plotted.count == 1 {
            path.addLine(to: plotted[0])
            path.addLine(to: CGPoint(x: w, y: yBase))
            path.closeSubpath()
            return path
        }
        path.addLine(to: plotted[0])
        if plotted.count == 2 {
            path.addLine(to: plotted[1])
        } else {
            for idx in 1 ..< plotted.count - 1 {
                let prev = plotted[idx]
                let next = plotted[idx + 1]
                let mid = CGPoint(x: (prev.x + next.x) * 0.5, y: (prev.y + next.y) * 0.5)
                path.addQuadCurve(to: mid, control: prev)
            }
            path.addQuadCurve(to: plotted[plotted.count - 1], control: plotted[plotted.count - 2])
        }
        path.addLine(to: CGPoint(x: w, y: yBase))
        path.closeSubpath()
        return path
    }
}

struct CommerceStatsLargeMetricCard: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let title: String
    let value: String
    /// Petit libellé sous la valeur (ex. « cartes au total »).
    var valueCaption: String? = nil
    var subtitle: String? = nil
    /// Série hebdo [0,1] alignée sur l’API (membres ou repli opérations) — **pas** les parts du donut.
    var membersWeeklySparkline: [CGFloat] = []
    let segments: [CommerceDonutSegment]
    var onTap: (() -> Void)? = nil
    /// Transition zoom (iOS 18+) : fournir `id` + `namespace` avec `onTap`.
    var zoomTransitionSourceID: String? = nil
    var zoomTransitionNamespace: Namespace.ID? = nil
    /// Animation néon + tracé à l’ouverture (carte Membres).
    var playNeonLineIntro: Bool = true

    @State private var membersLineTrim: CGFloat = 0
    @State private var membersNeonWeight: CGFloat = 1
    @State private var membersAreaReveal: CGFloat = 0
    @State private var membersHeadScale: CGFloat = 0.01

    var body: some View {
        Group {
            if let onTap {
                if let zid = zoomTransitionSourceID, let ns = zoomTransitionNamespace {
                    Button(action: onTap) {
                        membersMetricCardLabel
                            .zoomTransitionSource(id: zid, in: ns)
                    }
                    .commerceStatsLiquidGlassTileButton(
                        cornerRadius: CommerceStatsIndicatorLiquidGlass.kpiCornerRadius,
                        controlSize: .large,
                        backgroundFillOpacity: CommerceStatisticsTheme.kpiClusterTileBackgroundOpacity
                    )
                } else {
                    Button(action: onTap) {
                        membersMetricCardLabel
                    }
                    .commerceStatsLiquidGlassTileButton(
                        cornerRadius: CommerceStatsIndicatorLiquidGlass.kpiCornerRadius,
                        controlSize: .large,
                        backgroundFillOpacity: CommerceStatisticsTheme.kpiClusterTileBackgroundOpacity
                    )
                }
            } else {
                membersMetricCardLabel
                    .commerceStatsKpiLiquidGlassButton(controlSize: .large)
            }
        }
    }

    private var membersMetricCardLabel: some View {
        let lineColor = Color(red: 0.33, green: 0.94, blue: 0.66)
        return VStack(spacing: 0) {
            cardHeader(lineColor: lineColor)
                .padding(.top, 12)
                .padding(.horizontal, 14)

            membersAreaChart(lineColor: lineColor)
                .frame(height: 104)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cardHeader(lineColor: Color) -> some View {
        let g = commerceStatsGlassOverlay
        let primary = CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: g)
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(CommerceStatisticsTheme.kpiTileTitleFont())
                .foregroundStyle(CommerceStatisticsTheme.kpiTileTitleForeground(forGlassOverlay: g))

            Text(value)
                .font(CommerceStatisticsTheme.statisticNumbers(size: 22, weight: .bold))
                .foregroundStyle(primary)
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            HStack(spacing: 6) {
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(CommerceStatisticsTheme.statsText(size: 12, weight: .semibold))
                        .foregroundStyle(lineColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                if let valueCaption, !valueCaption.isEmpty {
                    Text(valueCaption)
                        .font(CommerceStatisticsTheme.statsText(size: 15, weight: .semibold))
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
        let lineWidth: CGFloat = 4
        let neon = max(0, min(1, membersNeonWeight))
        return GeometryReader { geo in
            let w = max(1, geo.size.width)
            let hTotal = max(1, geo.size.height)
            let topInset: CGFloat = 2
            let bottomInset = lineWidth * 0.5 + 2
            let h = max(1, hTotal - topInset - bottomInset)
            let yForPoint: (CGFloat) -> CGFloat = { p in topInset + h - (p * h * 0.92) }
            let lastIdx = max(0, points.count - 1)
            let headX = CGFloat(lastIdx) / CGFloat(max(1, lastIdx)) * w
            let headY = points.isEmpty ? hTotal * 0.5 : yForPoint(points[lastIdx])

            ZStack(alignment: .topLeading) {
                MembersSparklineAreaShape(points: points)
                    .fill(
                        LinearGradient(
                            colors: [lineColor.opacity(0.42), lineColor.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .mask(
                        HStack(spacing: 0) {
                            Rectangle()
                                .frame(width: w * max(0, min(1, membersAreaReveal)))
                            Spacer(minLength: 0)
                        }
                        .frame(width: w, height: hTotal, alignment: .leading)
                    )

                MembersSparklineLineShape(points: points, trimEnd: membersLineTrim)
                    .stroke(
                        lineColor.opacity(0.28 + 0.35 * neon),
                        style: StrokeStyle(lineWidth: lineWidth + 12 * neon, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: 9 * neon)

                MembersSparklineLineShape(points: points, trimEnd: membersLineTrim)
                    .stroke(
                        lineColor.opacity(0.55 + 0.25 * neon),
                        style: StrokeStyle(lineWidth: lineWidth + 5 * neon, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: 4.5 * neon)

                MembersSparklineLineShape(points: points, trimEnd: membersLineTrim)
                    .stroke(
                        Color.white.opacity(0.55 * neon),
                        style: StrokeStyle(lineWidth: max(1, lineWidth * 0.35 * neon), lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: 2 * neon)

                MembersSparklineLineShape(points: points, trimEnd: membersLineTrim)
                    .stroke(
                        lineColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )

                if !points.isEmpty, membersLineTrim > 0.94 {
                    ZStack {
                        Circle()
                            .fill(lineColor.opacity(0.45 * neon))
                            .frame(width: 22 + 10 * neon, height: 22 + 10 * neon)
                            .blur(radius: 6 * neon)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [lineColor, lineColor.opacity(0.15)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 10
                                )
                            )
                            .frame(width: 9, height: 9)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.35 + 0.4 * neon), lineWidth: 1)
                            )
                    }
                    .position(x: headX, y: headY)
                    .scaleEffect(membersHeadScale)
                }
            }
            .frame(width: w, height: hTotal, alignment: .topLeading)
            .onAppear {
                runMembersChartIntroAnimation()
            }
        }
    }

    private func runMembersChartIntroAnimation() {
        guard playNeonLineIntro else {
            membersLineTrim = 1
            membersNeonWeight = 0
            membersAreaReveal = 1
            membersHeadScale = 1
            return
        }
        if accessibilityReduceMotion {
            membersLineTrim = 1
            membersNeonWeight = 0
            membersAreaReveal = 1
            membersHeadScale = 1
            return
        }

        membersLineTrim = 0
        membersNeonWeight = 1
        membersAreaReveal = 0
        membersHeadScale = 0.15

        withAnimation(.timingCurve(0.22, 0.08, 0.2, 1.0, duration: 1.45)) {
            membersLineTrim = 1
        }
        withAnimation(.easeOut(duration: 0.72).delay(0.06)) {
            membersAreaReveal = 1
        }
        withAnimation(.easeInOut(duration: 1.52).delay(0.62)) {
            membersNeonWeight = 0
        }
        withAnimation(.spring(response: 0.72, dampingFraction: 0.74).delay(1.05)) {
            membersHeadScale = 1
        }
    }

    private var chartPoints: [CGFloat] {
        if !membersWeeklySparkline.isEmpty { return membersWeeklySparkline }
        // Pas de donnée d’évolution : ligne neutre (évite une fausse « forme » toujours identique).
        return [0.5, 0.5, 0.5, 0.5, 0.5]
    }
}

struct CommerceStatsCompactMetricCard: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay

    let title: String
    let value: String
    let trendText: String?
    var trendPositive: Bool?
    var footnote: String?
    /// Tap sur toute la tuile (ex. panier repère).
    var onCardTap: (() -> Void)? = nil
    var bottom: AnyView

    init(
        title: String,
        value: String,
        trendText: String?,
        trendPositive: Bool? = nil,
        footnote: String? = nil,
        onCardTap: (() -> Void)? = nil,
        @ViewBuilder bottom: () -> some View
    ) {
        self.title = title
        self.value = value
        self.trendText = trendText
        self.trendPositive = trendPositive
        self.footnote = footnote
        self.onCardTap = onCardTap
        self.bottom = AnyView(bottom())
    }

    var body: some View {
        let g = commerceStatsGlassOverlay
        let stack = VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(CommerceStatisticsTheme.kpiTileTitleFont())
                .foregroundStyle(CommerceStatisticsTheme.kpiTileTitleForeground(forGlassOverlay: g))
                .lineLimit(2)
                .minimumScaleFactor(0.88)
            Text(value)
                .font(CommerceStatisticsTheme.statisticNumbers(size: 22, weight: .bold))
                .foregroundStyle(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: g))
                .minimumScaleFactor(0.62)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if let trendText, !trendText.isEmpty {
                HStack(spacing: 4) {
                    if let trendPositive {
                        Image(systemName: trendPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(CommerceStatisticsTheme.statsText(size: 9, weight: .bold))
                            .foregroundStyle(trendPositive ? CommerceStatisticsTheme.positive : CommerceStatisticsTheme.negative)
                    }
                    Text(trendText)
                        .font(CommerceStatisticsTheme.statisticNumbers(size: 12, weight: .semibold))
                        .foregroundStyle(trendColor(glass: g))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }
            if let footnote, !footnote.isEmpty {
                Text(footnote)
                    .font(CommerceStatisticsTheme.statsText(size: 11, weight: .medium))
                    .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g).opacity(0.95))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: false)
            }
            Spacer(minLength: 0)
            bottom
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        return Group {
            if let onCardTap {
                stack.commerceStatsKpiLiquidGlassButton(action: onCardTap, controlSize: .large)
            } else {
                stack.commerceStatsKpiLiquidGlassButton(controlSize: .large)
            }
        }
    }

    private func trendColor(glass: Bool) -> Color {
        guard let trendPositive else { return CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: glass) }
        return trendPositive ? CommerceStatisticsTheme.positive : CommerceStatisticsTheme.negative
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
                        controlSize: .large,
                        backgroundFillOpacity: CommerceStatisticsTheme.kpiClusterTileBackgroundOpacity
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
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
        }
        .modifier(TopBarLiquidGlassButtonModifier())
        .accessibilityLabel("Retour")
    }
}
