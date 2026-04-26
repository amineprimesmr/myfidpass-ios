//
//  CommerceNotificationImpactListCard.swift
//  myfidpass
//
//  Liste des envois de campagne (titre, message, volumes) — aligné sur l’aperçu Campagnes.
//

import SwiftUI

enum NotificationCampaignDisplay {
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
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var d = f.date(from: iso)
        if d == nil {
            f.formatOptions = [.withInternetDateTime]
            d = f.date(from: iso)
        }
        guard let date = d else { return "—" }
        let out = DateFormatter()
        out.locale = Locale(identifier: "fr_FR")
        out.dateStyle = .short
        out.timeStyle = .short
        return out.string(from: date)
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

    var body: some View {
        Button(action: {}) {
            VStack(spacing: 0) {
                ForEach(Array(campaigns.enumerated()), id: \.element.id) { idx, c in
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
        .buttonStyle(.plain)
        .commerceStatsLiquidGlassTileButton(cornerRadius: CommerceStatsIndicatorLiquidGlass.kpiCornerRadius, controlSize: .large)
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
                        .font(CommerceStatisticsTheme.statsText(size: 15, weight: .semibold))
                        .foregroundStyle(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: commerceStatsGlassOverlay))
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Text(NotificationCampaignDisplay.shortDateLabel(campaign.createdAt))
                        .font(CommerceStatisticsTheme.statsText(size: 11, weight: .medium))
                        .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: commerceStatsGlassOverlay).opacity(0.95))
                }

                if let bodyText = NotificationCampaignDisplay.messageBody(campaign), !bodyText.isEmpty {
                    Text(bodyText)
                        .font(CommerceStatisticsTheme.statsText(size: 12, weight: .regular))
                        .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: commerceStatsGlassOverlay))
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
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityString)
    }

    @ViewBuilder
    private var notificationIcon: some View {
        let side: CGFloat = 40
        if let s = notificationIconURL?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            BusinessLogoView(logoURL: s, logoAssetContext: .campaignNotificationIcon, size: side, cornerRadius: 10)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .frame(width: side, height: side)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(CommerceStatisticsTheme.pillBackground)
                    .frame(width: side, height: side)
                Image("logonotif")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
        }
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
