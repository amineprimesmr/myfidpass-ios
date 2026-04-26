//
//  CommerceStatsDonutChart.swift
//  myfidpass
//

import SwiftUI

struct CommerceStatsDonutChart: View {
    let segments: [CommerceDonutSegment]
    let centerTitle: String
    let centerValue: String
    let centerCaption: String
    var lineWidth: CGFloat = 22

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - lineWidth / 2
                var start = Angle.degrees(-90)
                let valid = segments.filter { $0.fraction > 0.001 }
                if valid.isEmpty {
                    var ring = Path()
                    ring.addArc(center: center, radius: radius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
                    ctx.stroke(ring, with: .color(CommerceStatisticsTheme.secondaryLabel.opacity(0.35)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    return
                }
                for seg in valid {
                    let sweep = Angle.degrees(360 * seg.fraction)
                    var arc = Path()
                    arc.addArc(center: center, radius: radius, startAngle: start, endAngle: start + sweep, clockwise: false)
                    ctx.stroke(arc, with: .color(seg.color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    start += sweep
                }
            }
            .aspectRatio(1, contentMode: .fit)

            VStack(spacing: 4) {
                Text(centerTitle)
                    .font(CommerceStatisticsTheme.statsText(size: 13, weight: .medium))
                    .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
                Text(centerValue)
                    .font(CommerceStatisticsTheme.statisticNumbers(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(centerCaption)
                    .font(CommerceStatisticsTheme.statsText(size: 13, weight: .medium))
                    .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
            }
            .padding(.horizontal, 28)
        }
    }
}
