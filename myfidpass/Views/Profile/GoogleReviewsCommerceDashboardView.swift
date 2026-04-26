//
//  GoogleReviewsCommerceDashboardView.swift
//  myfidpass
//
//  Tableau de bord avis Google (Commerce) — lecture seule, données synchronisées automatiquement.
//

import Charts
import SwiftUI

/// Barres dérivées de l’historique API (`social-metrics`).
private struct GoogleReviewHistoryBar: Identifiable {
    let id: String
    let label: String
    let reviews: Double
}

/// UX « dashboard » : synthèse, progression, graphique — non interactive (`allowsHitTesting(false)`).
struct GoogleReviewsCommerceDashboardView: View {
    /// Place ID renseigné côté engagement (vide = état vide).
    let placeIdTrimmed: String
    /// Faux lorsque le parent affiche déjà un titre (ex. carte « Avis Google » dans l’onglet Commerce).
    let showTitleRow: Bool
    /// Message d’état vide orienté bouton « Configurer » sous le bloc (onglet Commerce).
    let emptyStateHighlightsConfigureButton: Bool

    init(
        placeIdTrimmed: String,
        showTitleRow: Bool = true,
        emptyStateHighlightsConfigureButton: Bool = false
    ) {
        self.placeIdTrimmed = placeIdTrimmed
        self.showTitleRow = showTitleRow
        self.emptyStateHighlightsConfigureButton = emptyStateHighlightsConfigureButton
    }

    @State private var summary: SocialMetricsSummaryResponse?
    @State private var channel: SocialMetricsChannelRow?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var lastAutoRefresh: Date?

    private var hasPlace: Bool { !placeIdTrimmed.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !hasPlace {
                emptyPlaceState
            } else if isLoading && channel == nil {
                loadingBlock
            } else if let err = loadError, channel == nil {
                Text(err)
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.error)
                    .padding(.vertical, 8)
            } else if let ch = channel {
                dashboardContent(ch: ch)
            } else if !isLoading {
                Text("Aucune donnée d’avis pour ce lieu pour l’instant.")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .padding(.vertical, 8)
            } else {
                loadingBlock
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .task(id: placeIdTrimmed) {
            await loadMetrics(autoRefreshPlaces: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassRemoteSyncDidMerge)) { _ in
            Task { await loadMetrics(autoRefreshPlaces: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassEngagementOAuthDidComplete)) { _ in
            Task { await loadMetrics(autoRefreshPlaces: false) }
        }
    }

    private var emptyPlaceState: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "mappin.slash.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Text("Aucune fiche Google liée")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
            Text(
                emptyStateHighlightsConfigureButton
                    ? "Touchez « Configurer la fiche Google » sous ce bloc pour lier votre établissement ou vérifier le lieu utilisé pour les avis."
                    : "Ajoutez le Place ID de votre établissement dans Réglages → Mon établissement pour afficher la note et l’évolution des avis."
            )
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.Colors.cardBackground.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.12), lineWidth: 1)
        )
    }

    private var loadingBlock: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Synchronisation des avis…")
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func dashboardContent(ch: SocialMetricsChannelRow) -> some View {
        let bars = historyBars(from: ch.history)
        let latest = ch.latest
        let m = latest?.metrics ?? [:]
        let rating = m["rating"]
        let count = m["reviews_count"]
        let baselineCount = ch.history.sorted(by: { $0.capturedAt < $1.capturedAt }).first?.metrics["reviews_count"]
        let deltaReviews = ch.deltaSinceBaseline?["reviews_count"]

        VStack(alignment: .leading, spacing: 18) {
            if showTitleRow {
                HStack(alignment: .firstTextBaseline) {
                    Text("Avis Google")
                        .font(.system(.title3, design: .default, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Spacer()
                    if let t = lastAutoRefresh {
                        Text("MAJ \(Self.shortTimeFormatter.string(from: t))")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.85))
                    }
                }
            } else if let t = lastAutoRefresh {
                HStack {
                    Spacer()
                    Text("MAJ \(Self.shortTimeFormatter.string(from: t))")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.85))
                }
            }

            if summary?.googlePlacesConfigured == false {
                Label("Mise à jour Google Places indisponible sur le serveur.", systemImage: "exclamationmark.triangle.fill")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.warning)
            }

            // Synthèse type « carte métrique »
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if let r = rating {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", r))
                                .font(.system(size: 34, weight: .bold, design: .default))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Text("/ 5")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                        Text("Note moyenne")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    } else {
                        Text("—")
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                Spacer(minLength: 16)
                VStack(alignment: .trailing, spacing: 4) {
                    if let c = count {
                        Text("\(Int(c))")
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text("avis au total")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.cardBackground)
            )
            .shadow(color: AppTheme.Colors.shadow.opacity(0.35), radius: 8, y: 3)

            // Progression (évolution vs premier relevé)
            if let cur = count, let first = baselineCount, first > 0, cur >= first {
                let growth = cur - first
                let progress = min(Double(growth) / Double(max(first, 1)), 1)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Évolution")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Spacer()
                        Text("+\(Int(growth)) avis")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.success)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AppTheme.Colors.textSecondary.opacity(0.12))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.success.opacity(0.85), AppTheme.Colors.success.opacity(0.55)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(8, g.size.width * progress))
                        }
                    }
                    .frame(height: 10)
                    HStack {
                        Text("Depuis le 1er relevé")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        Spacer()
                        Text("+\(Int(growth)) vs départ")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.Colors.primary.opacity(0.06))
                )
            } else if let d = deltaReviews, d != 0 {
                HStack {
                    Image(systemName: d > 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                        .foregroundStyle(d > 0 ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)
                    Text(d > 0 ? "+\(Int(d)) avis depuis la ligne de base" : "\(Int(d)) avis vs ligne de base")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.Colors.cardBackground.opacity(0.7)))
            }

            // Graphique
            if !bars.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Historique des avis")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Spacer()
                        if bars.count >= 2,
                           let avg = averageMonthlyReviewsHint(bars: bars) {
                            Text("Moy. \(avg) / période")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }

                    Chart(bars) { bar in
                        BarMark(
                            x: .value("Période", bar.label),
                            y: .value("Avis", bar.reviews)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.35),
                                    Color(white: 0.55),
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .cornerRadius(6, style: .continuous)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { v in
                            AxisValueLabel {
                                if let n = v.as(Double.self) {
                                    Text("\(Int(n))")
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.Colors.textSecondary)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { v in
                            AxisValueLabel()
                                .font(.caption2)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                    .frame(height: 168)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.Colors.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.08), lineWidth: 1)
                    )
                }
            } else if latest != nil {
                Text("L’historique détaillé apparaîtra après plusieurs synchronisations.")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Text("Données actualisées automatiquement — aucune action requise.")
                .font(.caption2)
                .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.9))
        }
        .padding(.vertical, 4)
    }

    private func averageMonthlyReviewsHint(bars: [GoogleReviewHistoryBar]) -> String? {
        guard !bars.isEmpty else { return nil }
        let sum = bars.reduce(0.0) { $0 + $1.reviews }
        let avg = sum / Double(bars.count)
        if avg >= 10 { return String(format: "%.0f", avg) }
        return String(format: "%.1f", avg)
    }

    private func historyBars(from history: [SocialMetricsHistoryPoint]) -> [GoogleReviewHistoryBar] {
        let sorted = history.sorted { $0.capturedAt < $1.capturedAt }
        let tail = Array(sorted.suffix(6))
        return tail.enumerated().map { idx, pt in
            let raw = pt.metrics["reviews_count"] ?? 0
            let label = Self.shortLabel(for: pt.capturedAt, index: idx, total: tail.count)
            return GoogleReviewHistoryBar(
                id: pt.capturedAt + "\(idx)",
                label: label,
                reviews: raw
            )
        }
    }

    private static let shortTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    private static func shortLabel(for iso: String, index: Int, total: Int) -> String {
        let parsers: [ISO8601DateFormatter] = {
            let a = ISO8601DateFormatter()
            a.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let b = ISO8601DateFormatter()
            b.formatOptions = [.withInternetDateTime]
            return [a, b]
        }()
        let date = parsers.compactMap { $0.date(from: iso) }.first
        guard let date else {
            return "\(index + 1)"
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        if total <= 4 {
            f.setLocalizedDateFormatFromTemplate("d MMM")
        } else {
            f.setLocalizedDateFormatFromTemplate("MMM")
        }
        return f.string(from: date)
    }

    private func loadMetrics(autoRefreshPlaces: Bool) async {
        guard hasPlace else {
            await MainActor.run {
                isLoading = false
                channel = nil
                summary = nil
            }
            return
        }
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            await MainActor.run {
                loadError = "Session commerce indisponible."
                isLoading = false
            }
            return
        }

        await MainActor.run {
            loadError = nil
            if channel == nil { isLoading = true }
        }

        if autoRefreshPlaces {
            do {
                let _: SocialMetricsSummaryResponse = try await APIClient.shared.request(.dashboardSocialMetricsRefresh(slug: slug))
            } catch {
                if !APIError.isBenignRequestCancellation(error) {
                    // On continue avec un GET même si le refresh échoue (quota, etc.).
                }
            }
        }

        do {
            let s: SocialMetricsSummaryResponse = try await APIClient.shared.request(.dashboardSocialMetrics(slug: slug))
            let row = s.channels.first { $0.channel == "google_review" }
            await MainActor.run {
                summary = s
                channel = row
                isLoading = false
                lastAutoRefresh = Date()
            }
        } catch {
            if APIError.isBenignRequestCancellation(error) { return }
            await MainActor.run {
                loadError = "Impossible de charger les avis."
                isLoading = false
            }
        }
    }
}
