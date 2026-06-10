//
//  CommerceStatsRewardsUsedCard.swift
//  myfidpass
//
//  Tuile « Récompenses utilisées » : mêmes blocs que la référence (lignes chiffre + tendance + libellé),
//  libellé = nom de la récompense, couleurs thème page statistiques.
//

import SwiftUI

private enum CommerceStatsRewardsUsedCardInfo {
    static let message =
        "Chaque ligne correspond à un type de récompense échangé sur la période. "
        + "Le second chiffre est la part (en points du total) des rachats ; le repère vert ou rouge "
        + "indique si cette part est au moins la répartition « équitable » (100 % ÷ nombre de types)."
}

struct CommerceStatsRewardsUsedCard: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay

    let row: CommerceCategoryRowData
    let detail: CommerceRewardsUsedDetail
    var showsInlineInfo: Bool = true

    @State private var showInfoSheet = false

    private var g: Bool { commerceStatsGlassOverlay }
    private var trendGreen: Color { CommerceStatisticsTheme.kpiTrendPositiveGreen }

    var body: some View {
        Group {
            if showsInlineInfo {
                mainContent
                    .alert("Récompenses utilisées", isPresented: $showInfoSheet) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(CommerceStatsRewardsUsedCardInfo.message)
                    }
            } else {
                mainContent
            }
        }
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(detail.items.enumerated()), id: \.offset) { _, item in
                    rewardMetricRow(item)
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 14)
        .padding(.leading, 18)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(row.title)
                .font(CommerceStatisticsTheme.kpiTileTitleFont())
                .foregroundStyle(CommerceStatisticsTheme.kpiTileTitleGradient(forGlassOverlay: g))
            Spacer(minLength: 8)
            if showsInlineInfo {
                Button {
                    showInfoSheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(CommerceStatisticsTheme.statsText(size: 17, weight: .regular))
                        .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g).opacity(0.85))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Informations sur les récompenses utilisées")
            }
        }
    }

    private func rewardMetricRow(_ item: CommerceRewardUsedLineItem) -> some View {
        return HStack(alignment: .center, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(StatsFR.formatInt(item.count))
                    .font(CommerceStatisticsTheme.statisticNumbers(size: 30, weight: .bold))
                    .foregroundStyle(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: g))
                    .monospacedDigit()

                Text("+\(StatsFR.formatInt(item.shareRounded))%")
                    .font(CommerceStatisticsTheme.statisticNumbers(size: 16, weight: .semibold))
                    .foregroundStyle(trendGreen)
                    .monospacedDigit()
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 10)

            Text(item.label)
                .font(CommerceStatisticsTheme.statsText(size: 13, weight: .regular))
                .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g).opacity(1))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.92),
                            Color.white.opacity(0.86),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.07), lineWidth: 0.75)
        )
    }
}

// MARK: - Liste « Plus de données » : pas de `Button` imbriqué pour l’info

struct CommerceStatsRewardsUsedListButtonRow: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay

    let row: CommerceCategoryRowData
    let detail: CommerceRewardsUsedDetail
    let onRowTap: () -> Void
    @State private var showInfo = false
    private var g: Bool { commerceStatsGlassOverlay }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                onRowTap()
            } label: {
                CommerceStatsRewardsUsedCard(row: row, detail: detail, showsInlineInfo: false)
            }

            Button {
                showInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(CommerceStatisticsTheme.statsText(size: 17, weight: .regular))
                    .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g).opacity(0.85))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Informations sur les récompenses utilisées")
            .padding(.trailing, 20)
            .padding(.top, 16)
            .zIndex(2)
        }
        .alert("Récompenses utilisées", isPresented: $showInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(CommerceStatsRewardsUsedCardInfo.message)
        }
    }
}
