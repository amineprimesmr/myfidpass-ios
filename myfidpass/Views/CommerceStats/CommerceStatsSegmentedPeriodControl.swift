//
//  CommerceStatsSegmentedPeriodControl.swift
//  myfidpass
//

import SwiftUI

enum CommerceStatsPeriodTab: String, CaseIterable, Identifiable {
    case oneWeek = "7d"
    case oneMonth = "this_month"
    case sixMonths = "6m"
    case oneYear = "12m"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .oneWeek: return "1S"
        case .oneMonth: return "1M"
        case .sixMonths: return "6M"
        case .oneYear: return "1A"
        }
    }
}

struct CommerceStatsSegmentedPeriodControl: View {
    @Binding var selection: CommerceStatsPeriodTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CommerceStatsPeriodTab.allCases) { tab in
                let on = selection == tab
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        selection = tab
                    }
                } label: {
                    Text(tab.shortLabel)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(on ? .white : CommerceStatisticsTheme.secondaryLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(CommerceStatisticsTheme.pillBackground.opacity(1.15))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(CommerceStatisticsTheme.card.opacity(0.95))
        )
    }
}
