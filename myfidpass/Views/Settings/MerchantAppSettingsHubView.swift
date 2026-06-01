//
//  MerchantAppSettingsHubView.swift
//  myfidpass
//
//  Paramètres app : sécurité caisse, pack comptable, légal, support, déconnexion.
//

import SwiftUI
import UIKit

enum MerchantAppSettingsHubMode {
    /// Commerçant propriétaire / admin workspace.
    case merchant
    /// Employé caisse : pas de pack comptable.
    case staff
}

struct MerchantAppSettingsHubView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService

    var mode: MerchantAppSettingsHubMode = .merchant
    /// Sections seules, sans ScrollView (page Paramètres menu Accueil).
    var embedInParentScroll: Bool = false

    @State private var showLogoutConfirmation = false
    @State private var inAppSafariURL: URL?

    private var showsAccountingPack: Bool { mode == .merchant }

    var body: some View {
        Group {
            if embedInParentScroll {
                appSettingsSectionsContent
                    .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
            } else {
                ScrollView {
                    appSettingsSectionsContent
                        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .background(GroupedSettingsMetrics.pageBackground.ignoresSafeArea())
                .navigationTitle("Paramètres")
                .navigationBarTitleDisplayMode(.large)
            }
        }
        .sheet(isPresented: Binding(
            get: { inAppSafariURL != nil },
            set: { if !$0 { inAppSafariURL = nil } }
        )) {
            if let url = inAppSafariURL {
                InAppSafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .alert("Déconnexion", isPresented: $showLogoutConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Se déconnecter", role: .destructive) { authService.logout() }
        } message: {
            Text(mode == .staff
                ? "Vous devrez vous reconnecter avec vos identifiants employé."
                : "Vous devrez vous reconnecter.")
        }
    }

    private var appSettingsSectionsContent: some View {
        VStack(alignment: .leading, spacing: GroupedSettingsMetrics.interCardSpacing) {
            if !embedInParentScroll {
                GroupedSettingsSectionHeader(title: "Commerce & sécurité")
            }

            GroupedSettingsCard {
                NavigationLink {
                    SettingsScanSecurityView()
                        .environmentObject(syncService)
                } label: {
                    GroupedSettingsNavigationRow(
                        icon: "shield.lefthalf.filled",
                        title: "Sécurité caisse & scan",
                        subtitle: embedInParentScroll ? nil : "QR, tickets, anti-fraude",
                        value: nil,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)

                if showsAccountingPack {
                    GroupedSettingsRowDivider()
                    NavigationLink {
                        MerchantAccountingPackView()
                    } label: {
                        GroupedSettingsNavigationRow(
                            icon: "doc.text.magnifyingglass",
                            title: "Pack comptable (bilan)",
                            subtitle: embedInParentScroll ? nil : "Exports CSV pour votre expert-comptable",
                            value: nil,
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if !embedInParentScroll {
                GroupedSettingsSectionHeader(title: "Informations légales")
            }

            GroupedSettingsCard {
                Button {
                    inAppSafariURL = LegalURLs.termsOfUse
                } label: {
                    GroupedSettingsNavigationRow(
                        icon: "doc.text",
                        title: "Conditions d’utilisation",
                        subtitle: nil,
                        value: nil,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                GroupedSettingsRowDivider()
                Button {
                    inAppSafariURL = LegalURLs.privacyPolicy
                } label: {
                    GroupedSettingsNavigationRow(
                        icon: "hand.raised",
                        title: "Politique de confidentialité",
                        subtitle: nil,
                        value: nil,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
            }

            if !embedInParentScroll {
                GroupedSettingsSectionHeader(title: "Assistance")
            }

            GroupedSettingsCard {
                Button {
                    openURL(LegalURLs.supportMail)
                } label: {
                    GroupedSettingsNavigationRow(
                        icon: "envelope.open",
                        title: "Contacter le support",
                        subtitle: embedInParentScroll ? nil : "E-mail à l’équipe MyFidpass",
                        value: nil,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
            }

            if !embedInParentScroll {
                GroupedSettingsCard {
                    GroupedSettingsLogoutRow(action: { showLogoutConfirmation = true })
                }
            }
        }
    }
}

/// Petit titre de section dans les hubs Réglages / Paramètres.
struct GroupedSettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(UIColor.secondaryLabel))
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 4)
    }
}
