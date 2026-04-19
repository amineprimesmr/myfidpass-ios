//
//  FlyerAIGenerationCoordinator.swift
//  myfidpass
//
//  Génération flyer IA asynchrone (202 + job_id) : persistance du job, polling avec tâche en arrière-plan,
//  notification locale si l’app n’est pas au premier plan quand le résultat arrive.
//

import Foundation
import UIKit
@preconcurrency import UserNotifications

enum FlyerAIGenerationCoordinatorError: LocalizedError {
    case timeout
    case missingImage

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Délai dépassé. Rouvrez l’onglet Flyer pour reprendre le suivi ou réessayez."
        case .missingImage:
            return "Réponse serveur inattendue (image manquante)."
        }
    }
}

@MainActor
final class FlyerAIGenerationCoordinator {
    static let shared = FlyerAIGenerationCoordinator()

    private static let pendingJobIdKey = "flyerAi.pendingJobId"
    private static let pendingSlugKey = "flyerAi.pendingSlug"

    private init() {}

    func savePending(slug: String, jobId: String) {
        UserDefaults.standard.set(jobId, forKey: Self.pendingJobIdKey)
        UserDefaults.standard.set(slug, forKey: Self.pendingSlugKey)
    }

    func peekPending() -> (slug: String, jobId: String)? {
        let j = UserDefaults.standard.string(forKey: Self.pendingJobIdKey) ?? ""
        let s = UserDefaults.standard.string(forKey: Self.pendingSlugKey) ?? ""
        if j.isEmpty || s.isEmpty { return nil }
        return (s, j)
    }

    func clearPending() {
        UserDefaults.standard.removeObject(forKey: Self.pendingJobIdKey)
        UserDefaults.standard.removeObject(forKey: Self.pendingSlugKey)
    }

    /// Attend la fin du job (polling ~2 s). Peut être relancé après retour au premier plan si le job est encore en cours.
    /// - Parameter respectsTaskCancellation: si `false`, la boucle continue même si la Task Swift est annulée (ex. changement d’onglet SwiftUI) — indispensable pour ne pas couper la génération en arrière-plan.
    func pollUntilComplete(slug: String, jobId: String, respectsTaskCancellation: Bool = true) async throws -> FlyerAIGenerateJobStatusResponseDTO {
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "flyer-ai-poll") {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
        defer {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }

        let deadline = Date().addingTimeInterval(6 * 60)
        while Date() < deadline {
            if respectsTaskCancellation {
                try Task.checkCancellation()
            }
            let status: FlyerAIGenerateJobStatusResponseDTO = try await requestJobStatus(
                slug: slug,
                jobId: jobId,
                respectsTaskCancellation: respectsTaskCancellation
            )
            switch status.status {
            case "done":
                clearPending()
                notifyIfAppInBackground()
                guard let img = status.imageBase64, !img.isEmpty else {
                    throw FlyerAIGenerationCoordinatorError.missingImage
                }
                return status
            case "failed":
                clearPending()
                let msg = status.error?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    ?? "Échec de la génération."
                throw APIError.server(statusCode: 502, message: msg)
            case "queued", "running":
                try await flyerPollSleep(respectsTaskCancellation: respectsTaskCancellation)
            default:
                try await flyerPollSleep(respectsTaskCancellation: respectsTaskCancellation)
            }
        }
        clearPending()
        throw FlyerAIGenerationCoordinatorError.timeout
    }

    /// Pause entre deux polls : `Task.sleep` est annulé avec la hiérarchie SwiftUI ; hors annulation, attente non coopérative.
    private func flyerPollSleep(respectsTaskCancellation: Bool) async throws {
        if respectsTaskCancellation {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                continuation.resume()
            }
        }
    }

    /// GET statut job : en mode « génération flyer » on relance une fois après annulation liée au runtime SwiftUI (changement d’onglet).
    private func requestJobStatus(
        slug: String,
        jobId: String,
        respectsTaskCancellation: Bool
    ) async throws -> FlyerAIGenerateJobStatusResponseDTO {
        do {
            return try await APIClient.shared.request(
                .dashboardFlyerAIGenerateJobStatus(slug: slug, jobId: jobId)
            )
        } catch is CancellationError where !respectsTaskCancellation {
            try await flyerPollSleep(respectsTaskCancellation: false)
            return try await APIClient.shared.request(
                .dashboardFlyerAIGenerateJobStatus(slug: slug, jobId: jobId)
            )
        }
    }

    private func notifyIfAppInBackground() {
        guard UIApplication.shared.applicationState != .active else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let ok: Bool = {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral: return true
                default: return false
                }
            }()
            guard ok else { return }
            let content = UNMutableNotificationContent()
            content.title = "Flyer prêt"
            content.body = "Votre fond flyer IA est prêt. Ouvrez l’app pour l’aperçu."
            content.sound = .default
            let req = UNNotificationRequest(
                identifier: "flyer-ai-job-\(UUID().uuidString)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
            )
            UNUserNotificationCenter.current().add(req) { _ in }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
