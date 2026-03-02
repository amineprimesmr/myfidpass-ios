//
//  AppState.swift
//  myfidpass
//
//  État global de l’app : erreurs utilisateur, chargements, actions partagées.
//

import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    /// Message d’erreur à afficher (bannière ou alert). Nil = rien.
    @Published var errorMessage: String?
    /// Afficher une erreur temporaire (auto-dismiss après délai).
    func showError(_ message: String, dismissAfter: Double = 4) {
        errorMessage = message
        Task {
            try? await Task.sleep(nanoseconds: UInt64(dismissAfter * 1_000_000_000))
            if errorMessage == message { errorMessage = nil }
        }
    }
    func clearError() { errorMessage = nil }
}
