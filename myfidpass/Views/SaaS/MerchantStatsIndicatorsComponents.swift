import SwiftUI

// MARK: - KPI Cards

struct MerchantStatsKpiCardView: View {
    let model: MerchantStatsKpiCardModel

    var body: some View {
        Group {
            switch model.kind {
            case .ratio:
                if let ratioPercent = model.ratioPercent {
                    MerchantStatsRatioProgressCardView(model: model, ratioPercent: ratioPercent)
                } else {
                    MerchantStatsValueCardView(model: model)
                }
            case .value:
                MerchantStatsValueCardView(model: model)
            }
        }
        .accessibilityLabel(model.accessibilityLabel)
    }
}

private struct MerchantStatsValueCardView: View {
    let model: MerchantStatsKpiCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.title)
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text(model.value)
                .font(AppTheme.Fonts.title3())
                .foregroundStyle(AppTheme.Colors.textPrimary)
            if let subtitle = model.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(AppTheme.Fonts.caption2())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
    }
}

private struct MerchantStatsRatioProgressCardView: View {
    let model: MerchantStatsKpiCardModel
    let ratioPercent: Double

    private var clamped: Double { min(100, max(0, ratioPercent)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.title)
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)

            Text(model.value)
                .font(AppTheme.Fonts.title3())
                .foregroundStyle(AppTheme.Colors.textPrimary)

            if clamped > 0 {
                ProgressView(value: clamped, total: 100)
                    .tint(AppTheme.Colors.primary)
                    .frame(maxWidth: .infinity)
            } else {
                ProgressView(value: 0, total: 100)
                    .tint(AppTheme.Colors.primary)
                    .frame(maxWidth: .infinity)
            }

            if let subtitle = model.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(AppTheme.Fonts.caption2())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
    }
}

