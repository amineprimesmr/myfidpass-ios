//
//  FlyerAIGenerateAPI.swift
//  myfidpass
//
//  POST dashboard `flyer/ai-generate` (202 + job) puis polling jusqu’au statut `done`.
//

import Foundation

enum FlyerAIGenerateAPIError: LocalizedError {
    case missingImageAfterSuccess
    case timeout
    case unexpectedSyncStatus(Int)

    var errorDescription: String? {
        switch self {
        case .missingImageAfterSuccess:
            return "La génération s’est terminée sans image exploitable. Réessayez."
        case .timeout:
            return "La génération prend plus de temps que prévu. Réessayez dans un instant."
        case .unexpectedSyncStatus(let code):
            return "Réponse inattendue du serveur (\(code))."
        }
    }
}

enum FlyerAIGenerateAPI {
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    /// Lance la génération et attend l’image (`image_base64` dans le statut `done`).
    static func generateAndWaitForImage(slug: String, body: FlyerAIGenerateRequestDTO) async throws -> FlyerAIGenerateJobStatusResponseDTO {
        let (data, http) = try await APIClient.shared.requestSuccessfulDataWithHTTPResponse(
            APIEndpoint.dashboardFlyerAIGenerate(slug: slug, body: body)
        )
        let outcome: FlyerAIGenerateJobStatusResponseDTO
        switch http.statusCode {
        case 202:
            let enq = try Self.decoder.decode(FlyerAIGenerateEnqueueResponseDTO.self, from: data)
            outcome = try await pollJob(slug: slug, jobId: enq.jobId)
        case 200:
            let sync = try Self.decoder.decode(FlyerAIGenerateResponseDTO.self, from: data)
            guard !sync.imageBase64.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw FlyerAIGenerateAPIError.missingImageAfterSuccess
            }
            outcome = FlyerAIGenerateJobStatusResponseDTO(
                status: "done",
                jobId: "",
                error: nil,
                imageBase64: sync.imageBase64,
                revisedPrompt: sync.revisedPrompt,
                flyerAiGenerationsUsed: sync.flyerAiGenerationsUsed,
                flyerAiGenerationsRemaining: sync.flyerAiGenerationsRemaining,
                flyerAiUnlimited: sync.flyerAiUnlimited,
                fidelityPageBackgroundSaved: nil,
                fidelityPageBackgroundError: nil
            )
        default:
            throw FlyerAIGenerateAPIError.unexpectedSyncStatus(http.statusCode)
        }
        let trimmed = outcome.imageBase64?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard outcome.status.lowercased() == "done", !trimmed.isEmpty else {
            if let err = outcome.error?.trimmingCharacters(in: .whitespacesAndNewlines), !err.isEmpty {
                throw APIError.server(statusCode: 500, message: err)
            }
            throw FlyerAIGenerateAPIError.missingImageAfterSuccess
        }
        return outcome
    }

    private static func pollJob(slug: String, jobId: String) async throws -> FlyerAIGenerateJobStatusResponseDTO {
        let deadline = Date().addingTimeInterval(240)
        var delayNs: UInt64 = 800_000_000
        while Date() < deadline {
            try await Task.sleep(nanoseconds: delayNs)
            delayNs = min(delayNs + 100_000_000, 2_000_000_000)
            let status: FlyerAIGenerateJobStatusResponseDTO = try await APIClient.shared.request(
                APIEndpoint.dashboardFlyerAIGenerateJobStatus(slug: slug, jobId: jobId)
            )
            let s = status.status.lowercased()
            if s == "done" { return status }
            if s == "failed" {
                let rawErr = status.error?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let msg = rawErr.isEmpty ? "Échec de la génération." : rawErr
                throw APIError.server(statusCode: 500, message: msg)
            }
        }
        throw FlyerAIGenerateAPIError.timeout
    }
}
