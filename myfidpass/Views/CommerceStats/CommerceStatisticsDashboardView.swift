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

private struct MerchantStatsZoomDetailItem: Identifiable {
    let id: String
    let topic: CommerceStatisticDetailTopic
    let periodKey: String
}

struct CommerceStatisticsDashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @ObservedObject var vm: MerchantStatsIndicatorsViewModel
    /// Ordre : index 0 = mois le plus récent, … 5 = M-5.
    let statsMonthKeys: [String]
    @Binding var selectedMonthIndex: Int
    let onClose: () -> Void
    var showsInlineCloseButton: Bool = true
    /// Présentation par-dessus Commerce : fond transparent, en-tête flou, bouton « X » (ref. Revolut).
    var glassOverlayMode: Bool = false

    @Namespace private var statsZoomNamespace
    @State private var zoomDetailSheetItem: MerchantStatsZoomDetailItem?
    @State private var accountingPackPresented = false
    @State private var panierRepereSheetPresented = false
    @State private var statsPageEntranceReady = false

    /// Espace sous le titre du carrousel KPI, entre carrousel et points (inchangé, lisible).
    private let kpiClusterVerticalSpacing: CGFloat = 8
    /// Espace **réduit** entre la carte Membres et la ligne Panier / Fréquence (évite le « trou » visuel).
    /// Un peu d’air entre la carte Membres et la rangée Panier / Fréquence.
    private let kpiMembersToPanierRowSpacing: CGFloat = 9
    /// Respiration supplémentaire sous le titre KPI avant la carte Membres.
    private let kpiMonthTitleBottomInset: CGFloat = 4
    /// Réduction visuelle très légère des cartes KPI (proche 1 = bloc Membres / Panier / Fréquence plus large).
    private let kpiCardsMicroScale: CGFloat = 0.988
    /// Panier moyen + Fréquence : un tout petit peu plus petits que Membres.
    private let kpiPanierFreqExtraScale: CGFloat = 0.985
    /// Marge latérale sur la rangée Panier / Fréquence (faible = presque alignée sur Membres, section plus large).
    private let kpiPanierFreqRowHorizontalInset: CGFloat = 2
    /// Marge latérale pour voir un aperçu du mois précédent / suivant (réduite = pages KPI un peu plus larges).
    private let kpiMonthCarouselPeek: CGFloat = 6
    private let kpiMonthCarouselItemSpacing: CGFloat = 10
    /// Déborde légèrement hors du `contentGutter` pour élargir visuellement Membres / Panier / Fréquence.
    private let kpiBlockHorizontalOutdent: CGFloat = 6
    /// Marge supplémentaire entre le carrousel KPI (panier / fréquence) et « Plus de données ».
    private let kpiToDetailSectionsTopInset: CGFloat = 22
    private let contentGutter: CGFloat = 16

    /// Marge intérieure sous la rangée panier / fréquence (sépare du clip + des pastilles, sans rogner les barres).
    private let kpiScrollContentBottomPadding: CGFloat = 10
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
        return max(0, (rowW - kpiClusterVerticalSpacing) / 2)
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

    private var presentation: CommerceStatisticsPresentation {
        CommerceStatisticsDataBuilder.build(
            stats: vm.stats,
            evolution: vm.evolution,
            panierRepereEuro: vm.baselinePanierRepereEUR
        )
    }

    private var selectedMonthKey: String? {
        guard statsMonthKeys.indices.contains(selectedMonthIndex) else { return nil }
        return statsMonthKeys[selectedMonthIndex]
    }

    /// « Votre commerce ce mois » si le mois affiché est le mois civil actuel, sinon « Votre commerce en {mois} ».
    private var kpiCarouselMonthHeading: String {
        guard let key = selectedMonthKey else { return "Votre commerce ce mois" }
        if key == CommerceStatsMonthNavigator.calendarMonthKey(for: Date()) {
            return "Votre commerce ce mois"
        }
        let month = CommerceStatsMonthNavigator.displayTitleMonthOnly(forMonthKey: key).lowercased()
        return "Votre commerce en \(month)"
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
                    CommerceStatisticsTheme.background
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            statsAmbientBackdrop
                .allowsHitTesting(false)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    statisticsTopChrome
                        .padding(.top, statsScrollContentTopPadding)
                        .offset(y: statsPageEntranceReady ? 0 : 22)
                        .opacity(statsPageEntranceReady ? 1 : 0.66)
                        .animation(.spring(response: 0.88, dampingFraction: 0.89), value: statsPageEntranceReady)

                    kpiCarouselSection
                        .offset(y: statsPageEntranceReady ? 0 : 26)
                        // Ne jamais masquer totalement les KPI (Membres / Panier / Fréquence) : opacité 0 = écran vide si l’anim ne part pas.
                        .opacity(statsPageEntranceReady ? 1 : 0.92)
                        .animation(.spring(response: 0.92, dampingFraction: 0.88).delay(0.14), value: statsPageEntranceReady)

                    detailSectionsBelowCarousel
                        .padding(.top, kpiToDetailSectionsTopInset)
                        .animation(.easeInOut(duration: 0.22), value: selectedMonthIndex)
                        .offset(y: statsPageEntranceReady ? 0 : 20)
                        .opacity(statsPageEntranceReady ? 1 : 0.92)
                        .animation(.spring(response: 0.95, dampingFraction: 0.89).delay(0.28), value: statsPageEntranceReady)

                    if let err = vm.errorMessage, !err.isEmpty {
                        Text(err)
                            .font(CommerceStatisticsTheme.statsText(size: 15, weight: .regular))
                            .foregroundStyle(CommerceStatisticsTheme.negative.opacity(glassOverlayMode ? 1 : 0.9))
                            .padding(.vertical, 8)
                    }

                    statisticsDemoSixMonthsButton
                        .padding(.top, 28)
                        .offset(y: statsPageEntranceReady ? 0 : 18)
                        .opacity(statsPageEntranceReady ? 1 : 0.92)
                        .animation(.spring(response: 0.9, dampingFraction: 0.9).delay(0.38), value: statsPageEntranceReady)

                    Color.clear.frame(height: 44)
                }
                .padding(.horizontal, contentGutter)
                .padding(.bottom, 12)
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .refreshable {
                await loadMonthForCurrentSelection()
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
        .onAppear {
            if accessibilityReduceMotion {
                statsPageEntranceReady = true
            } else {
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.92, dampingFraction: 0.88)) {
                        statsPageEntranceReady = true
                    }
                }
            }
        }
        .task(id: selectedMonthIndex) {
            await loadMonthForCurrentSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassRemoteSyncDidMerge)) { _ in
            Task { await loadMonthForCurrentSelection() }
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
        .sheet(isPresented: $panierRepereSheetPresented) {
            MerchantStatsPanierRepereCompactSheet(
                initialEuro: vm.baselinePanierRepereEUR,
                onSave: { value, clear in
                    await savePanierRepere(value: value, clear: clear)
                }
            )
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
    }

    // MARK: - Ambiance

    /// Lueurs bleu / vert très douces sur le fond (plein écran ou overlay).
    private var statsAmbientBackdrop: some View {
        let bluePrimary: CGFloat = glassOverlayMode ? 0.09 : 0.14
        let blueSecondary: CGFloat = glassOverlayMode ? 0.055 : 0.09
        let greenPrimary: CGFloat = glassOverlayMode ? 0.075 : 0.12
        let greenSecondary: CGFloat = glassOverlayMode ? 0.045 : 0.075

        return GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                statsAmbientGlowOrb(
                    tint: Color(red: 0.24, green: 0.52, blue: 1.0),
                    edgeOpacity: bluePrimary,
                    width: min(w * 0.95, 420),
                    height: min(h * 0.38, 340),
                    blur: 52,
                    endRadius: 200,
                    x: w * 0.18,
                    y: h * 0.28
                )
                statsAmbientGlowOrb(
                    tint: Color(red: 0.16, green: 0.78, blue: 0.48),
                    edgeOpacity: greenPrimary,
                    width: min(w * 0.88, 380),
                    height: min(h * 0.36, 300),
                    blur: 58,
                    endRadius: 185,
                    x: w * 0.82,
                    y: h * 0.72
                )
                statsAmbientGlowOrb(
                    tint: Color(red: 0.28, green: 0.62, blue: 0.98),
                    edgeOpacity: blueSecondary,
                    width: min(w * 0.72, 300),
                    height: min(h * 0.32, 260),
                    blur: 64,
                    endRadius: 165,
                    x: w * 0.55,
                    y: h * 0.12
                )
                statsAmbientGlowOrb(
                    tint: Color(red: 0.22, green: 0.72, blue: 0.44),
                    edgeOpacity: greenSecondary,
                    width: min(w * 0.65, 280),
                    height: min(h * 0.28, 240),
                    blur: 56,
                    endRadius: 150,
                    x: w * 0.42,
                    y: h * 0.88
                )
            }
            .frame(width: w, height: h)
        }
    }

    private func statsAmbientGlowOrb(
        tint: Color,
        edgeOpacity: CGFloat,
        width: CGFloat,
        height: CGFloat,
        blur: CGFloat,
        endRadius: CGFloat,
        x: CGFloat,
        y: CGFloat
    ) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        tint.opacity(edgeOpacity),
                        tint.opacity(edgeOpacity * 0.35),
                        Color.clear,
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: endRadius
                )
            )
            .frame(width: width, height: height)
            .blur(radius: blur)
            .position(x: x, y: y)
    }

    @MainActor
    private func loadMonthForCurrentSelection() async {
        guard let key = selectedMonthKey else { return }
        if vm.isDemoSixMonthPreviewActive {
            vm.applyDemoPayload(forMonthKey: key)
            return
        }
        if let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty {
            vm.prepareMonthNavigation(slug: slug, allMonthKeys: statsMonthKeys, focusPeriod: key)
        }
        await vm.load(period: key)
    }

    @ViewBuilder
    private var statsOverlayCloseButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(CommerceStatisticsTheme.statsText(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
        }
        .modifier(TopBarLiquidGlassButtonModifier())
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
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                    }
                    .modifier(TopBarLiquidGlassButtonModifier())
                    .accessibilityLabel("Retour")
                    Spacer(minLength: 0)
                }
            }

            Text("Outils d'analyse")
                .font(Font.system(size: 34, weight: .heavy, design: .default))
                .foregroundStyle(Color.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 6)
        .animation(.smooth(duration: 0.28), value: selectedMonthIndex)
    }

    @ViewBuilder
    private var statisticsDemoSixMonthsButton: some View {
        let g = glassOverlayMode
        Button {
            let key = statsMonthKeys.indices.contains(selectedMonthIndex)
                ? statsMonthKeys[selectedMonthIndex]
                : (statsMonthKeys.first ?? "")
            vm.applySixMonthsPreviewDemo(monthKeys: statsMonthKeys, displayMonthKey: key)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(CommerceStatisticsTheme.statsText(size: 13, weight: .semibold))
                Text("Démo 6 mois — données test")
                    .font(CommerceStatisticsTheme.statsText(size: 13, weight: .semibold))
            }
            .foregroundStyle(CommerceStatisticsTheme.accentBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(CommerceStatisticsTheme.card.opacity(g ? 0.48 : 0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remplir avec une démonstration sur six mois (glissement par mois)")
    }

    @ViewBuilder
    private var kpiCarouselSection: some View {
        let g = glassOverlayMode
        VStack(alignment: .leading, spacing: kpiClusterVerticalSpacing) {
            /// Même marge de départ que « Outils d'analyse » : l’outdent ne s’applique qu’au carrousel, pas à ce titre.
            HStack(alignment: .firstTextBaseline) {
                Text(kpiCarouselMonthHeading)
                    .font(CommerceStatisticsTheme.statsChromeSectionTitle(size: 18, weight: .bold))
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
                            kpiCluster(forMonthKey: monthKey, panierFreqCellSide: stablePanierFreqCellSide)
                                .frame(width: stableKpiPageWidth)
                                .id(tabIdx)
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
                .clipped()

                monthCarouselPageIndicator
            }
            .onChange(of: selectedMonthIndex) { old, new in
                guard old != new else { return }
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
        let activePill = Color(red: 0.53, green: 0.80, blue: 1.0)
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
                            .fill(idx == active ? activePill : Color.white.opacity(g ? 0.34 : 0.24))
                            .frame(width: idx == active ? pillOn : pillOff, height: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 3)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(monthCarouselPageIndicatorSpring, value: active)
            .padding(.top, 20)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Mois affiché")
            .accessibilityValue("\(active + 1) sur \(n)")
        }
    }

    @ViewBuilder
    private func kpiCluster(forMonthKey monthKey: String, panierFreqCellSide: CGFloat) -> some View {
        let pres = vm.presentationForMonthCarousel(monthKey: monthKey)
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
                zoomTransitionNamespace: statsZoomNamespace
            )
            .frame(height: membersKpiCardFixedHeight, alignment: .top)
            .clipped()
            .scaleEffect(kpiCardsMicroScale, anchor: .top)
            .accessibilityLabel(newMembersCardAccessibilityLabel(stats: monthStats, presentation: pres))

            panierFrequenceSquareRow(presentation: pres, cellSide: panierFreqCellSide) {
                panierRepereSheetPresented = true
            }
                .padding(.horizontal, kpiPanierFreqRowHorizontalInset)
                .scaleEffect(kpiCardsMicroScale * kpiPanierFreqExtraScale, anchor: .top)
        }
    }

    @ViewBuilder
    private var detailSectionsBelowCarousel: some View {
        VStack(alignment: .leading, spacing: 22) {
            CommerceStatsSectionHeader(title: "Plus de données", titleFontSize: 18, titleWeight: .bold)

            CommerceStatsCategoryListCard(rows: presentation.categoryRows) { rowId in
                guard rowId == "rewards" else { return }
                accountingPackPresented = true
            }

            if !EngagementTemporaryVisibility.hideGoogleReviewsUI {
                CommerceStatsSectionHeader(title: "Avis Google", titleFontSize: 18, titleWeight: .bold)
                CommerceStatsCategoryListCard(rows: presentation.googleReviewsRows)
            }

            if !notificationCampaignsForSection.isEmpty {
                CommerceNotificationImpactListCard(
                    campaigns: notificationCampaignsForSection,
                    notificationIconURL: vm.statsNotificationIconURL
                )
            }
        }
    }

    private func panierFrequenceSquareRow(
        presentation: CommerceStatisticsPresentation,
        cellSide: CGFloat,
        onPanierTap: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: kpiClusterVerticalSpacing) {
            panierFreqSquareSlot(cellSide: cellSide) {
                CommerceStatsCompactMetricCard(
                    title: "Panier moyen",
                    value: panierText(presentation: presentation),
                    trendText: panierTrendText(presentation: presentation),
                    trendPositive: panierTrendPositive(presentation: presentation),
                    footnote: panierFootnoteShort(presentation: presentation),
                    onCardTap: onPanierTap
                ) {
                    CommerceStatsMiniSparklineChart(
                        weeks: presentation.barWeeksOperations,
                        lineColor: CommerceStatisticsTheme.positive
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            panierFreqSquareSlot(cellSide: cellSide) {
                CommerceStatsCompactMetricCard(
                    title: "Fréquence d’achat",
                    value: frequenceText(presentation: presentation),
                    trendText: freqTrendText(presentation: presentation),
                    trendPositive: presentation.trendFrequenceDelta.map { $0 >= 0 }
                ) {
                    CommerceStatsDualToneMiniBars(
                        topFraction: freqTopBar(presentation: presentation),
                        bottomFraction: freqBottomBar(presentation: presentation)
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
            .clipped()
    }

    private func newMembersTotalCartesValue(stats: BusinessStatsResponse?, presentation: CommerceStatisticsPresentation) -> String {
        if let n = stats?.membersCount { return StatsFR.formatInt(n) }
        if let n = presentation.membersTotal { return StatsFR.formatInt(n) }
        return "—"
    }

    private func newMembersInscriptionSubtitle(stats: BusinessStatsResponse?) -> String? {
        guard stats != nil else { return nil }
        let n = stats?.newMembersInPeriod ?? stats?.newMembersLast30Days
        guard let n else { return nil }
        return "+\(StatsFR.formatInt(n)) nouveaux"
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
        guard let p = presentation.panierMoyenEuro else { return "—" }
        return StatsFR.formatEuro(p) + " €"
    }

    private func frequenceText(presentation: CommerceStatisticsPresentation) -> String {
        guard let f = presentation.frequenceParActif else { return "—" }
        return StatsFR.formatDoubleSmart(f) + " visites/actif"
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
            return "\(sign)\(StatsFR.formatDoubleSmart(abs(pct))) % vs repère"
        }
        guard let d = presentation.trendPanierDeltaEuro else { return nil }
        let sign = d >= 0 ? "+" : "−"
        return "série : \(sign)\(StatsFR.formatEuro(abs(d))) €"
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
            await loadMonthForCurrentSelection()
        } catch {
            /* réseau / 403 : la feuille se ferme ; l’utilisateur peut réessayer */
        }
        panierRepereSheetPresented = false
    }

    private func freqTrendText(presentation: CommerceStatisticsPresentation) -> String? {
        guard let d = presentation.trendFrequenceDelta else { return nil }
        let arrow = d >= 0 ? "\u{25B2}" : "\u{25BC}"
        return "\(arrow) \(StatsFR.formatPct(abs(d)))"
    }

    private func freqTopBar(presentation: CommerceStatisticsPresentation) -> CGFloat {
        let f = presentation.frequenceParActif ?? 0
        return CGFloat(min(1, max(0.2, f / max(2, f + 1))))
    }

    private func freqBottomBar(presentation: CommerceStatisticsPresentation) -> CGFloat {
        let r = presentation.retentionPct.map { CGFloat($0 / 100) } ?? 0.35
        return min(1, max(0.15, 1 - r))
    }

    private var notificationCampaignsForSection: [NotificationCampaignInsightDTO] {
        let camps = vm.notificationCampaignsForPresentation
        guard !camps.isEmpty else { return [] }
        return Array(camps.prefix(40))
    }
}

// MARK: - Panier repère (saisie compacte, clavier numérique)

private struct MerchantStatsPanierRepereCompactSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialEuro: Double?
    let onSave: (Double?, Bool) async -> Void

    @FocusState private var amountFieldFocused: Bool
    @State private var amountText: String = ""
    @State private var isSaving = false
    @State private var invalidAttempt = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Repère de panier moyen (€)")
                .font(CommerceStatisticsTheme.statsText(size: 18, weight: .bold))
                .foregroundStyle(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: true))
            Text("Ticket moyen habituel pour comparer à la moyenne mesurée en caisse.")
                .font(CommerceStatisticsTheme.statsText(size: 14, weight: .regular))
                .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: true).opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            TextField("Ex. 24,90", text: $amountText)
                .keyboardType(.decimalPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(CommerceStatisticsTheme.statisticNumbers(size: 22, weight: .semibold))
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(CommerceStatisticsTheme.pillBackground.opacity(0.55))
                )
                .focused($amountFieldFocused)
            HStack(spacing: 12) {
                Button("Annuler") { dismiss() }
                    .font(CommerceStatisticsTheme.statsText(size: 16, weight: .semibold))
                    .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: true))
                Spacer()
                if isSaving { ProgressView() }
                Button("Enregistrer") { Task { await performSave(allowClear: false) } }
                    .font(CommerceStatisticsTheme.statsText(size: 16, weight: .semibold))
                    .foregroundStyle(CommerceStatisticsTheme.accentBlue)
                    .disabled(isSaving)
            }
            if initialEuro != nil {
                Button("Supprimer le repère", role: .destructive) {
                    Task { await performSave(allowClear: true) }
                }
                .font(CommerceStatisticsTheme.statsText(size: 15, weight: .semibold))
                .disabled(isSaving)
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(CommerceStatisticsTheme.card.opacity(0.98))
        .onAppear {
            if let e = initialEuro, e > 0 {
                amountText = StatsFR.formatEuro(e)
            } else {
                amountText = ""
            }
            amountFieldFocused = true
        }
        .alert("Montant invalide", isPresented: $invalidAttempt) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Saisissez un montant entre 0 et 100 000 € (ex. 24,90).")
        }
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
