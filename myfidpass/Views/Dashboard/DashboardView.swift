//
//  DashboardView.swift
//  myfidpass
//
//  Accueil commerçant : en-tête glass (profil + carte), historique ;
//  scan QR et notifications membres en bas.
//

import SwiftUI
import CoreData
import UIKit

enum DashboardRoute: Hashable {
    /// Hub unifié membres + activité (filtre initial selon l’entrée tableau de bord).
    case membersActivity(MemberActivityFilter)
    /// Personnalisation carte fidélité (plein écran, pas une sheet).
    case myCard
    /// Fiche membre depuis une ligne d’activité (dernières transactions).
    case memberDetail(NSManagedObjectID)
}

// MARK: - Accueil : chrome partiel

private enum DashboardHomeChrome {
    /// Barre profil + scanner au-dessus de la carte : désactivée (profil = onglet du bas, scanner = bouton « Dernières transactions »).
    static let showMinimalTopBar = false
    /// Ancienne barre du bas (notification membres, menu catégories) + `CustomMenuView` autour du `NavigationStack`.
    static let showLegacyBottomNotificationChrome = false
}

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var tabRouter: MainTabRouter
    @EnvironmentObject private var authService: AuthService
    @StateObject private var dataService: DataService

    @State private var showScanner: Bool = false
    @State private var showToast: Bool = false
    @State private var successToast: Toast = .example1
    @State private var scanError: String?
    @FocusState private var isNotificationFieldFocused: Bool
    @State private var notificationMessage: String = ""
    @State private var isSendingNotification = false
    @State private var notifyResultMessage: String?
    @State private var menuConfig: MenuConfig = MenuConfig(symbolImage: "person.2.fill")
    @State private var selectedCategoryIdsForNotify: [String] = []
    @State private var showCategoriesManagement = false
    @State private var navigationPath = NavigationPath()
    @State private var contentAppeared = false
    @State private var scanResultSheet: ScanResultSheetData?
    @State private var scanStampSheet: ScanStampSheetData?
    @State private var isScanAmountSubmitting = false
    @State private var isStampVisitSubmitting = false
    @StateObject private var receiptCoordinator = ReceiptValidationCoordinator()
    /// Incrémenté quand `CardPreviewDisplaySnapshotStore` change pour forcer le re-rendu de l’aperçu carte (autre `DataService` que Ma carte).
    @State private var cardPreviewDisplayRefresh = 0
    /// Une fois `true` après avoir ouvert « Ma carte » depuis l’aperçu accueil — arrête pulse sur l’aperçu.
    @AppStorage("myfidpass.merchantHomeCardOpenedFromHome.v1") private var merchantHomeCardOpenedFromHome = false

    private var palette: DashboardRevolutPalette { DashboardRevolutPalette(colorScheme: colorScheme) }

    init(context: NSManagedObjectContext) {
        _dataService = StateObject(wrappedValue: DataService(context: context))
    }

    private var activityFeed: [DashboardActivityEntry] {
        /// Uniquement les **scans** : évite la répétition « inscription + scan » pour un même client dans « Dernières transactions ».
        dataService.dashboardActivityFeed(limit: 40, includeNewCardEvents: false)
    }

    private var activityPreview: [DashboardActivityEntry] {
        Array(activityFeed.prefix(8))
    }

    /// Type de programme fidélité pour l’accueil (snapshot « Ma carte », défaut tampons).
    private var homeProgramIsPoints: Bool {
        let slug = AuthStorage.currentBusinessSlug ?? ""
        let raw = slug.isEmpty ? nil : CardPreviewDisplaySnapshotStore.load(slug: slug)?.programType
        return (raw ?? "points").lowercased() == "points"
    }

    private var menuActions: [MenuAction] {
        var list: [MenuAction] = []
        list.append(MenuAction(id: "notify-all", symbolImage: "person.2.fill", text: "Tous les membres") {
            menuConfig.showMenu = false
            selectedCategoryIdsForNotify = []
            isNotificationFieldFocused = true
        })
        for category in categoriesForNotify {
            let cat = category
            let sid = cat.serverId ?? UUID().uuidString
            list.append(MenuAction(id: "cat-\(sid)", symbolImage: "folder.fill", text: cat.name ?? "Catégorie") {
                menuConfig.showMenu = false
                selectedCategoryIdsForNotify = [sid]
                isNotificationFieldFocused = true
            })
        }
        list.append(MenuAction(id: "manage-categories", symbolImage: "folder.badge.gearshape", text: "Gérer les catégories") {
            menuConfig.showMenu = false
            showCategoriesManagement = true
        })
        return list
    }

    /// Contenu principal de l’accueil (ZStack + modificateurs navigation / scan).
    @ViewBuilder
    private var dashboardHomeRoot: some View {
        ZStack(alignment: .top) {
            palette.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        fintechHomeTopAndCard
                        fintechTransactionsSection
                            .padding(.top, -12)
                    }
                }
                .padding(.horizontal, DashboardHomeLayoutMetrics.scrollHorizontalPadding)
                .padding(.top, DashboardHomeChrome.showMinimalTopBar ? 4 : 0)
                .padding(.bottom, DashboardHomeChrome.showLegacyBottomNotificationChrome ? 280 : 100)
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 14)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await syncService.syncIfNeeded(force: true)
            }

            if DashboardHomeChrome.showMinimalTopBar {
                VStack(spacing: 0) {
                    DashboardHomeMinimalTopBar(
                        palette: palette,
                        onOpenProfile: {
                            withAnimation(MerchantMotion.tabSwitch) {
                                tabRouter.selectedTab = 2
                            }
                        },
                        onOpenScan: { showScanner = true }
                    )
                    .padding(.horizontal, DashboardHomeLayoutMetrics.topBarHorizontalInset)
                    .padding(.top, 6)
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            syncOverlay

            if DashboardHomeChrome.showLegacyBottomNotificationChrome {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    notificationRecipientChips
                    notificationBottomBar
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 15)
                .padding(.bottom, 10)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: DashboardRoute.self) { route in
            switch route {
            case .membersActivity(let initialFilter):
                DashboardActivityFullView(context: viewContext, initialFilter: initialFilter)
                    .environmentObject(syncService)
            case .myCard:
                MyCardView(context: viewContext)
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
        .onAppear {
            withAnimation(MerchantMotion.contentReveal.delay(0.05)) {
                contentAppeared = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassOpenHomeScanner)) { _ in
            navigationPath = NavigationPath()
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
        .alert("Notification", isPresented: Binding(
            get: { notifyResultMessage != nil },
            set: { if !$0 { notifyResultMessage = nil } }
        )) {
            Button("OK") { notifyResultMessage = nil }
        } message: {
            if let msg = notifyResultMessage { Text(msg) }
        }
    }

    var body: some View {
        let _ = dataService.updateTrigger
        Group {
            if !DashboardHomeChrome.showLegacyBottomNotificationChrome {
                NavigationStack(path: $navigationPath) {
                    dashboardHomeRoot
                }
            } else {
                CustomMenuView(config: $menuConfig, actions: menuActions) {
                    NavigationStack(path: $navigationPath) {
                        dashboardHomeRoot
                    }
                }
            }
        }
        .animation(MerchantMotion.navigationPath, value: navigationPath.count)
        .onChange(of: navigationPath) { _, path in
            tabRouter.isDashboardAtRoot = path.isEmpty
        }
        .onAppear {
            tabRouter.isDashboardAtRoot = navigationPath.isEmpty
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassRemoteSyncDidMerge)) { _ in
            dataService.bumpRefreshAfterRemoteMerge()
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassCardPreviewDisplayDidChange)) { _ in
            cardPreviewDisplayRefresh += 1
        }
        .sheet(isPresented: $showCategoriesManagement) {
            CategoriesManagementView(context: viewContext)
                .environmentObject(syncService)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .modifier(LiquidGlassSheetModifier())
        }
        .fullScreenCover(item: $scanResultSheet) { data in
            scanAddPointsSheet(for: data)
        }
        .fullScreenCover(item: $scanStampSheet) { data in
            AddStampVisitSheet(
                data: data,
                isSubmitting: $isStampVisitSubmitting,
                onDismiss: { scanStampSheet = nil },
                onConfirm: {
                    await submitStampVisit(slug: data.slug, barcode: data.barcode)
                }
            )
        }
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

    @ViewBuilder
    private func merchantHomeCardPreviewButton<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        Button {
            merchantHomeCardOpenedFromHome = true
            navigationPath.append(DashboardRoute.myCard)
        } label: {
            label()
        }
        .buttonStyle(MerchantPressableButtonStyle())
        .accessibilityLabel("Ma carte")
        .accessibilityHint("Ouvre la personnalisation de la carte fidélité.")
    }

    private var fintechHomeTopAndCard: some View {
        VStack(alignment: .leading, spacing: DashboardHomeChrome.showMinimalTopBar ? 18 : 8) {
            Color.clear
                .frame(height: DashboardHomeChrome.showMinimalTopBar ? 72 : 8)
                .accessibilityHidden(true)

            if let model = DashboardHomeCardModel.resolve(dataService: dataService) {
                merchantHomeCardPreviewButton {
                    FintechHomeLoyaltyCardBlock(
                        model: model,
                        palette: palette
                    )
                    .modifier(MerchantHomeCardFirstVisitShakeModifier(active: showHomeCardTapHint))
                }
            } else {
                merchantHomeCardPreviewButton {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .fill(palette.card)
                        .frame(height: 200)
                        .overlay(
                            VStack(spacing: 10) {
                                Image(systemName: "creditcard")
                                    .font(.largeTitle)
                                    .foregroundStyle(palette.tertiaryText)
                                Text("Synchronisez pour afficher votre carte")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(palette.secondaryText)
                                    .multilineTextAlignment(.center)
                                Text("Ouvrir Ma carte")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(palette.accentBlue)
                            }
                            .padding()
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 36, style: .continuous)
                                .strokeBorder(palette.cardStroke, lineWidth: 1)
                        )
                        .modifier(MerchantHomeCardFirstVisitShakeModifier(active: showHomeCardTapHint))
                }
            }
        }
        .id(cardPreviewDisplayRefresh)
    }

    /// Secousse type « shake » toutes les ~5 s (pas un balancement continu) tant que Ma carte n’a pas été ouverte depuis l’accueil.
    private struct MerchantHomeCardFirstVisitShakeModifier: ViewModifier {
        var active: Bool
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var offsetX: CGFloat = 0
        @State private var shakeLoopTask: Task<Void, Never>?

        func body(content: Content) -> some View {
            content
                .offset(x: offsetX)
                .shadow(color: Color.black.opacity(active ? 0.2 : 0.18), radius: 12, y: 6)
                .onAppear { restartShakeLoopIfNeeded() }
                .onChange(of: active) { _, new in
                    if new {
                        restartShakeLoopIfNeeded()
                    } else {
                        cancelShakeLoop(resetOffset: true)
                    }
                }
                .onChange(of: reduceMotion) { _, _ in
                    if reduceMotion {
                        cancelShakeLoop(resetOffset: true)
                    } else {
                        restartShakeLoopIfNeeded()
                    }
                }
                .onDisappear {
                    cancelShakeLoop(resetOffset: true)
                }
        }

        private func cancelShakeLoop(resetOffset: Bool) {
            shakeLoopTask?.cancel()
            shakeLoopTask = nil
            if resetOffset {
                offsetX = 0
            }
        }

        private func restartShakeLoopIfNeeded() {
            cancelShakeLoop(resetOffset: true)
            guard active, !reduceMotion else { return }
            shakeLoopTask = Task { @MainActor in
                do {
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    return
                }
                while !Task.isCancelled {
                    await performShakeBurst()
                    do {
                        try await Task.sleep(for: .seconds(5))
                    } catch {
                        return
                    }
                }
            }
        }

        /// Même logique que `FlyerPrimaryCTAShakeModifier` : impulsions gauche-droite rapides, puis repos.
        private func performShakeBurst() async {
            let pattern: [CGFloat] = [0, -10, 10, -8, 8, -5, 5, -2, 2, 0]
            for x in pattern {
                if Task.isCancelled { return }
                withAnimation(MerchantMotion.flyerCTAShakeStep) {
                    offsetX = x
                }
                do {
                    try await Task.sleep(nanoseconds: 38_000_000)
                } catch {
                    return
                }
            }
        }
    }

    private var fintechTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FintechTransactionsSectionHeader(
                palette: palette,
                onSeeAll: { navigationPath.append(DashboardRoute.membersActivity(.all)) },
                onOpenScanner: { showScanner = true }
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
                            navigationPath.append(DashboardRoute.memberDetail(entry.cardObjectID))
                        } label: {
                            FintechTransactionRow(entry: entry, palette: palette, isPointsProgram: homeProgramIsPoints)
                        }
                        .buttonStyle(MerchantPressableButtonStyle(scalePressed: 0.98, opacityPressed: 0.94))
                        .accessibilityLabel("Ouvrir la fiche de \(entry.clientName)")
                    }
                }
            }
        }
        .padding(.horizontal, DashboardHomeLayoutMetrics.transactionsSectionExtraHorizontal)
    }

    @ViewBuilder
    private var syncOverlay: some View {
        if syncService.isSyncing {
            VStack {
                ProgressView()
                    .scaleEffect(1.15)
                    .tint(palette.onCanvasPrimary)
                    .padding(.top, 10)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Notification bas d’écran

    private var notificationBottomBar: some View {
        let fillColor = palette.barButtonFill
        let hasText = !notificationMessage.trimmingCharacters(in: .whitespaces).isEmpty
        return AnimatedBottomBar(
            hint: "Message pour vos membres…",
            tint: palette.accentBlue,
            text: $notificationMessage,
            isFocused: $isNotificationFieldFocused,
            leadingAction: {
                recipientsButtonView(fillColor: fillColor)
            },
            trailingAction: {
                if isNotificationFieldFocused {
                    Button {
                        if hasText { sendNotificationToAll() }
                        isNotificationFieldFocused = false
                    } label: {
                        Image(systemName: "checkmark")
                            .fontWeight(.medium)
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(palette.accentBlue.gradient, in: .circle)
                    }
                    .buttonStyle(.borderless)
                } else {
                    Color.clear
                        .frame(width: 35, height: 35)
                }
            },
            mainAction: {
                if isNotificationFieldFocused && hasText {
                    Button {
                        sendNotificationToAll()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.body)
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isSendingNotification)
                } else {
                    recipientsButtonView(fillColor: fillColor)
                }
            }
        )
    }

    @ViewBuilder
    private var notificationRecipientChips: some View {
        let cats = categoriesForNotify
        if isNotificationFieldFocused, !cats.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    RecipientCategoryChip(
                        title: "Tous",
                        isSelected: selectedCategoryIdsForNotify.isEmpty,
                        color: palette.accentBlue,
                        palette: palette
                    ) {
                        selectedCategoryIdsForNotify = []
                    }
                    ForEach(cats, id: \.objectID) { category in
                        let sid = category.serverId ?? ""
                        let isSelected = !sid.isEmpty && selectedCategoryIdsForNotify.contains(sid)
                        RecipientCategoryChip(
                            title: category.name ?? "",
                            isSelected: isSelected,
                            color: (category.colorHex.flatMap { Color(hex: $0) }) ?? palette.accentBlue,
                            palette: palette
                        ) {
                            if isSelected {
                                selectedCategoryIdsForNotify.removeAll { $0 == sid }
                            } else if !sid.isEmpty {
                                selectedCategoryIdsForNotify.append(sid)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .padding(.bottom, 4)
        }
    }

    private var categoriesForNotify: [MemberCategory] {
        guard let template = dataService.currentCardTemplate() else { return [] }
        return dataService.categories(for: template)
    }

    @ViewBuilder
    private func recipientsButtonView(fillColor: Color) -> some View {
        MenuSourceButton(config: $menuConfig) {
            Image(systemName: "person.2.fill")
                .fontWeight(.medium)
                .foregroundStyle(palette.onCanvasPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(fillColor, in: .circle)
        } onTap: {
            isNotificationFieldFocused = false
        }
    }

    private func sendNotificationToAll() {
        let msg = notificationMessage.trimmingCharacters(in: .whitespaces)
        guard !msg.isEmpty else { return }
        guard let slug = AuthStorage.currentBusinessSlug else {
            notifyResultMessage = "Aucun commerce. Reconnectez-vous."
            return
        }
        isSendingNotification = true
        notifyResultMessage = nil
        isNotificationFieldFocused = false
        Task {
            do {
                let result = try await APIClient.shared.request(
                    APIEndpoint.notifyClients(slug: slug, message: msg, categoryIds: selectedCategoryIdsForNotify.isEmpty ? nil : selectedCategoryIdsForNotify)
                ) as NotifyClientsResult
                await MainActor.run {
                    isSendingNotification = false
                    let n = result.sent ?? 0
                    notifyResultMessage = n > 0 ? "Notification envoyée (\(n) appareil(s))." : "Aucun appareil cible (Wallet / Web). Message enregistré."
                    notificationMessage = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        notifyResultMessage = nil
                    }
                }
                await syncService.syncAfterServerMutation()
            } catch {
                await MainActor.run {
                    isSendingNotification = false
                    notifyResultMessage = (error as? APIError)?.errorDescription ?? "Erreur lors de l’envoi."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        notifyResultMessage = nil
                    }
                }
            }
        }
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
        let barcode = normalizeBarcodeToMemberId(code)
        Task {
            do {
                async let lookupTask = APIClient.shared.request(.scanLookup(slug: slug, barcode: barcode)) as ScanLookupResponse

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

                if shouldPresentEuroPointsSheetAfterScan(settings) {
                    let tierDTOs = settings.pointsRewardTiers ?? []
                    let rewardTiers = tierDTOs
                        .filter { $0.points > 0 }
                        .map { ScanRewardTier(points: $0.points, label: $0.label.isEmpty ? "Récompense" : $0.label) }
                        .sorted { $0.points < $1.points }
                    let sheetData = ScanResultSheetData(
                        slug: slug,
                        memberName: memberName,
                        barcode: barcode,
                        pointsPerEuro: pointsPerEuro,
                        memberPoints: lookup.member.points,
                        rewardTiers: rewardTiers,
                        pointsMinAmountEur: settings.pointsMinAmountEur
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
                        DashboardHomeCardModel.resolveStampScanPreview(
                            dataService: dataService,
                            memberName: memberName,
                            memberStampBalance: lookup.member.points,
                            settings: settings
                        )
                    }
                    if let stampModel {
                        let stampData = ScanStampSheetData(
                            slug: slug,
                            barcode: barcode,
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
                    .scan(slug: slug, barcode: barcode, visit: true, points: nil, amountEur: nil, receiptValidationToken: nil)
                )
                await MainActor.run {
                    successToast = Toast.scanStampSuccess(
                        memberName: response.member?.name ?? memberName,
                        pointsCapped: response.pointsCapped == true,
                        pointsRequested: response.pointsRequested,
                        pointsAdded: response.pointsAdded,
                        stampCycleCompleted: response.stampCycleCompleted == true
                    )
                    showToast = true
                }
                Task { await syncService.syncAfterServerMutation() }
            } catch APIError.notFound {
                await MainActor.run {
                    scanError = "Code non reconnu pour ce commerce. Scannez le QR affiché sur la carte dans le Wallet du client (pas le lien « Ajouter à Wallet »)."
                    appState.showError(scanError ?? "Code non reconnu.")
                }
            } catch {
                let msg = (error as? APIError)?.errorDescription ?? "Erreur lors du scan."
                await MainActor.run {
                    scanError = msg
                    appState.showError(msg)
                }
            }
        }
    }

    @discardableResult
    private func submitStampVisit(slug: String, barcode: String) async -> Bool {
        isStampVisitSubmitting = true
        defer { Task { @MainActor in isStampVisitSubmitting = false } }
        do {
            let response: ScanResponse = try await APIClient.shared.request(
                .scan(slug: slug, barcode: barcode, visit: true, points: nil, amountEur: nil, receiptValidationToken: nil)
            )
            await MainActor.run {
                successToast = Toast.scanStampSuccess(
                    memberName: response.member?.name ?? "Client",
                    pointsCapped: response.pointsCapped == true,
                    pointsRequested: response.pointsRequested,
                    pointsAdded: response.pointsAdded,
                    stampCycleCompleted: response.stampCycleCompleted == true
                )
                var tx = Transaction()
                tx.disablesAnimations = true
                withTransaction(tx) {
                    scanStampSheet = nil
                }
                showToast = true
            }
            await syncService.syncAfterServerMutation()
            return true
        } catch {
            await MainActor.run {
                scanError = (error as? APIError)?.errorDescription ?? "Erreur lors de l’enregistrement du tampon."
                appState.showError(scanError ?? "Erreur")
            }
            return false
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
            Task { await syncService.syncAfterServerMutation() }
            return true
        } catch {
            await MainActor.run {
                scanError = (error as? APIError)?.errorDescription ?? "Erreur lors de l'enregistrement."
                appState.showError(scanError ?? "Erreur")
            }
            return false
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
                Task { await syncService.syncAfterServerMutation() }
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
                    Task { await syncService.syncAfterServerMutation() }
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
                Task { await syncService.syncAfterServerMutation() }
                return finalP
            }
            await MainActor.run {
                scanError = "Créditez d’abord assez de points pour ce palier (\(tier.points) pts), ou augmentez le montant du panier."
                appState.showError(scanError ?? "")
            }
            return nil
        } catch {
            await MainActor.run {
                let msg = (error as? APIError)?.errorDescription ?? "Impossible d’appliquer la récompense."
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
    DashboardView(context: PersistenceController.preview.container.viewContext)
        .environmentObject(SyncService(container: PersistenceController.preview.container))
        .environmentObject(AppState.shared)
        .environmentObject(MainTabRouter())
}
