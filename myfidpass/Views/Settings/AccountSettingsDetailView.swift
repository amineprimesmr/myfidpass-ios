//
//  AccountSettingsDetailView.swift
//  myfidpass
//
//  Hub compte : identité, sécurité, appareil — même DA que Réglages (cartes groupées).
//

import SwiftUI
import UIKit

struct AccountSettingsDetailView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService

    /// Sections seules, sans ScrollView (page Paramètres menu Accueil).
    var embedInParentScroll: Bool = false

    @ObservedObject private var notifications = NotificationsService.shared

    @State private var me: AuthMeResponse?
    @State private var isLoading = true
    @State private var lastRefreshAt: Date?
    @State private var loadError: String?
    @State private var isSendingPasswordReset = false
    @State private var passwordResetError: String?
    @State private var didRequestPushOnAccountAppear = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?

    private var emailDisplay: String {
        (me?.user.email ?? AuthStorage.userEmail ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var pushStatusLabel: String {
        notifications.isAuthorized ? "Autorisées" : "Non autorisées"
    }

    private var deviceLine: String {
        let v = UIDevice.current.systemVersion
        let model = UIDevice.current.model
        return "\(model) · iOS \(v)"
    }

    var body: some View {
        Group {
            if embedInParentScroll {
                accountSectionsContent
                    .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
            } else {
                ScrollView {
                    accountSectionsContent
                        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .background(GroupedSettingsMetrics.pageBackground.ignoresSafeArea())
                .navigationTitle("Compte")
                .navigationBarTitleDisplayMode(.large)
            }
        }
        .onAppear {
            notifications.refreshAuthorizationStatus()
            if !didRequestPushOnAccountAppear {
                didRequestPushOnAccountAppear = true
                notifications.requestPermissionAndRegister()
            }
        }
        .task {
            await refreshAccount(force: false)
        }
        .onAppear {
            if loadError != nil {
                Task { await refreshAccount(force: true) }
            }
        }
        .refreshable {
            await refreshAccount(force: true)
        }
        .alert("Réinitialisation", isPresented: .init(get: { passwordResetError != nil }, set: { if !$0 { passwordResetError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let m = passwordResetError { Text(m) }
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
        .overlay {
            if !embedInParentScroll, isLoading && me == nil {
                ProgressView()
                    .scaleEffect(1.1)
                    .tint(AppTheme.Colors.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemGroupedBackground).opacity(0.35))
            }
        }
    }

    private var accountSectionsContent: some View {
        VStack(alignment: .leading, spacing: GroupedSettingsMetrics.interCardSpacing) {
            if let err = loadError {
                loadErrorBanner(err)
            }

            if embedInParentScroll {
                embeddedAccountCard
            } else {
                standaloneAccountContent
            }
        }
    }

    private var embeddedAccountCard: some View {
        GroupedSettingsCard {
            GroupedSettingsInfoRow(
                icon: "envelope.fill",
                title: "E-mail",
                value: emailDisplay.isEmpty ? "—" : emailDisplay,
                valueMultiline: true,
                valueLineLimit: 2
            )
            GroupedSettingsRowDivider()
            GroupedSettingsInfoRow(icon: "building.2.fill", title: "Commerces", value: "\(authService.businesses.count)")

            if authService.businesses.count > 1 {
                GroupedSettingsRowDivider()
                commercePickerBlock
            }

            GroupedSettingsRowDivider()
            GroupedSettingsInfoRow(icon: "bell.badge.fill", title: "Notifications push", value: pushStatusLabel)
        }
    }

    private var standaloneAccountContent: some View {
        Group {
            GroupedSettingsCard {
                GroupedSettingsLastSyncSection()
            }

            GroupedSettingsCard {
                GroupedSettingsInfoRow(
                    icon: "envelope.fill",
                    title: "E-mail",
                    value: emailDisplay.isEmpty ? "—" : emailDisplay,
                    valueMultiline: true,
                    valueLineLimit: 2
                )
                GroupedSettingsRowDivider()
                GroupedSettingsInfoRow(icon: "key.fill", title: "Connexion", value: authProviderLabel)
                GroupedSettingsRowDivider()
                GroupedSettingsInfoRow(icon: "building.2.fill", title: "Commerces", value: "\(authService.businesses.count)")
            }

            if authService.businesses.count > 1 {
                GroupedSettingsCard {
                    commercePickerBlock
                }
            }

            GroupedSettingsCard {
                if AuthStorage.authProvider == .email {
                    Button {
                        Task { await sendPasswordResetEmail() }
                    } label: {
                        HStack(spacing: 12) {
                            GroupedSettingsIconBox(systemName: "lock.rotation")
                            Text(isSendingPasswordReset ? "Envoi en cours…" : "Réinitialiser le mot de passe")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color(UIColor.label))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
                        .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSendingPasswordReset || emailDisplay.isEmpty)
                } else {
                    GroupedSettingsInfoRow(
                        icon: "lock.shield",
                        title: "Mot de passe",
                        value: passwordExternalProviderLabel
                    )
                }
            }

            GroupedSettingsCard {
                GroupedSettingsInfoRow(icon: "iphone", title: "Cet appareil", value: deviceLine, valueMultiline: true)
                GroupedSettingsRowDivider()
                GroupedSettingsInfoRow(icon: "bell.badge.fill", title: "Notifications push", value: pushStatusLabel)
            }

            GroupedSettingsCard {
                GroupedSettingsDestructiveRow(title: "Supprimer mon compte") {
                    showDeleteAccountConfirmation = true
                }
            }
            Button {
                openURL(LegalURLs.deleteAccountInfo)
            } label: {
                Text("Page d’information (suppression de compte)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color(UIColor.secondaryLabel))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func loadErrorBanner(_ err: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(err)
                .font(.caption)
                .foregroundStyle(Color(UIColor.systemRed).opacity(colorScheme == .dark ? 0.95 : 1))
            HStack(spacing: 10) {
                Button("Réessayer") {
                    Task { await refreshAccount(force: true) }
                }
                .font(.caption.weight(.semibold))
                Button("Se déconnecter") {
                    authService.logout()
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemRed).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var authProviderLabel: String {
        switch AuthStorage.authProvider {
        case .apple: return "Apple"
        case .google: return "Google"
        case .email: return "E-mail"
        case .phone: return "Téléphone (SMS)"
        }
    }

    /// Hors compte e-mail : mot de passe géré par le fournisseur tiers.
    private var passwordExternalProviderLabel: String {
        switch AuthStorage.authProvider {
        case .apple: return "Géré par Apple"
        case .google: return "Géré par Google"
        case .phone: return "Connexion par SMS (sans mot de passe)"
        case .email: return ""
        }
    }

    private var activeCommerceDisplayName: String {
        if let s = AuthStorage.currentBusinessSlug,
           let b = authService.businesses.first(where: { $0.slug == s }) {
            let n = b.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return n.isEmpty ? b.slug : n
        }
        if let first = authService.businesses.first {
            let n = first.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return n.isEmpty ? first.slug : n
        }
        return "—"
    }

    private var commercePickerBlock: some View {
        HStack(alignment: .top, spacing: 12) {
            GroupedSettingsIconBox(systemName: "building.2")
            Text("Commerce actif")
                .font(.body.weight(.medium))
                .foregroundStyle(Color(UIColor.label))
                .fixedSize(horizontal: true, vertical: false)
            // `Menu` plutôt que `Picker` : sur les SDK récents, certaines surcharges de `Picker` exigent `sources:` / collections typées différemment.
            Menu {
                ForEach(authService.businesses, id: \.slug) { b in
                    Button {
                        guard b.slug != AuthStorage.currentBusinessSlug else { return }
                        authService.selectBusiness(slug: b.slug, showSwitchingOverlay: false)
                        Task {
                            await syncService.syncAfterServerMutation()
                            await seedWalletLocationDefaultsIfNeeded()
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack {
                            Text(b.name.isEmpty ? b.slug : b.name)
                            if b.slug == AuthStorage.currentBusinessSlug {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(activeCommerceDisplayName)
                        .font(.body)
                        .foregroundStyle(Color(UIColor.secondaryLabel))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(UIColor.tertiaryLabel))
                        .imageScale(.small)
                }
            }
        }
        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
        .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
    }

    private func refreshAccount(force: Bool = false) async {
        if !force, let lastRefreshAt, Date().timeIntervalSince(lastRefreshAt) < 30 {
            return
        }
        loadError = nil
        isLoading = true
        defer { isLoading = false }

        await APIClient.shared.ensureValidAccessTokenWithRetry(maxAttempts: 3)

        var lastError: Error?
        for attempt in 0..<3 {
            do {
                let r: AuthMeResponse = try await APIClient.shared.request(.authMe)
                await MainActor.run {
                    me = r
                    authService.applyAuthMeResponse(r)
                    lastRefreshAt = Date()
                    loadError = nil
                }
                await seedWalletLocationDefaultsIfNeeded()
                return
            } catch {
                if APIError.isBenignRequestCancellation(error) { return }
                lastError = error
                if case APIError.unauthorized = error {
                    let refresh = await APIClient.shared.tryRefreshToken()
                    if case .success = refresh, attempt < 2 {
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        continue
                    }
                    break
                }
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: UInt64(450_000_000 * UInt64(attempt + 1)))
                    await APIClient.shared.ensureValidAccessTokenWithRetry(maxAttempts: 2)
                    continue
                }
            }
        }

        await MainActor.run {
            loadError = accountLoadErrorMessage(from: lastError)
        }
    }

    private func accountLoadErrorMessage(from error: Error?) -> String {
        guard let error else {
            return "Impossible de charger le compte. Réessayez ou déconnectez-vous puis reconnectez-vous."
        }
        if let api = error as? APIError, let msg = api.errorDescription, !msg.isEmpty {
            return msg
        }
        if let localized = error as? LocalizedError, let msg = localized.errorDescription, !msg.isEmpty {
            return msg
        }
        return error.localizedDescription
    }

    /// Active une fois par commerce les notifications Wallet à proximité + texte périmètre par défaut (sans écran dédié).
    private func seedWalletLocationDefaultsIfNeeded() async {
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else { return }
        let flagKey = "myfidpass.account.walletLocationDefaultsSeeded." + slug
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        let defaultPerimeterMessage =
            "Vous êtes à proximité de notre commerce. Passez nous voir, votre carte Wallet est prête."
        do {
            let settings: BusinessSettingsResponse = try await APIClient.shared.request(.businessSettings(slug: slug))
            let include = settings.walletPassIncludeLocations ?? 0
            let msg = settings.locationRelevantText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let needsWallet = include != 1
            let needsMsg = msg.isEmpty
            guard needsWallet || needsMsg else {
                UserDefaults.standard.set(true, forKey: flagKey)
                return
            }
            _ = try await APIClient.shared.request(
                APIEndpoint.updateLocationSettings(
                    slug: slug,
                    locationLat: nil,
                    locationLng: nil,
                    locationRadiusMeters: nil,
                    locationRelevantText: needsMsg ? defaultPerimeterMessage : nil,
                    locationAddress: nil,
                    walletPassIncludeLocations: needsWallet ? true : nil
                )
            ) as EmptyResponse
            await syncService.syncAfterServerMutation()
            UserDefaults.standard.set(true, forKey: flagKey)
        } catch {
            // Silencieux : le commerce reste utilisable sans Wallet géolocalisé.
        }
    }

    private func sendPasswordResetEmail() async {
        passwordResetError = nil
        let email = emailDisplay
        guard !email.isEmpty else { return }
        isSendingPasswordReset = true
        defer { isSendingPasswordReset = false }
        do {
            try await authService.forgotPassword(email: email)
            await MainActor.run {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        } catch {
            await MainActor.run {
                passwordResetError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
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
