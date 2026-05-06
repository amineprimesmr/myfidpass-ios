//
//  AccountSettingsDetailView.swift
//  myfidpass
//
//  Hub compte : identité, sécurité, appareil — même DA que Réglages (cartes groupées).
//

import SwiftUI
import UIKit

struct AccountSettingsDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService

    @ObservedObject private var notifications = NotificationsService.shared

    @State private var me: AuthMeResponse?
    @State private var isLoading = true
    @State private var didInitialLoad = false
    @State private var lastRefreshAt: Date?
    @State private var loadError: String?
    @State private var isSendingPasswordReset = false
    @State private var passwordResetNotice: String?
    @State private var passwordResetError: String?
    @State private var didRequestPushOnAccountAppear = false

    private var theme: SettingsVisualThemeAccount { SettingsVisualThemeAccount(colorScheme: colorScheme) }

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
        ScrollView {
            VStack(alignment: .leading, spacing: GroupedSettingsMetrics.interCardSpacing) {
                if let notice = passwordResetNotice {
                    Text(notice)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.accentPositive)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(theme.noticeBG)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if let err = loadError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(Color(UIColor.systemRed).opacity(colorScheme == .dark ? 0.95 : 1))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.systemRed).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                            value: passwordExternalProviderLabel,
                        )
                    }
                }

                GroupedSettingsCard {
                    GroupedSettingsInfoRow(icon: "iphone", title: "Cet appareil", value: deviceLine, valueMultiline: true)
                    GroupedSettingsRowDivider()
                    GroupedSettingsInfoRow(icon: "bell.badge.fill", title: "Notifications push", value: pushStatusLabel)
                }

            }
            .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(GroupedSettingsMetrics.pageBackground.ignoresSafeArea())
        .navigationTitle("Compte")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            notifications.refreshAuthorizationStatus()
            if !didRequestPushOnAccountAppear {
                didRequestPushOnAccountAppear = true
                notifications.requestPermissionAndRegister()
            }
        }
        .task {
            guard !didInitialLoad else { return }
            didInitialLoad = true
            await refreshAccount(force: true)
        }
        .refreshable {
            await refreshAccount(force: true)
        }
        .alert("Réinitialisation", isPresented: .init(get: { passwordResetError != nil }, set: { if !$0 { passwordResetError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let m = passwordResetError { Text(m) }
        }
        .overlay {
            if isLoading && me == nil {
                ProgressView()
                    .scaleEffect(1.1)
                    .tint(AppTheme.Colors.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemGroupedBackground).opacity(0.35))
            }
        }
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
        do {
            let r: AuthMeResponse = try await APIClient.shared.request(.authMe)
            await MainActor.run {
                me = r
                authService.applyAuthMeResponse(r)
            }
            await seedWalletLocationDefaultsIfNeeded()
            await MainActor.run {
                lastRefreshAt = Date()
            }
        } catch {
            await MainActor.run {
                loadError = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
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
        passwordResetNotice = nil
        passwordResetError = nil
        let email = emailDisplay
        guard !email.isEmpty else { return }
        isSendingPasswordReset = true
        defer { isSendingPasswordReset = false }
        do {
            try await authService.forgotPassword(email: email)
            await MainActor.run {
                passwordResetNotice = "E-mail envoyé. Ouvrez le lien pour choisir un nouveau mot de passe."
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    passwordResetNotice = nil
                }
            }
        } catch {
            await MainActor.run {
                passwordResetError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

private struct SettingsVisualThemeAccount {
    let colorScheme: ColorScheme
    var isDark: Bool { colorScheme == .dark }
    var noticeBG: Color {
        isDark ? Color.green.opacity(0.18) : AppTheme.Colors.success.opacity(0.12)
    }
    var accentPositive: Color {
        isDark ? Color.green.opacity(0.95) : AppTheme.Colors.success
    }
}
