//
//  StaffAccountView.swift
//  myfidpass
//
//  Espace compte pour un profil **employé** : synchro, sécurité scan, support, déconnexion.
//  (Pas d’abonnement, pas de fiche Commerce, pas de suppression de compte commerçant côté UI.)
//

import SwiftUI
import UIKit

struct StaffAccountView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService
    @Environment(\.colorScheme) private var colorScheme
    @State private var showLogoutConfirmation = false
    @State private var ephemeralNotice: String?

    private var theme: SettingsVisualTheme { SettingsVisualTheme(colorScheme: colorScheme) }

    private var staffBusinessSubtitle: String? {
        let slug = AuthStorage.currentBusinessSlug ?? ""
        guard let business = authService.businesses.first(where: { $0.slug == slug }) else { return nil }
        let name = business.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    var body: some View {
        ZStack {
            GroupedSettingsMetrics.pageBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: GroupedSettingsMetrics.interCardSpacing) {
                    Color.clear.frame(height: 8)
                    if let notice = ephemeralNotice {
                        Text(notice)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(theme.accentPositive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(theme.noticeBG)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Compte employé")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(Color(UIColor.label))
                        if let sub = staffBusinessSubtitle {
                            Text(sub)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    GroupedSettingsCard {
                        GroupedSettingsNavigationRow(
                            icon: "person.text.rectangle",
                            title: authService.currentUserStaffLogin ?? "—",
                            subtitle: "Identifiant caisse",
                            value: nil,
                            showsChevron: false
                        )
                    }

                    GroupedSettingsCard {
                        lastSyncBlock
                        GroupedSettingsRowDivider()
                        syncNowButton
                        GroupedSettingsRowDivider()
                        NavigationLink {
                            SettingsScanSecurityView()
                                .environmentObject(syncService)
                        } label: {
                            GroupedSettingsNavigationRow(
                                icon: "shield.lefthalf.filled",
                                title: "Sécurité caisse & scan",
                                subtitle: nil,
                                value: nil,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    GroupedSettingsCard {
                        Button {
                            UIApplication.shared.open(LegalURLs.supportMail)
                        } label: {
                            GroupedSettingsNavigationRow(
                                icon: "questionmark.circle",
                                title: "Aide & support",
                                subtitle: nil,
                                value: nil,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    GroupedSettingsCard {
                        GroupedSettingsLogoutRow(action: { showLogoutConfirmation = true })
                    }
                }
                .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
                .padding(.top, 14)
            }
            .scrollIndicators(.hidden)
        }
        .alert("Déconnexion", isPresented: $showLogoutConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Se déconnecter", role: .destructive) { authService.logout() }
        } message: {
            Text("Vous devrez vous reconnecter avec vos identifiants employé.")
        }
    }

    private var lastSyncBlock: some View {
        HStack(alignment: .top, spacing: 12) {
            GroupedSettingsIconBox(systemName: "arrow.triangle.2.circlepath")
            VStack(alignment: .leading, spacing: 4) {
                Text("Dernière synchro")
                    .font(.body.weight(.medium))
                if let d = syncService.lastSyncDate {
                    Text(d, style: .relative)
                        .font(.subheadline)
                        .foregroundStyle(Color(UIColor.secondaryLabel))
                } else {
                    Text("Jamais")
                        .font(.subheadline)
                        .foregroundStyle(Color(UIColor.secondaryLabel))
                }
            }
            Spacer()
        }
    }

    private var syncNowButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { await syncService.syncAfterServerMutation() }
            flashNotice("Synchronisation lancée.")
        } label: {
            HStack {
                GroupedSettingsIconBox(systemName: "arrow.triangle.2.circlepath")
                Text("Synchroniser maintenant")
                    .font(.body.weight(.semibold))
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func flashNotice(_ text: String) {
        ephemeralNotice = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if ephemeralNotice == text { ephemeralNotice = nil }
        }
    }
}
