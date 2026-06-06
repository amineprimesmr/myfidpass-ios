//
//  CommerceNotificationImpactListCard.swift
//  myfidpass
//
//  Liste des envois de campagne (titre, message, volumes) — aligné sur l’aperçu Campagnes.
//

import SwiftUI

enum NotificationCampaignDisplay {
    private static let isoWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let out = DateFormatter()
        out.locale = Locale(identifier: "fr_FR")
        out.setLocalizedDateFormatFromTemplate("d MMMM 'à' HH:mm")
        return out
    }()

    static func title(_ c: NotificationCampaignInsightDTO) -> String {
        if let t = c.notificationTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            return t
        }
        if let m = c.message?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty {
            let oneLine = m.replacingOccurrences(of: "\n", with: " ")
            if oneLine.count <= 80 { return oneLine }
            return String(oneLine.prefix(80)) + "…"
        }
        if let h = humanizedTrigger(c.triggerName) { return h }
        if let raw = c.triggerName?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty { return raw }
        let when = shortDateLabel(c.createdAt)
        return when == "—" ? "Notification" : "Notification · \(when)"
    }

    static func messageBody(_ c: NotificationCampaignInsightDTO) -> String? {
        let m = c.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !m.isEmpty else { return nil }
        if let nt = c.notificationTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !nt.isEmpty {
            return m == nt ? nil : m
        }
        // Pas de titre API : le « titre » affiché peut être un extrait du message.
        let shownTitle = title(c)
        if m != shownTitle, m.replacingOccurrences(of: "\n", with: " ") != shownTitle { return m }
        if m.contains("\n") { return m }
        return nil
    }

    static func shortDateLabel(_ iso: String?) -> String {
        guard let iso, !iso.isEmpty else { return "—" }
        var d = isoWithFractional.date(from: iso)
        if d == nil { d = isoBasic.date(from: iso) }
        guard let date = d else { return "—" }
        return shortDateFormatter.string(from: date)
    }

    private static func humanizedTrigger(_ raw: String?) -> String? {
        guard let s = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !s.isEmpty else { return nil }
        switch s {
        case "campaign", "campaign_send", "marketing", "batch", "campagne", "camp":
            return "Envoi campagne"
        case "manual", "manual_send", "dashboard_send", "dashboard":
            return "Envoi manuel (app)"
        case "pass_sync", "pass_update", "wallet_sync":
            return "Mise à jour des passes"
        case "scheduled", "automation":
            return "Envoi programmé"
        case "receipt", "transaction_receipt", "caisse", "pos":
            return "Reçu / caisse"
        case "birthday", "anniversary":
            return "Anniversaire"
        default:
            return nil
        }
    }
}

// MARK: - Conteneur

struct CommerceNotificationImpactListCard: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay

    let campaigns: [NotificationCampaignInsightDTO]
    /// Même ressource que l’onglet Campagnes (`…/notification-icon` ou bundle `logonotif`).
    let notificationIconURL: String?
    var onTap: (() -> Void)? = nil

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { rowsContent }
                    .buttonStyle(.plain)
            } else {
                rowsContent
            }
        }
        .commerceStatsLiquidGlassTileButton(
            cornerRadius: CommerceStatsIndicatorLiquidGlass.kpiCornerRadius,
            controlSize: .large,
            useStatic3DSurface: true
        )
    }

    private var rowsContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Notifications envoyées")
                    .font(CommerceStatisticsTheme.kpiTileTitleFont())
                    .foregroundStyle(CommerceStatisticsTheme.kpiTileTitleGradient(forGlassOverlay: commerceStatsGlassOverlay))
                Spacer(minLength: 0)
            }
            .padding(.top, 16)
            .padding(.leading, 16)
            .padding(.trailing, 14)
            .padding(.bottom, 8)

            ForEach(Array(campaigns.prefix(24).enumerated()), id: \.element.id) { idx, c in
                if idx > 0 {
                    Divider()
                        .background(CommerceStatisticsTheme.subtleBorder(forGlassOverlay: commerceStatsGlassOverlay))
                        .padding(.leading, 54)
                }
                CommerceNotificationImpactRow(
                    campaign: c,
                    notificationIconURL: notificationIconURL
                )
            }
        }
    }
}

// MARK: - Ligne

private struct CommerceNotificationImpactRow: View {
    @Environment(\.commerceStatsGlassOverlay) private var commerceStatsGlassOverlay

    let campaign: NotificationCampaignInsightDTO
    let notificationIconURL: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            notificationIcon
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(NotificationCampaignDisplay.title(campaign))
                        .font(CommerceStatisticsTheme.kpiTileTitleFont())
                        .foregroundStyle(CommerceStatisticsTheme.kpiTileTitleGradient(forGlassOverlay: commerceStatsGlassOverlay))
                        .multilineTextAlignment(.leading)
                }

                if let bodyText = NotificationCampaignDisplay.messageBody(campaign), !bodyText.isEmpty {
                    Text(bodyText)
                        .font(CommerceStatisticsTheme.statsText(size: 13, weight: .medium))
                        .foregroundStyle(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: commerceStatsGlassOverlay).opacity(0.9))
                        .lineLimit(6)
                        .multilineTextAlignment(.leading)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Membres touchés")
                        .font(CommerceStatisticsTheme.statsText(size: 11, weight: .semibold))
                        .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: commerceStatsGlassOverlay))
                    let n = max(campaign.recipientsDistinct ?? 0, campaign.sentTotal ?? 0)
                    Text(StatsFR.formatInt(n))
                        .font(CommerceStatisticsTheme.statisticNumbers(size: 16, weight: .semibold))
                        .foregroundStyle(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: commerceStatsGlassOverlay))
                    Spacer(minLength: 8)
                    Text(NotificationCampaignDisplay.shortDateLabel(campaign.createdAt))
                        .font(CommerceStatisticsTheme.statsText(size: 11, weight: .medium))
                        .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: commerceStatsGlassOverlay).opacity(0.98))
                }
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .padding(.leading, 16)
        .padding(.trailing, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityString)
    }

    @ViewBuilder
    private var notificationIcon: some View {
        let side: CGFloat = 40
        if let s = notificationIconURL?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            if let url = APIResourceURL.resolved(from: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        notificationFallbackIcon(side: side)
                    @unknown default:
                        notificationFallbackIcon(side: side)
                    }
                }
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                notificationFallbackIcon(side: side)
            }
        } else {
            notificationFallbackIcon(side: side)
        }
    }

    private func notificationFallbackIcon(side: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(CommerceStatisticsTheme.pillBackground)
                .frame(width: side, height: side)
            Image("logonotif")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        }
        .frame(width: side, height: side)
    }

    private var accessibilityString: String {
        let t = NotificationCampaignDisplay.title(campaign)
        let n = max(campaign.recipientsDistinct ?? 0, campaign.sentTotal ?? 0)
        return "\(t), \(n) membres touchés"
    }
}

#if DEBUG
#Preview {
    let samples: [NotificationCampaignInsightDTO] = [
        .init(
            batchId: "1",
            triggerName: "manual",
            createdAt: "2026-04-10T09:00:00.000Z",
            sentTotal: 12,
            recipientsDistinct: 12,
            returnedWithin48h: nil,
            notificationTitle: "C’est le week-end",
            message: "Profitez de -10 % sur les boissons ce samedi. Venez nombreux, les stocks partent vite.",
            sentPasskit: nil,
            sentWebPush: nil
        ),
    ]
    return ZStack {
        Color.black.ignoresSafeArea()
        CommerceNotificationImpactListCard(campaigns: samples, notificationIconURL: nil)
            .padding()
    }
    .environment(\.commerceStatsGlassOverlay, false)
}
#endif
