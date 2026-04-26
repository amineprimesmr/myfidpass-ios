//
//  CommerceStatsMiniBarChart.swift
//  myfidpass
//

import SwiftUI

private struct CommerceMiniSparklineLineShape: Shape {
    let values: [CGFloat]

    func path(in rect: CGRect) -> Path {
        let w = max(1, rect.width)
        let h = max(1, rect.height)
        guard !values.isEmpty else { return Path() }
        let maxVal = max(values.max() ?? 1, 1)
        let pts: [CGPoint] = values.enumerated().map { idx, v in
            let x = CGFloat(idx) / CGFloat(max(1, values.count - 1)) * w
            let y = h - (max(0, v) / maxVal) * (h * 0.92)
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
            let prev = pts[i]
            let next = pts[i + 1]
            let mid = CGPoint(x: (prev.x + next.x) * 0.5, y: (prev.y + next.y) * 0.5)
            p.addQuadCurve(to: mid, control: prev)
        }
        p.addQuadCurve(to: pts[pts.count - 1], control: pts[pts.count - 2])
        return p
    }
}

private struct CommerceMiniSparklineAreaShape: Shape {
    let values: [CGFloat]

    func path(in rect: CGRect) -> Path {
        let w = max(1, rect.width)
        let h = max(1, rect.height)
        guard !values.isEmpty else { return Path() }
        let maxVal = max(values.max() ?? 1, 1)
        let pts: [CGPoint] = values.enumerated().map { idx, v in
            let x = CGFloat(idx) / CGFloat(max(1, values.count - 1)) * w
            let y = h - (max(0, v) / maxVal) * (h * 0.92)
            return CGPoint(x: x, y: y)
        }
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h))
        p.addLine(to: pts[0])
        if pts.count == 1 {
            p.addLine(to: CGPoint(x: w, y: h))
            p.closeSubpath()
            return p
        }
        if pts.count == 2 {
            p.addLine(to: pts[1])
        } else {
            for i in 1 ..< pts.count - 1 {
                let prev = pts[i]
                let next = pts[i + 1]
                let mid = CGPoint(x: (prev.x + next.x) * 0.5, y: (prev.y + next.y) * 0.5)
                p.addQuadCurve(to: mid, control: prev)
            }
            p.addQuadCurve(to: pts[pts.count - 1], control: pts[pts.count - 2])
        }
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
        return p
    }
}

struct CommerceStatsMiniBarChart: View {
    let weeks: [CommerceBarWeekData]
    var barColor: Color = .white.opacity(0.85)

    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(weeks) { w in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(barColor.opacity(0.25 + 0.75 * Double(w.value)))
                    .frame(height: max(6, 44 * CGFloat(w.value)))
            }
        }
        .frame(height: 48)
    }
}

struct CommerceStatsMiniSparklineChart: View {
    let weeks: [CommerceBarWeekData]
    var lineColor: Color = CommerceStatisticsTheme.positive

    private var values: [CGFloat] {
        let vals = weeks.map { max(0, $0.value) }
        if vals.isEmpty { return [0.5, 0.5, 0.5, 0.5, 0.5] }
        return vals
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CommerceMiniSparklineAreaShape(values: values)
                .fill(
                    LinearGradient(
                        colors: [lineColor.opacity(0.34), lineColor.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            CommerceMiniSparklineLineShape(values: values)
                .stroke(lineColor.opacity(0.35), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                .blur(radius: 4)

            CommerceMiniSparklineLineShape(values: values)
                .stroke(lineColor, style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
        }
        .frame(height: 48)
    }
}

struct CommerceStatsDualToneMiniBars: View {
    let topFraction: CGFloat
    let bottomFraction: CGFloat

    var body: some View {
        VStack(spacing: 5) {
            GeometryReader { g in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(CommerceStatisticsTheme.positive)
                    .frame(width: g.size.width, height: max(6, g.size.height * topFraction))
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            GeometryReader { g in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(CommerceStatisticsTheme.negative.opacity(0.85))
                    .frame(width: g.size.width, height: max(4, g.size.height * bottomFraction))
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(height: 44)
    }
}
