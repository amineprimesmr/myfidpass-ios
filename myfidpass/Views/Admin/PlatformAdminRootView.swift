//
//  PlatformAdminRootView.swift
//  myfidpass
//
//  Console admin — fond app standard, pastilles commerce noires, recherche native.
//

import SwiftUI

// MARK: - Navigation

private enum AdminRoute: Hashable {
    case commerce(AdminBusinessRow)
}

/// Style réservé aux pastilles commerce (fond noir, texte blanc).
private enum AdminCommercePillStyle {
    static let fill = Color.black
    static let stroke = Color.white.opacity(0.12)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.58)
    static let iconDisc = Color.white.opacity(0.14)
    static let activeLogoRing = Color(red: 0.42, green: 0.88, blue: 0.58)
}

struct PlatformAdminRootView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var navPath = NavigationPath()
    @State private var overview: AdminOverviewResponse?
    @State private var search = ""
    @State private var loadError: String?
    @State private var isLoading = true
    @State private var pilotingSlug: String?
    @State private var showCreateMerchantOnboarding = false
    @State private var createSuccessMessage: String?

    private var businesses: [AdminBusinessRow] {
        authService.platformAdminBusinessRows
    }

    private var filteredBusinesses: [AdminBusinessRow] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return businesses }
        return businesses.filter { b in
            [b.slug, b.name, b.organizationName, b.ownerEmail]
                .compactMap { $0?.lowercased() }
                .contains { $0.contains(q) }
        }
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    adminHeader
                    commerceList
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
            .background(AppTheme.Colors.background)
            .scrollIndicators(.hidden)
            .refreshable { await loadAll(forceBusinesses: true) }
            .searchable(text: $search, prompt: "Commerce, slug, e-mail…")
            .navigationTitle("Administration")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button(role: .destructive) {
                            authService.logout()
                        } label: {
                            Label("Déconnexion", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        authService.beginAdminMerchantProvisioning()
                        showCreateMerchantOnboarding = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Créer un compte commerçant")
                }
            }
            .fullScreenCover(isPresented: $showCreateMerchantOnboarding) {
                AdminMerchantProvisioningFlowView(
                    onFinished: { message in
                        showCreateMerchantOnboarding = false
                        createSuccessMessage = message
                        Task { await loadAll(forceBusinesses: true) }
                    },
                    onCancelled: {
                        showCreateMerchantOnboarding = false
                    }
                )
                .environmentObject(authService)
            }
            .alert("Compte créé", isPresented: .init(
                get: { createSuccessMessage != nil },
                set: { if !$0 { createSuccessMessage = nil } }
            )) {
                Button("OK", role: .cancel) { createSuccessMessage = nil }
            } message: {
                if let createSuccessMessage {
                    Text(createSuccessMessage)
                }
            }
            .navigationDestination(for: AdminRoute.self) { route in
                if case .commerce(let business) = route {
                    PlatformAdminCommerceDetailPage(business: business)
                }
            }
        }
        .tint(AppTheme.Colors.primary)
        .task { await loadAll(forceBusinesses: businesses.isEmpty) }
    }

    // MARK: Header

    private var adminHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            bigStatsRow
            if let overview {
                adminStatsBreakdown(overview)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("Tous les")
                    .font(.system(.title2, design: .default).weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Text("Commerces")
                    .font(.system(.largeTitle, design: .default).weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
        }
    }

    private var bigStatsRow: some View {
        HStack(spacing: 22) {
            bigStat(value: overview?.businessesCount ?? businesses.count, label: "Commerces")
            bigStat(value: overview?.usersCount ?? 0, label: "Comptes")
            bigStat(value: overview?.activeSubscriptionsCount ?? 0, label: "Abos")
        }
    }

    private func adminStatsBreakdown(_ overview: AdminOverviewResponse) -> some View {
        let parts = [
            overview.merchantOwnersCount.map { "\($0) proprio" },
            overview.teamMemberAccountsCount.flatMap { $0 > 0 ? "\($0) équipe" : nil },
            overview.platformAdminAccountsCount.flatMap { $0 > 0 ? "\($0) admin" : nil },
            overview.orphanAccountsCount.flatMap { $0 > 0 ? "\($0) orphelin\($0 > 1 ? "s" : "")" : nil },
        ].compactMap { $0 }

        return Group {
            if !parts.isEmpty {
                Text(parts.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            if let orphans = overview.orphanAccountsCount, orphans > 0 {
                Text("Comptes orphelins : inscriptions abandonnées ou commerces supprimés sans effacer le compte propriétaire.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }

    private func bigStat(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.Colors.primary)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    // MARK: Liste

    @ViewBuilder
    private var commerceList: some View {
        if isLoading && businesses.isEmpty {
            hubProgress
        } else if let loadError, businesses.isEmpty {
            hubError(loadError)
        } else if filteredBusinesses.isEmpty {
            hubEmptySearch
        } else {
            LazyVStack(spacing: 10) {
                ForEach(filteredBusinesses) { b in
                    AdminCommercePillRow(
                        business: b,
                        isPiloting: pilotingSlug == b.slug,
                        onPilot: { pilot(b) },
                        onOpenSettings: { openCommerceSettings(b) }
                    )
                }
            }
        }
    }

    private var hubProgress: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Chargement…")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func hubError(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title2)
                .foregroundStyle(AppTheme.Colors.error)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.Colors.error)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private var hubEmptySearch: some View {
        Text("Aucun résultat")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
    }

    private func pilot(_ b: AdminBusinessRow) {
        guard pilotingSlug == nil else { return }
        pilotingSlug = b.slug
        Task {
            await authService.openMerchantWorkspaceFromAdmin(preferredSlug: b.slug)
            pilotingSlug = nil
        }
    }

    private func openCommerceSettings(_ b: AdminBusinessRow) {
        navPath.append(AdminRoute.commerce(b))
    }

    private func loadAll(forceBusinesses: Bool) async {
        let hadCache = !businesses.isEmpty
        if !hadCache { isLoading = true }
        loadError = nil
        defer { isLoading = false }
        do {
            async let overviewTask: AdminOverviewResponse = APIClient.shared.request(.adminOverview)
            let businessesOK = await authService.refreshPlatformAdminBusinesses(force: true)
            overview = try await overviewTask
            if !businessesOK, businesses.isEmpty {
                loadError = "Impossible de charger la liste des commerces."
            }
        } catch {
            if businesses.isEmpty {
                loadError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

// MARK: - Ligne commerce

private struct AdminCommercePillRow: View {
    let business: AdminBusinessRow
    var isPiloting: Bool
    let onPilot: () -> Void
    let onOpenSettings: () -> Void

    @State private var isLongPressing = false
    @State private var longPressHapticTick = 0

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            AdminCommerceLogoDisc(
                business: business,
                size: 44,
                showsActiveSubscriptionRing: business.ownerHasActiveSubscription
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(business.displayName)
                    .font(.body.weight(.bold))
                    .foregroundStyle(AdminCommercePillStyle.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)
                Text(emailLine)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AdminCommercePillStyle.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(memberLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AdminCommercePillStyle.primaryText.opacity(0.82))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                if isPiloting {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AdminCommercePillStyle.secondaryText)
            }
            .layoutPriority(1)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(AdminCommercePillStyle.fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(AdminCommercePillStyle.stroke, lineWidth: 1)
        )
        .scaleEffect(isLongPressing ? 0.94 : 1)
        .brightness(isLongPressing ? 0.06 : 0)
        .animation(.spring(response: 0.34, dampingFraction: 0.68), value: isLongPressing)
        .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .onTapGesture {
            guard !isPiloting else { return }
            onPilot()
        }
        .onLongPressGesture(minimumDuration: 0.42, maximumDistance: 14, pressing: { pressing in
            withAnimation(.spring(response: 0.34, dampingFraction: 0.68)) {
                isLongPressing = pressing
            }
            if pressing {
                MerchantUXFeedback.shared.playSelection()
            }
        }, perform: {
            longPressHapticTick += 1
            MerchantUXFeedback.shared.play(.tap)
            onOpenSettings()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                isLongPressing = false
            }
        })
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.85), trigger: longPressHapticTick)
        .accessibilityHint("Appui court pour piloter. Appui long pour la fiche et les réglages.")
    }

    private var emailLine: String {
        let em = business.ownerEmail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !em.isEmpty { return em }
        return "E-mail non renseigné"
    }

    private var memberLabel: String {
        let n = max(0, business.memberCount ?? 0)
        return n == 1 ? "1 membre" : "\(n) membres"
    }
}

// MARK: - Logo commerce

private struct AdminCommerceLogoDisc: View {
    let business: AdminBusinessRow
    let size: CGFloat
    var showsActiveSubscriptionRing: Bool = false

    @State private var image: UIImage?
    @State private var loadGeneration = 0

    private var candidates: [URL] {
        AdminBusinessMediaURL.logoLoadCandidates(for: business)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(AdminCommercePillStyle.iconDisc)
                .frame(width: size, height: size)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size - 4, height: size - 4)
                    .clipShape(Circle())
            } else {
                Image(systemName: "storefront.fill")
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundStyle(AdminCommercePillStyle.primaryText.opacity(0.5))
            }
        }
        .frame(width: size, height: size)
        .overlay {
            if showsActiveSubscriptionRing {
                Circle()
                    .strokeBorder(AdminCommercePillStyle.activeLogoRing.opacity(0.92), lineWidth: 2.5)
                    .frame(width: size + 5, height: size + 5)
            }
        }
        .accessibilityLabel(showsActiveSubscriptionRing ? "Abonnement actif" : "Logo commerce")
        .task(id: business.slug) {
            await loadFirstAvailableLogo()
        }
    }

    @MainActor
    private func loadFirstAvailableLogo() async {
        loadGeneration += 1
        let generation = loadGeneration
        image = nil
        guard AuthStorage.authToken?.isEmpty == false else { return }

        for url in candidates {
            if let cached = AuthenticatedMediaLoader.memoryCachedImage(for: url, maxPixelDimension: 160) {
                image = cached
                return
            }
            do {
                let img = try await AuthenticatedMediaLoader.loadAuthenticatedImage(from: url, maxPixelDimension: 160)
                guard generation == loadGeneration else { return }
                image = img
                return
            } catch {
                continue
            }
        }
    }
}

// MARK: - Fiche commerce

private struct PlatformAdminCommerceDetailPage: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    let business: AdminBusinessRow

    @State private var isPiloting = false
    @State private var showDeleteSheet = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    AdminCommerceLogoDisc(business: business, size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(business.displayName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text(business.slug)
                            .font(.caption.monospaced())
                            .foregroundStyle(AppTheme.Colors.primary)
                    }
                    Spacer(minLength: 0)
                }

                detailBlock("Propriétaire", rows: [
                    ("E-mail", business.ownerEmail ?? "—"),
                    ("Abonnement", (business.ownerSubscriptionStatus ?? "—").replacingOccurrences(of: "_", with: " ")),
                ])

                detailBlock("Activité", rows: [
                    ("Membres", "\(business.memberCount ?? 0)"),
                    ("Créé le", business.createdAt ?? "—"),
                ])

                Button {
                    guard !isPiloting else { return }
                    isPiloting = true
                    authService.selectBusiness(slug: business.slug, showSwitchingOverlay: false)
                    Task {
                        await authService.openMerchantWorkspaceFromAdmin(preferredSlug: business.slug)
                        isPiloting = false
                    }
                } label: {
                    Group {
                        if isPiloting {
                            ProgressView().tint(.white).frame(maxWidth: .infinity)
                        } else {
                            Label("Piloter", systemImage: "arrow.right.circle.fill")
                                .font(.headline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Suppression définitive")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.error)
                    Button(role: .destructive) {
                        deleteError = nil
                        showDeleteSheet = true
                    } label: {
                        Label("Supprimer ce commerce", systemImage: "trash.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(14)
                .background(AppTheme.Colors.error.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(16)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDeleteSheet) {
            AdminDeleteCommerceSheet(
                business: business,
                isDeleting: isDeleting,
                errorMessage: deleteError,
                onCancel: { showDeleteSheet = false },
                onConfirm: { Task { await deleteCommerce() } }
            )
        }
    }

    private func detailBlock(_ title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.0)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        Text(row.1)
                            .font(.body)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 12)
            .background(AppTheme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.Colors.shadow.opacity(0.12), radius: 6, x: 0, y: 2)
        }
    }

    @MainActor
    private func deleteCommerce() async {
        isDeleting = true
        deleteError = nil
        defer { isDeleting = false }
        do {
            let _: AdminDeleteSuccessResponse = try await APIClient.shared.request(
                .adminDeleteBusiness(businessId: business.id, body: .wipe)
            )
            authService.pruneAdminBusiness(id: business.id)
            showDeleteSheet = false
            dismiss()
        } catch {
            deleteError = APIError.merchantFacingMessage(from: error) ?? error.localizedDescription
        }
    }
}

// MARK: - Suppression commerce

private struct AdminDeleteCommerceSheet: View {
    let business: AdminBusinessRow
    let isDeleting: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                (Text("Suppression définitive de ") + Text(business.displayName).fontWeight(.semibold) + Text(". Irréversible : commerce, compte propriétaire (s’il n’a pas d’autre commerce), employés liés, membres, transactions, flyer et logos."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.error)
                }

                SlideToConfirm(config: SlideToConfirm.Config(
                    idleText: "Glisser pour supprimer",
                    onSwipeText: "Effacer \(business.slug)",
                    confirmationText: "Supprimé",
                    tint: AppTheme.Colors.error,
                    foregroundColor: .white,
                    disabled: isDeleting
                )) {
                    onConfirm()
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Supprimer le commerce")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", action: onCancel)
                        .disabled(isDeleting)
                }
            }
            .overlay {
                if isDeleting {
                    Color.black.opacity(0.12).ignoresSafeArea()
                    ProgressView("Suppression…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Création compte commerçant (parcours onboarding standard)

private struct AdminMerchantProvisioningFlowView: View {
    @EnvironmentObject private var authService: AuthService

    let onFinished: (String) -> Void
    let onCancelled: () -> Void

    var body: some View {
        MyfidpassMerchantOnboardingRootView(
            adminProvisioningMode: true,
            onComplete: {},
            onAdminProvisioningFinished: { email in
                let label = email?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? email!
                    : "commerçant"
                onFinished("Compte \(label) et commerce créés.")
            },
            onAdminProvisioningCancelled: {
                authService.cancelAdminMerchantProvisioning()
                onCancelled()
            }
        )
        .environmentObject(authService)
        .ignoresSafeArea()
    }
}
