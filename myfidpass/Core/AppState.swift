//
//  AppState.swift
//  myfidpass
//
//  État global de l'app : erreurs utilisateur, chargements, actions partagées.
//

import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    /// Message d'erreur à afficher (bannière ou alert). Nil = rien.
    @Published var errorMessage: String?

    /// Task d'auto-dismiss : on l'annule à chaque nouvelle erreur pour ne pas accumuler
    /// 50 tasks pending si l'erreur repop en boucle (avant : fuite de Task non-cancellable).
    private var autoDismissTask: Task<Void, Never>?

    /// Afficher une erreur temporaire (auto-dismiss après délai).
    func showError(_ message: String, dismissAfter: Double = 4) {
        autoDismissTask?.cancel()
        errorMessage = message
        let captured = message
        autoDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(dismissAfter * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            if self.errorMessage == captured { self.errorMessage = nil }
        }
    }

    func clearError() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        errorMessage = nil
    }
}
