//
//  ReceiptValidationCoordinator.swift
//  myfidpass
//
//  Flux : challenge JWT → plein écran scan QR ticket → jeton pour POST scan.
//

import Combine
import SwiftUI

/// Session affichée en `fullScreenCover` (QR attendu + caméra).
struct ReceiptTicketScanSession: Identifiable {
    let id = UUID()
    let slug: String
    let amountEur: Double
    let qrPayload: String
    let expiresAt: String?
}

@MainActor
final class ReceiptValidationCoordinator: ObservableObject {
    @Published var session: ReceiptTicketScanSession?

    private var continuation: CheckedContinuation<String?, Never>?

    /// Demande un JWT serveur puis attend le scan physique du même QR (ou annulation).
    /// - Returns: `nil` si l’utilisateur annule ; sinon le jeton scanné.
    func requestValidatedToken(slug: String, amountEur: Double) async throws -> String? {
        let ch: ReceiptChallengeResponse = try await APIClient.shared.request(
            .dashboardReceiptChallenge(slug: slug, amountEur: amountEur)
        ) as ReceiptChallengeResponse
        let payload = ch.qrPayload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty else {
            throw APIError.noData
        }
        return await withCheckedContinuation { cont in
            self.continuation = cont
            self.session = ReceiptTicketScanSession(
                slug: slug,
                amountEur: amountEur,
                qrPayload: payload,
                expiresAt: ch.expiresAt
            )
        }
    }

    func complete(with token: String?) {
        session = nil
        continuation?.resume(returning: token)
        continuation = nil
    }
}
