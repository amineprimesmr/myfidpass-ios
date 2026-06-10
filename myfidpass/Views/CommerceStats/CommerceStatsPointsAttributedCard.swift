//
//  CommerceStatsPointsAttributedCard.swift
//  myfidpass
//
//  Tuile « Points attribués » : même structure UX qu’un indicateur type « order completion »
//  (titre, info, valeur, tendance, courbe lissée, grille, repères, point) — couleurs page stats.
//

import SwiftUI

private enum CommerceStatsPointsAttributedCardInfo {
    static let message =
        "Montant de points fidélité crédités sur la période affichée. La courbe suit l’activité hebdomadaire (passages en caisse). La variation % compare la dernière semaine de la série à la précédente."
}

// MARK: - Tracé (ligne lissée + aire, comme les sparklines Commerce)

private struct PointsAttributedLineShape: Shape {
    let values: [CGFloat]

    func path(in rect: CGRect) -> Path {
        let w = max(1, rect.width)
        let h = max(1, rect.height)
        let topPad: CGFloat = 6
        let bottomPad: CGFloat = 8
        let usableH = max(1, h - topPad - bottomPad)
        guard !values.isEmpty else { return Path() }
        let pts: [CGPoint] = values.enumerated().map { idx, v in
            let x = CGFloat(idx) / CGFloat(max(1, values.count - 1)) * w
            let y = topPad + usableH - (min(1, max(0, v)) * usableH * 0.92)
            return CGPoint(x: x, y: y)
        }
        var p = Path()
        p.move(to: pts[0])
        if pts.count == 1 { return p }
        if pts.count == 2 {
            p.addLine(to: pts[1])
            return p
        }
        for i in 1 ..< pts.count - 1 {
            let cur = pts[i]
            let next = pts[i + 1]
            let mid = CGPoint(x: (cur.x + next.x) * 0.5, y: (cur.y + next.y) * 0.5)
            p.addQuadCurve(to: mid, control: cur)
        }
        p.addQuadCurve(to: pts[pts.count - 1], control: pts[pts.count - 2])
        return p
    }
}

private struct PointsAttributedAreaShape: Shape {
    let values: [CGFloat]

    func path(in rect: CGRect) -> Path {
        let w = max(1, rect.width)
        let h = max(1, rect.height)
        let yBase = rect.maxY
        let topPad: CGFloat = 6
        let bottomPad: CGFloat = 8
        let usableH = max(1, h - topPad - bottomPad)
        guard !values.isEmpty else { return Path() }
        let pts: [CGPoint] = values.enumerated().map { idx, v in
            let x = CGFloat(idx) / CGFloat(max(1, values.count - 1)) * w
            let y = topPad + usableH - (min(1, max(0, v)) * usableH * 0.92)
            return CGPoint(x: x, y: y)
        }
        var p = Path()
        p.move(to: CGPoint(x: 0, y: yBase))
        p.addLine(to: pts[0])
        if pts.count == 1 {
            p.addLine(to: CGPoint(x: w, y: yBase))
            p.closeSubpath()
            return p
        }
        if pts.count == 2 {
            p.addLine(to: pts[1])
        } else {
            for i in 1 ..< pts.count - 1 {
                let cur = pts[i]
                let next = pts[i + 1]
                let mid = CGPoint(x: (cur.x + next.x) * 0.5, y: (cur.y + next.y) * 0.5)
                p.addQuadCurve(to: mid, control: cur)
            }
            p.addQuadCurve(to: pts[pts.count - 1], control: pts[pts.count - 2])
        }
        p.addLine(to: CGPoint(x: w, y: yBase))
        p.closeSubpath()
        return p
    }
}

// MARK: - Carte

struct CommerceStatsPointsAttributedCard: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay

    let row: CommerceCategoryRowData
    let detail: CommercePointsAttributedDetail
    /// Quand `false`, l’icône i est gérée par `CommerceStatsPointsAttributedListButtonRow` (évite un `Button` dans un `Button`).
    var showsInlineInfo: Bool = true

    @State private var showInfoSheet = false

    private var g: Bool { commerceStatsGlassOverlay }
    private var lineColor: Color { Color(red: 0.12, green: 0.52, blue: 0.66) }
    private var trendColor: Color { CommerceStatisticsTheme.kpiTrendPositiveGreen }

    var body: some View {
        Group {
            if showsInlineInfo {
                mainStack
                    .alert("Points attribués", isPresented: $showInfoSheet) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(CommerceStatsPointsAttributedCardInfo.message)
                    }
            } else {
                mainStack
            }
        }
    }

    private var mainStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .padding(.bottom, 12)

            valueTrendBlock
                .padding(.bottom, 6)

            Text("vs semaine précédente")
                .font(CommerceStatisticsTheme.statsText(size: 11, weight: .medium))
                .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g).opacity(0.9))
                .padding(.bottom, 14)

            chartBlock
        }
        .padding(.top, 16)
        .padding(.bottom, 14)
        .padding(.leading, 18)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(CommerceStatisticsTheme.kpiTileTitleFont())
                    .foregroundStyle(CommerceStatisticsTheme.kpiTileTitleGradient(forGlassOverlay: g))
                HStack {
                    Text(row.subtitle)
                        .font(CommerceStatisticsTheme.statsText(size: 13, weight: .medium))
                        .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g))
                    if !row.rightSecondary.isEmpty {
                        Text("·")
                            .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g).opacity(0.5))
                        Text("poids \(row.rightSecondary)")
                            .font(CommerceStatisticsTheme.statsText(size: 13, weight: .medium))
                            .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g))
                    }
                }
            }
            Spacer(minLength: 8)
            if showsInlineInfo {
                Button {
                    showInfoSheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(CommerceStatisticsTheme.statsText(size: 17, weight: .regular))
                        .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g).opacity(0.85))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Informations sur les points attribués")
            }
        }
    }

    @ViewBuilder
    private var valueTrendBlock: some View {
        let primaryValue = row.rightPrimary.hasPrefix("+") ? String(row.rightPrimary.dropFirst()) : row.rightPrimary
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(primaryValue)
                .font(CommerceStatisticsTheme.statisticNumbers(size: 30, weight: .bold))
            .foregroundStyle(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: g))
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            if let t = detail.trendPct {
                Text(trendMagnitudeString(t))
                    .font(CommerceStatisticsTheme.statisticNumbers(size: 16, weight: .semibold))
                    .foregroundStyle(trendColor)
                .padding(.leading, 10)
            }
            Spacer(minLength: 0)
        }
    }

    private func trendMagnitudeString(_ t: Double) -> String {
        let sign = t >= 0 ? "+" : "−"
        let pct = String(format: "%.1f%%", abs(t))
        return sign + pct
    }

    private var chartBlock: some View {
        let values = detail.sparkline
        let peakIndex = values.enumerated().max(by: { $0.element < $1.element })?.offset ?? max(0, values.count - 1)

        return ZStack(alignment: .topLeading) {
            CommerceStatsPointsAttributedDotGrid()
            chartReferenceLines(peakXFraction: chartPeakX(fraction: peakIndex, count: values.count))
            ZStack(alignment: .bottomLeading) {
                PointsAttributedAreaShape(values: values)
                    .fill(
                        LinearGradient(
                            colors: [lineColor.opacity(0.28), lineColor.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                PointsAttributedLineShape(values: values)
                    .stroke(
                        lineColor.opacity(0.22),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                PointsAttributedLineShape(values: values)
                    .stroke(
                        lineColor,
                        style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round)
                    )
            }

            if !values.isEmpty {
                peakMarker(values: values, index: peakIndex)
            }
        }
        .drawingGroup(opaque: false, colorMode: .nonLinear)
        .frame(height: 100)
        .clipped()
    }

    private func chartPeakX(fraction index: Int, count: Int) -> CGFloat {
        guard count > 1 else { return 0.5 }
        return CGFloat(index) / CGFloat(max(1, count - 1))
    }

    @ViewBuilder
    private func chartReferenceLines(peakXFraction: CGFloat) -> some View {
        let guideY: CGFloat = 0.24
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            Path { p in
                p.move(to: CGPoint(x: 0, y: h * guideY))
                p.addLine(to: CGPoint(x: w, y: h * guideY))
            }
            .stroke(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g).opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            Path { p in
                let x = peakXFraction * w
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: h))
            }
            .stroke(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g).opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .allowsHitTesting(false)
    }

    private func peakMarker(values: [CGFloat], index: Int) -> some View {
        GeometryReader { proxy in
            let w = max(1, proxy.size.width)
            let h = max(1, proxy.size.height)
            let topPad: CGFloat = 6
            let bottomPad: CGFloat = 8
            let usableH = max(1, h - topPad - bottomPad)
            let v = min(1, max(0, values[min(index, values.count - 1)]))
            let x = CGFloat(index) / CGFloat(max(1, values.count - 1)) * w
            let y = topPad + usableH - (v * usableH * 0.92)
            ZStack {
                Circle()
                    .fill(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: g).opacity(0.96))
                    .frame(width: 9, height: 9)
                Circle()
                    .strokeBorder(lineColor, lineWidth: 2)
                    .frame(width: 9, height: 9)
            }
            .position(x: x, y: y)
        }
    }
}

// MARK: - Ligne « Plus de données » : tap principal + i séparé (pas de `Button` imbriqué)

struct CommerceStatsPointsAttributedListButtonRow: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay

    let row: CommerceCategoryRowData
    let detail: CommercePointsAttributedDetail
    let onRowTap: () -> Void
    @State private var showInfo = false
    private var g: Bool { commerceStatsGlassOverlay }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                onRowTap()
            } label: {
                CommerceStatsPointsAttributedCard(row: row, detail: detail, showsInlineInfo: false)
            }

            Button {
                showInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(CommerceStatisticsTheme.statsText(size: 17, weight: .regular))
                    .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g).opacity(0.85))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Informations sur les points attribués")
            .padding(.trailing, 20)
            .padding(.top, 16)
            .zIndex(2)
        }
        .alert("Points attribués", isPresented: $showInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(CommerceStatsPointsAttributedCardInfo.message)
        }
    }
}

// MARK: - Grille de points

private struct CommerceStatsPointsAttributedDotGrid: View {
    private let cols = 24
    private let rows = 6

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let stepX = w / CGFloat(max(1, cols - 1))
            let stepY = h / CGFloat(max(1, rows - 1))
            let dot = Color.white.opacity(0.1)
            ForEach(0..<rows, id: \.self) { r in
                ForEach(0..<cols, id: \.self) { c in
                    Circle()
                        .fill(dot)
                        .frame(width: 1.2, height: 1.2)
                        .position(x: CGFloat(c) * stepX, y: CGFloat(r) * stepY)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
