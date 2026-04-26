//
//  ProfileView.swift
//  myfidpass
//
//  Onglet Commerce : identité commerçant, formulaire établissement, accès Réglages.
//

import SwiftUI
import CoreData
import UIKit

/// Navigation depuis l’onglet Commerce (hub Flyer — plus d’onglet Flyer dédié).
private enum CommerceFlyerDestination: Hashable {
    /// Assistant : premier écran type « Créer un flyer » (pas de flyer enregistré ou parcours création).
    case flyer
    /// Depuis l’aperçu « Votre flyer » : **Modifier** — même hub mais titre / flux édition (héros visible).
    case flyerForEdit
    case flyerAndMyCard
    /// Assistant IA : formulaire vierge pour une nouvelle création (confirmé dans l’alerte Commerce).
    case flyerRecreate
    /// Retour depuis **Modifier** : mêmes données que `flyer` mais sans réouvrir directement l’écran d’édition.
    case flyerFromEditBack
}

/// Stats : zoom fluide depuis la **barre** (icône graphique) et la **rangée « Statistiques »** (carte).
private enum CommerceZoomCanvasOverscan {
    static let inset: CGFloat = 88
}

private enum CommerceStatsZoomEntry: String, Identifiable, Hashable {
    case toolbar

    var id: String { rawValue }

    /// Doit être identique au `zoomTransitionSource` sur le contrôle qui ouvre les stats.
    var zoomSourceID: String {
        switch self {
        case .toolbar: return "commerce.stats.zoom.toolbar"
        }
    }
}

/// Masque partagé : panneau principal sous la barre noire, arrondi seulement en haut (noir en dessous pour masquer le canvas).
private enum CommerceTopCardPanel {
    static let shape = UnevenRoundedRectangle(
        topLeadingRadius: 24,
        bottomLeadingRadius: 0,
        bottomTrailingRadius: 0,
        topTrailingRadius: 24,
        style: .continuous
    )
}

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: SyncService
    @EnvironmentObject private var revenueCatSubscriptionState: RevenueCatSubscriptionState
    @EnvironmentObject private var tabRouter: MainTabRouter
    @Environment(\.isSoftwareKeyboardVisible) private var isSoftwareKeyboardVisible
    @StateObject private var dataService: DataService
    @State private var organizationName: String = ""
    @State private var logoURL: String = ""
    @State private var settingsSnapshot: BusinessSettingsResponse?
    @State private var flyerLooksCustomized = false
    /// Alimentés par `GET …/dashboard/flyer` pour le bloc flyer (aperçu Commerce).
    @State private var commerceFlyerShareURL: String = ""
    @State private var commerceFlyerCustomBgDataURL: String?
    /// JSON embed base64 (même source que l’éditeur) pour miniature **composite** (QR, roue, textes), pas seulement le fond IA.
    @State private var commerceFlyerBootstrapPreviewB64: String?
    @State private var showSettingsSheet = false
    @State private var showCommercePublicQRSheet = false
    @State private var showCommerceSavedFlyerLarge = false
    @State private var commerceNavPath = NavigationPath()
    @State private var commerceStatsPresentation: CommerceStatsZoomEntry?
    @Namespace private var commerceStatsZoomNamespace
    /// Une fois par lancement d’app : brouillon « Modifier le flyer » non enregistré → ouvrir l’éditeur sur le design en cours.
    @State private var didAutoResumeUnsavedFlyerSessionThisLaunch = false
    @State private var pendingUnsavedFlyerSessionNavigation = false

    init(context: NSManagedObjectContext) {
        _dataService = StateObject(wrappedValue: DataService(context: context))
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

    private var profileCanvas: Color {
        DashboardRevolutPalette(colorScheme: colorScheme).canvas
    }

    /// Même URL que la page client (SaaS « Lien et QR ») : `GET …/dashboard/flyer` puis repli `myfidpass.fr/fidelity/{slug}`.
    private var commercePublicPageURLString: String {
        let s = commerceFlyerShareURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty { return s }
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            return ""
        }
        return LegalURLs.fidelityCardPage(slug: slug)?.absoluteString ?? ""
    }

    var body: some View {
        commerceNavigationStack
            .animation(.spring(response: 0.68, dampingFraction: 0.88), value: commerceStatsPresentation)
            .fullScreenCover(item: $commerceStatsPresentation) { entry in
                merchantStatisticsRoot
                    .statsDetailZoomTransition(sourceID: entry.zoomSourceID, namespace: commerceStatsZoomNamespace)
                    .merchantFluidZoomFullScreenTransparentChrome()
            }
    }

    /// Contenu stats (identique barre / carte).
    private var merchantStatisticsRoot: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                commerceStatsFullscreenBackdrop
                MerchantStatisticsDashboardScreen(
                    glassOverlayPresentation: true,
                    onOverlayDismiss: { dismissMerchantStatisticsOverlay() }
                )
                .scrollContentBackground(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
        }
        .environment(\.managedObjectContext, viewContext)
        .environment(\.commerceStatsGlassOverlay, true)
    }

    /// Voile derrière le dashboard stats : flou live du Commerce + léger assombrissement (comme avant).
    @ViewBuilder
    private var commerceStatsFullscreenBackdrop: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            Color.black.opacity(0.22)
        }
        .environment(\.colorScheme, .dark)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var commerceNavigationStack: some View {
        NavigationStack(path: $commerceNavPath) {
                ZStack(alignment: .top) {
                    profileCanvas
                        .padding(-CommerceZoomCanvasOverscan.inset)
                        .ignoresSafeArea()
                    VStack(spacing: 0) {
                        Color.black
                            .frame(height: 140)
                        Spacer()
                    }
                    .padding(-CommerceZoomCanvasOverscan.inset)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()

                    VStack(spacing: 0) {
                        commerceTopBar
                        ZStack {
                            // Débord latéral + bas pour le zoom (pas le haut : sinon l’arrondi est poussé hors
                            // de la zone visible et le joint blanc / noir apparaît carré sur les côtés).
                            // Noir en dessous de la même forme : évite que le canvas (dégradé) ressortisse derrière l’arrondi.
                            Color.black
                                .padding(.horizontal, -CommerceZoomCanvasOverscan.inset)
                                .padding(.bottom, -CommerceZoomCanvasOverscan.inset)
                                .clipShape(CommerceTopCardPanel.shape)
                                .ignoresSafeArea(edges: .bottom)
                                .allowsHitTesting(false)
                            AppTheme.Colors.cardBackground
                                .padding(.horizontal, -CommerceZoomCanvasOverscan.inset)
                                .padding(.bottom, -CommerceZoomCanvasOverscan.inset)
                                .clipShape(CommerceTopCardPanel.shape)
                                .ignoresSafeArea(edges: .bottom)
                                .allowsHitTesting(false)

                            ScrollView {
                                VStack(alignment: .leading, spacing: 16) {
                                    if shouldShowCommerceTrialSubscribePill, let trialEnd = authService.merchantTrialEndsAt {
                                    CommerceTrialPromoBannerView(trialEndsAt: trialEnd) {
                                        NotificationCenter.default.post(
                                            name: .myfidpassOpenMerchantSubscriptionSheet,
                                            object: nil
                                        )
                                    }
                                        .padding(.top, 10)
                                    }
                                    commerceSetupChecklistCard
                                        .padding(.top, shouldShowCommerceTrialSubscribePill ? 4 : 10)
                                        .onBoarding(4, cornerRadius: 20) {
                                            VStack(spacing: 6) {
                                                Text("Votre espace Commerce")
                                                    .font(.headline)
                                                Text("Créez votre flyer, configurez votre programme fidélité et consultez vos statistiques.")
                                                    .font(.caption)
                                                    .multilineTextAlignment(.center)
                                            }
                                        }
                                    Color.clear.frame(height: 20)
                                }
                                .padding(.horizontal, 14)
                                .padding(.bottom, 100)
                            }
                            .background(Color.clear)
                            .scrollIndicators(.hidden)
                            .refreshable {
                                await syncService.syncAfterServerMutation()
                                loadProfile()
                                await loadProfileFromServer()
                            }
                        }
                    }

                    if syncService.isSyncing && organizationName.isEmpty {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(AppTheme.Colors.primary)
                            Spacer()
                        }
                        .padding(.top, 120)
                    }
                }
                .animation(MerchantMotion.navigationPath, value: commerceNavPath.count)
                .navigationDestination(for: CommerceFlyerDestination.self) { dest in
                    switch dest {
                    case .flyer, .flyerForEdit, .flyerAndMyCard, .flyerRecreate, .flyerFromEditBack:
                        MerchantProgramHubView(
                            context: viewContext,
                            seedOpenMyCard: dest == .flyerAndMyCard,
                            seedRecreateFlyer: dest == .flyerRecreate,
                            seedOpenFlyerForEdit: dest == .flyerForEdit,
                            startInCreateFromEditBack: dest == .flyerFromEditBack,
                            liveCommerceSnapshot: dest == .flyerForEdit
                                ? CommerceFlyerLiveSnapshot(
                                    bootstrapPreviewB64: commerceFlyerBootstrapPreviewB64,
                                    customBgDataURL: commerceFlyerCustomBgDataURL,
                                    shareURL: commerceFlyerShareURL.isEmpty ? nil : commerceFlyerShareURL
                                )
                                : nil,
                            onFlyerSaveSuccessReturnToCommerce: {
                                withAnimation(MerchantMotion.navigationPath) {
                                    if !commerceNavPath.isEmpty {
                                        commerceNavPath.removeLast()
                                    }
                                }
                            },
                            onBackFromModifyToCreateFlyer: {
                                withAnimation(MerchantMotion.navigationPath) {
                                    if !commerceNavPath.isEmpty {
                                        commerceNavPath.removeLast()
                                    }
                                    commerceNavPath.append(CommerceFlyerDestination.flyerFromEditBack)
                                }
                            }
                        )
                        .environmentObject(syncService)
                        .environmentObject(authService)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                syncMerchantFlyerHubPresentation()
                loadProfile()
                hydrateCommerceFromDiskCache()
                tryAutoResumeUnsavedFlyerSessionIfNeeded()
                Task { await loadProfileFromServer() }
                // WKWebView pool : sans délai 2+ s, l’aperçu composite Commerce reste sur chargement long.
                DispatchQueue.main.async { FlyerEmbedWarmup.startIfNeeded() }
            }
            .onChange(of: flyerLooksCustomized) { _, _ in
                pushFlyerOnboardingSync()
            }
            .sheet(isPresented: $showSettingsSheet) {
                NavigationStack {
                    SettingsView()
                        .environmentObject(authService)
                        .environmentObject(syncService)
                        .environmentObject(revenueCatSubscriptionState)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .sheet(isPresented: $showCommercePublicQRSheet) {
                CommercePublicQRSheet(urlString: commercePublicPageURLString)
            }
            .fullScreenCover(isPresented: $showCommerceSavedFlyerLarge) {
                CommerceSavedFlyerLargePreviewView(
                    shareURL: commercePublicPageURLString,
                    customBgDataURL: commerceFlyerCustomBgDataURL,
                    bootstrapPreviewBase64: commerceFlyerBootstrapPreviewB64,
                    businessSlug: AuthStorage.currentBusinessSlug,
                    onDismiss: { showCommerceSavedFlyerLarge = false },
                    onEditFlyer: {
                        showCommerceSavedFlyerLarge = false
                        commerceNavPath.append(CommerceFlyerDestination.flyerForEdit)
                    },
                    onConfirmRecreate: {
                        showCommerceSavedFlyerLarge = false
                        commerceNavPath.append(CommerceFlyerDestination.flyerRecreate)
                    }
                )
            }
            .onChange(of: commerceNavPath) { _, newPath in
                syncMerchantFlyerHubPresentation()
                if !newPath.isEmpty {
                    /// Préchauffage embed dès l’entrée vers le hub (avant l’onglet seul) : réduit le cold `WKWebView`.
                    FlyerEmbedWarmup.startIfNeeded()
                }
                // Refresh flyer status when user returns from MerchantProgramHubView
                if newPath.isEmpty {
                    Task { await loadProfileFromServer() }
                }
            }
            .onChange(of: tabRouter.selectedTab) { _, newTab in
                syncMerchantFlyerHubPresentation()
                if newTab == 2 {
                    if pendingUnsavedFlyerSessionNavigation, commerceNavPath.isEmpty {
                        pendingUnsavedFlyerSessionNavigation = false
                        commerceNavPath.append(CommerceFlyerDestination.flyerForEdit)
                    }
                    DispatchQueue.main.async { FlyerEmbedWarmup.startIfNeeded() }
                    Task { await loadProfileFromServer() }
                } else {
                    dismissMerchantStatisticsOverlay()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .myfidpassRemoteSyncDidMerge)) { _ in
                guard tabRouter.selectedTab == 2 else { return }
                Task { await loadProfileFromServer() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .myfidpassOpenMerchantStatistics)) { _ in
                if tabRouter.selectedTab != 2 {
                    tabRouter.selectedTab = 2
                }
                showSettingsSheet = false
                DispatchQueue.main.async {
                    openMerchantStatisticsOverlay(from: .toolbar)
                }
            }
    }

    /// Bandeau 1 € dans le contenu Commerce (scroll) — masqué clavier / hub Flyer.
    private var shouldShowCommerceTrialSubscribePill: Bool {
        guard !isSoftwareKeyboardVisible else { return false }
        guard authService.isMerchantTrialPeriodActive, authService.merchantTrialEndsAt != nil else { return false }
        return commerceNavPath.isEmpty
    }

    /// Masque la pastille d’essai dans `ContentView` tant que le hub Flyer est affiché (Commerce + navigation).
    private func syncMerchantFlyerHubPresentation() {
        tabRouter.isMerchantFlyerHubPresented = tabRouter.selectedTab == 2 && !commerceNavPath.isEmpty
    }

    /// Même source que la page Notifs : `GET …/notification-icon` (icône dédiée), pas le logo Ma Carte.
    private var commerceNotificationIconURL: String? {
        let t = settingsSnapshot?.notificationIconUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !t.isEmpty else { return nil }
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else { return nil }
        let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let enc = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        return "\(base)/api/businesses/\(enc)/notification-icon"
    }

    @ViewBuilder
    private var commerceTopBarLeadingAvatar: some View {
        if let url = commerceNotificationIconURL {
            BusinessLogoView(
                logoURL: url,
                logoAssetContext: .campaignNotificationIcon,
                size: 34,
                cornerRadius: 10
            )
            .id(settingsSnapshot?.notificationIconUpdatedAt ?? "notification-icon")
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.green.opacity(0.9))
                .frame(width: 34, height: 34)
                .overlay {
                    Text(storeInitials)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.9))
                }
        }
    }

    private var commerceTopBar: some View {
        HStack(spacing: 12) {
            commerceTopBarLeadingAvatar
            Text(organizationName.isEmpty ? "Ma boutique" : organizationName)
                .font(.system(.headline, design: .default, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 6)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showCommercePublicQRSheet = true
            } label: {
                Image(systemName: "qrcode")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
            }
            .modifier(TopBarLiquidGlassButtonModifier())
            .accessibilityLabel("Afficher le QR code de la page fidélité")
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                openMerchantStatisticsOverlay(from: .toolbar)
            } label: {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .foregroundStyle(.white)
            }
            .modifier(TopBarLiquidGlassButtonModifier())
            .zoomTransitionSource(id: CommerceStatsZoomEntry.toolbar.zoomSourceID, in: commerceStatsZoomNamespace)
            .accessibilityLabel("Ouvrir les statistiques")
            Button {
                showSettingsSheet = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .foregroundStyle(.white)
            }
            .modifier(TopBarLiquidGlassButtonModifier())
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color.black)
    }

    private func openMerchantStatisticsOverlay(from entry: CommerceStatsZoomEntry) {
        commerceStatsPresentation = entry
    }

    private func dismissMerchantStatisticsOverlay() {
        commerceStatsPresentation = nil
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
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            pushFlyerOnboardingSync()
            return
        }
        guard let cached = CommerceFlyerStateCache.load(slug: slug) else {
            pushFlyerOnboardingSync()
            return
        }
        let hasBootstrap = !(cached.bootstrapPreviewB64 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasCustomBgFile = !(cached.customBgDataURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        flyerLooksCustomized = cached.flyerRegistered || hasBootstrap || hasCustomBgFile
        commerceFlyerShareURL = cached.shareURL
        if let b = cached.bootstrapPreviewB64, !b.isEmpty {
            commerceFlyerBootstrapPreviewB64 = FlyerBootstrapPreviewPayloadBuilder.normalizeWheelModeInBootstrapBase64(b, businessSlug: slug) ?? b
        }
        commerceFlyerCustomBgDataURL = cached.customBgDataURL
        pushFlyerOnboardingSync()
    }

    /// Brouillon local d’une session d’édition (sans enregistrement) : relance l’onglet « Modifier le flyer » avec l’aperçu en cours.
    private func tryAutoResumeUnsavedFlyerSessionIfNeeded() {
        guard !didAutoResumeUnsavedFlyerSessionThisLaunch else { return }
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty
        else { return }
        guard let d = CommerceFlyerEditorDraftStore.load(slug: slug) else { return }
        if d.meta.openedAsFlyerForEdit == false { return }
        let b = FlyerBootstrapPreviewPayloadBuilder.normalizeWheelModeInBootstrapBase64(d.bootstrapB64, businessSlug: slug) ?? d.bootstrapB64
        commerceFlyerBootstrapPreviewB64 = b
        if let c = d.meta.customBgDataURL, !c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            commerceFlyerCustomBgDataURL = c
        }
        let tr = d.meta.shareURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tr.isEmpty { commerceFlyerShareURL = tr }
        flyerLooksCustomized = true
        didAutoResumeUnsavedFlyerSessionThisLaunch = true
        if tabRouter.selectedTab == 2, commerceNavPath.isEmpty {
            commerceNavPath.append(CommerceFlyerDestination.flyerForEdit)
        } else if tabRouter.selectedTab != 2 {
            pendingUnsavedFlyerSessionNavigation = true
            tabRouter.selectedTab = 2
        }
    }

    /// Aligne le verrou d’onglets (MainTabRouter) avec le cache / le serveur.
    private func pushFlyerOnboardingSync() {
        let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if slug.isEmpty {
            tabRouter.syncFlyerOnboardingRequirement(flyerRegistered: false, hasBusinessSlug: false)
        } else {
            tabRouter.syncFlyerOnboardingRequirement(flyerRegistered: flyerLooksCustomized, hasBusinessSlug: true)
        }
    }

    private var commerceSetupChecklistCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                if flyerLooksCustomized {
                    CommerceFlyerSavedBlockView(
                        customBgDataURL: commerceFlyerCustomBgDataURL,
                        bootstrapPreviewBase64: commerceFlyerBootstrapPreviewB64,
                        businessSlug: AuthStorage.currentBusinessSlug,
                        onOpenFlyerHub: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showCommerceSavedFlyerLarge = true
                        }
                    )
                } else {
                    commerceFlyerCreateRow
                }
            }
            .commerceTabSectionCard(emphasizePrimaryAccent: false)

            if !EngagementTemporaryVisibility.hideGoogleReviewsUI {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image("SocialGoogle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text("Avis Google")
                            .font(.system(.title3, design: .default, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                    MerchantEstablishmentForm(
                        context: viewContext,
                        sections: .commerceGoogleStandalone
                    )
                    .environmentObject(syncService)
                }
                .commerceTabSectionCard(emphasizePrimaryAccent: true)
            }
        }
        .padding(16)
    }

    /// Ratio canvas flyer (identique à `CommerceFlyerSavedBlockView`) — miniature alignée sur le flyer réel.
    private static let commerceFlyerThumbAspect: CGFloat = 2400.0 / 3600.0

    private var commerceFlyerCreateRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Créez votre Flyer de jeu")
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Partagez-le en magasin ou en ligne : vos clients scannent le QR, ajoutent votre carte et jouent à la roue.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.leading)
                .lineSpacing(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Largeur 100 % du cadre (jamais de .frame(width:) fixe — ça dépassait l’écran sur petits iPhones).
            Image("flyervide")
                .resizable()
                .scaledToFit()
                .aspectRatio(Self.commerceFlyerThumbAspect, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                commerceNavPath.append(CommerceFlyerDestination.flyer)
            } label: {
                Text("Créer mon flyer de jeu")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(MerchantPressableButtonStyle())
            .flyerPrimaryCTAShake(shakeToken: tabRouter.flyerPrimaryCTAShakeToken)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: tabRouter.selectedTab) {
            guard tabRouter.selectedTab == 2 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled, tabRouter.selectedTab == 2 else { return }
                tabRouter.triggerFlyerPrimaryCTAAutoShake()
            }
        }
    }

    private var storeInitials: String {
        let source = organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        if source.isEmpty { return "Mb" }
        let words = source.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "Mb" : letters
    }

    private var userInitials: String {
        if let phone = authService.currentUserPhone?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty {
            let digits = phone.filter(\.isNumber)
            let tail = String(digits.suffix(2))
            return tail.isEmpty ? "ME" : tail
        }
        let mail = authService.currentUserEmail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !mail.isEmpty else { return "ME" }
        let local = mail.split(separator: "@").first.map(String.init) ?? mail
        let parts = local.split(whereSeparator: { $0 == "." || $0 == "_" || $0 == "-" }).prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0).uppercased() }.joined()
        return letters.isEmpty ? "ME" : letters
    }

    private func loadProfile() {
        let business = dataService.createOrGetCurrentBusiness()
        let template = dataService.currentCardTemplate()
        organizationName = template?.displayName ?? business.name ?? "Mon établissement"
        let cardLogo = template?.logoURL ?? business.logoURL ?? ""
        let icon = template?.logoIconURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        logoURL = icon.isEmpty ? cardLogo : icon
    }

    private func loadProfileFromServer() async {
        guard let slug = AuthStorage.currentBusinessSlug else { return }
        do {
            // Parallélise les deux GET (settings + flyer) — économise 1-3 s de latence séquentielle.
            async let settingsTask: BusinessSettingsResponse = APIClient.shared.request(APIEndpoint.businessSettings(slug: slug))
            async let flyerTask: DashboardFlyerGetResponse = APIClient.shared.request(APIEndpoint.dashboardFlyerGet(slug: slug))
            let (settings, flyer) = try await (settingsTask, flyerTask)
            await MainActor.run {
                settingsSnapshot = settings
                flyerLooksCustomized = flyer.commerceIndicatesFlyerRegistered
                let trimmedShare = (flyer.shareUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedShare.isEmpty {
                    commerceFlyerShareURL = LegalURLs.fidelityCardPage(slug: slug)?.absoluteString ?? ""
                } else {
                    commerceFlyerShareURL = trimmedShare
                }
                commerceFlyerCustomBgDataURL = flyer.flyerPrefs?.customBgDataUrl
                commerceFlyerBootstrapPreviewB64 = FlyerBootstrapPreviewPayloadBuilder.base64(from: flyer, businessSlug: slug)
                let engagement = engagementStepDone(from: settings)
                CommerceFlyerStateCache.save(
                    slug: slug,
                    flyerRegistered: flyerLooksCustomized,
                    shareURL: commerceFlyerShareURL,
                    bootstrapB64: commerceFlyerBootstrapPreviewB64,
                    engagementStepDone: engagement,
                    customBgDataURL: commerceFlyerCustomBgDataURL
                )
                CommerceFlyerPublicBackgroundWarmup.prefetchFromNetworkIfNoCustomBgInPrefs(
                    slug: slug,
                    customBgDataUrl: flyer.flyerPrefs?.customBgDataUrl
                )
                MerchantLogoAssetCache.applyMerchantLogoTimestamps(from: settings)
                CampaignNotificationImageCache.applyPreviewTimestamps(from: settings)
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
                pushFlyerOnboardingSync()
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
    ProfileView(context: PersistenceController.preview.container.viewContext)
        .environmentObject(AuthService())
        .environmentObject(SyncService(container: PersistenceController.preview.container))
        .environmentObject(RevenueCatSubscriptionState())
        .environmentObject(MainTabRouter())
}
