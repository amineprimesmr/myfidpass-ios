//
//  HapticManager.swift
//  Process
//
//  Copie fonctionnelle depuis le projet Process (Bureau) — API identique pour l’onboarding.
//

import UIKit
import CoreHaptics
import Combine

/// Gestionnaire centralisé pour les feedbacks haptiques (délègue à `MerchantUXFeedback`, sans son).
@MainActor
class HapticManager: ObservableObject {
    static let shared = HapticManager()

    private var hapticEngine: CHHapticEngine?
    private var isEngineReady = false

    private init() {
        setupHapticEngine()
        MerchantUXFeedback.shared.prepare()
    }

    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            isEngineReady = false
            return
        }

        do {
            hapticEngine = try CHHapticEngine()
            hapticEngine?.stoppedHandler = { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.isEngineReady = false
                }
            }
            hapticEngine?.resetHandler = { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    do {
                        try self.hapticEngine?.start()
                        self.isEngineReady = true
                    } catch {
                        self.isEngineReady = false
                    }
                }
            }
            try hapticEngine?.start()
            isEngineReady = true
        } catch {
            isEngineReady = false
        }
    }

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        MerchantUXFeedback.shared.playImpact(style)
    }

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        MerchantUXFeedback.shared.playNotification(type)
    }

    func selection() {
        MerchantUXFeedback.shared.playSelection()
    }

    func lightImpact() { impact(.light) }
    func mediumImpact() { impact(.medium) }
    func heavyImpact() { impact(.heavy) }
    func softImpact() { impact(.soft) }
    func rigidImpact() { impact(.rigid) }
    func success() { notification(.success) }
    func warning() { notification(.warning) }
    func error() { notification(.error) }
}
