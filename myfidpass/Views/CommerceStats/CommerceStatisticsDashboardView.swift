//
//  CommerceStatisticsDashboardView.swift
//  myfidpass
//
//  Statistiques commerçant — refonte visuelle + feuille détail avec transition zoom (iOS 18+).
//

import CoreData
import SwiftUI
import UIKit

enum CommerceStatsRuntimeSession {
    static var hasRevealedEmbeddedDetailSections = false
}

struct CommerceStatisticsDashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var dataService: DataService
    @EnvironmentObject private var tabRouter: MainTabRouter
    @EnvironmentObject private var memberSearchCoordinator: MerchantMemberSearchCoordinator
    @Environment(\.merchantTabIsActive) private var merchantTabIsActive
    @ObservedObject var vm: MerchantStatsIndicatorsViewModel
    /// Ordre : index 0 = mois le plus récent, … 5 = M-5.
    let statsMonthKeys: [String]
    @Binding var selectedMonthIndex: Int
    let onClose: () -> Void
    var showsInlineCloseButton: Bool = true
    var showsTopTitle: Bool = true
    /// Présentation par-dessus Commerce : fond transparent, en-tête flou, bouton « X » (ref. Revolut).
    var glassOverlayMode: Bool = false

    @State private var accountingPackPresented = false
    @State private var panierReperePopupPresented = false
    @State private var socialMissionsSheetPresented = false
    @State private var socialMissionsConnectSubtitle = "Instagram · TikTok · Facebook · X — missions fidélité"
    @State private var showDeferredDetailSections = false
    /// Présentations KPI par mois — mises à jour uniquement quand les données changent (pas à chaque render).
    @State private var cachedMonthPresentations: [String: CommerceStatisticsPresentation] = [:]
    /// Présentation pour les sections de détail (« Plus de données ») — même logique.
    @State private var cachedDetailPresentation: CommerceStatisticsPresentation = CommerceStatisticsDataBuilder.build(stats: nil, evolution: [], panierRepereEuro: nil)
    /// Campagnes de notification — liste dérivée coûteuse (merge 3 sources), mise en cache.
    @State private var cachedNotificationCampaigns: [NotificationCampaignInsightDTO] = []
    @State private var statsScrollToTopTick = 0
    @State private var googleReviewsOpenAlert: GoogleReviewsOpenAlert?
    @State private var memberDetailSheetItem: MemberDetailSheetItem?
    @AppStorage(CommerceGoogleReviewsMonthHistory.storageKey) private var googleReviewsMonthlyHistoryJSON: String = "{}"

    private enum GoogleReviewsOpenAlert: Identifiable {
        case missingPlace
        case systemOpenFailed

        var id: String {
            switch self {
            case .missingPlace: return "missing"
            case .systemOpenFailed: return "openFailed"
            }
        }
    }

    /// Espace sous le titre du carrousel KPI, entre carrousel et points (inchangé, lisible).
    private let kpiClusterVerticalSpacing: CGFloat = 8
    /// Espace **minimal** entre la carte Membres et la ligne Panier / Fréquence.
    private let kpiMembersToPanierRowSpacing: CGFloat = 2
    /// Respiration supplémentaire sous le titre KPI avant la carte Membres.
    private let kpiMonthTitleBottomInset: CGFloat = 4
    /// Réduction visuelle très légère des cartes KPI (proche 1 = bloc Membres / Panier / Fréquence plus large).
    private let kpiCardsMicroScale: CGFloat = 0.955
    /// Panier moyen + Fréquence : un tout petit peu plus petits que Membres.
    private let kpiPanierFreqExtraScale: CGFloat = 0.965
    /// Marge latérale sur la rangée Panier / Fréquence (faible = presque alignée sur Membres, section plus large).
    private let kpiPanierFreqRowHorizontalInset: CGFloat = 0
    /// Espace entre les deux tuiles Panier / Fréquence.
    private let kpiPanierFreqInterItemSpacing: CGFloat = 12
    /// Marge latérale pour voir un aperçu du mois précédent / suivant (réduite = pages KPI un peu plus larges).
    private let kpiMonthCarouselPeek: CGFloat = 6
    private let kpiMonthCarouselItemSpacing: CGFloat = 10
    /// Déborde légèrement hors du `contentGutter` pour élargir visuellement Membres / Panier / Fréquence.
    private let kpiBlockHorizontalOutdent: CGFloat = 6
    /// Padding interne gauche des tuiles KPI (titres « Membres », « Panier moyen », etc.).
    private let kpiCardContentLeadingInset: CGFloat = 18
    /// Aligne "Plus de données" sur la largeur visuelle des KPI réduits.
    private let detailSectionsHorizontalInset: CGFloat = 8
    /// Marge supplémentaire entre le carrousel KPI (panier / fréquence) et « Plus de données ».
    private let kpiToDetailSectionsTopInset: CGFloat = 22
    private let contentGutter: CGFloat = 16

    /// Statistiques détaillées (hors carte Membres) : essai, abo, admin ou équipe.
    private var commerceStatsInsightsUnlocked: Bool {
        authService.merchantProInsightsUnlocked
    }

    private var isStampsProgram: Bool {
        CommerceStatsProgramKind.isStamps(vm.loyaltyProgramType)
    }

    private static let socialApiToButtonId: [String: String] = [
        "social-instagram": "instagram",
        "social-tiktok": "tiktok",
        "social-facebook": "facebook",
        "social-twitter": "x",
    ]

    private var connectedSocialNetworkButtonIds: Set<String> {
        Set(
            vm.configuredSocialHandles.compactMap { apiId, handle -> String? in
                guard let btnId = Self.socialApiToButtonId[apiId] else { return nil }
                let u = handle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !u.isEmpty else { return nil }
                return btnId
            }
        )
    }

    private var allSocialNetworksConfigured: Bool {
        connectedSocialNetworkButtonIds.count >= CommerceStatsConnectNetworksButton.allNetworks.count
    }

    @State private var detailCacheRefreshTask: Task<Void, Never>?

    /// Marge intérieure sous la rangée panier / fréquence (serrée : pastilles proches des tuiles).
    private let kpiScrollContentBottomPadding: CGFloat = 2
    /// Hauteur du carrousel = contenu réel (alignée sur la carte Membres **sans** frame 236 artificiel).
    /// 12 pt top + en-tête (~82) + graphique 104 + marge sécurité typo ; évite le grand vide sous le graphe.
    private func kpiMonthCarouselViewportHeight(pageWidth: CGFloat) -> CGFloat {
        let membersCardHeight: CGFloat = 12 + 90 + 104 + 6
        let rowContentWidth = pageWidth - 2 * kpiPanierFreqRowHorizontalInset
        let panierFreqRowHeight = max(0, (rowContentWidth - kpiClusterVerticalSpacing) / 2)
        return membersCardHeight + kpiMembersToPanierRowSpacing + panierFreqRowHeight + kpiScrollContentBottomPadding
    }

    /// Bloc KPI : largeur de contenu alignée sur le padding de l’écran (évite de recalculer la hauteur quand les données arrivent).
    private var stableKpiContentWidth: CGFloat {
        let w = UIScreen.main.bounds.width
        return w - 2 * contentGutter + 2 * kpiBlockHorizontalOutdent
    }

    private var stableKpiPageWidth: CGFloat {
        max(120, stableKpiContentWidth - 2 * kpiMonthCarouselPeek)
    }

    private var stableKpiCarouselBlockHeight: CGFloat {
        kpiMonthCarouselViewportHeight(pageWidth: stableKpiPageWidth)
    }

    /// Côté des tuiles carrées Panier / Fréquence (même sur tous les mois du carrousel).
    private var stablePanierFreqCellSide: CGFloat {
        let rowW = stableKpiPageWidth - 2 * kpiPanierFreqRowHorizontalInset
        return max(0, (rowW - kpiPanierFreqInterItemSpacing) / 2)
    }

    private let membersKpiCardFixedHeight: CGFloat = 12 + 90 + 104 + 6

    /// Overlay : la vue est **déjà** dans la zone sûre (`NavigationStack` / `ZStack`).
    /// Ne pas ajouter encore `window.safeAreaInsets.top` — ça doublait l’écart et « fixait » un vide énorme.
    private let statsOverlayCloseTopInset: CGFloat = 2
    /// Hauteur visuelle du bouton croix (frame 34 + marge pour le titre en dessous).
    private let statsOverlayCloseButtonBlockHeight: CGFloat = 38

    /// Marge scroll : titre « Statistiques » juste sous la ligne de la croix (sans doubler le safe area).
    private var statsScrollContentTopPadding: CGFloat {
        if glassOverlayMode {
            return statsOverlayCloseTopInset + statsOverlayCloseButtonBlockHeight + 6
        }
        return 4
    }

    /// Mode overlay (verre) : tap sur le « vide » (fond) sous/entre zones non interactives ferme l’écran.
    private var statsGlassTapBackdropMinHeight: CGFloat {
        max(UIScreen.main.bounds.height - 48, 300)
    }

    /// Recalcule les tuiles du carrousel KPI (tous les mois) — coûteux : à n’appeler que quand les snapshots ou le paywall changent, **pas** au simple swipe de mois.
    private func refreshMonthCarouselCachesOnly() {
        let demoPayloads = CommerceStatisticsPreviewMock.payloadsByMonthKeys(statsMonthKeys)
        let unlocked = commerceStatsInsightsUnlocked

        var updated: [String: CommerceStatisticsPresentation] = [:]
        updated.reserveCapacity(statsMonthKeys.count)
        for key in statsMonthKeys {
            let realPres = vm.presentationForMonthCarousel(monthKey: key)
            if unlocked {
                updated[key] = realPres
            } else if let mockPayload = demoPayloads[key] {
                let mockPres = CommerceStatisticsDataBuilder.build(
                    stats: mockPayload.stats,
                    evolution: mockPayload.evolution,
                    panierRepereEuro: mockPayload.stats.baselineAvgBasketEur,
                    programType: vm.loyaltyProgramType,
                    configuredSocialHandles: vm.configuredSocialHandles
                )
                updated[key] = CommerceStatisticsDataBuilder.paywallTeaserMerging(real: realPres, mock: mockPres)
            } else {
                updated[key] = realPres
            }
        }
        cachedMonthPresentations = updated
    }

    /// Section « Plus de données » + campagnes : léger — peut suivre le mois sélectionné sans recalculer tout le carrousel.
    private func refreshDetailCachesOnly() {
        let demoPayloads = CommerceStatisticsPreviewMock.payloadsByMonthKeys(statsMonthKeys)
        let unlocked = commerceStatsInsightsUnlocked
        let key = selectedMonthKey
            ?? statsMonthKeys.last
            ?? CommerceStatsMonthNavigator.calendarMonthKey(for: Date())

        if unlocked {
            if let pres = cachedMonthPresentations[key] {
                cachedDetailPresentation = pres
            } else {
                cachedDetailPresentation = vm.presentationForMonthCarousel(monthKey: key)
            }
            cachedNotificationCampaigns = vm.notificationCampaigns(forMonthKey: key)
        } else if let mockPayload = demoPayloads[key] {
            let realPres = vm.presentationForMonthCarousel(monthKey: key)
            let mockPres = CommerceStatisticsDataBuilder.build(
                stats: mockPayload.stats,
                evolution: mockPayload.evolution,
                panierRepereEuro: mockPayload.stats.baselineAvgBasketEur,
                programType: vm.loyaltyProgramType,
                configuredSocialHandles: vm.configuredSocialHandles
            )
            cachedDetailPresentation = CommerceStatisticsDataBuilder.paywallTeaserMerging(real: realPres, mock: mockPres)
            cachedNotificationCampaigns = CommerceStatisticsPreviewMock.paywallTeaserNotificationCampaigns
        } else {
            cachedDetailPresentation = CommerceStatisticsDataBuilder.build(stats: nil, evolution: [], panierRepereEuro: nil)
            cachedNotificationCampaigns = CommerceStatisticsPreviewMock.paywallTeaserNotificationCampaigns
        }
    }

    private func updateMonthCarouselCache(forMonthKey key: String) {
        guard statsMonthKeys.contains(key) else {
            refreshMonthCarouselCachesOnly()
            return
        }
        let demoPayloads = CommerceStatisticsPreviewMock.payloadsByMonthKeys(statsMonthKeys)
        let unlocked = commerceStatsInsightsUnlocked
        let realPres = vm.presentationForMonthCarousel(monthKey: key)
        let newPres: CommerceStatisticsPresentation = {
            if unlocked { return realPres }
            if let mockPayload = demoPayloads[key] {
                let mockPres = CommerceStatisticsDataBuilder.build(
                    stats: mockPayload.stats,
                    evolution: mockPayload.evolution,
                    panierRepereEuro: mockPayload.stats.baselineAvgBasketEur,
                    programType: vm.loyaltyProgramType,
                    configuredSocialHandles: vm.configuredSocialHandles
                )
                return CommerceStatisticsDataBuilder.paywallTeaserMerging(real: realPres, mock: mockPres)
            }
            return realPres
        }()
        var next = cachedMonthPresentations
        next[key] = newPres
        cachedMonthPresentations = next
    }

    private func refreshCachedPresentations() {
        refreshMonthCarouselCachesOnly()
        refreshDetailCachesOnly()
    }

    private func presentCommerceStatsPaywall() {
        NotificationCenter.default.postOpenMerchantSubscriptionFromSession(
            usedBusinesses: authService.usedBusinesses,
            allowedBusinesses: authService.allowedBusinesses,
            hasActiveSubscription: authService.hasEncashedMerchantSubscription
        )
    }

    private func openCommerceGoogleReviewsOnMaps() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            googleReviewsOpenAlert = .missingPlace
            return
        }
        let mapsContext = commerceStatsGoogleMapsContext(for: slug)
        let instant = CommerceStatsGoogleMapsOpener.openMapsReviews(for: slug, context: mapsContext)
        if instant == .opened { return }
        Task { @MainActor in
            let result = await CommerceStatsGoogleMapsOpener.openMapsReviewsResolvingIfNeeded(for: slug, context: mapsContext)
            switch result {
            case .opened:
                break
            case .missingPlace:
                googleReviewsOpenAlert = .missingPlace
            case .systemOpenFailed:
                googleReviewsOpenAlert = .systemOpenFailed
            }
        }
    }

    private func commerceStatsGoogleMapsContext(for slug: String) -> CommerceStatsGoogleMapsContext {
        CommerceStatsGoogleMapsContext.fromAuth(
            businesses: authService.businesses,
            slug: slug,
            cachedSettings: ScanFlowSettingsCache.cached(for: slug)
        )
    }

    private func prefetchCommerceGoogleMapsReviewsURL() {
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else { return }
        CommerceStatsGoogleMapsOpener.prefetchMapsReviewsURL(for: slug, context: commerceStatsGoogleMapsContext(for: slug))
    }

    private var selectedMonthKey: String? {
        guard statsMonthKeys.indices.contains(selectedMonthIndex) else { return nil }
        return statsMonthKeys[selectedMonthIndex]
    }

    /// Libellé carrousel (ex. « En mai »).
    private var kpiCarouselMonthHeading: String {
        let key = selectedMonthKey ?? CommerceStatsMonthNavigator.calendarMonthKey(for: Date())
        return CommerceStatsMonthNavigator.displayTitleInMonth(forMonthKey: key)
    }

    /// Alignement gauche du titre mois et des pastilles = texte des tuiles KPI.
    private var kpiChromeLeadingInset: CGFloat {
        kpiMonthCarouselPeek + kpiCardContentLeadingInset
    }

    /// Spinner uniquement au tout premier chargement (aucune donnée locale pour ce mois).
    private var showBlockingStatsLoading: Bool {
        guard let key = selectedMonthKey else { return vm.isLoading }
        return vm.isLoading && vm.businessStats(forMonthKey: key) == nil
    }

    /// Index d’onglet carrousel (0 = mois le plus ancien dans le swipe, n−1 = mois le plus récent).
    private var currentMonthCarouselTabIndex: Int {
        let n = statsMonthKeys.count
        guard n > 0 else { return 0 }
        let logic = min(max(selectedMonthIndex, 0), n - 1)
        return (n - 1) - logic
    }

    private var monthCarouselScrollTabBinding: Binding<Int?> {
        Binding(
            get: {
                statsMonthKeys.isEmpty ? nil : currentMonthCarouselTabIndex
            },
            set: { newId in
                guard let tabIdx = newId else { return }
                let n = statsMonthKeys.count
                guard n > 0 else { return }
                let clamped = min(max(tabIdx, 0), n - 1)
                selectedMonthIndex = (n - 1) - clamped
            }
        )
    }

    private var statsPageCanvas: Color {
        DashboardRevolutPalette(colorScheme: colorScheme).canvas
    }

    var body: some View {
        statsDashboardLifecycleLayer
    }

    private var statsDashboardLifecycleLayer: some View {
        applyStatsDashboardAlerts(
            applyStatsDashboardNotificationObservers(
                applyStatsDashboardLifecycleObservers(statsDashboardPresentationLayer)
            )
        )
    }

    @ViewBuilder
    private func applyStatsDashboardLifecycleObservers<V: View>(_ content: V) -> some View {
        content
            .onDisappear {
                detailCacheRefreshTask?.cancel()
                detailCacheRefreshTask = nil
                panierReperePopupPresented = false
                showDeferredDetailSections = false
                tabRouter.isCommerceStatsAtRoot = true
            }
            .onAppear {
                vm.syncLoyaltyProgramTypeFromLocalSources()
                refreshMonthCarouselCachesOnly()
                refreshDetailCachesOnly()
                syncCommerceStatsSubscribePillVisibility()
                revealDeferredDetailSectionsIfNeeded()
                resetStatsScrollToTop(animated: false)
                prefetchCommerceGoogleMapsReviewsURL()
                Task { await refreshSocialMissionsConnectSubtitle() }
            }
            .onChange(of: merchantTabIsActive) { _, active in
                guard active, isEmbeddedCommerceStats else { return }
                vm.syncLoyaltyProgramTypeFromLocalSources()
                refreshCachedPresentations()
                revealDeferredDetailSectionsIfNeeded()
                resetStatsScrollToTop(animated: false)
            }
            .onChange(of: AuthStorage.currentBusinessSlug) { _, newSlug in
                let s = newSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !s.isEmpty else { return }
                vm.resetForBusinessSwitch(slug: s)
                refreshCachedPresentations()
                Task { await loadMonthForCurrentSelection(forceRefresh: true) }
            }
            .onChange(of: vm.lastSuccessfullyLoadedPeriod) { _, newPeriod in
                let p = newPeriod?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !p.isEmpty, statsMonthKeys.contains(p) {
                    updateMonthCarouselCache(forMonthKey: p)
                    refreshDetailCachesOnly()
                } else {
                    refreshCachedPresentations()
                }
            }
            .onChange(of: vm.baselinePanierRepereEUR) { _, _ in
                refreshCachedPresentations()
            }
            .onChange(of: accountingPackPresented) { _, presented in
                if presented {
                    panierReperePopupPresented = false
                }
                syncCommerceStatsSubscribePillVisibility()
            }
            .onChange(of: panierReperePopupPresented) { _, _ in
                syncCommerceStatsSubscribePillVisibility()
            }
            .onChange(of: socialMissionsSheetPresented) { _, _ in
                syncCommerceStatsSubscribePillVisibility()
            }
            .task(id: selectedMonthIndex) {
                await loadMonthForCurrentSelection()
            }
    }

    @ViewBuilder
    private func applyStatsDashboardNotificationObservers<V: View>(_ content: V) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .myfidpassSocialMissionsDidSave)) { _ in
                Task { await refreshSocialMissionsConnectSubtitle() }
            }
            .onChange(of: authService.merchantSubscription?.status) { _, _ in
                refreshCachedPresentations()
            }
            .onChange(of: authService.isPlatformAdmin) { _, _ in
                refreshCachedPresentations()
            }
            .onChange(of: vm.loyaltyProgramType) { _, _ in
                refreshCachedPresentations()
            }
            .onReceive(NotificationCenter.default.publisher(for: .myfidpassCardPreviewDisplayDidChange)) { _ in
                vm.syncLoyaltyProgramTypeFromLocalSources()
                refreshCachedPresentations()
            }
            .onReceive(NotificationCenter.default.publisher(for: .myfidpassCommerceStatsTabDidBecomeSelected)) { _ in
                vm.syncLoyaltyProgramTypeFromLocalSources()
                refreshCachedPresentations()
                revealDeferredDetailSectionsIfNeeded()
                resetStatsScrollToTop(animated: false)
            }
            .onReceive(NotificationCenter.default.publisher(for: .myfidpassMerchantNotificationCampaignSent)) { _ in
                Task {
                    await vm.refreshNotificationStats(reloadMonthStats: false)
                    refreshDetailCachesOnly()
                }
            }
            .onChange(of: vm.configuredSocialHandles) { _, _ in
                refreshCachedPresentations()
            }
    }

    @ViewBuilder
    private func applyStatsDashboardAlerts<V: View>(_ content: V) -> some View {
        content
            .alert(item: $googleReviewsOpenAlert) { alert in
                switch alert {
                case .missingPlace:
                    Alert(
                        title: Text("Fiche Google introuvable"),
                        message: Text("Associez votre commerce à une fiche Google dans Mon établissement, puis réessayez."),
                        dismissButton: .cancel(Text("OK"))
                    )
                case .systemOpenFailed:
                    Alert(
                        title: Text("Ouverture impossible"),
                        message: Text("Google Maps n’a pas pu s’ouvrir. Réessayez ou vérifiez que l’app Maps est installée."),
                        dismissButton: .cancel(Text("OK"))
                    )
                }
            }
    }

    private var statsDashboardPresentationLayer: some View {
        statsDashboardZStack
            .overlay {
                if panierReperePopupPresented {
                    panierReperePopupOverlay
                }
            }
            .sheet(item: $memberDetailSheetItem) { item in
                if let card = viewContext.object(with: item.objectID) as? ClientCard {
                    MemberDetailView(card: card, context: viewContext)
                        .environmentObject(syncService)
                        .environmentObject(dataService)
                        .memberDetailSheetChrome()
                }
            }
            .sheet(isPresented: $accountingPackPresented) {
                NavigationStack {
                    MerchantAccountingPackView()
                }
                .presentationCornerRadius(28)
            }
            .sheet(isPresented: $socialMissionsSheetPresented) {
                if let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty {
                    SocialMissionsSheet(slug: slug) {
                        Task { await refreshSocialMissionsConnectSubtitle() }
                    }
                    .presentationCornerRadius(28)
                }
            }
    }

    private var statsDashboardZStack: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if glassOverlayMode {
                    Color.clear
                } else if isEmbeddedCommerceStats {
                    /// Onglet Statistiques : le canvas est déjà peint dans `ProfileView`.
                    Color.clear
                } else {
                    statsPageCanvas
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            /// Ne pas ignorer le haut : sinon le `ScrollView` peut perdre le safe area et passer sous la barre d’état / la top bar.
            .ignoresSafeArea(edges: [.horizontal, .bottom])

            if glassOverlayMode {
                statsAmbientBackdrop
                    .allowsHitTesting(false)
                    .ignoresSafeArea(edges: [.horizontal, .bottom])
            }

            statsDashboardScrollLayer

            if showBlockingStatsLoading {
                ProgressView()
                    .tint(glassOverlayMode ? .white : CommerceStatisticsTheme.accentBlue)
                    .padding(.top, glassOverlayMode ? statsScrollContentTopPadding + 18 : 14)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .allowsHitTesting(false)
            }

            if glassOverlayMode && showsInlineCloseButton {
                statsOverlayCloseButton
                    .zIndex(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
    }

    private var statsDashboardScrollLayer: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if glassOverlayMode {
                        ZStack(alignment: .top) {
                            Color.clear
                                .contentShape(Rectangle())
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: statsGlassTapBackdropMinHeight)
                                .onTapGesture { onClose() }
                                .accessibilityHidden(true)
                            statisticsScrollVStack
                                .zIndex(1)
                        }
                    } else {
                        statisticsScrollVStack
                    }
                }
                .id("commerce-stats-scroll-root")
            }
            .defaultScrollAnchor(.top)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .refreshable {
                await loadMonthForCurrentSelection(forceRefresh: true)
            }
            .onChange(of: statsScrollToTopTick) { _, _ in
                Task { @MainActor in
                    await Task.yield()
                    scrollStatsToTop(with: scrollProxy, animated: false)
                }
            }
        }
    }

    private var panierReperePopupOverlay: some View {
        ZStack {
            Color.black.opacity(0.38)
                .ignoresSafeArea()
                .onTapGesture {
                    panierReperePopupPresented = false
                }
            MerchantStatsPanierReperePopup(
                initialEuro: vm.baselinePanierRepereEUR,
                onClose: {
                    panierReperePopupPresented = false
                },
                onSave: { value, clear in
                    await savePanierRepere(value: value, clear: clear)
                }
            )
            .frame(maxWidth: 420)
            .padding(.horizontal, 22)
            .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: panierReperePopupPresented)
    }

    private func syncCommerceStatsSubscribePillVisibility() {
        tabRouter.isCommerceStatsAtRoot = !accountingPackPresented
            && !panierReperePopupPresented
            && !socialMissionsSheetPresented
    }

    /// Onglet Commerce : afficher tout de suite (pas de skeleton + yield qui décale le layout).
    private func revealDeferredDetailSectionsIfNeeded() {
        if isEmbeddedCommerceStats || CommerceStatsRuntimeSession.hasRevealedEmbeddedDetailSections {
            showDeferredDetailSections = true
            CommerceStatsRuntimeSession.hasRevealedEmbeddedDetailSections = true
            return
        }
        showDeferredDetailSections = false
        Task { @MainActor in
            await Task.yield()
            showDeferredDetailSections = true
            CommerceStatsRuntimeSession.hasRevealedEmbeddedDetailSections = true
        }
    }

    private func resetStatsScrollToTop(animated: Bool) {
        if animated {
            withAnimation(MerchantMotion.tabSwitch) {
                statsScrollToTopTick &+= 1
            }
        } else {
            statsScrollToTopTick &+= 1
        }
    }

    private func scrollStatsToTop(with proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(MerchantMotion.tabSwitch) {
                proxy.scrollTo("commerce-stats-scroll-root", anchor: .top)
            }
        } else {
            proxy.scrollTo("commerce-stats-scroll-root", anchor: .top)
        }
    }

    /// Contenu scrollé (KPI, sections) — dupliqué seulement en structure si/pas mode verre.
    @ViewBuilder
    private var statisticsScrollVStack: some View {
        VStack(alignment: .leading, spacing: 32) {
            if isEmbeddedCommerceStats && memberSearchCoordinator.isActive {
                MerchantMemberSearchInlineSection { oid in
                    memberDetailSheetItem = MemberDetailSheetItem(objectID: oid)
                }
                    .padding(.top, statsScrollContentTopPadding)
            } else {
                statisticsTopChrome
                    .padding(.top, statsScrollContentTopPadding)

                kpiCarouselSection

                Group {
                    if showDeferredDetailSections {
                        detailSectionsBelowCarousel
                    } else {
                        deferredSectionsSkeleton
                    }
                }
                .padding(.top, kpiToDetailSectionsTopInset)
                .padding(.horizontal, detailSectionsHorizontalInset)

                if let err = vm.errorMessage, !err.isEmpty {
                    Text(err)
                        .font(CommerceStatisticsTheme.statsText(size: 15, weight: .regular))
                        .foregroundStyle(CommerceStatisticsTheme.negative.opacity(glassOverlayMode ? 1 : 0.9))
                        .padding(.vertical, 8)
                }

                Color.clear.frame(height: 44)
            }
        }
        .padding(.horizontal, contentGutter)
        .padding(.bottom, 12)
        .animation(MerchantMotion.searchBarMorph, value: memberSearchCoordinator.isActive)
    }

    private var isEmbeddedCommerceStats: Bool {
        !glassOverlayMode && !showsTopTitle
    }

    private var deferredSectionsSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chargement des données détaillées…")
                .font(CommerceStatisticsTheme.statsText(size: 14, weight: .semibold))
                .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: glassOverlayMode).opacity(0.82))
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(glassOverlayMode ? 0.08 : 0.05))
                .frame(height: 92)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(glassOverlayMode ? 0.08 : 0.05))
                .frame(height: 92)
        }
    }

    private func refreshSocialMissionsConnectSubtitle() async {
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            await MainActor.run {
                socialMissionsConnectSubtitle = "Instagram · TikTok · Facebook · X — missions fidélité"
                vm.updateConfiguredSocialHandles([:])
            }
            return
        }
        do {
            let resp: SocialMissionsResponse = try await APIClient.shared.request(.dashboardSocialMissions(slug: slug))
            let mapping: [(networkId: String, tag: String, cfg: SocialMissionConfig?)] = [
                ("social-instagram", "IG", resp.instagram),
                ("social-tiktok", "TikTok", resp.tiktok),
                ("social-facebook", "FB", resp.facebook),
                ("social-twitter", "X", resp.twitter),
            ]
            var handles: [String: String] = [:]
            let connected = mapping.compactMap { item -> String? in
                guard let cfg = item.cfg, cfg.enabled else { return nil }
                let u = cfg.username.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !u.isEmpty else { return nil }
                handles[item.networkId] = u
                return "\(item.tag) @\(u)"
            }
            await MainActor.run {
                vm.updateConfiguredSocialHandles(handles)
                let rewardHint = isStampsProgram ? "1 tampon cumulé" : "points offerts"
                socialMissionsConnectSubtitle = connected.isEmpty
                    ? "Configurer les @ et les \(rewardHint)"
                    : connected.joined(separator: " · ")
            }
        } catch {
            if !APIError.isBenignRequestCancellation(error) {
                await MainActor.run {
                    socialMissionsConnectSubtitle = "Instagram · TikTok · Facebook · X — missions fidélité"
                }
            }
        }
    }

    // MARK: - Ambiance

    /// Fond ambiance allégé : version statique peu coûteuse (évite GeometryReader + gros blurs).
    private var statsAmbientBackdrop: some View {
        let top = glassOverlayMode ? Color(red: 0.16, green: 0.22, blue: 0.34).opacity(0.22) : Color(red: 0.20, green: 0.27, blue: 0.40).opacity(0.28)
        let bottom = glassOverlayMode ? Color(red: 0.10, green: 0.24, blue: 0.18).opacity(0.16) : Color(red: 0.12, green: 0.30, blue: 0.22).opacity(0.22)
        return LinearGradient(
            colors: [top, bottom, Color.clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @MainActor
    private func loadMonthForCurrentSelection(forceRefresh: Bool = false) async {
        guard let key = selectedMonthKey else { return }
        if vm.isDemoSixMonthPreviewActive {
            vm.applyDemoPayload(forMonthKey: key)
            return
        }
        if let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty {
            vm.prepareMonthNavigation(slug: slug, allMonthKeys: statsMonthKeys, focusPeriod: key)
        }
        await vm.load(period: key, forceRefresh: forceRefresh)
    }

    @ViewBuilder
    private var statsOverlayCloseButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(CommerceStatisticsTheme.statsText(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
        }
        .background(Circle().fill(Color.white))
        .overlay(
            Circle()
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        )
        .accessibilityLabel("Fermer les statistiques")
        .padding(.leading, contentGutter)
        .padding(.top, statsOverlayCloseTopInset)
    }

    @ViewBuilder
    private var statisticsTopChrome: some View {
        let g = glassOverlayMode
        VStack(alignment: .leading, spacing: 18) {
            if !g, showsInlineCloseButton {
                HStack(alignment: .center) {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .font(CommerceStatisticsTheme.statsText(size: 15, weight: .semibold))
                            .foregroundStyle(CommerceStatisticsTheme.pageTitle(forGlassOverlay: g))
                            .frame(width: 34, height: 34)
                    }
                    .background(Circle().fill(Color.white))
                    .overlay(
                        Circle()
                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                    )
                    .accessibilityLabel("Retour")
                    Spacer(minLength: 0)
                }
            }

            if showsTopTitle {
                Text("Statistiques")
                    .font(Font.system(size: 34, weight: .heavy, design: .default))
                    .foregroundStyle(CommerceStatisticsTheme.pageTitle(forGlassOverlay: g))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 6)
    }

    @ViewBuilder
    private var kpiCarouselSection: some View {
        if statsMonthKeys.isEmpty {
            EmptyView()
        } else {
            kpiCarouselSectionContent
        }
    }

    @ViewBuilder
    private var kpiCarouselSectionContent: some View {
        let g = glassOverlayMode
        VStack(alignment: .leading, spacing: kpiClusterVerticalSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(kpiCarouselMonthHeading)
                    .font(CommerceStatisticsTheme.statsChromeSectionTitle(size: 32, weight: .bold))
                    .foregroundStyle(CommerceStatisticsTheme.pageTitle(forGlassOverlay: g))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.leading, kpiChromeLeadingInset)
            .padding(.bottom, kpiMonthTitleBottomInset)

            VStack(alignment: .leading, spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    // `LazyHStack` casse le paging / `scrollTargetLayout` : pages KPI vides ou hors écran.
                    HStack(spacing: kpiMonthCarouselItemSpacing) {
                        ForEach(Array(statsMonthKeys.indices), id: \.self) { tabIdx in
                            let logicIdx = statsMonthKeys.count - 1 - tabIdx
                            let monthKey = statsMonthKeys[logicIdx]
                            if abs(tabIdx - currentMonthCarouselTabIndex) <= 1 {
                                kpiCluster(forMonthKey: monthKey, panierFreqCellSide: stablePanierFreqCellSide)
                                    .frame(width: stableKpiPageWidth)
                                    .id(tabIdx)
                            } else {
                                Color.clear
                                    .frame(width: stableKpiPageWidth, height: stableKpiCarouselBlockHeight)
                                    .id(tabIdx)
                            }
                        }
                    }
                    .padding(.bottom, kpiScrollContentBottomPadding)
                    .scrollTargetLayout()
                    .padding(.horizontal, kpiMonthCarouselPeek)
                }
                .scrollTargetBehavior(.viewAligned)
                .defaultScrollAnchor(.trailing)
                .scrollPosition(id: monthCarouselScrollTabBinding)
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: stableKpiCarouselBlockHeight, alignment: .top)

                monthCarouselPageIndicator
            }
            .onChange(of: selectedMonthIndex) { old, new in
                guard old != new else { return }
                detailCacheRefreshTask?.cancel()
                detailCacheRefreshTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(120))
                    guard !Task.isCancelled else { return }
                    refreshDetailCachesOnly()
                }
                if !accessibilityReduceMotion {
                    let g = UISelectionFeedbackGenerator()
                    g.prepare()
                    g.selectionChanged()
                }
            }
        }
        .padding(.horizontal, -kpiBlockHorizontalOutdent)
    }

    @ViewBuilder
    private var monthCarouselPageIndicator: some View {
        let n = statsMonthKeys.count
        let g = glassOverlayMode
        let active = currentMonthCarouselTabIndex
        let activePill = Color.black.opacity(0.92)
        let pillOn: CGFloat = 24
        let pillOff: CGFloat = 6
        if n > 1 {
            HStack(spacing: 0) {
                ForEach(0..<n, id: \.self) { idx in
                    Button {
                        selectedMonthIndex = (n - 1) - idx
                    } label: {
                        Capsule()
                            .fill(idx == active ? activePill : Color.black.opacity(g ? 0.24 : 0.18))
                            .frame(width: idx == active ? pillOn : pillOff, height: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, kpiChromeLeadingInset)
            .padding(.top, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Mois affiché")
            .accessibilityValue("\(active + 1) sur \(n)")
        }
    }

    @ViewBuilder
    private func kpiCluster(forMonthKey monthKey: String, panierFreqCellSide: CGFloat) -> some View {
        let pres = cachedMonthPresentations[monthKey] ?? CommerceStatisticsDataBuilder.build(stats: nil, evolution: [], panierRepereEuro: nil)
        let monthStats = vm.businessStats(forMonthKey: monthKey)
        VStack(alignment: .leading, spacing: kpiMembersToPanierRowSpacing) {
            CommerceStatsLargeMetricCard(
                title: "Membres",
                value: newMembersTotalCartesValue(stats: monthStats, presentation: pres),
                valueCaption: nil,
                subtitle: newMembersInscriptionSubtitle(stats: monthStats),
                membersWeeklySparkline: pres.membersWeeklySparkline,
                segments: pres.donutSegments,
                onTap: { memberSearchCoordinator.activate() },
                showsMonthDayAxis: true,
                monthDayAxisLabels: pres.membersMonthAxisDays
            )
            .frame(height: membersKpiCardFixedHeight, alignment: .bottom)
            .scaleEffect(kpiCardsMicroScale, anchor: .top)
            .accessibilityLabel(newMembersCardAccessibilityLabel(stats: monthStats, presentation: pres))

            paywallGatedPanierFrequenceRow(presentation: pres, panierFreqCellSide: panierFreqCellSide)
                .padding(.horizontal, kpiPanierFreqRowHorizontalInset)
                .scaleEffect(kpiCardsMicroScale * kpiPanierFreqExtraScale, anchor: .top)
        }
    }

    @ViewBuilder
    private func paywallGatedPanierFrequenceRow(
        presentation: CommerceStatisticsPresentation,
        panierFreqCellSide: CGFloat
    ) -> some View {
        Group {
            if isStampsProgram {
                stampsPurchaseFrequencySquareRow(presentation: presentation, cellSide: panierFreqCellSide)
            } else {
                panierFrequenceSquareRow(presentation: presentation, cellSide: panierFreqCellSide) {
                    panierReperePopupPresented = true
                }
            }
        }
        .commerceStatsPaywallGated(
            locked: !commerceStatsInsightsUnlocked,
            glassOverlayMode: glassOverlayMode,
            accessibilityUnlockLabel: isStampsProgram
                ? "Déverrouiller avec Pro pour la fréquence d'achat et les avis Google"
                : "Déverrouiller avec Pro pour le panier moyen et les avis Google",
            onUnlock: { presentCommerceStatsPaywall() }
        )
    }

    @ViewBuilder
    private var detailSectionsBelowCarousel: some View {
        VStack(alignment: .leading, spacing: 28) {
            statsDetailSection(
                title: "Plus de données",
                accessibilityUnlockLabel: "Déverrouiller avec Pro pour le détail des statistiques"
            ) {
                CommerceStatsCategoryListCard(
                    rows: detailCategoryRows(from: cachedDetailPresentation.categoryRows),
                    onViewGoogleReviews: { openCommerceGoogleReviewsOnMaps() }
                ) { rowId in
                    guard rowId == "rewards" else { return }
                    accountingPackPresented = true
                }

                if !cachedNotificationCampaigns.isEmpty {
                    CommerceNotificationImpactListCard(
                        campaigns: cachedNotificationCampaigns,
                        notificationIconURL: commerceStatsInsightsUnlocked ? vm.statsNotificationIconURL : nil
                    )
                } else if commerceStatsInsightsUnlocked {
                    Text("Aucune notification envoyée sur ce mois.")
                        .font(CommerceStatisticsTheme.statsText(size: 14, weight: .medium))
                        .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: glassOverlayMode).opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            }

            statsDetailSection(
                title: "Engagement réseaux sociaux",
                accessibilityUnlockLabel: "Déverrouiller avec Pro pour les statistiques d’engagement réseaux sociaux",
                engagementManageAction: allSocialNetworksConfigured ? {
                    socialMissionsSheetPresented = true
                } : nil
            ) {
                CommerceStatsCategoryListCard(rows: cachedDetailPresentation.engagementRows)

                if !allSocialNetworksConfigured {
                    CommerceStatsConnectNetworksButton(
                        subtitle: socialMissionsConnectSubtitle,
                        connectedNetworkIds: connectedSocialNetworkButtonIds,
                        glassOverlayMode: glassOverlayMode,
                        isStampsProgram: isStampsProgram,
                        action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            socialMissionsSheetPresented = true
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func statsDetailSection<Content: View>(
        title: String,
        accessibilityUnlockLabel: String,
        engagementManageAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            CommerceStatsSectionHeader(
                title: title,
                titleFontSize: 18,
                titleWeight: .bold,
                onManage: engagementManageAction == nil ? nil : {
                    engagementManageAction?()
                }
            )

            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .commerceStatsPaywallGated(
                locked: !commerceStatsInsightsUnlocked,
                glassOverlayMode: glassOverlayMode,
                accessibilityUnlockLabel: accessibilityUnlockLabel,
                onUnlock: { presentCommerceStatsPaywall() }
            )
        }
    }

    private func detailCategoryRows(from rows: [CommerceCategoryRowData]) -> [CommerceCategoryRowData] {
        guard isStampsProgram else { return rows }
        return rows.filter { $0.id != "pts" && $0.id != "freq" }
    }

    private func stampsPurchaseFrequencySquareRow(
        presentation: CommerceStatisticsPresentation,
        cellSide: CGFloat
    ) -> some View {
        HStack(alignment: .top, spacing: kpiPanierFreqInterItemSpacing) {
            panierFreqSquareSlot(cellSide: cellSide) {
                purchaseFrequencyCompactKpiCard(presentation: presentation)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            panierFreqSquareSlot(cellSide: cellSide) {
                googleReviewsKpiCard(presentation: presentation)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func purchaseFrequencyCompactKpiCard(presentation: CommerceStatisticsPresentation) -> some View {
        let freqRow = presentation.categoryRows.first { $0.id == "freq" }
        let spark = freqRow?.visitFrequencyDetail?.sparkline ?? []
        let trend = freqRow?.visitFrequencyDetail?.trendPct ?? presentation.trendFrequenceDelta
        let trendPos = freqRow?.visitFrequencyDetail?.trendIsPositive ?? ((trend ?? 0) >= 0)
        let freqValue: String = {
            guard let f = presentation.frequenceParActif, f >= 1 else { return "—" }
            return StatsFR.formatDoubleSmart(max(1, f))
        }()

        return CommerceStatsCompactMetricCard(
            title: "Fréquence d'achat",
            value: freqValue,
            valueFontSize: 30,
            valueBadge: presentation.frequenceParActif != nil ? "/mois" : nil,
            valueBadgeColor: CommerceStatisticsTheme.accentBlue,
            trendText: trend.map { d in
                let sign = d >= 0 ? "+" : "−"
                let pct = StatsFR.formatPct(abs(d)).replacingOccurrences(of: " %", with: "%")
                return "\(sign)\(pct)"
            },
            trendPositive: trendPos,
            footnote: nil,
            onCardTap: nil,
            edgeToEdgeBottomChart: true,
            bottomChartHeight: 52
        ) {
            CommerceStatsMiniSparklineChart(
                weeks: spark.enumerated().map { i, v in
                    .init(id: "freq\(i)", label: "\(i + 1)", value: v)
                },
                lineColor: CommerceStatisticsTheme.accentBlue
            )
        }
    }

    private func panierFrequenceSquareRow(
        presentation: CommerceStatisticsPresentation,
        cellSide: CGFloat,
        onPanierTap: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: kpiPanierFreqInterItemSpacing) {
            panierFreqSquareSlot(cellSide: cellSide) {
                CommerceStatsCompactMetricCard(
                    title: "Panier moyen",
                    value: panierText(presentation: presentation),
                    valueFontSize: 32,
                    trendText: panierTrendText(presentation: presentation),
                    trendPositive: panierTrendPositive(presentation: presentation),
                    footnote: nil,
                    onCardTap: onPanierTap,
                    edgeToEdgeBottomChart: true,
                    bottomChartHeight: 52
                ) {
                    CommerceStatsPanierEvolutionChart(
                        values: presentation.panierWeeklySparkline,
                        dayLabels: presentation.panierMonthAxisDays
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            panierFreqSquareSlot(cellSide: cellSide) {
                googleReviewsKpiCard(presentation: presentation)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func googleReviewsKpiCard(presentation: CommerceStatisticsPresentation) -> some View {
        let monthKey = selectedMonthKey ?? statsMonthKeys.last
        let trend = googleReviewsTrendText(
            presentation: presentation,
            monthKey: monthKey
        )
        return CommerceStatsCompactMetricCard(
            title: "Avis Google",
            value: googleReviewsKpiValue(presentation: presentation),
            valueFontSize: 30,
            trendText: trend,
            trendPositive: trend != nil ? true : nil,
            forcePositiveTrendColor: true,
            footnote: nil,
            leadingIconAsset: "googleicon",
            leadingIconSize: 28,
            onCardTap: { openCommerceGoogleReviewsOnMaps() },
            edgeToEdgeBottomChart: true,
            bottomChartHeight: 34
        ) {
            CommerceStatsGoogleReviewsKpiFooter()
        }
        .onAppear {
            CommerceGoogleReviewsMonthHistory.persistIfNeeded(
                monthKey: monthKey,
                newReviews: presentation.googleReviewsNewInPeriod,
                historyJSON: &googleReviewsMonthlyHistoryJSON
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(googleReviewsKpiAccessibilityLabel(presentation: presentation, monthKey: monthKey))
        .accessibilityAddTraits(.isButton)
    }

    private func googleReviewsTrendText(
        presentation: CommerceStatisticsPresentation,
        monthKey: String?
    ) -> String? {
        CommerceGoogleReviewsMonthHistory.trendText(
            monthKey: monthKey,
            newReviews: presentation.googleReviewsNewInPeriod,
            historyJSON: googleReviewsMonthlyHistoryJSON
        )
    }

    private func googleReviewsTrendPositive(
        presentation: CommerceStatisticsPresentation,
        monthKey: String?
    ) -> Bool? {
        CommerceGoogleReviewsMonthHistory.trendIsPositive(
            monthKey: monthKey,
            newReviews: presentation.googleReviewsNewInPeriod,
            historyJSON: googleReviewsMonthlyHistoryJSON
        )
    }

    private func googleReviewsKpiAccessibilityLabel(
        presentation: CommerceStatisticsPresentation,
        monthKey: String?
    ) -> String {
        var parts = ["Avis Google", googleReviewsKpiValue(presentation: presentation)]
        if let trend = googleReviewsTrendText(presentation: presentation, monthKey: monthKey) {
            parts.append(trend)
        }
        parts.append("voir les avis")
        return parts.joined(separator: ", ")
    }

    private func googleReviewsKpiValue(presentation: CommerceStatisticsPresentation) -> String {
        let n = presentation.googleReviewsNewInPeriod
        guard n > 0 else { return "—" }
        return "+\(StatsFR.formatInt(n))"
    }

    /// Deux cartes carrées **même côté** (hauteur fixe, le texte ne redimensionne plus le bloc).
    private func panierFreqSquareSlot<Content: View>(cellSide: CGFloat, @ViewBuilder content: @escaping () -> Content) -> some View {
        content()
            .frame(width: cellSide, height: cellSide)
    }

    private func newMembersTotalCartesValue(stats: BusinessStatsResponse?, presentation: CommerceStatisticsPresentation) -> String {
        if let n = stats?.membersCount { return StatsFR.formatInt(n) }
        if let n = presentation.membersTotal { return StatsFR.formatInt(n) }
        return "—"
    }

    private func newMembersInscriptionSubtitle(stats: BusinessStatsResponse?) -> String? {
        guard stats != nil else { return "+00 nouveaux" }
        let n = stats?.newMembersInPeriod ?? stats?.newMembersLast30Days
        guard let n else { return "+00 nouveaux" }
        let formatted = StatsFR.formatInt(n)
        if n < 10 {
            return "+0\(formatted) nouveaux"
        }
        return "+\(formatted) nouveaux"
    }

    private func newMembersCardAccessibilityLabel(
        stats: BusinessStatsResponse?,
        presentation: CommerceStatisticsPresentation
    ) -> String {
        var parts: [String] = [
            "Nouveaux membres",
            "\(newMembersTotalCartesValue(stats: stats, presentation: presentation)) cartes au total",
        ]
        if let s = newMembersInscriptionSubtitle(stats: stats), !s.isEmpty {
            parts.append(s)
        }
        parts.append("Ouvrir le détail")
        return parts.joined(separator: ", ")
    }

    private func panierText(presentation: CommerceStatisticsPresentation) -> String {
        guard let p = presentation.panierMoyenEuro, p > 0 else { return "—" }
        return "\(StatsFR.formatEuro(p)) €"
    }

    private func frequenceMainText(presentation: CommerceStatisticsPresentation) -> String {
        guard let f = presentation.frequenceParActif, f >= 1 else { return "—" }
        return StatsFR.formatDoubleSmart(max(1, f)) + " visites"
    }

    private func frequenceUnitFootnote(presentation: CommerceStatisticsPresentation) -> String? {
        guard presentation.frequenceParActif != nil else { return nil }
        return "/mois"
    }

    private func panierTrendPositive(presentation: CommerceStatisticsPresentation) -> Bool? {
        if let m = presentation.panierMoyenEuro, let r = presentation.panierRepereEuro, r > 0 {
            return (m - r) >= 0
        }
        return presentation.trendPanierDeltaEuro.map { $0 >= 0 }
    }

    private func panierTrendText(presentation: CommerceStatisticsPresentation) -> String? {
        if let m = presentation.panierMoyenEuro, let r = presentation.panierRepereEuro, r > 0 {
            let delta = m - r
            let sign = delta >= 0 ? "+" : "−"
            return "\(sign)\(StatsFR.formatEuro(abs(delta)))€"
        }
        if let delta = presentation.trendPanierDeltaEuro {
            let sign = delta >= 0 ? "+" : "−"
            return "\(sign)\(StatsFR.formatEuro(abs(delta)))€"
        }
        return nil
    }

    private func panierRepereFootnote(presentation: CommerceStatisticsPresentation) -> String? {
        guard let r = presentation.panierRepereEuro else { return nil }
        return "Repère : \(StatsFR.formatEuro(r))€"
    }

    /// Badge « Touchez » uniquement tant qu’aucun panier / repère n’est renseigné.
    private func shouldShowPanierTouchHint(presentation: CommerceStatisticsPresentation) -> Bool {
        guard commerceStatsInsightsUnlocked else { return false }
        if vm.baselinePanierRepereEUR != nil { return false }
        if presentation.panierMoyenEuro != nil { return false }
        if presentation.panierRepereEuro != nil { return false }
        return true
    }

    /// Texte court pour la tuile à hauteur fixe (détail complet possible en appui long / accessibilité plus tard).
    private func panierFootnoteShort(presentation: CommerceStatisticsPresentation) -> String? {
        let m = presentation.panierMoyenEuro
        let r = presentation.panierRepereEuro
        if m == nil, r == nil {
            return "Touchez : repère € de comparaison"
        }
        if m == nil, let rep = r {
            return "Repère : \(StatsFR.formatEuro(rep)) € — touchez pour modifier"
        }
        if m != nil, r == nil {
            return "Touchez : enregistrer un repère"
        }
        return "vs repère"
    }

    @MainActor
    private func savePanierRepere(value: Double?, clear: Bool) async {
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            panierReperePopupPresented = false
            return
        }
        var patch = FullDashboardSettingsPatch()
        if clear {
            patch.clearBaselineAvgBasketEur = true
        } else if let v = value {
            patch.baselineAvgBasketEur = v
        }
        do {
            _ = try await APIClient.shared.request(APIEndpoint.patchDashboardSettings(slug: slug, patch: patch)) as EmptyResponse
            vm.setBaselinePanierRepereEUR(clear ? nil : value)
            vm.markStatsMutation(slug: slug, period: selectedMonthKey)
            await loadMonthForCurrentSelection(forceRefresh: true)
        } catch {
            /* réseau / 403 : la feuille se ferme ; l’utilisateur peut réessayer */
        }
        panierReperePopupPresented = false
    }

    private func freqTrendText(presentation: CommerceStatisticsPresentation) -> String? {
        guard let d = presentation.trendFrequenceDelta else { return nil }
        let sign = d >= 0 ? "+" : "−"
        let pct = StatsFR.formatPct(abs(d)).replacingOccurrences(of: " %", with: "%")
        return "\(sign)\(pct)"
    }

    private func freqTopBar(presentation: CommerceStatisticsPresentation) -> CGFloat {
        let f = presentation.frequenceParActif ?? 0
        return CGFloat(min(1, max(0.2, f / max(2, f + 1))))
    }

    private func freqBottomBar(presentation: CommerceStatisticsPresentation) -> CGFloat {
        let r = presentation.retentionPct.map { CGFloat($0 / 100) } ?? 0.35
        return min(1, max(0.15, 1 - r))
    }

}

// MARK: - Panier repère (popup centré — tap sur la tuile Panier moyen)

private struct MerchantStatsPanierReperePopup: View {
    let initialEuro: Double?
    let onClose: () -> Void
    let onSave: (Double?, Bool) async -> Void

    @FocusState private var amountFieldFocused: Bool
    @State private var amountText: String = ""
    @State private var isSaving = false
    @State private var invalidAttempt = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Text("Quel est votre panier moyen actuel ?")
                    .font(CommerceStatisticsTheme.statsText(size: 18, weight: .bold))
                    .foregroundStyle(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: false))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(CommerceStatisticsTheme.statsText(size: 13, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.82))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.88)))
                }
                .buttonStyle(.plain)
            }
            TextField("Ex. 24,90", text: $amountText)
                .keyboardType(.decimalPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(CommerceStatisticsTheme.statisticNumbers(size: 24, weight: .semibold))
                .foregroundStyle(Color.black)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.84))
                )
                .focused($amountFieldFocused)
            if initialEuro != nil {
                Button("Supprimer le repère", role: .destructive) {
                    Task { await performSave(allowClear: true) }
                }
                .font(CommerceStatisticsTheme.statsText(size: 15, weight: .semibold))
                .disabled(isSaving)
            }
            buttonEnregistrerLarge
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.clear)
        )
        .modifier(MerchantPanierRepereLiquidGlassModifier())
        .onAppear {
            if let e = initialEuro, e > 0 {
                amountText = StatsFR.formatEuro(e)
            } else {
                amountText = ""
            }
            // Laisser une frame au layout (overlay verre) avant le focus — sinon le clavier ne s’affiche pas toujours.
            DispatchQueue.main.async {
                amountFieldFocused = true
            }
        }
        .alert("Montant invalide", isPresented: $invalidAttempt) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Saisissez un montant entre 0 et 100 000 € (ex. 24,90).")
        }
    }

    private var buttonEnregistrerLarge: some View {
        Button {
            Task { await performSave(allowClear: false) }
        } label: {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                        .tint(.black)
                }
                Text(isSaving ? "Enregistrement..." : "Enregistrer")
                    .font(CommerceStatisticsTheme.statsText(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 14)
            .background(Capsule().fill(Color.white))
            .overlay(
                Capsule()
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .opacity(isSaving ? 0.82 : 1)
        .padding(.top, 2)
    }

    private func performSave(allowClear: Bool) async {
        if allowClear {
            isSaving = true
            await onSave(nil, true)
            isSaving = false
            return
        }
        guard let v = Self.parseEuroAmount(amountText), v > 0 else {
            invalidAttempt = true
            return
        }
        invalidAttempt = false
        isSaving = true
        await onSave(v, false)
        isSaving = false
    }

    private static func parseEuroAmount(_ raw: String) -> Double? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !t.isEmpty, let v = Double(t), v >= 0, v <= 100_000 else { return nil }
        return (v * 100).rounded() / 100
    }
}

private struct MerchantPanierRepereLiquidGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.94))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                )
        }
    }
}
