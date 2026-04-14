//
//  AccountSettingsDetailView.swift
//  myfidpass
//
//  Hub compte : identité, sécurité, appareil, lien fiche établissement — même DA que Réglages (cartes groupées).
//

import SwiftUI
import UIKit

struct AccountSettingsDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService

    @ObservedObject private var notifications = NotificationsService.shared

    @State private var me: AuthMeResponse?
    @State private var establishmentAddress: String?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var isSendingPasswordReset = false
    @State private var passwordResetNotice: String?
    @State private var passwordResetError: String?

    private var theme: SettingsVisualThemeAccount { SettingsVisualThemeAccount(colorScheme: colorScheme) }

    private var emailDisplay: String {
        (me?.user.email ?? AuthStorage.userEmail ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var nameDisplay: String {
        let n = (me?.user.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "—" : n
    }

    private var subscriptionLine: String {
        guard let s = me?.subscription?.status?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
            return me?.hasActiveSubscription == true ? "Actif" : "—"
        }
        if let plan = me?.subscription?.planId, !plan.isEmpty {
            return "\(s) · \(plan)"
        }
        return s
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
                    GroupedSettingsInfoRow(icon: "envelope.fill", title: "E-mail", value: emailDisplay.isEmpty ? "—" : emailDisplay, valueMultiline: true)
                    GroupedSettingsRowDivider()
                    GroupedSettingsInfoRow(icon: "person.text.rectangle", title: "Nom", value: nameDisplay, valueMultiline: true)
                    GroupedSettingsRowDivider()
                    GroupedSettingsInfoRow(icon: "key.fill", title: "Connexion", value: authProviderLabel)
                    GroupedSettingsRowDivider()
                    GroupedSettingsInfoRow(icon: "creditcard.fill", title: "Abonnement", value: subscriptionLine, valueMultiline: true)
                    GroupedSettingsRowDivider()
                    GroupedSettingsInfoRow(icon: "building.2.fill", title: "Commerces", value: "\(authService.businesses.count)")
                }

                if authService.businesses.count > 1 {
                    GroupedSettingsCard {
                        commercePickerBlock
                    }
                }

                GroupedSettingsCard {
                    GroupedSettingsInfoRow(
                        icon: "mappin.circle.fill",
                        title: "Adresse (établissement)",
                        value: addressSnippet,
                        valueMultiline: true
                    )
                    GroupedSettingsRowDivider()
                    NavigationLink {
                        ScrollView {
                            MerchantEstablishmentForm(context: viewContext)
                                .environmentObject(syncService)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                        .background(GroupedSettingsMetrics.pageBackground)
                        .navigationTitle("Fiche commerce")
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        GroupedSettingsNavigationRow(
                            icon: "building.columns.fill",
                            title: "Modifier la fiche & l’adresse",
                            subtitle: "Identité, coordonnées, réseaux",
                            value: nil,
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                }

                GroupedSettingsCard {
                    if AuthStorage.authProvider == .email {
                        Button {
                            Task { await sendPasswordResetEmail() }
                        } label: {
                            HStack(spacing: 12) {
                                GroupedSettingsIconBox(systemName: "lock.rotation")
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(isSendingPasswordReset ? "Envoi en cours…" : "Réinitialiser le mot de passe")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(Color(UIColor.label))
                                    Text("Un lien sécurisé est envoyé à votre e-mail.")
                                        .font(.caption)
                                        .foregroundStyle(Color(UIColor.secondaryLabel))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
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
                            value: AuthStorage.authProvider == .apple ? "Géré par Apple" : "Géré par Google",
                        )
                    }
                }

                GroupedSettingsCard {
                    GroupedSettingsInfoRow(icon: "iphone", title: "Cet appareil", value: deviceLine, valueMultiline: true)
                    GroupedSettingsRowDivider()
                    GroupedSettingsInfoRow(icon: "bell.badge.fill", title: "Notifications push", value: pushStatusLabel)
                    GroupedSettingsRowDivider()
                    GroupedSettingsInfoRow(
                        icon: "info.circle.fill",
                        title: "Sessions",
                        value: "Cet iPhone utilise votre compte. La liste des autres appareils n’est pas disponible dans l’app pour l’instant.",
                        valueMultiline: true
                    )
                }

                GroupedSettingsCard {
                    NavigationLink {
                        SubscriptionBusinessView()
                            .environmentObject(authService)
                            .environmentObject(syncService)
                    } label: {
                        GroupedSettingsNavigationRow(
                            icon: "sparkles.rectangle.stack.fill",
                            title: "Abonnement & nouveau commerce",
                            subtitle: nil,
                            value: nil,
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                }

                Text("Les données de fidélité sont sur les serveurs MyFidpass. Cet écran résume votre compte marchand.")
                    .font(.caption)
                    .foregroundStyle(Color(UIColor.secondaryLabel))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .scrollContentEdgeFade(edgeHeight: 36)
        .background(GroupedSettingsMetrics.pageBackground.ignoresSafeArea())
        .navigationTitle("Compte")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await refreshAccount()
        }
        .refreshable {
            await refreshAccount()
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

    private var addressSnippet: String {
        let a = (establishmentAddress ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return a.isEmpty ? "Non renseignée" : a
    }

    private var authProviderLabel: String {
        switch AuthStorage.authProvider {
        case .apple: return "Apple"
        case .google: return "Google"
        case .email: return "E-mail"
        }
    }

    private var commercePickerBlock: some View {
        HStack(alignment: .center, spacing: 12) {
            GroupedSettingsIconBox(systemName: "building.2")
            Text("Commerce actif")
                .font(.body.weight(.medium))
                .foregroundStyle(Color(UIColor.label))
                .frame(maxWidth: .infinity, alignment: .leading)
            Picker("Commerce", selection: Binding(
                get: {
                    if let s = AuthStorage.currentBusinessSlug,
                       authService.businesses.contains(where: { $0.slug == s }) {
                        return s
                    }
                    return authService.businesses.first?.slug ?? ""
                },
                set: { newSlug in
                    guard !newSlug.isEmpty else { return }
                    authService.selectBusiness(slug: newSlug)
                    Task {
                        await syncService.syncAfterServerMutation()
                        await refreshAddressOnly()
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            )) {
                ForEach(authService.businesses, id: \.slug) { b in
                    Text(b.name.isEmpty ? b.slug : b.name).tag(b.slug)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
        .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
    }

    private func refreshAccount() async {
        loadError = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let r: AuthMeResponse = try await APIClient.shared.request(.authMe)
            await MainActor.run {
                me = r
                authService.applyAuthMeResponse(r)
            }
            await refreshAddressOnly()
        } catch {
            await MainActor.run {
                loadError = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func refreshAddressOnly() async {
        guard let slug = AuthStorage.currentBusinessSlug ?? authService.businesses.first?.slug else {
            await MainActor.run { establishmentAddress = nil }
            return
        }
        do {
            let s: BusinessSettingsResponse = try await APIClient.shared.request(.businessSettings(slug: slug))
            await MainActor.run { establishmentAddress = s.locationAddress }
        } catch {
            await MainActor.run { establishmentAddress = nil }
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
