//
//  CommerceStatsMetricCards.swift
//  myfidpass
//

import SwiftUI
import Foundation

// MARK: - Liquid glass tuiles KPI (déclaré ici pour rester dans la cible Xcode si l’app n’inclut pas tous les fichiers du dossier)

enum CommerceStatsIndicatorLiquidGlass {
    static let kpiCornerRadius: CGFloat = 26
}

// MARK: - Tuiles KPI (relief 3D, noir profond — `CommerceStatsSculpted3DTileStyle`)

extension View {
    /// Tuiles **Membres / Panier / Fréquence** et listes : relief sculpté, ombre, liseré.
    /// - `useStatic3DSurface` : conteneur non-`Button` (ex. `ZStack` avec plusieurs `Button` internes).
    func commerceStatsLiquidGlassTileButton(
        cornerRadius: CGFloat,
        controlSize: ControlSize = .large,
        useStatic3DSurface: Bool = false
    ) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                self
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                self
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(0.94))
                    )
            }
        }
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
    /// Couleur principale de la courbe/zone.
    var chartLineColor: Color = Color(red: 0, green: 1, blue: 133.0 / 255.0) // #00ff85

    @State private var membersLineTrim: CGFloat = 0
    @State private var membersNeonWeight: CGFloat = 1
    @State private var membersAreaReveal: CGFloat = 0

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
                        controlSize: .large
                    )
                } else {
                    Button(action: onTap) {
                        membersMetricCardLabel
                    }
                    .commerceStatsLiquidGlassTileButton(
                        cornerRadius: CommerceStatsIndicatorLiquidGlass.kpiCornerRadius,
                        controlSize: .large
                    )
                }
            } else {
                membersMetricCardLabel
            }
        }
        .task(id: chartSignature) {
            // Évite les mutations d'état pendant le cycle de rendu SwiftUI.
            await scheduleMembersChartIntroAnimation()
        }
    }

    private var membersMetricCardLabel: some View {
        let lineColor = chartLineColor
        return VStack(spacing: 0) {
            cardHeader(lineColor: lineColor)
                .padding(.top, 16)
                .padding(.leading, 18)
                .padding(.trailing, 16)

            membersAreaChart(lineColor: lineColor)
                .frame(height: 104)
                .frame(maxWidth: .infinity)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 22,
                        bottomTrailingRadius: 22,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cardHeader(lineColor: Color) -> some View {
        let g = commerceStatsGlassOverlay
        let primary = CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: g)
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(CommerceStatisticsTheme.kpiTileTitleFont())
                .foregroundStyle(CommerceStatisticsTheme.kpiTileTitleGradient(forGlassOverlay: g))

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
        let lineWidth: CGFloat = 4
        let neon = max(0, min(1, membersNeonWeight))
        return GeometryReader { geo in
            let w = max(1, geo.size.width)
            let hTotal = max(1, geo.size.height)

            ZStack(alignment: .topLeading) {
                MembersSparklineAreaShape(points: points)
                    .fill(
                        LinearGradient(
                            colors: [lineColor.opacity(0.42), lineColor.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(membersAreaReveal)

                if neon > 0.01 {
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
                }

                MembersSparklineLineShape(points: points, trimEnd: membersLineTrim)
                    .stroke(
                        lineColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )

            }
            .drawingGroup()
            .frame(width: w, height: hTotal, alignment: .topLeading)
        }
    }

    @MainActor
    private func scheduleMembersChartIntroAnimation() async {
        await Task.yield()
        runMembersChartIntroAnimation()
    }

    private func runMembersChartIntroAnimation() {
        guard playNeonLineIntro, !CommerceStatsRuntimeSession.hasPlayedMembersLineIntro else {
            // Replay léger à chaque arrivée / mise à jour données (sans néon), clairement visible.
            membersLineTrim = 0
            membersNeonWeight = 0
            membersAreaReveal = 0.22
            if accessibilityReduceMotion {
                membersLineTrim = 1
                membersAreaReveal = 1
                return
            }
            withAnimation(.timingCurve(0.22, 0.08, 0.2, 1.0, duration: 0.62)) {
                membersLineTrim = 1
            }
            withAnimation(.easeOut(duration: 0.42).delay(0.06)) {
                membersAreaReveal = 1
            }
            return
        }
        if accessibilityReduceMotion {
            membersLineTrim = 1
            membersNeonWeight = 0
            membersAreaReveal = 1
            CommerceStatsRuntimeSession.hasPlayedMembersLineIntro = true
            return
        }

        membersLineTrim = 0
        membersNeonWeight = 1
        membersAreaReveal = 0

        withAnimation(.timingCurve(0.22, 0.08, 0.2, 1.0, duration: 1.45)) {
            membersLineTrim = 1
        }
        withAnimation(.easeOut(duration: 0.72).delay(0.06)) {
            membersAreaReveal = 1
        }
        withAnimation(.easeInOut(duration: 1.52).delay(0.62)) {
            membersNeonWeight = 0
        }
        CommerceStatsRuntimeSession.hasPlayedMembersLineIntro = true
    }

    private var chartPoints: [CGFloat] {
        if !membersWeeklySparkline.isEmpty { return membersWeeklySparkline }
        // Pas de donnée d’évolution : ligne neutre (évite une fausse « forme » toujours identique).
        return [0.5, 0.5, 0.5, 0.5, 0.5]
    }

    private var chartSignature: String {
        chartPoints
            .map { String(format: "%.4f", Double($0)) }
            .joined(separator: "|")
    }
}

struct CommerceStatsCompactMetricCard: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay

    let title: String
    let value: String
    var valueFontSize: CGFloat = 30
    var valueSubline: String? = nil
    var valueSublineFontSize: CGFloat = 13
    let trendText: String?
    var trendPositive: Bool?
    var footnote: String?
    /// Tap sur toute la tuile (ex. panier repère).
    var onCardTap: (() -> Void)? = nil
    var bottom: AnyView

    init(
        title: String,
        value: String,
        valueFontSize: CGFloat = 30,
        valueSubline: String? = nil,
        valueSublineFontSize: CGFloat = 13,
        trendText: String?,
        trendPositive: Bool? = nil,
        footnote: String? = nil,
        onCardTap: (() -> Void)? = nil,
        @ViewBuilder bottom: () -> some View
    ) {
        self.title = title
        self.value = value
        self.valueFontSize = valueFontSize
        self.valueSubline = valueSubline
        self.valueSublineFontSize = valueSublineFontSize
        self.trendText = trendText
        self.trendPositive = trendPositive
        self.footnote = footnote
        self.onCardTap = onCardTap
        self.bottom = AnyView(bottom())
    }

    var body: some View {
        let g = commerceStatsGlassOverlay
        let stack = VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(CommerceStatisticsTheme.kpiTileTitleFont())
                .foregroundStyle(CommerceStatisticsTheme.kpiTileTitleGradient(forGlassOverlay: g))
                .lineLimit(2)
                .minimumScaleFactor(0.88)
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
            if let trendText, !trendText.isEmpty {
                Text(trendText)
                    .font(CommerceStatisticsTheme.statisticNumbers(size: 17, weight: .semibold))
                    .foregroundStyle(CommerceStatisticsTheme.kpiTrendPositiveGreen)
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
            Spacer(minLength: 0)
            bottom
        }
        .padding(.top, 16)
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        return Group {
            if let onCardTap {
                stack.commerceStatsKpiLiquidGlassButton(action: onCardTap, controlSize: .large)
            } else {
                stack.commerceStatsKpiLiquidGlassButton(controlSize: .large)
            }
        }
    }

    private func trendColor(glass _: Bool) -> Color { CommerceStatisticsTheme.kpiTrendPositiveGreen }
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
