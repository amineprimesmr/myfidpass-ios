//
//  MerchantHomeMenuSettingsView.swift
//  myfidpass
//
//  Paramètres menu Accueil — liste unifiée sans catégories.
//

import SwiftUI

struct MerchantHomeMenuSettingsView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService

    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GroupedSettingsMetrics.interCardSpacing) {
                AccountSettingsDetailView(embedInParentScroll: true)

                commerceAndToolsCard

                MerchantAppSettingsHubView(embedInParentScroll: true)

                GroupedSettingsCard {
                    GroupedSettingsLogoutRow(action: { showLogoutConfirmation = true })
                }
                .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)

                GroupedSettingsCard {
                    GroupedSettingsDestructiveRow(title: "Supprimer mon compte") {
                        showDeleteAccountConfirmation = true
                    }
                }
                .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(GroupedSettingsMetrics.pageBackground.ignoresSafeArea())
        .navigationTitle("Paramètres")
        .navigationBarTitleDisplayMode(.large)
        .alert("Déconnexion", isPresented: $showLogoutConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Se déconnecter", role: .destructive) { authService.logout() }
        } message: {
            Text("Vous devrez vous reconnecter.")
        }
        .alert("Supprimer votre compte ?", isPresented: $showDeleteAccountConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer définitivement", role: .destructive) {
                Task { await performDeleteAccount() }
            }
        } message: {
            Text(
                "Cette action est irréversible : compte commerçant, données et historique associés. L’abonnement Stripe sera annulé. Un abonnement App Store reste lié à votre Apple ID (annulez-le dans Réglages iPhone → Abonnements si vous ne souhaitez plus être facturé). Vous serez déconnecté immédiatement."
            )
        }
        .alert("Erreur", isPresented: .init(get: { deleteAccountError != nil }, set: { if !$0 { deleteAccountError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let msg = deleteAccountError { Text(msg) }
        }
        .overlay {
            if isDeletingAccount {
                ZStack {
                    Color(UIColor.tertiarySystemBackground)
                        .opacity(0.92)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.3).tint(AppTheme.Colors.primary)
                        Text("Suppression…")
                            .font(.headline)
                            .foregroundStyle(Color(UIColor.label))
                    }
                    .padding(32)
                }
            }
        }
    }

    @ViewBuilder
    private var commerceAndToolsCard: some View {
        let showsTeam = authService.canManageMerchantTeam
        let showsAddAddress = !authService.isPlatformAdmin || authService.adminShowsMerchantWorkspace
        let showsLoyaltyNetwork = showsTeam
        if showsTeam || showsAddAddress || showsLoyaltyNetwork {
            GroupedSettingsCard {
                if showsTeam {
                    NavigationLink {
                        MerchantTeamManagementView()
                            .environmentObject(authService)
                    } label: {
                        GroupedSettingsNavigationRow(
                            icon: "person.2",
                            title: "Équipe",
                            subtitle: nil,
                            value: nil,
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                }

                if showsAddAddress {
                    if showsTeam { GroupedSettingsRowDivider() }
                    Button {
                        Task { @MainActor in
                            await authService.refreshMerchantBillingStateFromServer(force: true)
                            if authService.canCreateBusiness {
                                NotificationCenter.default.post(name: .myfidpassOpenAddCommerceSheet, object: nil)
                            } else {
                                NotificationCenter.default.postOpenMerchantSubscription(
                                    usedBusinesses: authService.usedBusinesses,
                                    allowedBusinesses: authService.allowedBusinesses,
                                    addingAnotherCommerce: true
                                )
                            }
                        }
                    } label: {
                        GroupedSettingsNavigationRow(
                            icon: "plus.circle",
                            title: "Ajouter une adresse",
                            subtitle: nil,
                            value: nil,
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                }

                if showsLoyaltyNetwork {
                    if showsTeam || showsAddAddress { GroupedSettingsRowDivider() }
                    NavigationLink {
                        LoyaltyNetworkSettingsView()
                    } label: {
                        GroupedSettingsNavigationRow(
                            icon: "link.circle",
                            title: "Réseau fidélité",
                            subtitle: authService.businesses.contains(where: \.isInLoyaltyNetwork)
                                ? "Carte partagée active"
                                : "Regrouper plusieurs adresses",
                            value: nil,
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
        }
    }

    private func performDeleteAccount() async {
        await MainActor.run {
            isDeletingAccount = true
            deleteAccountError = nil
        }
        defer {
            Task { @MainActor in
                isDeletingAccount = false
            }
        }
        do {
            try await authService.deleteAccount()
        } catch {
            await MainActor.run {
                deleteAccountError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
