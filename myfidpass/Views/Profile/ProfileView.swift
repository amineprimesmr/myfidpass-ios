//
//  ProfileView.swift
//  myfidpass
//
//  Onglet Commerce : statistiques (menu latéral = Accueil uniquement).
//

import SwiftUI
import CoreData

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: SyncService
    @EnvironmentObject private var tabRouter: MainTabRouter
    @Environment(\.merchantTabIsActive) private var merchantTabIsActive
    @Environment(\.isSoftwareKeyboardVisible) private var isSoftwareKeyboardVisible
    @EnvironmentObject private var dataService: DataService
    @State private var organizationName: String = ""
    @State private var settingsSnapshot: BusinessSettingsResponse?
    @State private var flyerLooksCustomized = false
    /// Alimentés par `GET …/dashboard/flyer` pour le bloc flyer (aperçu Commerce).
    @State private var commerceFlyerShareURL: String = ""
    @State private var commerceFlyerCustomBgDataURL: String?
    /// JSON embed base64 (même source que l’éditeur) pour miniature **composite** (QR, roue, textes), pas seulement le fond IA.
    @State private var commerceFlyerBootstrapPreviewB64: String?
    @State private var isLoadingProfileFromServer = false
    @State private var lastProfileServerLoadAt: Date?
    @State private var lastPassiveProfileServerLoadAt: Date?
    @State private var suspendProfileRefreshUntil: Date?
    @State private var mountCommerceStats = false
    @State private var preparedCommerceSlugForRender: String = ""
    @State private var didRunInitialCommerceServerLoad = false
    @State private var passiveProfileReloadTask: Task<Void, Never>?

    init() {
        /// Premier frame aligné sur le cache disque (évite le passage animé « Créer le flyer » → « Flyer prêt » à chaque arrivée sur Commerce).
        _flyerLooksCustomized = State(initialValue: Self.flyerLooksCustomizedFromDiskCacheIfAvailable())
    }

    private static func flyerLooksCustomizedFromDiskCacheIfAvailable() -> Bool {
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty,
              let cached = CommerceFlyerStateCache.load(slug: slug)
        else { return false }
        let hasBootstrap = !(cached.bootstrapPreviewB64 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasCustomBgFile = !(cached.customBgDataURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return cached.flyerRegistered || hasBootstrap || hasCustomBgFile
    }

    private var profilePalette: DashboardRevolutPalette {
        DashboardRevolutPalette(colorScheme: colorScheme)
    }

    private var profileCanvas: Color {
        profilePalette.canvas
    }

    private var activeCommerceSlugForRender: String {
        AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var body: some View {
        commerceNavigationStack
    }

    private var commerceNavigationStack: some View {
        NavigationStack {
            MerchantTabScaffold(
                panelBackground: profileCanvas,
                topBar: { commerceTopBar },
                panel: { commerceStatsPanel }
            )
            .overlay {
                if syncService.isSyncing && organizationName.isEmpty {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(AppTheme.Colors.primary)
                        Spacer()
                    }
                    .padding(.top, DashboardHomeMinimalTopBarLayout.scrollPanelTopOffset + 40)
                    .allowsHitTesting(false)
                }
            }
        }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                loadProfile()
                hydrateCommerceFromDiskCache()
                if merchantTabIsActive {
                    if !mountCommerceStats {
                        preparedCommerceSlugForRender = activeCommerceSlugForRender
                        mountCommerceStats = true
                    }
                }
                if !didRunInitialCommerceServerLoad {
                    didRunInitialCommerceServerLoad = true
                    Task {
                        try? await Task.sleep(nanoseconds: 900_000_000)
                        await loadProfileFromServer(passive: true)
                    }
                } else {
                    Task { await loadProfileFromServer(passive: true) }
                }
            }
            .onChange(of: flyerLooksCustomized) { _, _ in
                Task { await NotificationsService.shared.refreshMerchantCardSetupReminder() }
            }
            .onChange(of: merchantTabIsActive) { _, active in
                if active {
                    if !mountCommerceStats {
                        preparedCommerceSlugForRender = activeCommerceSlugForRender
                        mountCommerceStats = true
                    }
                    schedulePassiveProfileReload()
                } else {
                    passiveProfileReloadTask?.cancel()
                    passiveProfileReloadTask = nil
                }
            }
            .onChange(of: activeCommerceSlugForRender) { oldSlug, newSlug in
                guard oldSlug != newSlug else { return }
                settingsSnapshot = nil
                mountCommerceStats = false
                preparedCommerceSlugForRender = ""
                Task { @MainActor in
                    await Task.yield()
                    preparedCommerceSlugForRender = newSlug
                    if merchantTabIsActive {
                        mountCommerceStats = true
                    }
                    schedulePassiveProfileReload()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .myfidpassOpenMerchantStatistics)) { _ in
                if tabRouter.selectedTab != 2 {
                    tabRouter.selectedTab = 2
                }
            }
            .onDisappear {
                passiveProfileReloadTask?.cancel()
                passiveProfileReloadTask = nil
            }
    }

    @ViewBuilder
    private var commerceStatsPanel: some View {
        if mountCommerceStats,
           !authService.isBusinessSwitching,
           preparedCommerceSlugForRender == activeCommerceSlugForRender {
            MerchantStatisticsDashboardScreen(
                glassOverlayPresentation: false,
                onOverlayDismiss: {},
                showsInlineCloseButton: false,
                showsTopTitle: false,
                hidesTabBar: false
            )
            .id("commerce-stats-\(activeCommerceSlugForRender)")
            .environment(\.managedObjectContext, viewContext)
        } else {
            VStack(spacing: 10) {
                ProgressView()
                    .tint(AppTheme.Colors.primary)
                Text("Chargement des statistiques…")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(profilePalette.onCanvasSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 24)
        }
    }

    private var commerceTopBar: some View {
        DashboardHomeMinimalTopBar(
            title: "Statistiques",
            merchantName: organizationName.isEmpty ? "Mon commerce" : organizationName,
            accountEmail: authService.currentUserEmail ?? AuthStorage.userEmail,
            notificationIconURL: settingsSnapshot?.notificationIconUrl,
            hasNotificationIcon: hasCommerceNotificationIconConfigured,
            businesses: authService.businessesForMerchantSwitcher,
            activeBusinessSlug: AuthStorage.currentBusinessSlug,
            canCreateBusiness: authService.isPlatformAdmin ? false : authService.canCreateBusiness,
            isPlatformAdminAllCommercesMode: authService.isPlatformAdmin,
            onOpenAdministration: authService.isPlatformAdmin ? { authService.returnToPlatformAdministrationHub() } : nil,
            onBusinessSwitcherWillOpen: authService.isPlatformAdmin ? {
                Task { await authService.refreshPlatformAdminBusinesses(force: true) }
            } : nil,
            onSelectBusiness: { slug in
                settingsSnapshot = nil
                mountCommerceStats = false
                preparedCommerceSlugForRender = ""
                authService.selectBusiness(slug: slug)
                Task {
                    defer { authService.finishBusinessSwitch() }
                    await syncService.syncAfterServerMutation()
                    await loadProfileFromServer(force: true, passive: true)
                    await MainActor.run {
                        preparedCommerceSlugForRender = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        mountCommerceStats = true
                    }
                }
            },
            onAddCommerce: {
                NotificationCenter.default.post(name: .myfidpassOpenAddCommerceSheet, object: nil)
            },
            onUpgradeCommerceQuota: {
                NotificationCenter.default.postOpenMerchantSubscription(
                    usedBusinesses: authService.usedBusinesses,
                    allowedBusinesses: authService.allowedBusinesses,
                    addingAnotherCommerce: true
                )
            }
        )
    }

    private var hasCommerceNotificationIconConfigured: Bool {
        let raw = settingsSnapshot?.notificationIconUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !raw.isEmpty
    }

    private func prewarmCommerceNotificationIconIfPossible(for settings: BusinessSettingsResponse?) {
        let raw = settings?.notificationIconUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return }
        guard let url = APIResourceURL.resolved(from: raw) else { return }
        Task.detached(priority: .utility) {
            await AuthenticatedMediaLoader.prefetch(url: url)
        }
    }

    private func schedulePassiveProfileReload() {
        passiveProfileReloadTask?.cancel()
        passiveProfileReloadTask = Task {
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            await loadProfileFromServer(passive: true)
        }
    }

    private func engagementStepDone(from settings: BusinessSettingsResponse) -> Bool {
        guard let e = settings.engagementRewards else { return false }
        let googleOk = (e.googleReview?.enabled == true)
            && !(e.googleReview?.placeId ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if EngagementTemporaryVisibility.commerceEngagementGoogleOnly {
            return googleOk
        }
        let others: [EngagementChannelDTO?] = {
            if EngagementTemporaryVisibility.hideSecondaryReviewNetworks {
                return [e.instagramFollow, e.tiktokFollow, e.facebookFollow, e.youtubeFollow]
            }
            return [
                e.instagramFollow, e.tiktokFollow, e.facebookFollow,
                e.twitterFollow, e.snapchatFollow, e.linkedinFollow, e.youtubeFollow,
                e.trustpilotReview, e.tripadvisorReview,
            ]
        }()
        let otherOk = others.contains {
            ($0?.enabled == true) && !(($0?.url ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        return googleOk || otherOk
    }

    /// Réhydrate flyer + bootstrap + lien depuis le dernier GET réussi (affichage instantané sans flash).
    private func hydrateCommerceFromDiskCache() {
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else { return }
        CommerceFlyerStore.shared.hydrateFromDiskIfNeeded(slug: slug)
        guard let cached = CommerceFlyerStore.shared.snapshot(for: slug) else { return }
        let hasBootstrap = !(cached.bootstrapPreviewB64 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasCustomBgFile = !(cached.customBgDataURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        flyerLooksCustomized = cached.flyerRegistered || hasBootstrap || hasCustomBgFile
        commerceFlyerShareURL = cached.shareURL
        if let b = cached.bootstrapPreviewB64, !b.isEmpty {
            commerceFlyerBootstrapPreviewB64 = FlyerBootstrapPreviewPayloadBuilder.normalizeWheelModeInBootstrapBase64(b, businessSlug: slug) ?? b
        }
        commerceFlyerCustomBgDataURL = cached.customBgDataURL
        preparedCommerceSlugForRender = slug
    }

    private func loadProfile() {
        let business = dataService.createOrGetCurrentBusiness()
        let template = dataService.currentCardTemplate()
        organizationName = template?.displayName ?? business.name ?? "Mon établissement"
        if let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines),
           !slug.isEmpty,
           let cached = ScanFlowSettingsCache.cached(for: slug) {
            settingsSnapshot = cached
            prewarmCommerceNotificationIconIfPossible(for: cached)
        }
    }

    private func loadProfileFromServer(force: Bool = false, passive: Bool = false) async {
        if isLoadingProfileFromServer { return }
        if !force, let until = suspendProfileRefreshUntil, Date() < until { return }
        if !force, let last = lastProfileServerLoadAt, Date().timeIntervalSince(last) < 1.2 {
            return
        }
        if passive, !force, let lastPassive = lastPassiveProfileServerLoadAt, Date().timeIntervalSince(lastPassive) < 12 {
            return
        }
        guard let slug = AuthStorage.currentBusinessSlug else { return }
        isLoadingProfileFromServer = true
        defer { isLoadingProfileFromServer = false }
        do {
            async let settingsTask: BusinessSettingsResponse = APIClient.shared.request(APIEndpoint.businessSettings(slug: slug))
            async let flyerTask: DashboardFlyerGetResponse = APIClient.shared.request(APIEndpoint.dashboardFlyerGet(slug: slug))
            let (settings, flyer) = try await (settingsTask, flyerTask)
            await MainActor.run {
                settingsSnapshot = settings
                ScanFlowSettingsCache.store(settings, for: slug)
                prewarmCommerceNotificationIconIfPossible(for: settings)
                let cacheRegistered = CommerceFlyerStore.shared.snapshot(for: slug)?.flyerRegistered ?? false
                flyerLooksCustomized = flyer.commerceIndicatesFlyerRegistered || cacheRegistered
                let trimmedShare = (flyer.shareUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedShare.isEmpty {
                    commerceFlyerShareURL = LegalURLs.fidelityCardPage(slug: slug)?.absoluteString ?? ""
                } else {
                    commerceFlyerShareURL = trimmedShare
                }
                commerceFlyerCustomBgDataURL = flyer.flyerPrefs?.customBgDataUrl
                let priorBootstrapRaw = CommerceFlyerStore.shared.snapshot(for: slug)?.bootstrapPreviewB64
                    ?? CommerceFlyerStateCache.load(slug: slug)?.bootstrapPreviewB64
                let priorBootstrap = priorBootstrapRaw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let fallbackState: FlyerStateDTO? = priorBootstrap.isEmpty
                    ? nil
                    : FlyerBootstrapPreviewPayloadBuilder.flyerStateFromBootstrapBase64(priorBootstrap)
                var newBootstrapB64 = FlyerBootstrapPreviewPayloadBuilder.base64(
                    from: flyer,
                    businessSlug: slug,
                    fallbackStateIfMissing: fallbackState
                )
                if newBootstrapB64 == nil, !priorBootstrap.isEmpty {
                    newBootstrapB64 = priorBootstrap
                }
                if let built = newBootstrapB64?.trimmingCharacters(in: .whitespacesAndNewlines), !built.isEmpty,
                   let fb = fallbackState ?? FlyerBootstrapPreviewPayloadBuilder.flyerStateFromBootstrapBase64(built)
                {
                    let repaired = FlyerBootstrapPreviewPayloadBuilder.repairBootstrapBase64IfSparseFlyerState(
                        built,
                        resolvedState: fb,
                        businessSlug: slug
                    )
                    newBootstrapB64 = repaired
                }
                commerceFlyerBootstrapPreviewB64 = newBootstrapB64
                let engagement = engagementStepDone(from: settings)
                CommerceFlyerStateCache.save(
                    slug: slug,
                    flyerRegistered: flyerLooksCustomized,
                    shareURL: commerceFlyerShareURL,
                    bootstrapB64: commerceFlyerBootstrapPreviewB64,
                    engagementStepDone: engagement,
                    customBgDataURL: commerceFlyerCustomBgDataURL,
                    revisionKey: flyer.updatedAt
                )
                CommerceFlyerStore.shared.upsert(
                    slug: slug,
                    snapshot: .init(
                        flyerRegistered: flyerLooksCustomized,
                        shareURL: commerceFlyerShareURL,
                        bootstrapPreviewB64: commerceFlyerBootstrapPreviewB64,
                        customBgDataURL: commerceFlyerCustomBgDataURL,
                        revisionKey: flyer.updatedAt
                    )
                )
                CommerceFlyerPublicBackgroundWarmup.prefetchFromNetworkIfNoCustomBgInPrefs(
                    slug: slug,
                    customBgDataUrl: flyer.flyerPrefs?.customBgDataUrl,
                    revisionKey: flyer.updatedAt
                )
                MerchantLogoAssetCache.applyMerchantLogoTimestamps(from: settings)
                CampaignNotificationImageCache.applyPreviewTimestamps(from: settings, slug: slug)
                if let name = settings.organizationName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    organizationName = name
                    if let t = dataService.currentCardTemplate() {
                        t.displayName = name
                    }
                }
                let b = dataService.createOrGetCurrentBusiness()
                if let name = settings.organizationName, !name.isEmpty { b.name = name }
                let tpl = dataService.currentCardTemplate()
                if let u = settings.logoUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty {
                    let cur = tpl?.logoURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !CardLogoStorage.isLocalPendingLogoReference(cur) {
                        tpl?.logoURL = u
                    }
                }
                if let u = settings.logoIconUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty {
                    let cur = tpl?.logoIconURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !CardLogoStorage.isLocalPendingLogoIconReference(cur) {
                        tpl?.logoIconURL = u
                    }
                }
                try? viewContext.save()
                loadProfile()
                preparedCommerceSlugForRender = slug
                lastProfileServerLoadAt = Date()
                if passive && !force {
                    lastPassiveProfileServerLoadAt = Date()
                }
            }
        } catch {}
    }
}

private extension View {
    /// Carte section onglet Commerce — variante Google avec léger accent couleur primaire.
    func commerceTabSectionCard(emphasizePrimaryAccent: Bool) -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.background.opacity(emphasizePrimaryAccent ? 0.62 : 0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        emphasizePrimaryAccent
                            ? AppTheme.Colors.primary.opacity(0.22)
                            : AppTheme.Colors.textSecondary.opacity(0.14),
                        lineWidth: 1
                    )
            )
    }
}

#Preview {
    let container = PersistenceController.preview.container
    ProfileView()
        .environmentObject(DataService(context: container.viewContext))
        .environmentObject(AuthService())
        .environmentObject(SyncService(container: container))
        .environmentObject(MainTabRouter())
}
