//
//  CommerceStatsHorizontalBreakdownBar.swift
//  myfidpass
//

import SwiftUI

struct CommerceStatsHorizontalBreakdownBar: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay

    let segments: [CommerceDonutSegment]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let valid = segments.filter { $0.fraction > 0.001 }
            HStack(spacing: 0) {
                if valid.isEmpty {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: commerceStatsGlassOverlay).opacity(0.35))
                } else {
                    ForEach(valid) { s in
                        RoundedRectangle(cornerRadius: 0, style: .continuous)
                            .fill(s.color)
                            .frame(width: max(4, w * CGFloat(s.fraction)))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .frame(height: 8)
    }
}

struct CommerceStatsBreakdownLegend: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay

    let segments: [CommerceDonutSegment]

    var body: some View {
        let valid = segments.filter { $0.fraction > 0.02 }
        HStack(spacing: 14) {
            ForEach(valid) { s in
                HStack(spacing: 6) {
                    Circle()
                        .fill(s.color)
                        .frame(width: 7, height: 7)
                    Text(s.label)
                        .font(CommerceStatisticsTheme.statsText(size: 11, weight: .medium))
                        .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: commerceStatsGlassOverlay))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
