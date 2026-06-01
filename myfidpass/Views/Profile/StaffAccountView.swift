//
//  StaffAccountView.swift
//  myfidpass
//
//  Espace compte employé : identité, synchro, accès Paramètres (sécurité, support, déconnexion).
//

import SwiftUI
import UIKit

struct StaffAccountView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService
    @Environment(\.colorScheme) private var colorScheme
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
                        Text("Compte")
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
                        GroupedSettingsLastSyncSection(
                            onSyncStarted: { flashNotice("Synchronisation lancée.") }
                        )
                    }

                    GroupedSettingsCard {
                        NavigationLink {
                            MerchantAppSettingsHubView(mode: .staff)
                                .environmentObject(authService)
                                .environmentObject(syncService)
                        } label: {
                            GroupedSettingsNavigationRow(
                                icon: "gearshape.fill",
                                title: "Paramètres",
                                subtitle: "Sécurité caisse, aide, déconnexion",
                                value: nil,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
                .padding(.top, 14)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func flashNotice(_ text: String) {
        ephemeralNotice = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if ephemeralNotice == text { ephemeralNotice = nil }
        }
    }
}
