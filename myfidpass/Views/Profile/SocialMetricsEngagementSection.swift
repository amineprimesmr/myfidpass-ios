//
//  SocialMetricsEngagementSection.swift
//  myfidpass
//
//  Métriques avis & réseaux (OAuth, historique).
//

import SwiftUI
import UIKit

struct SocialMetricsEngagementSection: View {
    @State private var summary: SocialMetricsSummaryResponse?
    @State private var loadError: String?
    @State private var isLoading = false
    @State private var isRefreshingMetrics = false
    @State private var isConnectingInstagram = false
    @State private var isConnectingYouTube = false
    @State private var isConnectingTikTok = false

    var body: some View {
        Group {
            if isLoading && summary == nil {
                sectionCard {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            } else if let err = loadError {
                sectionCard {
                    Text(err)
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(AppTheme.Colors.error)
                }
            } else if let s = summary {
                let rows = visibleRows(from: s.channels)
                if !rows.isEmpty {
                    sectionCard {
                        ForEach(rows) { row in
                            channelBlock(row: row, summary: s)
                        }
                    }
                }
            }
        }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassOAuthUniversalLinkRelay)) { note in
            guard let url = note.object as? URL else { return }
            Task {
                switch EngagementOAuthLauncher.parseCallback(url) {
                case .success:
                    await MainActor.run {
                        NotificationCenter.default.post(name: .myfidpassEngagementOAuthDidComplete, object: nil)
                    }
                    await load()
                case .failure(let msg):
                    await MainActor.run { loadError = msg }
                case .cancelled:
                    break
                }
            }
        }
    }

    /// Google : métriques affichées dans la ligne dédiée du formulaire (`socialGoogleRow`), pas ici.
    private func visibleRows(from channels: [SocialMetricsChannelRow]) -> [SocialMetricsChannelRow] {
        channels.filter { row in
            row.enabled && row.configured && row.channel != "google_review"
                && !(EngagementTemporaryVisibility.hideSecondaryReviewNetworks
                    && EngagementTemporaryVisibility.hiddenSocialMetricChannelIds.contains(row.channel))
        }
    }

    @ViewBuilder
    private func channelOAuthToolbar(row: SocialMetricsChannelRow, summary: SocialMetricsSummaryResponse) -> some View {
        if row.channel == "instagram_follow" || row.channel == "facebook_follow", summary.metaOauthAvailable == true {
            if row.oauthConnected == true {
                Button {
                    Task { await refreshSocialMetrics() }
                } label: {
                    if isRefreshingMetrics {
                        ProgressView().scaleEffect(0.85)
                    } else {
                        Label("Rafraîchir", systemImage: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isRefreshingMetrics)
            } else {
                Button {
                    Task { await connectMetaOAuth() }
                } label: {
                    if isConnectingInstagram {
                        ProgressView().scaleEffect(0.85)
                    } else {
                        Label("Connecter Meta", systemImage: "link")
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isConnectingInstagram)
            }
        } else if row.channel == "youtube_follow", summary.youtubeOauthAvailable == true {
            if row.oauthConnected == true {
                Button {
                    Task { await refreshSocialMetrics() }
                } label: {
                    if isRefreshingMetrics {
                        ProgressView().scaleEffect(0.85)
                    } else {
                        Label("Rafraîchir", systemImage: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isRefreshingMetrics)
            } else {
                Button {
                    Task { await connectYouTubeOAuth() }
                } label: {
                    if isConnectingYouTube {
                        ProgressView().scaleEffect(0.85)
                    } else {
                        Label("Connecter YouTube", systemImage: "link")
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isConnectingYouTube)
            }
        } else if row.channel == "tiktok_follow", summary.tiktokOauthAvailable == true {
            if row.oauthConnected == true {
                Button {
                    Task { await refreshSocialMetrics() }
                } label: {
                    if isRefreshingMetrics {
                        ProgressView().scaleEffect(0.85)
                    } else {
                        Label("Rafraîchir", systemImage: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isRefreshingMetrics)
            } else {
                Button {
                    Task { await connectTikTokOAuth() }
                } label: {
                    if isConnectingTikTok {
                        ProgressView().scaleEffect(0.85)
                    } else {
                        Label("Connecter TikTok", systemImage: "link")
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isConnectingTikTok)
            }
        }
    }

    @ViewBuilder
    private func channelBlock(row: SocialMetricsChannelRow, summary: SocialMetricsSummaryResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(row.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
                channelOAuthToolbar(row: row, summary: summary)
            }

            if let latest = row.latest {
                metricsLine(
                    label: "Dernière mesure",
                    date: latest.capturedAt,
                    metrics: latest.metrics,
                    channel: row.channel
                )
            } else {
                Text("Aucune mesure encore — connectez le réseau ci‑dessus puis rafraîchissez.")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            if let d = row.deltaSinceBaseline, !d.isEmpty {
                deltaPills(title: "Depuis le début", deltas: d)
            }
            if let d = row.deltaSincePrevious, !d.isEmpty {
                deltaPills(title: "Depuis la dernière mesure", deltas: d)
            }

            if row.channel == "twitter_follow" || row.channel == "snapchat_follow" || row.channel == "linkedin_follow" {
                Text("Connexion OAuth automatique — intégration prévue (X, Snapchat, LinkedIn).")
                    .font(AppTheme.Fonts.caption2())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            } else if row.channel.contains("trustpilot") || row.channel.contains("tripadvisor") {
                Text("Automatisation prévue — pas de saisie manuelle.")
                    .font(AppTheme.Fonts.caption2())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            if row.channel == "google_review", !summary.googlePlacesConfigured {
                Text("Mise à jour auto Google indisponible (clé Places côté serveur).")
                    .font(AppTheme.Fonts.caption2())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.background.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func metricsLine(label: String, date: String, metrics: [String: Double], channel: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppTheme.Fonts.caption2())
                .foregroundStyle(AppTheme.Colors.textSecondary)
            HStack(spacing: 12) {
                ForEach(sortedMetricKeys(metrics, channel: channel), id: \.self) { key in
                    if let v = metrics[key] {
                        Text(metricLabel(key: key, value: v))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                }
            }
            Text(shortDate(date))
                .font(AppTheme.Fonts.caption2())
                .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.9))
        }
    }

    private func sortedMetricKeys(_ m: [String: Double], channel: String) -> [String] {
        let order = ["reviews_count", "rating", "followers"]
        return order.filter { m[$0] != nil }
    }

    private func metricLabel(key: String, value: Double) -> String {
        switch key {
        case "reviews_count":
            return "\(Int(value)) avis"
        case "rating":
            return String(format: "★ %.1f", value)
        case "followers":
            return formatInt(Int(value)) + " abonnés"
        default:
            return "\(key): \(value)"
        }
    }

    private func formatInt(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "fr_FR")
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func shortDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var d = f.date(from: iso)
        if d == nil {
            f.formatOptions = [.withInternetDateTime]
            d = f.date(from: iso)
        }
        guard let date = d else { return iso }
        let out = DateFormatter()
        out.locale = Locale(identifier: "fr_FR")
        out.dateStyle = .short
        out.timeStyle = .short
        return out.string(from: date)
    }

    private func deltaPills(title: String, deltas: [String: Double]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTheme.Fonts.caption2())
                .foregroundStyle(AppTheme.Colors.textSecondary)
            FlowLayout(spacing: 6) {
                ForEach(Array(deltas.keys.sorted()), id: \.self) { key in
                    if let v = deltas[key], v != 0 {
                        Text(deltaText(key: key, delta: v))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(v > 0 ? AppTheme.Colors.success.opacity(0.15) : AppTheme.Colors.error.opacity(0.12))
                            .foregroundStyle(v > 0 ? AppTheme.Colors.success : AppTheme.Colors.error)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func deltaText(key: String, delta: Double) -> String {
        let sign = delta > 0 ? "+" : ""
        switch key {
        case "reviews_count":
            return "\(sign)\(Int(delta)) avis"
        case "followers":
            return "\(sign)\(formatInt(Int(delta))) abonnés"
        case "rating":
            return String(format: "%@%.2f ★", sign, delta)
        default:
            return "\(sign)\(delta)"
        }
    }

    private static func friendlyMetricsLoadError(_ error: Error) -> String {
        if let api = error as? APIError {
            switch api {
            case .notFound:
                return "Métriques indisponibles sur le serveur (déploiement en cours). Réessayez dans quelques minutes."
            case .decoding:
                return "Impossible de lire la réponse du serveur. Mettez à jour l’app."
            default:
                return api.errorDescription ?? "Impossible de charger les métriques."
            }
        }
        return "Impossible de charger les métriques."
    }

    private func load() async {
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            await MainActor.run { loadError = "Commerce non chargé." }
            return
        }
        let firstPaint = await MainActor.run { summary == nil }
        await MainActor.run {
            if firstPaint { isLoading = true }
            loadError = nil
        }
        do {
            let s: SocialMetricsSummaryResponse = try await APIClient.shared.request(.dashboardSocialMetrics(slug: slug))
            await MainActor.run {
                summary = s
                isLoading = false
            }
        } catch {
            if APIError.isBenignRequestCancellation(error) {
                await MainActor.run { isLoading = false }
                return
            }
            await MainActor.run {
                loadError = Self.friendlyMetricsLoadError(error)
                isLoading = false
            }
        }
    }

    private func refreshSocialMetrics() async {
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else { return }
        await MainActor.run { isRefreshingMetrics = true }
        defer { Task { @MainActor in isRefreshingMetrics = false } }
        do {
            let _: SocialMetricsSummaryResponse = try await APIClient.shared.request(.dashboardSocialMetricsRefresh(slug: slug))
            await load()
        } catch {
            await MainActor.run { loadError = "Rafraîchissement impossible." }
        }
    }

    private func connectMetaOAuth() async {
        await MainActor.run {
            isConnectingInstagram = true
            loadError = nil
        }
        defer { Task { @MainActor in isConnectingInstagram = false } }
        let outcome = await EngagementOAuthLauncher.connectMeta()
        switch outcome {
        case .success:
            await MainActor.run {
                NotificationCenter.default.post(name: .myfidpassEngagementOAuthDidComplete, object: nil)
            }
            await load()
        case .failure(let msg):
            await MainActor.run { loadError = msg }
        case .cancelled:
            break
        }
    }

    private func connectYouTubeOAuth() async {
        await MainActor.run {
            isConnectingYouTube = true
            loadError = nil
        }
        defer { Task { @MainActor in isConnectingYouTube = false } }
        let outcome = await EngagementOAuthLauncher.connectYouTube()
        switch outcome {
        case .success:
            await MainActor.run {
                NotificationCenter.default.post(name: .myfidpassEngagementOAuthDidComplete, object: nil)
            }
            await load()
        case .failure(let msg):
            await MainActor.run { loadError = msg }
        case .cancelled:
            break
        }
    }

    private func connectTikTokOAuth() async {
        await MainActor.run {
            isConnectingTikTok = true
            loadError = nil
        }
        defer { Task { @MainActor in isConnectingTikTok = false } }
        let outcome = await EngagementOAuthLauncher.connectTikTok()
        switch outcome {
        case .success:
            await MainActor.run {
                NotificationCenter.default.post(name: .myfidpassEngagementOAuthDidComplete, object: nil)
            }
            await load()
        case .failure(let msg):
            await MainActor.run { loadError = msg }
        case .cancelled:
            break
        }
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppTheme.Colors.shadow, radius: 6, y: 2)
    }
}

// MARK: - Layout léger pour les pastilles

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (i, pos) in result.positions.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowH: CGFloat = 0
        var positions: [CGPoint] = []
        let maxW = proposal.width ?? .infinity

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxW, x > 0 {
                x = 0
                y += rowH + spacing
                rowH = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowH = max(rowH, size.height)
            x += size.width + spacing
        }
        let totalH = y + rowH
        let totalW = min(maxW, x)
        return (CGSize(width: totalW, height: totalH), positions)
    }
}
