//
//  SettingsNotificationsHubView.swift
//  myfidpass
//
//  Notifications appareil + messages aux clients (Wallet), regroupés comme dans les apps « banque ».
//

import SwiftUI
import UIKit

struct SettingsNotificationsHubView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var syncService: SyncService
    @ObservedObject private var notifications = NotificationsService.shared

    @State private var notificationMessage: String = ""
    @State private var isSendingNotification = false
    @State private var notifyResultMessage: String?
    @State private var notifyResultSuccess = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Sur cet iPhone")
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .textCase(.uppercase)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: notifications.isAuthorized ? "checkmark.circle.fill" : "bell.slash.fill")
                                .foregroundStyle(notifications.isAuthorized ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)
                            Text(notifications.isAuthorized ? "Notifications autorisées" : "Notifications désactivées")
                                .font(AppTheme.Fonts.body())
                            Spacer()
                        }
                        Button {
                            notifications.requestPermissionAndRegister()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                notifications.refreshAuthorizationStatus()
                            }
                        } label: {
                            Text("Demander l’autorisation")
                                .font(AppTheme.Fonts.subheadline().weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.Colors.primary)

                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        } label: {
                            Text("Ouvrir les réglages iOS")
                                .font(AppTheme.Fonts.subheadline().weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Vos clients (Apple Wallet)")
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .textCase(.uppercase)
                    Text("Message affiché sur l’écran de verrouillage pour les clients qui ont ajouté votre carte.")
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    ZStack(alignment: .topLeading) {
                        if notificationMessage.isEmpty {
                            Text("Ex. Nouvelle offre ce week-end !")
                                .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.6))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                        }
                        TextEditor(text: $notificationMessage)
                            .padding(8)
                            .frame(minHeight: 100, maxHeight: 140)
                            .scrollContentBackground(.hidden)
                            .font(AppTheme.Fonts.body())
                    }
                    .background(AppTheme.Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                            .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.15), lineWidth: 1)
                    )

                    if let msg = notifyResultMessage {
                        Text(msg)
                            .font(AppTheme.Fonts.caption())
                            .foregroundStyle(notifyResultSuccess ? AppTheme.Colors.success : AppTheme.Colors.error)
                    }

                    Button {
                        sendNotificationToClients()
                    } label: {
                        HStack {
                            if isSendingNotification {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text("Envoyer aux clients")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Colors.primary)
                    .disabled(notificationMessage.trimmingCharacters(in: .whitespaces).isEmpty || isSendingNotification)
                }
            }
            .padding(AppTheme.Spacing.md)
            .padding(.bottom, 48)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { notifications.refreshAuthorizationStatus() }
    }

    private func sendNotificationToClients() {
        let msg = notificationMessage.trimmingCharacters(in: .whitespaces)
        guard !msg.isEmpty else { return }
        guard let slug = AuthStorage.currentBusinessSlug else {
            notifyResultSuccess = false
            notifyResultMessage = "Aucun commerce sélectionné."
            return
        }
        isSendingNotification = true
        notifyResultMessage = nil
        Task {
            do {
                let result = try await APIClient.shared.request(
                    APIEndpoint.notifyClients(slug: slug, message: msg, categoryIds: nil)
                ) as NotifyClientsResult
                await MainActor.run {
                    isSendingNotification = false
                    notifyResultSuccess = true
                    let n = result.sent ?? 0
                    notifyResultMessage = n > 0
                        ? "Envoyé (\(n) appareil\(n > 1 ? "x" : ""))."
                        : "Aucun appareil cible pour l’instant."
                    notificationMessage = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { notifyResultMessage = nil }
                }
                await syncService.syncAfterServerMutation()
            } catch {
                await MainActor.run {
                    isSendingNotification = false
                    notifyResultSuccess = false
                    notifyResultMessage = (error as? APIError)?.errorDescription ?? "Erreur d’envoi."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { notifyResultMessage = nil }
                }
            }
        }
    }
}
