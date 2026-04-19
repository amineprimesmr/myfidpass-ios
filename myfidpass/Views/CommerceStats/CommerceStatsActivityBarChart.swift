//
//  CommerceStatsActivityBarChart.swift
//  myfidpass
//

import SwiftUI

/// Histogramme simple type Revolut (une ou deux barres + repères).
struct CommerceStatsActivityBarChart: View {
    let primaryValue: CGFloat
    let secondaryValue: CGFloat
    let primaryLabel: String
    let secondaryLabel: String
    var axisCaption: String = ""

    var body: some View {
        let maxV = max(primaryValue, secondaryValue, 1)
        let hPrimary = max(32, 140 * (primaryValue / maxV))
        let hSecondary = max(24, 140 * (secondaryValue / maxV))

        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 28) {
                VStack(spacing: 8) {
                    Text(primaryLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(CommerceStatisticsTheme.positive)
                        .frame(width: 52, height: hPrimary)
                }
                VStack(spacing: 8) {
                    Text(secondaryLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(CommerceStatisticsTheme.negative.opacity(0.9))
                        .frame(width: 52, height: hSecondary)
                }
            }
            .frame(height: 168)
            .frame(maxWidth: .infinity)

            if !axisCaption.isEmpty {
                Text(axisCaption)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
            }
        }
    }
}
