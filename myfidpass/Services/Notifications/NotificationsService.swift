//
//  NotificationsService.swift
//  myfidpass
//
//  Gestion des notifications push : permission, enregistrement, envoi du token au backend.
//

import Foundation
import UserNotifications
import UIKit
import Combine

@MainActor
final class NotificationsService: NSObject, ObservableObject {
    static let shared = NotificationsService()
    @Published var isAuthorized = false
    @Published var deviceToken: String?

    override private init() {
        super.init()
    }

    /// Demande la permission et enregistre pour les notifications à distance.
    func requestPermissionAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
            let service = self
            Task { @MainActor in
                service?.isAuthorized = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    /// Appelé par AppDelegate quand le device token est reçu. Envoie le token au backend.
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = token
        Task { await sendTokenToBackend(token) }
    }

    private func sendTokenToBackend(_ token: String) async {
        guard AuthStorage.isLoggedIn, APIClient.shared.authToken != nil else { return }
        do {
            _ = try await APIClient.shared.request(APIEndpoint.deviceRegister(token: token)) as EmptyResponse
        } catch {
            // Silencieux : le backend peut ne pas exposer l’endpoint encore
        }
    }
}
