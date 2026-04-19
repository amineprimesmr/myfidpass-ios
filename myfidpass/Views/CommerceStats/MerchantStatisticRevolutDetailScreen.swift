//
//  MerchantStatisticRevolutDetailScreen.swift
//  myfidpass
//
//  Écran détail « plein écran » inspiré de Revolut (Dépenses) : métrique, tendance, courbes, période, ventilation.
//

import Charts
import SwiftUI

struct MerchantStatisticRevolutDetailScreen: View {
    let topic: CommerceStatisticDetailTopic
    let initialPeriodRaw: String

    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm = MerchantStatsIndicatorsViewModel()
    @State private var periodTab: CommerceStatsPeriodTab
    @State private var chartMode: DetailChartMode = .line

    private enum DetailChartMode: Hashable {
        case line
        case bar
    }

    init(topic: CommerceStatisticDetailTopic, initialPeriodRaw: String) {
        self.topic = topic
        self.initialPeriodRaw = initialPeriodRaw
        let initial = CommerceStatsPeriodTab(rawValue: initialPeriodRaw) ?? .oneMonth
        _periodTab = State(initialValue: initial)
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

    private var chartPoints: [RevolutDetailChartPoint] {
        let vals = topic.chartValues(from: vm.evolution)
        guard !vals.isEmpty else { return [] }
        return vals.enumerated().map { i, v in
            let lagPrior = i > 0 ? vals[i - 1] : max(0, Int(Double(v) * 0.88))
            return RevolutDetailChartPoint(
                id: i,
                xLabel: xAxisLabel(index: i, total: vals.count),
                current: Double(v),
                prior: Double(lagPrior)
            )
        }
    }

    private func xAxisLabel(index: Int, total: Int) -> String {
        _ = total
        return "\(index + 1)"
    }

    private var weekOverWeekTrend: (arrow: String, text: String, favorable: Bool)? {
        let vals = topic.chartValues(from: vm.evolution)
        guard vals.count >= 2,
              let last = vals.last,
              let prev = vals.dropLast().last,
              prev > 0
        else { return nil }
        let pct = (Double(last - prev) / Double(prev)) * 100
        let favorable = last >= prev
        let arrow = favorable ? "▲" : "▼"
        let text = String(format: "%.0f %%", abs(pct))
        return (arrow, text, favorable)
    }

    var body: some View {
        ZStack {
            CommerceStatisticsTheme.background.ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 0.05, green: 0.12, blue: 0.28).opacity(0.55),
                    Color.clear,
                ],
                center: .topLeading,
                startRadius: 10,
                endRadius: 320
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 0.08, green: 0.22, blue: 0.14).opacity(0.35),
                    Color.clear,
                ],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 280
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    topToolbar

                    Text(topic.screenTitle)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(topic.primaryMetric(from: vm.stats))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)

                    if let t = weekOverWeekTrend {
                        HStack(spacing: 6) {
                            Text("\(t.arrow) \(t.text)")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(t.favorable ? CommerceStatisticsTheme.positive : CommerceStatisticsTheme.negative)
                            Text("·")
                                .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
                            Text(periodRightLabel)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
                        }
                    }

                    chartBlock
                        .padding(.top, 4)

                    CommerceStatsSegmentedPeriodControl(selection: $periodTab)
                        .padding(.top, 4)

                    Text(topic.chartFootnote)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CommerceStatisticsTheme.secondaryLabel.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)

                    CommerceStatsSectionHeader(title: "Par catégorie", onManage: {})
                        .padding(.top, 8)

                    CommerceStatsCategoryListCard(rows: topic.breakdownRows(stats: vm.stats))

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("Tout afficher")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(CommerceStatisticsTheme.accentBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)

                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)

            if vm.isLoading {
                VStack {
                    ProgressView()
                        .tint(.white)
                        .padding(.top, 8)
                    Spacer()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task(id: periodTab.rawValue) {
            await vm.load(period: periodTab.rawValue)
        }
    }

    private var topToolbar: some View {
        HStack(alignment: .center) {
            CommerceStatsBackCircleButton(action: { dismiss() })

            Spacer(minLength: 0)

            HStack(spacing: 2) {
                chartModeChip(.line, systemImage: "chart.xyaxis.line")
                chartModeChip(.bar, systemImage: "chart.bar.fill")
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    Task { await vm.load(period: periodTab.rawValue) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(3)
            .background(
                Capsule(style: .continuous)
                    .fill(CommerceStatisticsTheme.pillBackground.opacity(0.95))
            )
        }
    }

    private func chartModeChip(_ mode: DetailChartMode, systemImage: String) -> some View {
        let on = chartMode == mode
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                chartMode = mode
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(on ? .white : CommerceStatisticsTheme.secondaryLabel)
                .frame(width: 36, height: 32)
                .background {
                    if on {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(CommerceStatisticsTheme.cardElevated)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var chartBlock: some View {
        let pts = chartPoints
        if pts.isEmpty {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(CommerceStatisticsTheme.card)
                .frame(height: 220)
                .overlay {
                    Text("Pas assez de données pour ce graphique.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
                }
        } else {
            Group {
                switch chartMode {
                case .line:
                    lineChart(pts)
                case .bar:
                    barChart(pts)
                }
            }
            .frame(height: 240)
            .padding(.horizontal, 4)
        }
    }

    private func lineChart(_ pts: [RevolutDetailChartPoint]) -> some View {
        Chart {
            ForEach(pts) { p in
                LineMark(
                    x: .value("S", p.xLabel),
                    y: .value("P", p.prior)
                )
                .foregroundStyle(Color.white.opacity(0.22))
                .lineStyle(StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }
            ForEach(pts) { p in
                AreaMark(
                    x: .value("S", p.xLabel),
                    y: .value("V", p.current)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            CommerceStatisticsTheme.positive.opacity(0.38),
                            CommerceStatisticsTheme.positive.opacity(0.02),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            ForEach(pts) { p in
                LineMark(
                    x: .value("S", p.xLabel),
                    y: .value("C", p.current)
                )
                .foregroundStyle(CommerceStatisticsTheme.positive)
                .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }
            if let last = pts.last {
                PointMark(
                    x: .value("S", last.xLabel),
                    y: .value("D", last.current)
                )
                .symbolSize(72)
                .foregroundStyle(CommerceStatisticsTheme.positive)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6, dash: [4, 5]))
                    .foregroundStyle(Color.white.opacity(0.12))
                AxisValueLabel()
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
            }
        }
        .chartPlotStyle { plot in
            plot.padding(.trailing, 6)
        }
    }

    private func barChart(_ pts: [RevolutDetailChartPoint]) -> some View {
        Chart {
            ForEach(pts) { p in
                BarMark(
                    x: .value("S", p.xLabel),
                    y: .value("V", p.current)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            CommerceStatisticsTheme.positive,
                            CommerceStatisticsTheme.positive.opacity(0.55),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(5, style: .continuous)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6, dash: [4, 5]))
                    .foregroundStyle(Color.white.opacity(0.12))
                AxisValueLabel()
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
            }
        }
    }
}

private struct RevolutDetailChartPoint: Identifiable {
    let id: Int
    let xLabel: String
    let current: Double
    let prior: Double
}
