//
//  NotificationDeliveryFollowUp.swift
//  myfidpass
//
//  Après un envoi async (HTTP 202) : poll le job serveur, historise uniquement
//  à la livraison confirmée, puis rafraîchit l’écran Statistiques.
//

import Foundation

struct NotificationJobStatusDTO: Decodable, Sendable {
    let ok: Bool?
    let jobId: String?
    let jobStatus: String?
    let batchId: String?
    let deliveryStatus: String?
    let sent: Int?
    let sentTotal: Int?
    let recipientsDistinct: Int?
    let expectedDevices: Int?
    let notificationTitle: String?
    let message: String?
    // Pas de CodingKeys snake_case ici : APIClient décode avec `.convertFromSnakeCase`,
    // un rawValue `"job_id"` ne matcherait jamais (clé convertie en `jobId` avant lookup).
}

enum NotificationDeliveryFollowUp {
    private static let terminalStatuses: Set<String> = [
        "delivered", "partial", "failed", "no_targets", "dead",
    ]

    /// Poll job + historise à la livraison terminale + notifie les stats.
    /// Le son « notification envoyée » est joué à la fin de la barre de progression (`CampaignNotificationsView.send()`).
    static func trackAsyncSend(
        slug: String,
        title: String?,
        message: String,
        jobId: String?,
        batchId: String?,
        expectedDevices: Int?,
        playsSoundOnDelivered: Bool = false
    ) {
        let slugKey = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slugKey.isEmpty else { return }
        let expected = max(0, expectedDevices ?? 0)
        let m = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !m.isEmpty else { return }

        NotificationCenter.default.post(
            name: .myfidpassMerchantNotificationCampaignSent,
            object: nil,
            userInfo: [
                MyfidpassNotificationUserInfoKey.businessSlug: slugKey,
                MyfidpassNotificationUserInfoKey.notificationBatchId: batchId ?? "",
            ]
        )

        guard let job = jobId?.trimmingCharacters(in: .whitespacesAndNewlines), !job.isEmpty else {
            return
        }
        Task {
            await pollUntilTerminal(
                slug: slugKey,
                jobId: job,
                title: title,
                message: m,
                expectedDevices: expected,
                playsSoundOnDelivered: playsSoundOnDelivered
            )
        }
    }

    @MainActor
    private static func pollUntilTerminal(
        slug: String,
        jobId: String,
        title: String?,
        message: String,
        expectedDevices: Int,
        playsSoundOnDelivered: Bool
    ) async {
        let delaysNs: [UInt64] = [
            1_000_000_000, 2_000_000_000, 4_000_000_000, 8_000_000_000,
            15_000_000_000, 30_000_000_000, 60_000_000_000,
        ]
        for delay in delaysNs {
            try? await Task.sleep(nanoseconds: delay)
            guard let status: NotificationJobStatusDTO = try? await APIClient.shared.request(
                .dashboardNotificationJobStatus(slug: slug, jobId: jobId)
            ) else { continue }

            let delivered = max(status.recipientsDistinct ?? 0, status.sent ?? status.sentTotal ?? 0)
            let delivery = status.deliveryStatus?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""
            let jobDone = status.jobStatus == "done" || status.jobStatus == "dead"
            if terminalStatuses.contains(delivery) || jobDone {
                let batch = status.batchId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let finalBatch = batch.isEmpty ? "job:\(jobId)" : batch
                let finalStatus = delivery.isEmpty ? (jobDone ? "delivered" : "failed") : delivery
                NotificationSendLocalHistoryStore.recordDelivered(
                    slug: slug,
                    batchId: finalBatch,
                    jobId: jobId,
                    title: title ?? status.notificationTitle,
                    message: status.message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                        ? status.message!.trimmingCharacters(in: .whitespacesAndNewlines)
                        : message,
                    expectedDevices: max(expectedDevices, status.expectedDevices ?? 0),
                    deliveryStatus: finalStatus,
                    recipientsDistinct: delivered
                )
                if playsSoundOnDelivered, delivery == "delivered" || delivery == "partial" {
                    MerchantUXFeedback.shared.playNotificationSent()
                }
                NotificationCenter.default.post(
                    name: .myfidpassMerchantNotificationCampaignSent,
                    object: nil,
                    userInfo: [MyfidpassNotificationUserInfoKey.businessSlug: slug]
                )
                return
            }
        }
        NotificationCenter.default.post(
            name: .myfidpassMerchantNotificationCampaignSent,
            object: nil,
            userInfo: [MyfidpassNotificationUserInfoKey.businessSlug: slug]
        )
    }
}
