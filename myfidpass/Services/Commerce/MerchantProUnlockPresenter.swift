//
//  MerchantProUnlockPresenter.swift
//  myfidpass
//
//  Feuille « Débloquez Pro » avant le paywall (remplace bannière rouge / alerte abonnement).
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class MerchantProUnlockPresenter: ObservableObject {
    static let shared = MerchantProUnlockPresenter()

    @Published private(set) var showsTeaser = false

    private init() {}

    func presentTeaser() {
        showsTeaser = true
    }

    func dismissTeaser() {
        showsTeaser = false
    }

    func continueToPaywall() {
        dismissTeaser()
        NotificationCenter.default.post(name: .myfidpassOpenMerchantSubscriptionSheet, object: nil)
    }

    static func isSubscriptionGateMessage(_ message: String) -> Bool {
        let m = message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !m.isEmpty else { return false }
        if m.contains("subscription_required") { return true }
        if m.contains("myfidpass pro") && m.contains("abonnement") { return true }
        if m.contains("abonnement inactif") || m.contains("offre (stripe)") { return true }
        if m.contains("souscrivez depuis l'écran d'abonnement")
            || m.contains("souscrivez depuis l’écran d’abonnement") {
            return true
        }
        return false
    }

    /// Erreur API / scan : feuille Pro ou bannière classique.
    static func presentMerchantError(_ error: Error) {
        if let api = error as? APIError, case .subscriptionRequired = api {
            shared.presentTeaser()
            return
        }
        if let api = error as? APIError, let msg = api.errorDescription, isSubscriptionGateMessage(msg) {
            shared.presentTeaser()
            return
        }
        guard let msg = APIError.merchantFacingMessage(from: error), !msg.isEmpty else { return }
        if isSubscriptionGateMessage(msg) {
            shared.presentTeaser()
            return
        }
        AppState.shared.showError(msg)
    }
}
