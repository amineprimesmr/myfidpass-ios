//
//  CommerceStatsMiniBarChart.swift
//  myfidpass
//

import SwiftUI

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
