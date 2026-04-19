//
//  NotificationPermissionStepView.swift
//  Process
//
//  Page de demande de permission pour les notifications
//

import SwiftUI
import UserNotifications

struct NotificationPermissionStepView: View {
    @EnvironmentObject var permissionsManager: PermissionsManager
    @StateObject private var hapticManager = HapticManager.shared

    let onComplete: () -> Void
    let onBack: (() -> Void)?

    @State private var isRequesting = false

    init(onComplete: @escaping () -> Void, onBack: (() -> Void)? = nil) {
        self.onComplete = onComplete
        self.onBack = onBack
    }

    var body: some View {
        ZStack {
            // ✅ Fond noir (comme toutes les autres pages d'onboarding)
            Color.black
                .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                // Espacement en haut (augmenté pour mettre le titre plus bas)
                Spacer()
                    .frame(height: 120)

                // Titre avec "à la fin" en bleu
                (Text("Tu recevras un message ") + Text("à la fin").foregroundColor(Color(hex: "a7c4f2")) + Text(" de ton essai"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)

                // Image de notification en gros au centre (plus basse)
                Image("Notif")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 420)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)

                Spacer()

                // Bouton d'action
                Button(action: {
                    Task {
                        await requestNotifications()
                    }
                }) {
                    HStack(spacing: 12) {
                        if isRequesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text("Activer les notifications")
                            .font(.system(size: 20, weight: .black))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 50))
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
                .disabled(isRequesting)
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func requestNotifications() async {
        hapticManager.impact(.medium)
        isRequesting = true

        // Demander la permission
        await permissionsManager.requestNotificationPermission()

        // Continuer même si l'utilisateur refuse
        // On ne bloque pas le flow pour les notifications
        isRequesting = false

        // Petit délai pour l'animation
        try? await Task.sleep(for: .milliseconds(300))

        hapticManager.notification(.success)
        onComplete()
    }

}
