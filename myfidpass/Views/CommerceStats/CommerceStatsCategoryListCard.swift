//
//  CommerceStatsCategoryListCard.swift
//  myfidpass
//

import SwiftUI

struct CommerceStatsCategoryListCard: View {
    let rows: [CommerceCategoryRowData]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                if idx > 0 {
                    Divider()
                        .background(Color.white.opacity(0.06))
                        .padding(.leading, 54)
                }
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(CommerceStatisticsTheme.pillBackground)
                            .frame(width: 40, height: 40)
                        Image(systemName: row.iconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(row.swatch)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(row.subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(row.rightPrimary)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(row.rightSecondary)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(CommerceStatisticsTheme.card)
        )
    }
}

struct CommerceStatsSectionHeader: View {
    let title: String
    var trailing: String? = nil
    var onManage: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
            }
            if let onManage {
                Button("Gérer", action: onManage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CommerceStatisticsTheme.accentBlue)
            }
        }
        .padding(.horizontal, 4)
    }
}
