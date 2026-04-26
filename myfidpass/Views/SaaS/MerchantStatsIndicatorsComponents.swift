import SwiftUI

// MARK: - Grille KPI (SaaS & cohérence pastilles)

enum MerchantStatsKpiGridLayout {
    /// Fente entre cellules (ne pas coller Actifs / Inactifs / Points…).
    static let interColumnSpacing: CGFloat = 14
    static let interRowSpacing: CGFloat = 14
    /// Même hauteur pour chaque pastille, alignée sur la carte « Membres » (ligne 1, style valeur).
    static let cellMinHeight: CGFloat = 122
}

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
        Button(action: {}) {
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
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: MerchantStatsKpiGridLayout.cellMinHeight, alignment: .topLeading)
            .padding()
        }
        .commerceStatsLiquidGlassTileButton(cornerRadius: AppTheme.Radius.md, controlSize: .regular)
    }
}

private struct MerchantStatsRatioProgressCardView: View {
    let model: MerchantStatsKpiCardModel
    let ratioPercent: Double

    private var clamped: Double { min(100, max(0, ratioPercent)) }

    var body: some View {
        Button(action: {}) {
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
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: MerchantStatsKpiGridLayout.cellMinHeight, alignment: .topLeading)
            .padding()
        }
        .commerceStatsLiquidGlassTileButton(cornerRadius: AppTheme.Radius.md, controlSize: .regular)
    }
}

