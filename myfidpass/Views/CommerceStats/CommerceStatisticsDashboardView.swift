//
//  CommerceStatisticsDashboardView.swift
//  myfidpass
//
//  Statistiques commerçant — refonte visuelle + feuille détail avec transition zoom (iOS 18+).
//

import SwiftUI
import UIKit

private enum MerchantStatsZoom {
    static func newMembersSourceID(monthKey: String) -> String {
        "merchantStats.zoom.newMembers.\(monthKey)"
    }
}

private struct MerchantStatsZoomDetailItem: Identifiable, Equatable {
    let id: String
    let topic: CommerceStatisticDetailTopic
    let periodKey: String
}

enum CommerceStatsRuntimeSession {
    /// Evite de rejouer les animations lourdes à chaque navigation; reset automatique au relaunch app.
    static var hasPlayedMembersLineIntro = false
    static var hasRevealedEmbeddedDetailSections = false
}

struct CommerceStatisticsDashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @EnvironmentObject private var authService: AuthService
    @ObservedObject var vm: MerchantStatsIndicatorsViewModel
    /// Ordre : index 0 = mois le plus récent, … 5 = M-5.
    let statsMonthKeys: [String]
    @Binding var selectedMonthIndex: Int
    let onClose: () -> Void
    var showsInlineCloseButton: Bool = true
    var showsTopTitle: Bool = true
    /// Présentation par-dessus Commerce : fond transparent, en-tête flou, bouton « X » (ref. Revolut).
    var glassOverlayMode: Bool = false

    @Namespace private var statsZoomNamespace
    @State private var zoomDetailSheetItem: MerchantStatsZoomDetailItem?
    @State private var accountingPackPresented = false
    @State private var panierRepereSheetPresented = false
    @State private var socialMissionsSheetPresented = false
    /// Même schéma que `scheduleNotificationIconNudgeIfNeeded` sur Campagnes : délai 3 s puis feuille si repère absent.
    @State private var panierRepereNudgeTask: Task<Void, Never>?
    @State private var showDeferredDetailSections = false
    /// Présentations KPI par mois — mises à jour uniquement quand les données changent (pas à chaque render).
    @State private var cachedMonthPresentations: [String: CommerceStatisticsPresentation] = [:]
    /// Présentation pour les sections de détail (« Plus de données ») — même logique.
    @State private var cachedDetailPresentation: CommerceStatisticsPresentation = CommerceStatisticsDataBuilder.build(stats: nil, evolution: [], panierRepereEuro: nil)
    /// Campagnes de notification — liste dérivée coûteuse (merge 3 sources), mise en cache.
    @State private var cachedNotificationCampaigns: [NotificationCampaignInsightDTO] = []

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
    /// Aligne "Plus de données" sur la largeur visuelle des KPI réduits.
    private let detailSectionsHorizontalInset: CGFloat = 8
    /// Marge supplémentaire entre le carrousel KPI (panier / fréquence) et « Plus de données ».
    private let kpiToDetailSectionsTopInset: CGFloat = 22
    private let contentGutter: CGFloat = 16

    /// Statistiques détaillées (hors carte Membres) : débloquées avec abonnement Stripe qualifiant (ou admin).
    private var commerceStatsInsightsUnlocked: Bool {
        if authService.isPlatformAdmin { return true }
        if authService.hasPaidStripeSubscription { return true }
        return false
    }

    private var statsPaywallBlurRadius: CGFloat { 5 }

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

    private func refreshCachedPresentations() {
        let demoPayloads = CommerceStatisticsPreviewMock.payloadsByMonthKeys(statsMonthKeys)
        let unlocked = commerceStatsInsightsUnlocked

        var updated: [String: CommerceStatisticsPresentation] = [:]
        for key in statsMonthKeys {
            let realPres = vm.presentationForMonthCarousel(monthKey: key)
            if unlocked {
                updated[key] = realPres
            } else if let mockPayload = demoPayloads[key] {
                let mockPres = CommerceStatisticsDataBuilder.build(
                    stats: mockPayload.stats,
                    evolution: mockPayload.evolution,
                    panierRepereEuro: mockPayload.stats.baselineAvgBasketEur
                )
                updated[key] = CommerceStatisticsDataBuilder.paywallTeaserMerging(real: realPres, mock: mockPres)
            } else {
                updated[key] = realPres
            }
        }
        cachedMonthPresentations = updated

        if unlocked {
            cachedDetailPresentation = CommerceStatisticsDataBuilder.build(
                stats: vm.stats,
                evolution: vm.evolution,
                panierRepereEuro: vm.baselinePanierRepereEUR
            )
            cachedNotificationCampaigns = Array(vm.notificationCampaignsForPresentation.prefix(40))
        } else {
            let key = selectedMonthKey
                ?? statsMonthKeys.last
                ?? CommerceStatsMonthNavigator.calendarMonthKey(for: Date())
            if let mockPayload = demoPayloads[key] {
                cachedDetailPresentation = CommerceStatisticsDataBuilder.build(
                    stats: mockPayload.stats,
                    evolution: mockPayload.evolution,
                    panierRepereEuro: mockPayload.stats.baselineAvgBasketEur
                )
            } else {
                cachedDetailPresentation = CommerceStatisticsDataBuilder.build(stats: nil, evolution: [], panierRepereEuro: nil)
            }
            cachedNotificationCampaigns = CommerceStatisticsPreviewMock.paywallTeaserNotificationCampaigns
        }
    }

    private func presentCommerceStatsPaywall() {
        NotificationCenter.default.post(name: .myfidpassOpenMerchantSubscriptionSheet, object: nil)
    }

    private var selectedMonthKey: String? {
        guard statsMonthKeys.indices.contains(selectedMonthIndex) else { return nil }
        return statsMonthKeys[selectedMonthIndex]
    }

    /// Libellé court du mois civil (ex. « mai », « septembre »).
    private var kpiCarouselMonthHeading: String {
        let key = selectedMonthKey ?? CommerceStatsMonthNavigator.calendarMonthKey(for: Date())
        return CommerceStatsMonthNavigator.displayTitleMonthOnly(forMonthKey: key).lowercased()
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

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if glassOverlayMode {
                    Color.clear
                } else {
                    Color.black
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            /// Ne pas ignorer le haut : sinon le `ScrollView` peut perdre le safe area et passer sous la barre d’état / la top bar.
            .ignoresSafeArea(edges: [.horizontal, .bottom])

            if !glassOverlayMode {
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 24,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.92, green: 0.92, blue: 0.93),
                            Color(red: 0.88, green: 0.88, blue: 0.90),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea(edges: [.horizontal, .bottom])
            }

            if glassOverlayMode {
                statsAmbientBackdrop
                    .allowsHitTesting(false)
                    .ignoresSafeArea(edges: [.horizontal, .bottom])
            }

            ScrollView {
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
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .refreshable {
                await loadMonthForCurrentSelection(forceRefresh: true)
            }

            if showBlockingStatsLoading {
                ProgressView()
                    .tint(.white)
                    .padding(.top, glassOverlayMode ? statsScrollContentTopPadding + 18 : 14)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .allowsHitTesting(false)
            }

            if glassOverlayMode && showsInlineCloseButton {
                statsOverlayCloseButton
                    .zIndex(20)
            }

            if panierRepereSheetPresented {
                Color.black.opacity(glassOverlayMode ? 0.24 : 0.18)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                            panierRepereSheetPresented = false
                        }
                        schedulePanierRepereNudgeIfNeeded()
                    }
                    .zIndex(28)

                MerchantStatsPanierRepereCompactSheet(
                    initialEuro: vm.baselinePanierRepereEUR,
                    onClose: {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                            panierRepereSheetPresented = false
                        }
                        schedulePanierRepereNudgeIfNeeded()
                    },
                    onSave: { value, clear in
                        await savePanierRepere(value: value, clear: clear)
                    }
                )
                .frame(maxWidth: 430)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .transition(.scale(scale: 0.97).combined(with: .opacity))
                .zIndex(29)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
        .onDisappear {
            cancelPanierRepereNudge()
            panierRepereSheetPresented = false
            showDeferredDetailSections = false
        }
        .onAppear {
            refreshCachedPresentations()
            if isEmbeddedCommerceStats {
                /// Affichage immédiat en embarqué: évite l'effet "les blocs arrivent après".
                showDeferredDetailSections = true
                CommerceStatsRuntimeSession.hasRevealedEmbeddedDetailSections = true
            } else {
                showDeferredDetailSections = true
            }
            schedulePanierRepereNudgeIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassCommerceStatsTabDidBecomeSelected)) { _ in
            schedulePanierRepereNudgeIfNeeded()
        }
        .onChange(of: vm.lastSuccessfullyLoadedPeriod) { _, _ in
            refreshCachedPresentations()
        }
        .onChange(of: vm.baselinePanierRepereEUR) { _, newVal in
            refreshCachedPresentations()
            if newVal != nil {
                cancelPanierRepereNudge()
            } else {
                schedulePanierRepereNudgeIfNeeded()
            }
        }
        .onChange(of: zoomDetailSheetItem) { _, newVal in
            if newVal != nil {
                cancelPanierRepereNudge()
            } else if vm.baselinePanierRepereEUR == nil {
                schedulePanierRepereNudgeIfNeeded()
            }
        }
        .onChange(of: accountingPackPresented) { _, presented in
            if presented {
                cancelPanierRepereNudge()
            } else if vm.baselinePanierRepereEUR == nil {
                schedulePanierRepereNudgeIfNeeded()
            }
        }
        .task(id: selectedMonthIndex) {
            await loadMonthForCurrentSelection()
        }
        .sheet(item: $zoomDetailSheetItem) { item in
            MerchantStatisticRevolutDetailScreen(topic: item.topic, initialPeriodRaw: item.periodKey)
                .environment(\.managedObjectContext, viewContext)
                .environment(\.commerceStatsGlassOverlay, true)
                .environment(\.colorScheme, .dark)
                .statsDetailZoomTransition(sourceID: item.id, namespace: statsZoomNamespace)
                .presentationCornerRadius(28)
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $accountingPackPresented) {
            NavigationStack {
                MerchantAccountingPackView()
            }
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $socialMissionsSheetPresented) {
            if let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty {
                SocialMissionsSheet(slug: slug)
                    .presentationCornerRadius(28)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.9), value: panierRepereSheetPresented)
        .onChange(of: authService.merchantSubscription?.status) { _, _ in
            refreshCachedPresentations()
        }
        .onChange(of: authService.isPlatformAdmin) { _, _ in
            refreshCachedPresentations()
        }
    }

    /// Contenu scrollé (KPI, sections) — dupliqué seulement en structure si/pas mode verre.
    @ViewBuilder
    private var statisticsScrollVStack: some View {
        VStack(alignment: .leading, spacing: 32) {
            statisticsTopChrome
                .padding(.top, statsScrollContentTopPadding)

            kpiCarouselSection

            if showDeferredDetailSections {
                detailSectionsBelowCarousel
                    .padding(.top, kpiToDetailSectionsTopInset)
                    .padding(.horizontal, detailSectionsHorizontalInset)
            } else {
                deferredSectionsSkeleton
                    .padding(.top, kpiToDetailSectionsTopInset)
                    .padding(.horizontal, detailSectionsHorizontalInset)
            }

            if let err = vm.errorMessage, !err.isEmpty {
                Text(err)
                    .font(CommerceStatisticsTheme.statsText(size: 15, weight: .regular))
                    .foregroundStyle(CommerceStatisticsTheme.negative.opacity(glassOverlayMode ? 1 : 0.9))
                    .padding(.vertical, 8)
            }

            gatedConnectSocialNetworksButton

            Color.clear.frame(height: 44)
        }
        .padding(.horizontal, contentGutter)
        .padding(.bottom, 12)
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
                .fill(Color.white.opacity(glassOverlayMode ? 0.08 : 0.5))
                .frame(height: 92)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(glassOverlayMode ? 0.08 : 0.5))
                .frame(height: 92)
        }
    }

    private var gatedConnectSocialNetworksButton: some View {
        ZStack {
            connectSocialNetworksButton
                .blur(radius: commerceStatsInsightsUnlocked ? 0 : statsPaywallBlurRadius)
                .allowsHitTesting(commerceStatsInsightsUnlocked)

            if !commerceStatsInsightsUnlocked {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(glassOverlayMode ? 0.08 : 0.05))
                    .allowsHitTesting(false)
                MerchantProUnlockTeaserButton(preferDarkGlassTint: glassOverlayMode) {
                    presentCommerceStatsPaywall()
                }
                .accessibilityLabel("Déverrouiller avec Pro pour connecter les réseaux sociaux")
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    private var connectSocialNetworksButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            socialMissionsSheetPresented = true
        } label: {
            let fgPrimary = glassOverlayMode ? Color.white : Color.accentColor
            let fgSecondary = glassOverlayMode ? Color.white.opacity(0.6) : Color(UIColor.secondaryLabel)
            let bgFill = glassOverlayMode ? Color.white.opacity(0.1) : Color.accentColor.opacity(0.07)
            let border = glassOverlayMode ? Color.white.opacity(0.2) : Color.accentColor.opacity(0.18)
            HStack(spacing: 10) {
                Image(systemName: "person.2.wave.2.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(fgPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connecter mes réseaux")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(fgPrimary)
                    Text("Instagram · TikTok · Facebook · X — missions & points")
                        .font(.caption2)
                        .foregroundStyle(fgSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(fgSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(bgFill))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        .animation(.smooth(duration: 0.28), value: selectedMonthIndex)
    }

    @ViewBuilder
    private var kpiCarouselSection: some View {
        let g = glassOverlayMode
        VStack(alignment: .leading, spacing: kpiClusterVerticalSpacing) {
            /// Même marge de départ que « Outils d'analyse » : l’outdent ne s’applique qu’au carrousel, pas à ce titre.
            HStack(alignment: .firstTextBaseline) {
                Text(kpiCarouselMonthHeading)
                    .font(CommerceStatisticsTheme.statsChromeSectionTitle(size: 32, weight: .bold))
                    .foregroundStyle(CommerceStatisticsTheme.pageTitle(forGlassOverlay: g))
                    .multilineTextAlignment(.leading)
                    .animation(.easeInOut(duration: 0.22), value: selectedMonthIndex)
                Spacer()
            }
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
                .frame(height: stableKpiCarouselBlockHeight, alignment: .top)

                monthCarouselPageIndicator
            }
            .onChange(of: selectedMonthIndex) { old, new in
                guard old != new else { return }
                refreshCachedPresentations()
                if !accessibilityReduceMotion {
                    let g = UISelectionFeedbackGenerator()
                    g.prepare()
                    g.selectionChanged()
                }
            }
            .padding(.horizontal, -kpiBlockHorizontalOutdent)
        }
    }

    /// Ressort aligné sur l’écran notifs (carrousel + pastilles cliquables).
    private var monthCarouselPageIndicatorSpring: Animation {
        .spring(response: 0.44, dampingFraction: 0.86, blendDuration: 0.1)
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
                        withAnimation(monthCarouselPageIndicatorSpring) {
                            selectedMonthIndex = (n - 1) - idx
                        }
                    } label: {
                        Capsule()
                            .fill(idx == active ? activePill : Color.black.opacity(g ? 0.24 : 0.18))
                            .frame(width: idx == active ? pillOn : pillOff, height: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 3)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(monthCarouselPageIndicatorSpring, value: active)
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
        let zoomID = MerchantStatsZoom.newMembersSourceID(monthKey: monthKey)

        VStack(alignment: .leading, spacing: kpiMembersToPanierRowSpacing) {
            CommerceStatsLargeMetricCard(
                title: "Membres",
                value: newMembersTotalCartesValue(stats: monthStats, presentation: pres),
                valueCaption: nil,
                subtitle: newMembersInscriptionSubtitle(stats: monthStats),
                membersWeeklySparkline: pres.membersWeeklySparkline,
                segments: pres.donutSegments,
                onTap: {
                    let item = MerchantStatsZoomDetailItem(
                        id: zoomID,
                        topic: .newMembers,
                        periodKey: monthKey
                    )
                    DispatchQueue.main.async {
                        zoomDetailSheetItem = item
                    }
                },
                zoomTransitionSourceID: zoomID,
                zoomTransitionNamespace: statsZoomNamespace,
                playNeonLineIntro: selectedMonthKey == monthKey
            )
            .frame(height: membersKpiCardFixedHeight, alignment: .top)
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
        let locked = !commerceStatsInsightsUnlocked
        ZStack {
            panierFrequenceSquareRow(presentation: presentation, cellSide: panierFreqCellSide) {
                cancelPanierRepereNudge()
                panierRepereSheetPresented = true
            }
            .blur(radius: locked ? statsPaywallBlurRadius : 0)
            .allowsHitTesting(!locked)

            if locked {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(glassOverlayMode ? 0.08 : 0.05))
                    .allowsHitTesting(false)
                MerchantProUnlockTeaserButton(preferDarkGlassTint: glassOverlayMode) {
                    presentCommerceStatsPaywall()
                }
                .accessibilityLabel("Déverrouiller avec Pro pour le panier moyen et la fréquence")
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    @ViewBuilder
    private var detailSectionsBelowCarousel: some View {
        let locked = !commerceStatsInsightsUnlocked
        VStack(alignment: .leading, spacing: 22) {
            CommerceStatsSectionHeader(title: "Plus de données", titleFontSize: 18, titleWeight: .bold)

            ZStack {
                VStack(alignment: .leading, spacing: 22) {
                    CommerceStatsCategoryListCard(rows: cachedDetailPresentation.categoryRows + cachedDetailPresentation.googleReviewsRows) { rowId in
                        guard rowId == "rewards" else { return }
                        accountingPackPresented = true
                    }

                    let socialRows = cachedDetailPresentation.socialNetworkRows
                    if !socialRows.isEmpty {
                        CommerceStatsSectionHeader(title: "Réseaux sociaux", titleFontSize: 16, titleWeight: .semibold)
                        CommerceStatsCategoryListCard(rows: socialRows)
                    }

                    if !cachedNotificationCampaigns.isEmpty {
                        CommerceNotificationImpactListCard(
                            campaigns: cachedNotificationCampaigns,
                            notificationIconURL: commerceStatsInsightsUnlocked ? vm.statsNotificationIconURL : nil
                        )
                    }
                }
                .blur(radius: locked ? statsPaywallBlurRadius : 0)
                .allowsHitTesting(!locked)

                if locked {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black.opacity(glassOverlayMode ? 0.07 : 0.05))
                        .allowsHitTesting(false)
                    MerchantProUnlockTeaserButton(preferDarkGlassTint: glassOverlayMode) {
                        presentCommerceStatsPaywall()
                    }
                    .accessibilityLabel("Déverrouiller avec Pro pour le détail des statistiques")
                    .accessibilityAddTraits(.isButton)
                }
            }
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
                    valueFontSize: 30,
                    trendText: panierTrendText(presentation: presentation),
                    trendPositive: panierTrendPositive(presentation: presentation),
                    footnote: panierRepereFootnote(presentation: presentation),
                    onCardTap: onPanierTap
                ) {
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            panierFreqSquareSlot(cellSide: cellSide) {
                CommerceStatsCompactMetricCard(
                    title: "Fréquence d’achat",
                    value: frequenceMainText(presentation: presentation),
                    valueSubline: frequenceUnitFootnote(presentation: presentation),
                    valueSublineFontSize: 16,
                    trendText: freqTrendText(presentation: presentation),
                    trendPositive: presentation.trendFrequenceDelta.map { $0 >= 0 },
                    footnote: nil
                ) {
                    CommerceStatsMiniSparklineChart(
                        weeks: presentation.barWeeksOperations,
                        lineColor: CommerceStatisticsTheme.accentBlue
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Deux cartes carrées **même côté** (hauteur fixe, le texte ne redimensionne plus le bloc).
    private func panierFreqSquareSlot<Content: View>(cellSide: CGFloat, @ViewBuilder content: @escaping () -> Content) -> some View {
        content()
            .frame(width: cellSide, height: cellSide, alignment: .topLeading)
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
        if let p = presentation.panierMoyenEuro {
            return StatsFR.formatEuro(p) + "€"
        }
        if let r = presentation.panierRepereEuro {
            return StatsFR.formatEuro(r) + "€"
        }
        return "—"
    }

    private func frequenceMainText(presentation: CommerceStatisticsPresentation) -> String {
        guard let f = presentation.frequenceParActif else { return "—" }
        return StatsFR.formatDoubleSmart(f) + " visites"
    }

    private func frequenceUnitFootnote(presentation: CommerceStatisticsPresentation) -> String? {
        guard presentation.frequenceParActif != nil else { return nil }
        return "/mois"
    }

    private func panierTrendPositive(presentation: CommerceStatisticsPresentation) -> Bool? {
        if presentation.panierMesureVsReperePct != nil {
            return presentation.panierMesureVsReperePct.map { $0 >= 0 }
        }
        return presentation.trendPanierDeltaEuro.map { $0 >= 0 }
    }

    private func panierTrendText(presentation: CommerceStatisticsPresentation) -> String? {
        if let pct = presentation.panierMesureVsReperePct {
            let sign = pct >= 0 ? "+" : "−"
            return "\(sign)\(StatsFR.formatDoubleSmart(abs(pct)))%"
        }
        return nil
    }

    private func panierRepereFootnote(presentation: CommerceStatisticsPresentation) -> String? {
        guard let r = presentation.panierRepereEuro else { return nil }
        return "Repère : \(StatsFR.formatEuro(r))€"
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

    private func cancelPanierRepereNudge() {
        panierRepereNudgeTask?.cancel()
        panierRepereNudgeTask = nil
    }

    /// Après 3 s sur l’écran stats : feuille « panier repère » si aucun repère (même délai que le rappel icône sur Campagnes).
    private func schedulePanierRepereNudgeIfNeeded() {
        cancelPanierRepereNudge()
        guard commerceStatsInsightsUnlocked else { return }
        guard vm.baselinePanierRepereEUR == nil else { return }
        guard !vm.isDemoSixMonthPreviewActive else { return }
        panierRepereNudgeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            guard vm.baselinePanierRepereEUR == nil else { return }
            guard !vm.isDemoSixMonthPreviewActive else { return }
            guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else { return }
            guard zoomDetailSheetItem == nil else { return }
            guard !accountingPackPresented else { return }
            guard !panierRepereSheetPresented else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                panierRepereSheetPresented = true
            }
        }
    }

    @MainActor
    private func savePanierRepere(value: Double?, clear: Bool) async {
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            panierRepereSheetPresented = false
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
        panierRepereSheetPresented = false
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

// MARK: - Panier repère (saisie compacte, clavier numérique)

private struct MerchantStatsPanierRepereCompactSheet: View {
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
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
