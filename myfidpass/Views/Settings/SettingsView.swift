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
    /// Si non nil : « Statistiques » appelle ce bloc (ex. paywall bloquant : fermer le sheet puis pousser la route).
    /// Si nil : fermeture du sheet Réglages + notification pour pousser sur la pile Commerce.
    var onRequestOpenStatistics: (() -> Void)? = nil

    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var revenueCatSubscriptionState: RevenueCatSubscriptionState

    @ObservedObject private var notifications = NotificationsService.shared

    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var showClearScanCacheConfirmation = false
    @State private var ephemeralNotice: String?
    @State private var isSyncingManual = false
    @State private var inAppSafariURL: URL?

    private var theme: SettingsVisualTheme { SettingsVisualTheme(colorScheme: colorScheme) }

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

    private var subscriptionSettingsSubtitle: String? {
        if authService.subscriptionAccessUnlocked(revenueCatPremium: revenueCatSubscriptionState.hasPremiumEntitlement) {
            return "Accès actif"
        }
        return "Essai 1 mois, mensuel ou annuel"
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
                    .scrollContentEdgeFade(edgeHeight: 40)
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
        .alert("Vider le cache de scan ?", isPresented: $showClearScanCacheConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Vider", role: .destructive) {
                ScanFlowSettingsCache.clearAll()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                flashNotice("Cache vidé.")
            }
        } message: {
            Text("Le prochain scan rechargera les réglages depuis le serveur.")
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

    private var statisticsNavigationRow: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if let onRequestOpenStatistics {
                onRequestOpenStatistics()
            } else {
                dismiss()
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .myfidpassOpenMerchantStatistics, object: nil)
                }
            }
        } label: {
            GroupedSettingsNavigationRow(
                icon: "chart.xyaxis.line",
                title: "Statistiques",
                subtitle: nil,
                value: nil,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Contenu fusionné

    @ViewBuilder
    private var settingsMergedInnerVStack: some View {
        VStack(alignment: .leading, spacing: GroupedSettingsMetrics.interCardSpacing) {
            if let notice = ephemeralNotice {
                Text(notice)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.accentPositive)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(theme.noticeBG)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if embedInProfile {
                GroupedSettingsPageTitle(compact: embedInProfile)
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
                GroupedSettingsRowDivider()
                Button {
                    dismiss()
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .myfidpassOpenMerchantSubscriptionSheet, object: nil)
                    }
                } label: {
                    GroupedSettingsNavigationRow(
                        icon: "crown.fill",
                        title: "Abonnement PRO",
                        subtitle: subscriptionSettingsSubtitle,
                        value: nil,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                GroupedSettingsRowDivider()
                statisticsNavigationRow
            }

            GroupedSettingsCard {
                NavigationLink {
                    MerchantEstablishmentForm(context: viewContext, sections: .engagementOnly)
                        .environmentObject(syncService)
                        .navigationTitle("Avis & réseaux")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    GroupedSettingsNavigationRow(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "Avis & réseaux",
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
                syncNowButtonRow
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
                Button {
                    showClearScanCacheConfirmation = true
                } label: {
                    GroupedSettingsNavigationRow(
                        icon: "trash.circle",
                        title: "Vider le cache de scan",
                        subtitle: nil,
                        value: nil,
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)
                GroupedSettingsRowDivider()
                NavigationLink {
                    MerchantTraceabilityExportView()
                } label: {
                    GroupedSettingsNavigationRow(
                        icon: "doc.richtext.fill",
                        title: "Traçabilité & exports",
                        subtitle: nil,
                        value: nil,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                GroupedSettingsRowDivider()
                NavigationLink {
                    MembersImportExportView()
                        .environmentObject(syncService)
                } label: {
                    GroupedSettingsNavigationRow(
                        icon: "square.and.arrow.up.on.square",
                        title: "Import / export CSV",
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

    private var syncNowButtonRow: some View {
        Button {
            Task {
                isSyncingManual = true
                await syncService.syncAfterServerMutation()
                isSyncingManual = false
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                flashNotice("Synchronisation terminée.")
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    if syncService.isSyncing || isSyncingManual {
                        ProgressView()
                            .tint(Color(UIColor.label))
                    } else {
                        GroupedSettingsIconBox(systemName: "arrow.clockwise")
                    }
                }
                .frame(width: GroupedSettingsMetrics.iconBoxSize, height: GroupedSettingsMetrics.iconBoxSize)
                Text(syncService.isSyncing || isSyncingManual ? "Synchronisation…" : "Synchroniser maintenant")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(UIColor.label))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
            .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(syncService.isSyncing || isSyncingManual)
    }

    private func flashNotice(_ text: String) {
        ephemeralNotice = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            ephemeralNotice = nil
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
            .environmentObject(RevenueCatSubscriptionState())
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
