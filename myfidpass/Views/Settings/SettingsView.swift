//
//  SettingsView.swift
//  myfidpass
//
//  Réglages style iOS groupé : fond systemGroupedBackground, cartes arrondies, pastilles d’icônes.
//

import SwiftUI
import UIKit
import CoreData

struct SettingsView: View {
    /// Contenu fusionné (sans `ScrollView`) pour l’onglet « Réglages » du hub Commerce.
    var embedInProfile: Bool = false

    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService

    private let notifications = NotificationsService.shared

    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var inAppSafariURL: URL?

    private var appVersionShort: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private static let relativeSyncFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.unitsStyle = .abbreviated
        return f
    }()

    private var lastSyncText: String {
        guard let d = syncService.lastSyncDate else { return "Jamais" }
        return Self.relativeSyncFormatter.localizedString(for: d, relativeTo: Date())
    }

    private var shouldShowTrialPromoBanner: Bool {
        !authService.hasPaidStripeSubscription
            && authService.isMerchantTrialPeriodActive
            && authService.merchantTrialEndsAt != nil
    }

    private var needsFlyerSetupBadge: Bool {
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines),
              !slug.isEmpty else { return false }
        CommerceFlyerStore.shared.hydrateFromDiskIfNeeded(slug: slug)
        guard let cached = CommerceFlyerStore.shared.snapshot(for: slug) else { return true }
        let hasBootstrap = !(cached.bootstrapPreviewB64 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasCustomBg = !(cached.customBgDataURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !(cached.flyerRegistered || hasBootstrap || hasCustomBg)
    }

    var body: some View {
        Group {
            if embedInProfile {
                settingsMergedInnerVStack
            } else {
                ZStack {
                    GroupedSettingsMetrics.pageBackground.ignoresSafeArea()
                    ScrollView {
                        VStack(alignment: .leading, spacing: GroupedSettingsMetrics.interCardSpacing) {
                            Color.clear.frame(height: 8)
                            settingsMergedInnerVStack
                        }
                        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
                        .padding(.top, 14)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .background(embedInProfile ? Color.clear : GroupedSettingsMetrics.pageBackground)
        .settingsNavigationChrome(embedInProfile: embedInProfile)
        .onAppear {
            notifications.refreshAuthorizationStatus()
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
        /// `alert` plutôt que `confirmationDialog` : évite la présentation type popover avec flèche (iPad / certains contextes).
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
                "Cette action est irréversible : compte commerçant, données et historique associés. Vous serez déconnecté immédiatement après confirmation."
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
        .frame(maxWidth: .infinity, maxHeight: embedInProfile ? nil : .infinity)
    }

    // MARK: - Contenu fusionné

    @ViewBuilder
    private var settingsMergedInnerVStack: some View {
        VStack(alignment: .leading, spacing: GroupedSettingsMetrics.interCardSpacing) {
            if embedInProfile {
                GroupedSettingsPageTitle(compact: embedInProfile)
            }

            if shouldShowTrialPromoBanner, let trialEnd = authService.merchantTrialEndsAt {
                CommerceTrialPromoBannerView(trialEndsAt: trialEnd) {
                    NotificationCenter.default.post(name: .myfidpassOpenMerchantSubscriptionSheet, object: nil)
                }
            }

            if authService.canManageMerchantTeam {
                GroupedSettingsCard {
                    NavigationLink {
                        MerchantTeamManagementView()
                    } label: {
                        GroupedSettingsNavigationRow(
                            icon: "person.3.fill",
                            title: "Équipe",
                            subtitle: nil,
                            value: nil,
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if let slug = authService.businesses.first?.slug.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty {
                GroupedSettingsCard {
                    Button {
                        NotificationCenter.default.post(name: .myfidpassSelectMerchantHomeTab, object: nil)
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 280_000_000)
                            NotificationCenter.default.post(name: .myfidpassOpenMerchantFlyerHub, object: nil)
                        }
                    } label: {
                        GroupedSettingsNavigationRow(
                            icon: "doc.richtext",
                            title: "Flyer",
                            subtitle: nil,
                            value: nil,
                            showsChevron: true,
                            showsAttentionDot: needsFlyerSetupBadge
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            GroupedSettingsCard {
                NavigationLink {
                    AccountSettingsDetailView()
                        .environmentObject(authService)
                        .environmentObject(syncService)
                        .environment(\.managedObjectContext, viewContext)
                } label: {
                    GroupedSettingsNavigationRow(
                        icon: "person.crop.circle.fill",
                        title: "Compte",
                        subtitle: nil,
                        value: nil,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
            }

            GroupedSettingsCard {
                lastSyncDetailBlock
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
                GroupedSettingsRowDivider()
                NavigationLink {
                    MerchantAccountingPackView()
                } label: {
                    GroupedSettingsNavigationRow(
                        icon: "doc.text.magnifyingglass",
                        title: "Pack comptable (bilan)",
                        subtitle: nil,
                        value: nil,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
            }

            GroupedSettingsCard {
                Button {
                    inAppSafariURL = LegalURLs.termsOfUse
                } label: {
                    GroupedSettingsNavigationRow(icon: "doc.text", title: "Conditions d’utilisation", subtitle: nil, value: nil, showsChevron: true)
                }
                .buttonStyle(.plain)
                GroupedSettingsRowDivider()
                Button {
                    inAppSafariURL = LegalURLs.privacyPolicy
                } label: {
                    GroupedSettingsNavigationRow(icon: "hand.raised", title: "Politique de confidentialité", subtitle: nil, value: nil, showsChevron: true)
                }
                .buttonStyle(.plain)
            }

            GroupedSettingsCard {
                Button {
                    openURL(LegalURLs.supportMail)
                } label: {
                    GroupedSettingsNavigationRow(
                        icon: "envelope.open",
                        title: "Contacter le support",
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

            GroupedSettingsCard {
                GroupedSettingsDestructiveRow(title: "Supprimer mon compte", action: { showDeleteAccountConfirmation = true })
            }

            Text("Version \(appVersionShort)")
                .font(.caption)
                .foregroundStyle(Color(UIColor.secondaryLabel).opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, embedInProfile ? 28 : 100)
        }
    }

    private var lastSyncDetailBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                GroupedSettingsIconBox(systemName: "arrow.triangle.2.circlepath")
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Dernière synchro")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color(UIColor.label))
                        Spacer(minLength: 8)
                        Text(lastSyncText)
                            .font(.body)
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                    }
                    if let err = syncService.lastError, !err.isEmpty {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(Color(UIColor.systemRed)
                                .opacity(colorScheme == .dark ? 0.9 : 1))
                    }
                }
            }
        }
        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
        .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
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

// MARK: - Navigation

private extension View {
    /// Depuis Commerce : barre visible avec titre « Réglages » et bouton retour système. Intégré dans l’onglet : barre masquée comme avant.
    @ViewBuilder
    func settingsNavigationChrome(embedInProfile: Bool) -> some View {
        if embedInProfile {
            self.toolbar(.hidden, for: .navigationBar)
        } else {
            self
                .navigationTitle("Réglages")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Thème (pilule SaaS, notice)

struct SettingsVisualTheme {
    let colorScheme: ColorScheme
    var isDark: Bool { colorScheme == .dark }

    var noticeBG: Color {
        isDark ? Color.green.opacity(0.18) : AppTheme.Colors.success.opacity(0.12)
    }

    var accentPositive: Color {
        isDark ? Color.green.opacity(0.95) : AppTheme.Colors.success
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AuthService())
            .environmentObject(SyncService(container: PersistenceController.preview.container))
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
