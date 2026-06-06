//
//  DashboardView.swift
//  myfidpass
//
//  Accueil commerçant : carte fidélité, historique des transactions ;
//  scan QR et accès programme (flyer) via Réglages.
//

import SwiftUI
import CoreData
import UIKit

enum DashboardRoute: Hashable {
    /// Hub unifié membres + activité (filtre initial selon l’entrée tableau de bord).
    case membersActivity(MemberActivityFilter)
    /// Fiche membre depuis une ligne d’activité (dernières transactions).
    case memberDetail(NSManagedObjectID)
}

private enum HomeMyCardZoom {
    /// Source = aperçu carte sur l’accueil (iOS 18+ zoom vers `MyCardView`).
    static let previewSourceID = "dashboard.home.mycard.preview"
}

// MARK: - Accueil : chrome partiel

private enum DashboardHomeChrome {
    /// Barre profil + scanner au-dessus de la carte : désactivée (profil = onglet du bas, scanner = bouton « Dernières transactions »).
    static let showMinimalTopBar = true
}

/// Placeholder « carte vide » (forme Wallet horizontale) — évite tout raster confondu avec le flyer.
private struct DashboardHomeSetupEmptyCardPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.98, blue: 1.0),
                        Color(red: 0.90, green: 0.92, blue: 0.96),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(1.78, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        Color(red: 0.72, green: 0.76, blue: 0.86).opacity(0.55),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
            )
            .overlay {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color(red: 0.52, green: 0.58, blue: 0.72).opacity(0.5))
            }
    }
}

private struct DashboardSetupHeroCarousel: View {
    /// Formats cibles : carte fidélité = format **ISO ID-1** (85,6 × 53,98 mm) ; flyer = **9:16** portrait (aperçu téléphone / affiche).
    enum HeroVisualKind: Equatable {
        case loyaltyCardIsoId1
        case flyerPortrait9x16
    }

    let kind: HeroVisualKind
    let imageNames: [String]
    var fallbackImage: UIImage? = nil

    /// Cadre contenu (avant rotation / éventail). Les assets `cartefid*` sont des visuels **portrait 9:16** pour le carrousel « Créez votre carte ».
    private var heroSlotSize: CGSize {
        switch kind {
        case .loyaltyCardIsoId1:
            let w: CGFloat = 86
            let h = w * (16.0 / 9.0)
            return CGSize(width: w, height: h)
        case .flyerPortrait9x16:
            let h: CGFloat = 140
            let w = h * (9.0 / 16.0)
            return CGSize(width: w, height: h)
        }
    }

    /// Zone d’empilement : un peu plus large que la carte la plus large pour l’effet en éventail.
    private var stackViewport: CGSize {
        let slot = heroSlotSize
        switch kind {
        case .loyaltyCardIsoId1:
            return CGSize(width: max(148, slot.width + 28), height: max(168, slot.height + 24))
        case .flyerPortrait9x16:
            return CGSize(width: max(118, slot.width + 36), height: max(158, slot.height + 22))
        }
    }

    var body: some View {
        let slot = heroSlotSize
        let viewport = stackViewport
        TimelineView(.periodic(from: .now, by: 2.7)) { timeline in
            let count = max(imageNames.count, 1)
            let tick = Int(timeline.date.timeIntervalSinceReferenceDate / 2.7)
            let active = ((tick % count) + count) % count

            ZStack {
                ForEach(imageNames.indices, id: \.self) { index in
                    let rank = ((index - active) % count + count) % count
                    carouselCard(for: imageNames[index])
                        .frame(width: slot.width, height: slot.height)
                        .clipShape(RoundedRectangle(cornerRadius: heroClipCornerRadius, style: .continuous))
                        .shadow(color: .black.opacity(0.38), radius: 14, y: 8)
                        .scaleEffect(rank == 0 ? 1.0 : (rank == 1 ? 0.94 : 0.89))
                        .rotationEffect(.degrees(fanRotationDegrees(rank: rank)))
                        .offset(x: fanOffsetX(rank: rank), y: fanOffsetY(rank: rank))
                        .opacity(rank == 0 ? 1.0 : (rank == 1 ? 0.88 : 0.72))
                        .zIndex(Double(100 - rank))
                        .animation(.spring(response: 0.44, dampingFraction: 0.9), value: active)
                }
            }
            .frame(width: viewport.width, height: viewport.height, alignment: .center)
        }
    }

    /// Flyer : coins plus francs ; carte : léger arrondi (visuels portrait).
    private var heroClipCornerRadius: CGFloat {
        switch kind {
        case .flyerPortrait9x16: return 10
        case .loyaltyCardIsoId1: return 14
        }
    }

    private func fanRotationDegrees(rank: Int) -> Double {
        switch kind {
        case .loyaltyCardIsoId1:
            return rank == 0 ? -4 : (rank == 1 ? 6 : 10)
        case .flyerPortrait9x16:
            return rank == 0 ? -3 : (rank == 1 ? 5 : 8)
        }
    }

    private func fanOffsetX(rank: Int) -> CGFloat {
        switch kind {
        case .loyaltyCardIsoId1:
            return rank == 0 ? 0 : (rank == 1 ? 20 : 36)
        case .flyerPortrait9x16:
            return rank == 0 ? 0 : (rank == 1 ? 10 : 20)
        }
    }

    private func fanOffsetY(rank: Int) -> CGFloat {
        switch kind {
        case .loyaltyCardIsoId1:
            return rank == 0 ? 0 : (rank == 1 ? -4 : -7)
        case .flyerPortrait9x16:
            return rank == 0 ? 0 : (rank == 1 ? -3 : -5)
        }
    }

    @ViewBuilder
    private func carouselCard(for name: String) -> some View {
        if let ui = UIImage(named: name) {
            Image(uiImage: ui)
                .resizable()
                .aspectRatio(contentMode: kind == .loyaltyCardIsoId1 ? .fit : .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    kind == .loyaltyCardIsoId1
                        ? Color.black.opacity(0.2)
                        : Color.clear
                )
        } else if let fallbackImage {
            Image(uiImage: fallbackImage)
                .resizable()
                .aspectRatio(contentMode: kind == .loyaltyCardIsoId1 ? .fit : .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.17, green: 0.24, blue: 0.35),
                    Color(red: 0.09, green: 0.13, blue: 0.2),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct HomeSetupGlassButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.14, green: 0.15, blue: 0.18),
                        Color(red: 0.05, green: 0.06, blue: 0.08),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: Capsule(style: .continuous)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.46), lineWidth: 1.35)
            )
            .shadow(color: .black.opacity(0.28), radius: 8, y: 3)
    }
}

private struct MerchantHomeFlyerPromoSheetContext: Identifiable, Equatable {
    let id = UUID()
    let businessSlug: String

    static func == (lhs: MerchantHomeFlyerPromoSheetContext, rhs: MerchantHomeFlyerPromoSheetContext) -> Bool {
        lhs.id == rhs.id && lhs.businessSlug == rhs.businessSlug
    }
}

struct DashboardView: View {
    private let homeTopPreviewCardHeight: CGFloat = 152
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var tabRouter: MainTabRouter
    @Environment(\.merchantTabIsActive) private var merchantTabIsActive
    @EnvironmentObject private var authService: AuthService
    @Environment(\.merchantWorkspaceMode) private var merchantWorkspaceMode
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var dataService: DataService

    @State private var showScanner: Bool = false
    @State private var showToast: Bool = false
    @State private var successToast: Toast = .example1
    @State private var scanError: String?
    @State private var navigationPath = NavigationPath()
    @Namespace private var homeMyCardZoomNamespace
    @State private var showMyCardFullScreen = false
    @State private var showHomeFlyerHubFullScreen = false
    @State private var homeFlyerHubOpenedForEdit = false
    /// Checklist « Créer le flyer » : ouvrir l’assistant création, pas l’aperçu « Votre flyer » (cache brouillon).
    @State private var homeFlyerHubStartCreateAssistant = false
    @State private var scanResultSheet: ScanResultSheetData?
    @State private var scanStampSheet: ScanStampSheetData?
    @State private var scanRewardRedeemSheet: ScanRewardRedeemSheetData?
    @State private var isScanAmountSubmitting = false
    @State private var isStampVisitSubmitting = false
    @StateObject private var receiptCoordinator = ReceiptValidationCoordinator()
    /// Incrémenté quand `CardPreviewDisplaySnapshotStore` change pour forcer le re-rendu de l’aperçu carte (autre `DataService` que Ma carte).
    @State private var cardPreviewDisplayRefresh = 0
    @State private var homeFlyerAvailable = false
    @State private var homeFlyerBootstrapB64: String?
    @State private var homeFlyerShareURL: String = ""
    @State private var homeFlyerCustomBgDataURL: String?
    @State private var homeFlyerUnderlayUIImage: UIImage?
    @State private var homeFlyerCompositeSnapshot: UIImage?
    /// Miniature « Ma carte » pour la tuile « Finalisez votre lancement » (remplace le placeholder une fois la carte prête).
    @State private var homeCardSetupThumbnail: UIImage?
    @State private var cachedFlyerUnderlayState: FlyerStateDTO = FlyerStateDTO.default
    @State private var homeHasNotificationIconConfigured = false
    @State private var homeNotificationIconURL: String?
    @State private var homeNotificationIconLastCheckAt: Date?
    @State private var homeNotificationIconRefreshInFlight = false
    @State private var homeNotificationIconLastSlug: String?
    @State private var homeSetupStateResolved = false
    /// Une fois `true` après avoir ouvert « Ma carte » depuis l’aperçu accueil — arrête pulse sur l’aperçu.
    @AppStorage("myfidpass.merchantHomeCardOpenedFromHome.v1") private var merchantHomeCardOpenedFromHome = false
    /// Feuille « Créer le flyer » tant que pas de flyer enregistré — à la réouverture de l’app + file post « Ma carte ».
    @State private var merchantHomeFlyerPromoPresentation: MerchantHomeFlyerPromoSheetContext?
    @State private var merchantFlyerPromoQueuedPresentationWorkItem: DispatchWorkItem?
    @State private var postScanSyncDebounceTask: Task<Void, Never>?
    @State private var isHomeSidebarExpanded = false
    @State private var homeSidebarPresentationPending = false
    @State private var homeSettingsSafariURL: URL?
    @State private var showHomeMatchPredictionsSheet = false
    /// Évite de marquer « fermé pour la session » quand on ouvre l’éditeur flyer depuis le CTA.
    @State private var skipFlyerPromoSuppressOnDismiss = false
    private var palette: DashboardRevolutPalette { DashboardRevolutPalette(colorScheme: colorScheme) }

    private var activityPreview: [DashboardActivityEntry] {
        dataService.dashboardActivityPreview(limit: 8, includeNewCardEvents: false)
    }

    /// Relance le polling accueil quand onglet actif, retour à la racine navigation, ou retour premier plan.
    private var homeActivityLiveSyncTaskKey: String {
        let slug = currentBusinessSlug ?? ""
        return "\(slug)|\(merchantTabIsActive)|\(navigationPath.count)|\(scenePhase)"
    }

    private static let homeActivityPollIntervalSeconds: UInt64 = 25

    private var currentBusinessSlug: String? {
        let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return slug.isEmpty ? nil : slug
    }

    /// Titre fixe à gauche (aligné Notifications / Commerce).
    private var dashboardTopBarTitle: String { "Accueil" }

    private var dashboardTopBarMerchantName: String {
        let businessName = dataService.currentBusiness()?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return businessName.isEmpty ? "Mon commerce" : businessName
    }

    private var homeCardConfigured: Bool {
        guard let slug = currentBusinessSlug else { return false }
        return CardPreviewDisplaySnapshotStore.isMerchantCardConfigured(slug: slug)
    }

    /// Détection "mission carte faite" plus tolérante : si un snapshot carte existe déjà,
    /// on considère la mission démarrée/faite pour masquer le bloc onboarding accueil.
    private var homeCardMissionDone: Bool {
        guard let slug = currentBusinessSlug else { return false }
        return CardPreviewDisplaySnapshotStore.load(slug: slug) != nil
    }

    private var shouldShowSimpleHomeSetup: Bool {
        // Désactivation temporaire demandée du mode "Finalisez votre lancement".
        false
    }

    private var isHomeSetupMode: Bool {
        shouldShowSimpleHomeSetup
    }

    private var showHomeCardSetupOverlay: Bool {
        isHomeSetupMode && !homeCardConfigured
    }

    /// Type de programme fidélité pour l’accueil (snapshot « Ma carte », défaut tampons).
    private var homeProgramIsPoints: Bool {
        let slug = AuthStorage.currentBusinessSlug ?? ""
        let raw = slug.isEmpty ? nil : CardPreviewDisplaySnapshotStore.load(slug: slug)?.programType
        return (raw ?? "points").lowercased() == "points"
    }

    /// Contenu principal de l’accueil (ZStack + modificateurs navigation / scan).
    @ViewBuilder
    private var dashboardHomeRoot: some View {
        MerchantTabScaffold(
            panelBackground: palette.canvas,
            topBar: {
                if DashboardHomeChrome.showMinimalTopBar {
                    DashboardHomeMinimalTopBar(
                        title: dashboardTopBarTitle,
                        merchantName: dashboardTopBarMerchantName,
                        accountEmail: authService.currentUserEmail ?? AuthStorage.userEmail,
                        notificationIconURL: homeNotificationIconURL,
                        hasNotificationIcon: homeHasNotificationIconConfigured,
                        businesses: authService.businessesForMerchantSwitcher,
                        activeBusinessSlug: AuthStorage.currentBusinessSlug,
                        canCreateBusiness: authService.isPlatformAdmin ? false : authService.canCreateBusiness,
                        isPlatformAdminAllCommercesMode: authService.isPlatformAdmin,
                        onOpenAdministration: authService.isPlatformAdmin ? { authService.returnToPlatformAdministrationHub() } : nil,
                        onBusinessSwitcherWillOpen: authService.isPlatformAdmin ? {
                            Task { await authService.refreshPlatformAdminBusinesses(force: true) }
                        } : nil,
                        onOpenSideMenu: {
                            openHomeSidebar(animated: true)
                        },
                        onSelectBusiness: { slug in
                            authService.selectBusiness(slug: slug)
                            homeHasNotificationIconConfigured = false
                            homeNotificationIconURL = nil
                            homeNotificationIconLastCheckAt = nil
                            homeNotificationIconLastSlug = nil
                            refreshHomeFlyerAvailability()
                            Task {
                                defer { authService.finishBusinessSwitch() }
                                await syncService.syncIfNeeded(force: true)
                                await refreshHomeNotificationIconStatusIfNeeded(force: true)
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
            },
            panel: {
                ZStack(alignment: .top) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            employeeOrOwnerHomeContent
                        }
                        .padding(.horizontal, DashboardHomeLayoutMetrics.scrollHorizontalPadding)
                        .padding(.top, 0)
                        .padding(.bottom, 100)
                    }
                    .scrollIndicators(.hidden)
                    .refreshable {
                        await syncService.syncIfNeeded(force: true)
                    }

                    syncOverlay
                }
            }
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: DashboardRoute.self) { route in
            switch route {
            case .membersActivity(let initialFilter):
                DashboardActivityFullView(context: viewContext, initialFilter: initialFilter)
                    .environmentObject(syncService)
            case .memberDetail(let oid):
                if let card = viewContext.object(with: oid) as? ClientCard {
                    MemberDetailView(card: card, context: viewContext)
                        .environmentObject(syncService)
                        .environmentObject(dataService)
                } else {
                    ContentUnavailableView(
                        "Membre introuvable",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("Cette fiche n’est plus disponible.")
                    )
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassOpenHomeScanner)) { _ in
            navigationPath = NavigationPath()
            showMyCardFullScreen = false
            showScanner = true
        }
        .qrScanner(isScanning: $showScanner) { code in
            handleQRScanned(code)
        }
        .dynamicIslandToast(isPresented: $showToast, value: successToast)
        .alert("Erreur scan", isPresented: .constant(scanError != nil)) {
            Button("OK") { scanError = nil }
        } message: {
            if let msg = scanError { Text(msg) }
        }
    }

    var body: some View {
        Group {
            if merchantTabIsActive {
                let _ = dataService.updateTrigger
                applyDashboardPresentations(to: applyDashboardListeners(to: dashboardSideMenuShell))
            } else {
                applyDashboardPresentations(to: applyDashboardListeners(to: dashboardSideMenuShell))
            }
        }
    }

    /// Sync différée après scan / tampon (évite N sync complètes en rafale).
    private func scheduleDebouncedPostScanSync() {
        postScanSyncDebounceTask?.cancel()
        postScanSyncDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            await syncService.syncIfNeeded(force: true)
        }
    }

    private var dashboardSideMenuShell: some View {
        let menuEnabled = navigationPath.isEmpty

        return CustomSideMenu(
            isEnabled: menuEnabled,
            slidingPanelFill: palette.canvas,
            isExpanded: $isHomeSidebarExpanded
        ) { _ in
            XStyleSettingsSideBar(
                isExpanded: $isHomeSidebarExpanded,
                path: $navigationPath,
                notificationIconURL: homeNotificationIconURL,
                hasNotificationIcon: homeHasNotificationIconConfigured,
                onOpenFlyer: openFlyerHubFromHomeSidebar,
                onOpenFootballGame: openFootballGameFromHomeSidebar,
                onOpenLiveGame: openTestGameFromHomeSidebar
            )
            .environmentObject(authService)
        } content: { _ in
            NavigationStack(path: $navigationPath) {
                dashboardHomeRoot
                    .navigationDestination(for: SettingsSideRoute.self) { route in
                        homeSettingsSideDestination(route)
                    }
            }
        }
        .background {
            if isHomeSidebarExpanded {
                Color.black
                    .ignoresSafeArea()
            }
        }
        .background(alignment: .bottom) {
            Group {
                if isHomeSidebarExpanded {
                    Color.black
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    palette.canvas
                        .ignoresSafeArea(edges: .bottom)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassCloseGlobalSettingsSheet)) { _ in
            closeHomeSidebar(resetNavigation: true)
        }
        .onChange(of: tabRouter.pendingHomeSidebarOpen) { _, shouldOpen in
            guard shouldOpen else { return }
            tabRouter.pendingHomeSidebarOpen = false
            openHomeSidebar(animated: true)
        }
        .toolbar(hidesHomeTabBar ? .hidden : .visible, for: .tabBar)
    }

    private var hidesHomeTabBar: Bool {
        isHomeSidebarExpanded
            || homeSidebarPresentationPending
            || !navigationPath.isEmpty
    }

    @ViewBuilder
    private func homeSettingsSideDestination(_ route: SettingsSideRoute) -> some View {
        switch route {
        case .settings:
            MerchantHomeMenuSettingsView()
                .environmentObject(authService)
                .environmentObject(syncService)
                .environment(\.managedObjectContext, viewContext)
                .toolbar(.visible, for: .navigationBar)
        }
    }

    private func openHomeSidebar(animated: Bool) {
        if tabRouter.selectedTab != 0 {
            tabRouter.selectedTab = 0
        }
        if animated {
            withAnimation(MerchantMotion.sidebar) {
                isHomeSidebarExpanded = true
            }
        } else {
            isHomeSidebarExpanded = true
        }
    }

    private func closeHomeSidebar(resetNavigation: Bool) {
        withAnimation(MerchantMotion.sidebar) {
            isHomeSidebarExpanded = false
            if resetNavigation {
                navigationPath = NavigationPath()
            }
        }
    }

    private func syncDashboardAtRootState() {
        tabRouter.isDashboardAtRoot = navigationPath.isEmpty
            && !showMyCardFullScreen
            && !showHomeFlyerHubFullScreen
    }

    /// Ferme le menu latéral puis exécute l’action — le fullScreenCover recouvre la sidebar : pas d’attente animation.
    private func runAfterHomeSidebarDismisses(_ action: @escaping () -> Void) {
        if isHomeSidebarExpanded {
            homeSidebarPresentationPending = true
            withAnimation(MerchantMotion.sidebar) {
                isHomeSidebarExpanded = false
            }
        }
        action()
        DispatchQueue.main.async {
            homeSidebarPresentationPending = false
        }
    }

    private func openFlyerHubFromHomeSidebar() {
        runAfterHomeSidebarDismisses {
            openFlyerHubFromHome(forEdit: false, startCreateAssistant: false)
        }
    }

    private func openTestGameFromHomeSidebar() {
        guard let slug = currentBusinessSlug,
              let url = LegalURLs.fidelityCardPage(slug: slug) else { return }
        runAfterHomeSidebarDismisses {
            homeSettingsSafariURL = url
        }
    }

    private func openFootballGameFromHomeSidebar() {
        guard currentBusinessSlug != nil else { return }
        runAfterHomeSidebarDismisses {
            showHomeMatchPredictionsSheet = true
        }
    }

    private func applyDashboardListeners<V: View>(to content: V) -> some View {
        applyDashboardListenersPhase2(to: applyDashboardListenersPhase1(to: content))
    }

    private func applyDashboardListenersPhase1<V: View>(to content: V) -> some View {
        content
            .onChange(of: navigationPath) { _, _ in
                syncDashboardAtRootState()
            }
            .onChange(of: isHomeSidebarExpanded) { _, expanded in
                tabRouter.isHomeSidebarExpanded = expanded
            }
            .onChange(of: merchantTabIsActive) { _, active in
                if !active {
                    merchantFlyerPromoQueuedPresentationWorkItem?.cancel()
                    merchantFlyerPromoQueuedPresentationWorkItem = nil
                    return
                }
                refreshHomeFlyerAvailability()
                Task { await refreshHomeNotificationIconStatusIfNeeded() }
            }
            .onAppear {
                syncDashboardAtRootState()
                tabRouter.isHomeSidebarExpanded = isHomeSidebarExpanded
                tabRouter.isDashboardSetupMode = isHomeSetupMode
                tabRouter.hasResolvedDashboardSetupMode = true
                refreshHomeFlyerAvailability()
                Task { await refreshHomeNotificationIconStatusIfNeeded() }
                scheduleMerchantFlyerPromoSheetIfEligible()
            }
            .onDisappear {
                tabRouter.isDashboardSetupMode = false
                tabRouter.hasResolvedDashboardSetupMode = false
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background {
                    PostCardFlyerPromoEligibility.resetSessionSuppressionForAppOpen()
                }
                if newPhase == .active && oldPhase == .background {
                    scheduleMerchantFlyerPromoSheetIfEligible()
                }
            }
    }

    private func applyDashboardListenersPhase2<V: View>(to content: V) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .myfidpassCardPreviewDisplayDidChange)) { _ in
                cardPreviewDisplayRefresh += 1
                refreshHomeFlyerAvailability()
                scheduleMerchantFlyerPromoSheetIfEligible()
                Task { await prefetchHomeCardMediaIfNeeded() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .myfidpassMerchantCoreDataDidMergeFromSync)) { _ in
                if let slug = currentBusinessSlug {
                    CardPreviewDisplaySnapshotStore.reconcileFromSettingsCacheIfNeeded(slug: slug)
                }
                cardPreviewDisplayRefresh += 1
            }
            .onReceive(NotificationCenter.default.publisher(for: .myfidpassOpenMerchantFlyerHub)) { note in
                handleOpenMerchantFlyerHubNotification(note)
            }
            .onReceive(NotificationCenter.default.publisher(for: .myfidpassOpenHomeMyCardFullScreen)) { _ in
                showMyCardFullScreen = true
            }
            .onChange(of: showMyCardFullScreen) { _, isOpen in
                syncDashboardAtRootState()
                if !isOpen {
                    refreshHomeCardSetupThumbnail()
                    Task { await prefetchHomeCardMediaIfNeeded() }
                    if PostCardFlyerPromoEligibility.hasQueuedPendingMerchantHomeSlug() {
                        scheduleMerchantFlyerPromoSheetIfEligible()
                    }
                }
            }
            .onChange(of: merchantHomeFlyerPromoPresentation) { old, new in
                guard let previous = old, new == nil else { return }
                if skipFlyerPromoSuppressOnDismiss {
                    skipFlyerPromoSuppressOnDismiss = false
                    return
                }
                if PostCardFlyerPromoEligibility.stillNeedsFlyerPromo(for: previous.businessSlug) {
                    PostCardFlyerPromoEligibility.markDismissedWithoutCompletingFlyer()
                }
            }
            .onChange(of: currentBusinessSlug) { _, _ in
                homeHasNotificationIconConfigured = false
                homeNotificationIconURL = nil
                homeNotificationIconLastCheckAt = nil
                homeNotificationIconLastSlug = nil
                refreshHomeFlyerAvailability()
                Task { await refreshHomeNotificationIconStatusIfNeeded(force: true) }
            }
            .onChange(of: isHomeSetupMode) { _, newValue in
                tabRouter.isDashboardSetupMode = newValue
            }
            .onChange(of: homeFlyerBootstrapB64) { _, newB64 in
                applyHomeFlyerBootstrapB64Change(newB64)
            }
            .onChange(of: showHomeFlyerHubFullScreen) { _, isPresented in
                syncDashboardAtRootState()
                if !isPresented {
                    homeFlyerHubStartCreateAssistant = false
                    refreshHomeFlyerAvailability()
                }
            }
    }

    private func applyHomeFlyerBootstrapB64Change(_ newB64: String?) {
        let raw = newB64?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !raw.isEmpty, let parsed = FlyerBootstrapPreviewPayloadBuilder.flyerStateFromBootstrapBase64(raw) {
            cachedFlyerUnderlayState = parsed
        } else {
            var d = FlyerStateDTO.default
            d.normalizeClamps()
            cachedFlyerUnderlayState = d
        }
    }

    private func handleOpenMerchantFlyerHubNotification(_ note: Notification) {
        let startCreate = Self.flyerHubStartCreateAssistant(from: note)
        openFlyerHubFromHome(forEdit: false, startCreateAssistant: startCreate)
    }

    private func applyDashboardPresentations<V: View>(to content: V) -> some View {
        applyDashboardFullScreenCovers(to: applyDashboardSheetPresentations(to: content))
    }

    private func applyDashboardSheetPresentations<V: View>(to content: V) -> some View {
        content
            .sheet(isPresented: Binding(
                get: { homeSettingsSafariURL != nil },
                set: { if !$0 { homeSettingsSafariURL = nil } }
            )) {
                if let url = homeSettingsSafariURL {
                    InAppSafariView(url: url)
                        .ignoresSafeArea()
                }
            }
            .sheet(isPresented: $showHomeMatchPredictionsSheet) {
                if let slug = currentBusinessSlug {
                    MatchPredictionsSheet(slug: slug)
                }
            }
            .sheet(item: $merchantHomeFlyerPromoPresentation) { ctx in
                merchantHomeFlyerPromoSheet(ctx)
            }
            .fullScreenCover(item: $scanResultSheet) { data in
                scanAddPointsSheet(for: data)
            }
            .fullScreenCover(item: $scanStampSheet) { data in
                dashboardScanStampSheet(data)
            }
            .fullScreenCover(item: $scanRewardRedeemSheet) { data in
                RewardRedeemScanSheet(
                    data: data,
                    onDismiss: { scanRewardRedeemSheet = nil },
                    onRedeem: { await performRewardRedeemScan(data: data) }
                )
            }
    }

    private func applyDashboardFullScreenCovers<V: View>(to content: V) -> some View {
        content
            .fullScreenCover(isPresented: $showMyCardFullScreen) {
                dashboardMyCardFullScreen
            }
            .fullScreenCover(isPresented: $showHomeFlyerHubFullScreen) {
                dashboardHomeFlyerHubFullScreen
            }
    }

    @ViewBuilder
    private func merchantHomeFlyerPromoSheet(_ ctx: MerchantHomeFlyerPromoSheetContext) -> some View {
        PostCardFlyerPromoSheet(
            slug: ctx.businessSlug,
            isPresented: Binding(
                get: { merchantHomeFlyerPromoPresentation != nil },
                set: { if !$0 { merchantHomeFlyerPromoPresentation = nil } }
            ),
            onCreateFlyerTapped: {
                skipFlyerPromoSuppressOnDismiss = true
                merchantHomeFlyerPromoPresentation = nil
                openFlyerHubFromHome(forEdit: false, startCreateAssistant: true)
            }
        )
    }

    @ViewBuilder
    private func dashboardScanStampSheet(_ data: ScanStampSheetData) -> some View {
        AddStampVisitSheet(
            data: data,
            isSubmitting: $isStampVisitSubmitting,
            onDismiss: { scanStampSheet = nil },
            onStampVisitSuccess: { response in
                successToast = Toast.scanStampSuccess(
                    memberName: response.member?.name ?? data.memberName,
                    pointsCapped: response.pointsCapped == true,
                    pointsRequested: response.pointsRequested,
                    pointsAdded: response.pointsAdded,
                    stampCycleCompleted: response.stampCycleCompleted == true
                )
                showToast = true
            },
            onConfirm: {
                await submitStampVisit(slug: data.slug, barcode: data.barcode)
            },
            onGrantReward: {
                await grantStampRewardFromMerchantScan(data: data)
            }
        )
    }

    /// Carte tampons pleine après scan Wallet : ouvre la validation récompense ou valide directement.
    private func grantStampRewardFromMerchantScan(data: ScanStampSheetData) async -> String? {
        let slug = data.slug
        let memberId = data.barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !memberId.isEmpty else { return "Identifiant client manquant." }
        let redeemBarcode = RewardRedeemQRPayload.fullCardBarcode(memberId: memberId)
        do {
            let lookup: ScanLookupResponse = try await APIClient.shared.request(
                .scanLookup(slug: slug, barcode: redeemBarcode)
            )
            let memberName = lookup.member.name ?? data.memberName
            if let sheetData = ScanRewardRedeemSheetDataBuilder.make(
                slug: slug,
                barcode: redeemBarcode,
                memberName: memberName,
                memberId: lookup.member.id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? memberId,
                lookup: lookup
            ) {
                await MainActor.run {
                    scanStampSheet = nil
                    scanRewardRedeemSheet = sheetData
                }
                return nil
            }
            let response: IntegrationRewardRedeemResponse = try await APIClient.shared.request(
                .integrationRewardRedeem(slug: slug, barcode: redeemBarcode)
            )
            let label = response.rewardLabel ?? data.cardModel.stampRewardLabel
            let newP = response.newPoints ?? 0
            await MainActor.run {
                successToast = Toast(
                    symbol: "gift.fill",
                    symbolFont: .system(size: 32, weight: .semibold),
                    symbolForegroundStyle: (.white, Color(red: 1, green: 0.55, blue: 0.2)),
                    title: "Récompense validée",
                    message: "\(memberName) — \(label). Nouveau solde : \(newP) tampon\(newP > 1 ? "s" : "")."
                )
                showToast = true
            }
            scheduleDebouncedPostScanSync()
            return nil
        } catch {
            return APIError.merchantFacingMessage(from: error) ?? "Impossible d’accorder la récompense."
        }
    }

    @ViewBuilder
    private var dashboardMyCardFullScreen: some View {
        NavigationStack {
            MyCardView(context: viewContext)
                .environmentObject(syncService)
        }
        .environment(\.managedObjectContext, viewContext)
        .statsDetailZoomTransition(sourceID: HomeMyCardZoom.previewSourceID, namespace: homeMyCardZoomNamespace)
    }

    @ViewBuilder
    private var dashboardHomeFlyerHubFullScreen: some View {
        NavigationStack {
            MerchantProgramHubView(
                context: viewContext,
                seedOpenFlyerForEdit: homeFlyerHubOpenedForEdit,
                startInCreateFromEditBack: homeFlyerHubStartCreateAssistant,
                liveCommerceSnapshot: homeFlyerHubLiveSnapshot,
                onFlyerSaveSuccessReturnToCommerce: { showHomeFlyerHubFullScreen = false },
                onExitFlyerHubPopCommerce: { showHomeFlyerHubFullScreen = false }
            )
            .environmentObject(syncService)
            .environmentObject(authService)
        }
        .environment(\.managedObjectContext, viewContext)
    }

    private var homeFlyerHubLiveSnapshot: CommerceFlyerLiveSnapshot? {
        if homeFlyerHubOpenedForEdit {
            return CommerceFlyerLiveSnapshot(
                bootstrapPreviewB64: homeFlyerBootstrapB64,
                customBgDataURL: homeFlyerCustomBgDataURL,
                shareURL: homeFlyerPublicPageURLString
            )
        }
        if let b64 = homeFlyerBootstrapB64?.trimmingCharacters(in: .whitespacesAndNewlines), !b64.isEmpty {
            return CommerceFlyerLiveSnapshot(
                bootstrapPreviewB64: b64,
                customBgDataURL: homeFlyerCustomBgDataURL,
                shareURL: homeFlyerPublicPageURLString
            )
        }
        guard let slug = currentBusinessSlug,
              let cached = CommerceFlyerStateCache.load(slug: slug),
              let b64 = cached.bootstrapPreviewB64?.trimmingCharacters(in: .whitespacesAndNewlines),
              !b64.isEmpty
        else { return nil }
        return CommerceFlyerLiveSnapshot(
            bootstrapPreviewB64: b64,
            customBgDataURL: cached.customBgDataURL,
            shareURL: cached.shareURL
        )
    }

    /// Évite le ternaire `onRedeemTier` dans `body` (échec d’inférence Swift / « Failed to produce diagnostic »).
    @ViewBuilder
    private func scanAddPointsSheet(for data: ScanResultSheetData) -> some View {
        AddPointsAmountSheet(
            memberName: data.memberName,
            barcode: data.barcode,
            pointsPerEuro: data.pointsPerEuro,
            memberPoints: data.memberPoints,
            rewardTiers: data.rewardTiers,
            pointsMinAmountEur: data.pointsMinAmountEur,
            scanMaxPointsPerTransaction: data.scanMaxPointsPerTransaction,
            isSubmitting: $isScanAmountSubmitting,
            receiptCoordinator: receiptCoordinator,
            onDismiss: { scanResultSheet = nil },
            onSubmit: { amountEur in
                await submitScanAmount(slug: data.slug, barcode: data.barcode, amountEur: amountEur)
            },
            onRedeemTier: scanRedeemHandler(for: data)
        )
    }

    private func scanRedeemHandler(for data: ScanResultSheetData) -> ((ScanRewardTier, Double) async -> Int?)? {
        guard !data.rewardTiers.isEmpty else { return nil }
        return { tier, amount in
            await redeemOrCreditScan(tier: tier, amountEur: amount, data: data)
        }
    }

    // MARK: - Accueil type fintech (carte + transactions)

    private var showHomeCardTapHint: Bool { !merchantHomeCardOpenedFromHome }
    private var shouldShowHomeCardSetupBadge: Bool { !homeCardConfigured }

    @ViewBuilder
    private func merchantHomeCardPreviewButton<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        Button {
            merchantHomeCardOpenedFromHome = true
            DispatchQueue.main.async {
                showMyCardFullScreen = true
            }
        } label: {
            label()
                .zoomTransitionSource(id: HomeMyCardZoom.previewSourceID, in: homeMyCardZoomNamespace)
        }
        .buttonStyle(MerchantPressableButtonStyle(scalePressed: 0.94, opacityPressed: 0.88, recognizeTouchImmediately: true))
        .accessibilityLabel("Ma carte")
        .accessibilityHint("Ouvre la personnalisation de la carte fidélité.")
    }

    // MARK: - Accueil employé (caisse) vs commerçant

    @ViewBuilder
    private var employeeOrOwnerHomeContent: some View {
        if merchantWorkspaceMode == .staff {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .frame(height: 8)
                    .accessibilityHidden(true)
                fintechTransactionsSection
                    .padding(.top, 14)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if shouldShowSimpleHomeSetup {
                    Color.clear
                        .frame(height: DashboardHomeChrome.showMinimalTopBar ? (DashboardHomeMinimalTopBarLayout.scrollPanelTopOffset + 4) : 8)
                        .accessibilityHidden(true)
                    homeSimpleSetupSection
                        .padding(.top, 12)
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                } else {
                    fintechHomeTopAndCardOwner
                    fintechTransactionsSection
                        .padding(.top, 2)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.28), value: shouldShowSimpleHomeSetup)
        }
    }

    /// Recalcule la vignette carte pour la section setup (ImageRenderer — même rendu que l’accueil).
    @MainActor
    private func refreshHomeCardSetupThumbnail() {
        guard homeCardConfigured,
              let model = DashboardHomeCardModel.resolve(dataService: dataService) else {
            homeCardSetupThumbnail = nil
            return
        }
        let renderW: CGFloat = 360
        let renderH: CGFloat = 460
        let card = FintechHomeLoyaltyCardBlock(model: model, palette: palette)
            .environment(\.colorScheme, colorScheme)
            .frame(width: renderW, height: renderH, alignment: .center)
            .clipped()
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        homeCardSetupThumbnail = renderer.uiImage
    }

    private var homeCardSetupThumbnailTaskId: String {
        "\(currentBusinessSlug ?? "")|\(homeCardConfigured)|\(cardPreviewDisplayRefresh)"
    }

    private var homeCardMediaPrefetchTaskId: String {
        let _ = dataService.updateTrigger
        let model = DashboardHomeCardModel.resolve(dataService: dataService)
        return "\(currentBusinessSlug ?? "")|\(dataService.updateTrigger)|\(model?.logoURL ?? "")|\(model?.cardBackgroundRemoteURL ?? "")|\(cardPreviewDisplayRefresh)"
    }

    @MainActor
    private func prefetchHomeCardMediaIfNeeded() async {
        if let slug = currentBusinessSlug {
            CardPreviewDisplaySnapshotStore.reconcileFromSettingsCacheIfNeeded(slug: slug)
        }
        guard let model = DashboardHomeCardModel.resolve(dataService: dataService) else { return }
        await AuthenticatedMediaLoader.prefetchCardAssets(
            logoURLString: model.logoURL ?? "",
            backgroundURLString: model.cardBackgroundRemoteURL
        )
    }

    private var homeSimpleSetupSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Finalisez votre lancement")
                .font(.system(size: 34, weight: .regular, design: .default))
                .foregroundStyle(Color(red: 0.05, green: 0.12, blue: 0.26))
                .lineSpacing(0)
                .kerning(-0.2)
                .fixedSize(horizontal: false, vertical: true)

            Text("Commencez par votre carte et votre flyer de jeu : deux étapes suffisent pour être prêt à l’emploi")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color(red: 0.37, green: 0.47, blue: 0.63))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 14) {
                homeSimpleSetupCard(
                    title: "Créez votre carte",
                    useHeroCarousel: true,
                    carouselKind: .loyaltyCardIsoId1,
                    carouselImageNames: ["cartefid1", "cartefid2", "cartefid3"],
                    fallbackCarouselImage: nil,
                    isReady: homeCardConfigured,
                    readyLabel: "Commencer",
                    pendingLabel: "Commencer"
                ) {
                    merchantHomeCardOpenedFromHome = true
                    showMyCardFullScreen = true
                }

                homeSimpleSetupCard(
                    title: "Créez votre flyer",
                    useHeroCarousel: true,
                    carouselKind: .flyerPortrait9x16,
                    carouselImageNames: ["flyerfid1", "flyerfid2", "flyerfid3", "flyerfid4"],
                    fallbackCarouselImage: homeFlyerCompositeSnapshot ?? homeFlyerUnderlayUIImage,
                    isReady: homeFlyerAvailable,
                    readyLabel: "Commencer",
                    pendingLabel: "Commencer"
                ) {
                    openFlyerHubFromHome(startCreateAssistant: true)
                }
            }
        }
        .padding(.horizontal, 4)
        .task(id: homeCardSetupThumbnailTaskId) {
            await Task.yield()
            refreshHomeCardSetupThumbnail()
        }
    }

    /// Découpe « Créez votre carte » → (« Créez votre », « carte ») pour titres sur deux lignes serrées.
    private func homeSetupHeadlineLines(from title: String) -> (String, String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let needle = " votre "
        if let r = t.range(of: needle, options: .caseInsensitive) {
            let first = String(t[..<r.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let second = String(t[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !second.isEmpty { return (first, second) }
        }
        return (t, "")
    }

    @ViewBuilder
    private func homeFlyerSetupStaticHero(fallback: UIImage?) -> some View {
        Group {
            if let u = fallback {
                Image(uiImage: u)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 100, height: 168)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func homeSimpleSetupCard(
        title: String,
        useHeroCarousel: Bool,
        carouselKind: DashboardSetupHeroCarousel.HeroVisualKind,
        carouselImageNames: [String],
        fallbackCarouselImage: UIImage? = nil,
        isReady: Bool,
        readyLabel: String,
        pendingLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        let headline = homeSetupHeadlineLines(from: title)
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(red: 0.92, green: 0.93, blue: 0.95))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.13, blue: 0.18),
                                Color(red: 0.08, green: 0.11, blue: 0.16),
                                Color(red: 0.07, green: 0.10, blue: 0.14),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RadialGradient(
                            colors: [
                                Color(red: 0.05, green: 0.53, blue: 0.77).opacity(0.35),
                                .clear,
                            ],
                            center: .bottom,
                            startRadius: 16,
                            endRadius: 220
                        )
                    )
                    .padding(9)
                    .overlay {
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(headline.0)
                                    .font(.system(size: 27, weight: .black))
                                    .foregroundStyle(.white.opacity(0.96))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                if !headline.1.isEmpty {
                                    Text(headline.1)
                                        .font(.system(size: 27, weight: .black))
                                        .foregroundStyle(.white.opacity(0.96))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .padding(.top, -1)
                                }
                                Button(action: action) {
                                    HStack(spacing: 10) {
                                        Circle()
                                            .stroke(Color.white.opacity(0.55), lineWidth: 1.2)
                                            .frame(width: 10, height: 10)
                                        Text(isReady ? readyLabel : pendingLabel)
                                            .font(.system(size: 20, weight: .bold))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.72)
                                    }
                                    .frame(width: 232)
                                    .padding(.horizontal, 26)
                                    .padding(.vertical, 14)
                                }
                                .disabled(isReady)
                                .opacity(isReady ? 0.58 : 1)
                                .allowsHitTesting(!isReady)
                                .modifier(HomeSetupGlassButtonModifier())
                                .padding(.top, 10)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1)

                            Group {
                                if useHeroCarousel {
                                    DashboardSetupHeroCarousel(
                                        kind: carouselKind,
                                        imageNames: carouselImageNames,
                                        fallbackImage: fallbackCarouselImage
                                    )
                                    .fixedSize(horizontal: true, vertical: true)
                                } else {
                                    homeFlyerSetupStaticHero(fallback: fallbackCarouselImage)
                                        .fixedSize(horizontal: true, vertical: true)
                                }
                            }
                        }
                        .padding(.leading, 22)
                        .padding(.trailing, 8)
                        .padding(.vertical, 10)
                    }
            }
            .frame(height: 244)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }

    private var fintechHomeTopAndCardOwner: some View {
        VStack(alignment: .leading, spacing: DashboardHomeChrome.showMinimalTopBar ? 10 : 8) {
            Color.clear
                .frame(height: 0)
                .accessibilityHidden(true)

            homeMyCardSlide
                .environment(\.homeCarouselPress, .inactive)
                .frame(maxWidth: .infinity)
                .padding(.top, -14)
                .padding(.bottom, -10)
        }
    }

    @ViewBuilder
    private var homeMyCardSlide: some View {
        Group {
            if showHomeCardSetupOverlay {
                merchantHomeCardPreviewButton {
                    homeCardSetupReplacement
                }
            } else {
                Group {
                    if let model = DashboardHomeCardModel.resolve(dataService: dataService) {
                        merchantHomeCardPreviewButton {
                                FintechHomeLoyaltyCardBlock(
                                    model: model,
                                    palette: palette
                                )
                            .overlay {
                                if shouldShowHomeCardSetupBadge {
                                    HomeCardTouchHintPill()
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .task(id: homeCardMediaPrefetchTaskId) {
            await prefetchHomeCardMediaIfNeeded()
        }
    }

    /// Feuille « Créer le flyer » tant que pas de flyer enregistré : lancement Accueil, retour après arrière-plan, file post « Ma carte ».
    private func scheduleMerchantFlyerPromoSheetIfEligible() {
        guard merchantWorkspaceMode != .staff else { return }
        guard tabRouter.selectedTab == 0 else { return }
        guard !showMyCardFullScreen else { return }
        guard !showHomeFlyerHubFullScreen else { return }
        guard merchantHomeFlyerPromoPresentation == nil else { return }

        merchantFlyerPromoQueuedPresentationWorkItem?.cancel()
        let work = DispatchWorkItem {
            guard merchantWorkspaceMode != .staff else { return }
            guard tabRouter.selectedTab == 0 else { return }
            guard !showMyCardFullScreen else { return }
            guard !showHomeFlyerHubFullScreen else { return }
            guard merchantHomeFlyerPromoPresentation == nil else { return }

            let slugQueued = PostCardFlyerPromoEligibility.dequeuePendingSlugIfEligible()
            let activeRaw = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let slug = slugQueued ?? (activeRaw.isEmpty ? nil : activeRaw)

            guard let slug, PostCardFlyerPromoEligibility.shouldOffer(for: slug) else { return }

            merchantHomeFlyerPromoPresentation = MerchantHomeFlyerPromoSheetContext(businessSlug: slug)
        }
        merchantFlyerPromoQueuedPresentationWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func openFlyerHubFromHome(forEdit: Bool = false, startCreateAssistant: Bool = false) {
        homeFlyerHubOpenedForEdit = forEdit
        homeFlyerHubStartCreateAssistant = startCreateAssistant
        showHomeFlyerHubFullScreen = true
    }

    /// `userInfo` peut exposer un `Bool` Swift ou un `NSNumber` (pont Objective-C) — les deux doivent ouvrir l’assistant création.
    private static func flyerHubStartCreateAssistant(from note: Notification) -> Bool {
        let key = MyfidpassNotificationUserInfoKey.flyerHubStartCreateAssistant
        guard let raw = note.userInfo?[key] else { return false }
        if let b = raw as? Bool { return b }
        if let n = raw as? NSNumber { return n.boolValue }
        if let s = raw as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return t == "1" || t == "true" || t == "yes"
        }
        return false
    }

    private func homeSetupReplacementButton(
        title: String,
        subtitle: String,
        icon: String,
        cornerRadius: CGFloat
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.95), Color(red: 0.88, green: 0.89, blue: 0.92)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                )

            VStack(spacing: 14) {
                Spacer(minLength: 0)
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.82))

                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.black.opacity(0.92))
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.black.opacity(0.62))
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                    Text("Cliquer pour ouvrir")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.right")
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black, in: Capsule())
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 10, y: 6)
        .allowsHitTesting(false)
    }

    private var homeCardSetupReplacement: some View {
        homeSetupReplacementButton(
            title: "Personnaliser la carte",
            subtitle: "Appuyez pour configurer votre carte",
            icon: "creditcard.fill",
            cornerRadius: 22
        )
        .padding(.horizontal, 36)
        .frame(minHeight: DashboardHomeCardChrome.previewMinHeight)
        .scaleEffect(DashboardHomeCardChrome.homeCardScale, anchor: .center)
        .padding(.vertical, AppTheme.Spacing.xs)
        .frame(maxWidth: .infinity)
    }

    private struct HomeCardTouchHintPill: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var isPulsing = false

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 15, weight: .black))
                Text("Touchez")
                    .font(.system(size: 16, weight: .black))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.86))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.42), lineWidth: 1.2)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 10, y: 5)
            .fixedSize()
            .scaleEffect(reduceMotion ? 1 : (isPulsing ? 1.08 : 0.96), anchor: .center)
            .task {
                guard !reduceMotion else { return }
                try? await Task.sleep(nanoseconds: 80_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.82).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
            .onDisappear {
                isPulsing = false
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var fintechTransactionsSection: some View {
        let _ = dataService.updateTrigger
        return VStack(alignment: .leading, spacing: 12) {
            FintechTransactionsSectionHeader(
                palette: palette,
                onSeeAll: nil,
                onOpenScanner: { showScanner = true },
                statsTransitionSourceID: nil,
                statsTransitionNamespace: nil
            )

            if activityPreview.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundStyle(palette.tertiaryText)
                    Text("Aucune transaction récente")
                        .font(.body.weight(.bold))
                        .foregroundStyle(palette.onCanvasPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .padding(.horizontal, 18)
                .background(palette.transactionPillBG, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(activityPreview) { entry in
                        Button {
                            withAnimation(MerchantMotion.navigationPath) {
                                navigationPath.append(DashboardRoute.memberDetail(entry.cardObjectID))
                            }
                        } label: {
                            FintechTransactionRow(entry: entry, palette: palette, isPointsProgram: homeProgramIsPoints)
                        }
                        .buttonStyle(MerchantPressableButtonStyle(scalePressed: 0.98, opacityPressed: 0.94))
                        .accessibilityLabel("\(entry.clientName), \(entry.eventTitle)")
                        .accessibilityHint("Ouvre la fiche membre")
                    }
                }
            }
        }
        .padding(.horizontal, DashboardHomeLayoutMetrics.transactionsSectionExtraHorizontal)
        .task(id: homeActivityLiveSyncTaskKey) {
            guard merchantTabIsActive, navigationPath.isEmpty, scenePhase == .active else { return }
            guard currentBusinessSlug != nil else { return }
            await syncService.syncIfNeeded()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.homeActivityPollIntervalSeconds))
                guard !Task.isCancelled else { return }
                guard merchantTabIsActive, navigationPath.isEmpty, scenePhase == .active else { return }
                await syncService.syncIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var syncOverlay: some View {
        // Le bandeau global de ContentView couvre déjà l'état sync.
        // Supprimer ce spinner additionnel évite les clignotements visuels constants à l'ouverture des écrans.
        EmptyView()
    }

    private func normalizeBarcodeToMemberId(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return raw }
        let uuidPattern = #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#
        if let range = s.range(of: uuidPattern, options: .regularExpression) {
            return String(s[range])
        }
        if s.count == 36, s.contains("-") { return s }
        return s
    }

    @State private var lastHomeFlyerRefreshAt: Date?

    private func refreshHomeFlyerAvailability() {
        if let last = lastHomeFlyerRefreshAt, Date().timeIntervalSince(last) < 1.5 { return }
        lastHomeFlyerRefreshAt = Date()
        refreshHomeFlyerAvailabilityNow()
    }

    private func refreshHomeFlyerAvailabilityNow() {
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            homeFlyerAvailable = false
            homeFlyerBootstrapB64 = nil
            homeFlyerShareURL = ""
            homeFlyerCustomBgDataURL = nil
            homeFlyerUnderlayUIImage = nil
            homeFlyerCompositeSnapshot = nil
            homeSetupStateResolved = true
            return
        }
        CommerceFlyerStore.shared.hydrateFromDiskIfNeeded(slug: slug)
        guard let cached = CommerceFlyerStore.shared.snapshot(for: slug) else {
            homeFlyerAvailable = false
            homeFlyerBootstrapB64 = nil
            homeFlyerShareURL = ""
            homeFlyerCustomBgDataURL = nil
            homeFlyerUnderlayUIImage = nil
            homeFlyerCompositeSnapshot = nil
            homeSetupStateResolved = true
            return
        }
        let hasBootstrap = !(cached.bootstrapPreviewB64 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasBg = !(cached.customBgDataURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        homeFlyerAvailable = cached.flyerRegistered || hasBootstrap || hasBg
        homeFlyerBootstrapB64 = hasBootstrap ? cached.bootstrapPreviewB64 : nil
        homeFlyerShareURL = cached.shareURL
        homeFlyerCustomBgDataURL = cached.customBgDataURL
        if let draft = CommerceFlyerEditorDraftStore.load(slug: slug) {
            let draftB64 = draft.bootstrapB64.trimmingCharacters(in: .whitespacesAndNewlines)
            if !draftB64.isEmpty {
                homeFlyerBootstrapB64 = draftB64
                let draftBg = draft.meta.customBgDataURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !draftBg.isEmpty { homeFlyerCustomBgDataURL = draftBg }
                let draftShare = draft.meta.shareURL.trimmingCharacters(in: .whitespacesAndNewlines)
                if !draftShare.isEmpty { homeFlyerShareURL = draftShare }
                homeFlyerAvailable = true
            }
        }
        if (homeFlyerCustomBgDataURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
           let b64 = homeFlyerBootstrapB64,
           let bgFromBootstrap = FlyerBootstrapPreviewPayloadBuilder.customBgDataURLFromBootstrapBase64(b64) {
            homeFlyerCustomBgDataURL = bgFromBootstrap
        }
        CommerceFlyerStore.shared.upsert(
            slug: slug,
            snapshot: .init(
                flyerRegistered: homeFlyerAvailable,
                shareURL: homeFlyerShareURL,
                bootstrapPreviewB64: homeFlyerBootstrapB64,
                customBgDataURL: homeFlyerCustomBgDataURL,
                revisionKey: cached.revisionKey
            )
        )
        Task { await refreshHomeFlyerVisualAssets(slug: slug) }
        homeSetupStateResolved = true
    }

    @MainActor
    private func refreshHomeNotificationIconStatusIfNeeded(force: Bool = false) async {
        if homeNotificationIconRefreshInFlight { return }
        guard let slug = currentBusinessSlug else {
            homeHasNotificationIconConfigured = false
            homeNotificationIconURL = nil
            homeNotificationIconLastCheckAt = Date()
            homeNotificationIconLastSlug = nil
            return
        }
        if !force,
           homeNotificationIconLastSlug == slug,
           let last = homeNotificationIconLastCheckAt,
           Date().timeIntervalSince(last) < 45 {
            return
        }
        if !force,
           let cached = ScanFlowSettingsCache.cached(for: slug),
           let syncedAt = syncService.lastSyncDate,
           Date().timeIntervalSince(syncedAt) < 120 {
            let icon = cached.notificationIconUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            homeHasNotificationIconConfigured = !icon.isEmpty
            homeNotificationIconURL = icon.isEmpty ? nil : icon
            homeNotificationIconLastCheckAt = Date()
            homeNotificationIconLastSlug = slug
            return
        }
        if let cached = ScanFlowSettingsCache.cached(for: slug) {
            let icon = cached.notificationIconUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            homeHasNotificationIconConfigured = !icon.isEmpty
            homeNotificationIconURL = icon.isEmpty ? nil : icon
            if let raw = homeNotificationIconURL,
               let url = APIResourceURL.resolved(from: raw) {
                Task.detached(priority: .utility) {
                    await AuthenticatedMediaLoader.prefetch(url: url)
                }
            }
        }
        homeNotificationIconRefreshInFlight = true
        defer { homeNotificationIconRefreshInFlight = false }
        do {
            let settings: BusinessSettingsResponse = try await APIClient.shared.request(.businessSettings(slug: slug))
            ScanFlowSettingsCache.store(settings, for: slug)
            let icon = settings.notificationIconUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            homeHasNotificationIconConfigured = !icon.isEmpty
            homeNotificationIconURL = icon.isEmpty ? nil : icon
            if let raw = homeNotificationIconURL,
               let url = APIResourceURL.resolved(from: raw) {
                Task.detached(priority: .utility) {
                    await AuthenticatedMediaLoader.prefetch(url: url)
                }
            }
        } catch {
            // Conserve l'état précédent en cas de réseau KO.
        }
        homeNotificationIconLastCheckAt = Date()
        homeNotificationIconLastSlug = slug
    }

    private var homeFlyerPublicPageURLString: String {
        let s = homeFlyerShareURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty { return s }
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            return ""
        }
        return LegalURLs.fidelityCardPage(slug: slug)?.absoluteString ?? ""
    }

    private var homeFlyerCompositeToken: String? {
        CommerceFlyerRasterCache.compositeSnapshotToken(
            slug: AuthStorage.currentBusinessSlug,
            bootstrapB64: homeFlyerBootstrapB64
        )
    }

    @MainActor
    private func refreshHomeFlyerVisualAssets(slug: String) async {
        if let token = homeFlyerCompositeToken {
            homeFlyerCompositeSnapshot = CommerceFlyerRasterCache.image(forCompositeToken: token)
        } else {
            homeFlyerCompositeSnapshot = nil
        }

        let bgDataURL = homeFlyerCustomBgDataURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !bgDataURL.isEmpty {
            homeFlyerUnderlayUIImage = await CommerceFlyerRasterCache.coalescedCustomBgImage(key: bgDataURL) {
                await Task.detached(priority: .userInitiated) {
                    Self.decodeHomeFlyerDataURLImage(bgDataURL)
                }.value
            }
        } else if !slug.isEmpty {
            let revisionKey = FlyerBootstrapPreviewPayloadBuilder.updatedAtFromBootstrapBase64(homeFlyerBootstrapB64)
            homeFlyerUnderlayUIImage = await CommerceFlyerRasterCache.coalescedPublicBgImage(slug: slug, revisionKey: revisionKey) {
                await CommerceFlyerPublicBgThumbnail.loadUIImage(slug: slug, revisionKey: revisionKey)
            }
        } else {
            homeFlyerUnderlayUIImage = nil
        }

    }

    private nonisolated static func decodeHomeFlyerDataURLImage(_ s: String) -> UIImage? {
        guard s.hasPrefix("data:image/"), let comma = s.firstIndex(of: ",") else { return nil }
        let b64 = String(s[s.index(after: comma)...])
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        guard let data = Data(base64Encoded: b64, options: [.ignoreUnknownCharacters]), !data.isEmpty else { return nil }
        return UIImage(data: data)
    }

    /// Plein écran montant € (comme la fiche membre) : `program_type == points`, ou champ absent avec mode caisse / points_per_euro.
    private func shouldPresentEuroPointsSheetAfterScan(_ settings: BusinessSettingsResponse) -> Bool {
        let pt = (settings.programType ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if pt == "stamps" { return false }
        if pt == "points" { return true }
        let lm = (settings.loyaltyMode ?? "").lowercased()
        if lm.contains("point") || lm.contains("cash") { return true }
        return (settings.pointsPerEuro ?? 0) > 0
    }

    private func shouldPresentStampVisitSheetAfterScan(_ settings: BusinessSettingsResponse) -> Bool {
        let pt = (settings.programType ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return pt == "stamps"
    }

    private func handleQRScanned(_ code: String) {
        guard let slug = AuthStorage.currentBusinessSlug else {
            appState.showError("Aucun commerce. Reconnectez-vous.")
            scanError = "Aucun commerce. Reconnectez-vous."
            return
        }
        /// Lookup : chaîne brute (ex. `MYFIDPASS_REDEEM:1:…`) pour détecter `reward_redeem`.
        /// Crédit passage : identifiant membre / QR Wallet (UUID).
        let barcode = normalizeBarcodeToMemberId(code)
        Task {
            do {
                async let lookupTask = APIClient.shared.request(.scanLookup(slug: slug, barcode: code)) as ScanLookupResponse

                let settings: BusinessSettingsResponse
                if let cached = ScanFlowSettingsCache.cached(for: slug) {
                    settings = cached
                    Task.detached(priority: .utility) {
                        do {
                            let fresh = try await APIClient.shared.request(.businessSettings(slug: slug)) as BusinessSettingsResponse
                            ScanFlowSettingsCache.store(fresh, for: slug)
                        } catch { /* ignore */ }
                    }
                } else {
                    settings = try await APIClient.shared.request(.businessSettings(slug: slug)) as BusinessSettingsResponse
                    ScanFlowSettingsCache.store(settings, for: slug)
                }

                let lookup = try await lookupTask
                let memberName = lookup.member.name ?? "Client"
                let pointsPerEuro = settings.pointsPerEuro ?? 1
                let walletBarcode: String = {
                    let mid = lookup.member.id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return mid.isEmpty ? barcode : mid
                }()

                if let sheetData = ScanRewardRedeemSheetDataBuilder.make(
                    slug: slug,
                    barcode: code,
                    memberName: memberName,
                    memberId: lookup.member.id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? walletBarcode,
                    lookup: lookup
                ) {
                    await MainActor.run {
                        var tx = Transaction()
                        tx.disablesAnimations = true
                        withTransaction(tx) {
                            scanRewardRedeemSheet = sheetData
                        }
                    }
                    return
                }

                if shouldPresentEuroPointsSheetAfterScan(settings) {
                    let tierDTOs = settings.pointsRewardTiers ?? []
                    let rewardTiers = tierDTOs
                        .filter { $0.points > 0 }
                        .map { ScanRewardTier(points: $0.points, label: $0.label.isEmpty ? "Récompense" : $0.label) }
                        .sorted { $0.points < $1.points }
                    let sheetData = ScanResultSheetData(
                        slug: slug,
                        memberName: memberName,
                        barcode: walletBarcode,
                        pointsPerEuro: pointsPerEuro,
                        memberPoints: lookup.member.points,
                        rewardTiers: rewardTiers,
                        pointsMinAmountEur: settings.pointsMinAmountEur,
                        scanMaxPointsPerTransaction: settings.scanMaxPointsPerTransaction
                    )
                    await MainActor.run {
                        var tx = Transaction()
                        tx.disablesAnimations = true
                        withTransaction(tx) {
                            scanResultSheet = sheetData
                        }
                    }
                    return
                }

                if shouldPresentStampVisitSheetAfterScan(settings) {
                    let stampModel = await MainActor.run {
                        let api = lookup.member.points ?? 0
                        let bc = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
                        let merged: Int = {
                            guard let t = dataService.currentCardTemplate(), !bc.isEmpty,
                                  let card = dataService.clientCard(byQRCodeValue: bc),
                                  card.template == t else { return api }
                            return max(api, Int(card.stampsCount))
                        }()
                        return DashboardHomeCardModel.resolveStampScanPreview(
                            dataService: dataService,
                            memberName: memberName,
                            memberStampBalance: merged,
                            settings: settings
                        )
                    }
                    if let stampModel {
                        let stampData = ScanStampSheetData(
                            slug: slug,
                            barcode: walletBarcode,
                            memberName: memberName,
                            cardModel: stampModel
                        )
                        await MainActor.run {
                            var tx = Transaction()
                            tx.disablesAnimations = true
                            withTransaction(tx) {
                                scanStampSheet = stampData
                            }
                        }
                        return
                    }
                }

                let response: ScanResponse = try await APIClient.shared.request(
                    .scan(slug: slug, barcode: walletBarcode, visit: true, points: nil, amountEur: nil, receiptValidationToken: nil)
                )
                await MainActor.run {
                    applyScanBalanceLocally(barcode: walletBarcode, response: response)
                    successToast = Toast.scanStampSuccess(
                        memberName: response.member?.name ?? memberName,
                        pointsCapped: response.pointsCapped == true,
                        pointsRequested: response.pointsRequested,
                        pointsAdded: response.pointsAdded,
                        stampCycleCompleted: response.stampCycleCompleted == true
                    )
                    showToast = true
                }
                scheduleDebouncedPostScanSync()
            } catch let e as APIError where e.isHTTPResourceMissing {
                await MainActor.run {
                    scanError = "Code non reconnu pour ce commerce. Scannez le QR affiché sur la carte dans le Wallet du client (pas le lien « Ajouter à Wallet »)."
                    appState.showError(scanError ?? "Code non reconnu.")
                }
            } catch {
                await MainActor.run {
                    presentScanFailure(error, fallback: "Erreur lors du scan.")
                }
            }
        }
    }

    @MainActor
    private func presentScanFailure(_ error: Error, fallback: String) {
        let msg = APIError.merchantFacingMessage(from: error) ?? fallback
        scanError = msg
        appState.showError(msg)
    }

    @MainActor
    private func applyScanBalanceLocally(barcode: String, response: ScanResponse) {
        guard let template = dataService.currentCardTemplate() else { return }
        let bc = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bc.isEmpty else { return }
        let card = dataService.clientCard(byQRCodeValue: bc)
            ?? dataService.findOrCreateClientCard(
                qrCodeValue: bc,
                template: template,
                clientDisplayName: response.member?.name
            )
        if let bal = response.newBalance {
            card.stampsCount = Int32(bal)
        } else if let p = response.member?.points {
            card.stampsCount = Int32(p)
        } else if let added = response.pointsAdded {
            card.stampsCount += Int32(added)
        }
        card.updatedAt = Date()
        if let name = response.member?.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            card.clientDisplayName = name
        }
        try? viewContext.save()
    }

    private func submitStampVisit(slug: String, barcode: String) async -> ScanResponse? {
        isStampVisitSubmitting = true
        defer { Task { @MainActor in isStampVisitSubmitting = false } }
        do {
            let response: ScanResponse = try await APIClient.shared.request(
                .scan(slug: slug, barcode: barcode, visit: true, points: nil, amountEur: nil, receiptValidationToken: nil)
            )
            await MainActor.run {
                applyScanBalanceLocally(barcode: barcode, response: response)
            }
            scheduleDebouncedPostScanSync()
            return response
        } catch {
            scheduleDebouncedPostScanSync()
            await MainActor.run {
                presentScanFailure(error, fallback: "Erreur lors de l’enregistrement du tampon.")
            }
            return nil
        }
    }

    @discardableResult
    private func submitScanAmount(slug: String, barcode: String, amountEur: Double) async -> Bool {
        isScanAmountSubmitting = true
        defer { Task { @MainActor in isScanAmountSubmitting = false } }
        do {
            let settings: BusinessSettingsResponse
            if let c = ScanFlowSettingsCache.cached(for: slug) {
                settings = c
            } else {
                settings = try await APIClient.shared.request(.businessSettings(slug: slug)) as BusinessSettingsResponse
                ScanFlowSettingsCache.store(settings, for: slug)
            }
            var receiptTok: String?
            if (settings.requireReceiptQrValidation ?? 0) == 1, amountEur > 0 {
                guard let t = try await receiptCoordinator.requestValidatedToken(slug: slug, amountEur: amountEur) else {
                    await MainActor.run {
                        scanError = "Scan du ticket de caisse annulé."
                        appState.showError(scanError ?? "")
                    }
                    return false
                }
                receiptTok = t
            }
            let response: ScanResponse = try await APIClient.shared.request(
                .scan(
                    slug: slug,
                    barcode: barcode,
                    visit: false,
                    points: nil,
                    amountEur: amountEur,
                    receiptValidationToken: receiptTok
                )
            )
            await MainActor.run {
                successToast = Toast.scanSuccess(
                    memberName: response.member?.name ?? "Client",
                    pointsAdded: response.pointsAdded,
                    pointsCapped: response.pointsCapped == true,
                    pointsRequested: response.pointsRequested
                )
                var tx = Transaction()
                tx.disablesAnimations = true
                withTransaction(tx) {
                    scanResultSheet = nil
                }
                showToast = true
            }
            scheduleDebouncedPostScanSync()
            return true
        } catch {
            await MainActor.run {
                presentScanFailure(error, fallback: "Erreur lors de l'enregistrement.")
            }
            return false
        }
    }

    private func performRewardRedeemScan(data: ScanRewardRedeemSheetData) async -> String? {
        do {
            let response: IntegrationRewardRedeemResponse = try await APIClient.shared.request(
                .integrationRewardRedeem(slug: data.slug, barcode: data.barcode)
            )
            let label = response.rewardLabel ?? data.rewardLabel
            let newP = response.newPoints ?? data.pointsBalance
            await MainActor.run {
                successToast = Toast(
                    symbol: "gift.fill",
                    symbolFont: .system(size: 32, weight: .semibold),
                    symbolForegroundStyle: (.white, Color(red: 1, green: 0.55, blue: 0.2)),
                    title: "Récompense validée",
                    message: "\(data.memberName) — \(label). Nouveau solde : \(newP) pts."
                )
                showToast = true
            }
            scheduleDebouncedPostScanSync()
            return nil
        } catch {
            let msg = APIError.merchantFacingMessage(from: error) ?? "Validation impossible."
            await MainActor.run {
                scanError = msg
                appState.showError(msg)
            }
            return msg
        }
    }

    /// Même logique que la fiche membre : redeem immédiat ou crédit panier puis redeem (scan QR).
    private func redeemOrCreditScan(tier: ScanRewardTier, amountEur: Double, data: ScanResultSheetData) async -> Int? {
        let slug = data.slug
        let barcode = data.barcode
        let before = data.memberPoints ?? 0
        let ppe = max(1, data.pointsPerEuro)
        var earned = 0
        if amountEur > 0 {
            if let minEur = data.pointsMinAmountEur, amountEur < minEur - 1e-9 {
                await MainActor.run {
                    scanError = "Montant sous le minimum défini pour ce commerce."
                    appState.showError(scanError ?? "")
                }
                return nil
            }
            earned = Int(floor(amountEur * Double(ppe)))
        }
        let after = before + earned

        func performRedeem() async throws -> RedeemResponse {
            try await APIClient.shared.request(
                .redeemReward(slug: slug, memberId: barcode, type: .points(pointsToDeduct: tier.points))
            ) as RedeemResponse
        }

        do {
            if before >= tier.points {
                let response = try await performRedeem()
                let newP = response.newPoints ?? max(0, before - tier.points)
                await MainActor.run {
                    successToast = Toast(
                        symbol: "gift.fill",
                        symbolFont: .system(size: 32, weight: .semibold),
                        symbolForegroundStyle: (.white, Color(red: 1, green: 0.55, blue: 0.2)),
                        title: "Récompense offerte",
                        message: "\(data.memberName) — \(tier.label). Solde : \(newP) pts."
                    )
                    showToast = true
                }
                scheduleDebouncedPostScanSync()
                return newP
            }
            if earned > 0, after >= tier.points {
                let settings: BusinessSettingsResponse
                if let c = ScanFlowSettingsCache.cached(for: slug) {
                    settings = c
                } else {
                    settings = try await APIClient.shared.request(.businessSettings(slug: slug)) as BusinessSettingsResponse
                    ScanFlowSettingsCache.store(settings, for: slug)
                }
                var receiptTok: String?
                if (settings.requireReceiptQrValidation ?? 0) == 1, amountEur > 0 {
                    guard let t = try await receiptCoordinator.requestValidatedToken(slug: slug, amountEur: amountEur) else {
                        await MainActor.run {
                            scanError = "Scan du ticket de caisse annulé."
                            appState.showError(scanError ?? "")
                        }
                        return nil
                    }
                    receiptTok = t
                }
                let creditResponse: ScanResponse = try await APIClient.shared.request(
                    .scan(
                        slug: slug,
                        barcode: barcode,
                        visit: false,
                        points: nil,
                        amountEur: amountEur,
                        receiptValidationToken: receiptTok
                    )
                )
                let credited = creditResponse.newBalance
                    ?? creditResponse.member?.points
                    ?? (before + (creditResponse.pointsAdded ?? earned))
                guard credited >= tier.points else {
                    await MainActor.run {
                        scanError = "Solde encore insuffisant après crédit."
                        appState.showError(scanError ?? "")
                    }
                    scheduleDebouncedPostScanSync()
                    return nil
                }
                let redeemResponse = try await performRedeem()
                let finalP = redeemResponse.newPoints ?? max(0, credited - tier.points)
                await MainActor.run {
                    successToast = Toast(
                        symbol: "gift.fill",
                        symbolFont: .system(size: 32, weight: .semibold),
                        symbolForegroundStyle: (.white, Color(red: 1, green: 0.55, blue: 0.2)),
                        title: "Panier crédité et récompense offerte",
                        message: "\(data.memberName) — \(tier.label). Solde : \(finalP) pts."
                    )
                    showToast = true
                }
                scheduleDebouncedPostScanSync()
                return finalP
            }
            await MainActor.run {
                scanError = "Créditez d’abord assez de points pour ce palier (\(tier.points) pts), ou augmentez le montant du panier."
                appState.showError(scanError ?? "")
            }
            return nil
        } catch {
            await MainActor.run {
                let msg = APIError.merchantFacingMessage(from: error) ?? "Impossible d’appliquer la récompense."
                scanError = msg
                appState.showError(msg)
            }
            return nil
        }
    }
}

// MARK: - Chips destinataires (clair / sombre)

private struct RecipientCategoryChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let palette: DashboardRevolutPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? palette.chipSelectedFG : palette.chipUnselectedFG)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : palette.chipUnselectedBG, in: Capsule())
        }
        .buttonStyle(.borderless)
    }
}

#Preview {
    let container = PersistenceController.preview.container
    DashboardView()
        .environmentObject(DataService(context: container.viewContext))
        .environmentObject(SyncService(container: container))
        .environmentObject(AppState.shared)
        .environmentObject(MainTabRouter())
}
