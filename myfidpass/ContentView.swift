//
//  ContentView.swift
//  myfidpass
//
//  Point d’entrée principal : app commerçant (accueil, carte, profil, espace pro).
//

import SwiftUI
import CoreData
import UIKit

struct ContentView: View {
    /// Temporaire : `true` = pas de feuille « mise à jour disponible » au lancement. Repasser à `false` pour réactiver.
    private static let suppressAppUpdateAvailableSheet = true
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var revenueCatSubscriptionState: RevenueCatSubscriptionState
    @StateObject private var tabRouter = MainTabRouter()
    @State private var updateAppInfo: VersionCheckManager.ReturnResult?
    @State private var forcedAppUpdate = false
    @State private var showMerchantSubscriptionSheet = false
    @State private var showTrialStripePaymentSafari = false
    /// Évite les sync forcées en rafale (retour app, multitâche). Intervalle large = bandeau moins « nerveux ».
    @State private var lastForegroundFullSyncAt: Date = .distantPast
    /// Pastille « Synchronisé » après une sync réussie (masquée si une nouvelle sync démarre).
    @State private var showSyncSuccessChip = false
    @State private var syncSuccessHideTask: Task<Void, Never>?
    /// Masque la pastille « Abonnez-vous 1 € » quand le clavier recouvre l’écran (saisie de texte).
    @State private var isSoftwareKeyboardVisible = false
    @State private var didScheduleStartupVersionCheck = false

    var body: some View {
        Group {
            if shouldShowPostSignupSubscriptionGate {
                MerchantSubscriptionGateView()
                    .environmentObject(authService)
                    .environmentObject(revenueCatSubscriptionState)
                    .environment(\.managedObjectContext, viewContext)
            } else if merchantSubscriptionPaywallBlocking {
                MerchantSubscriptionPaywallBlockingView(
                    onContinue: { showMerchantSubscriptionSheet = true }
                )
                .environmentObject(authService)
                .environmentObject(syncService)
                .environmentObject(revenueCatSubscriptionState)
                .environment(\.managedObjectContext, viewContext)
            } else {
                mainMerchantTabStack
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassOpenMerchantSubscriptionSheet)) { _ in
            showMerchantSubscriptionSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassOpenMerchantTrialStripePaymentLink)) { _ in
            showTrialStripePaymentSafari = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassSubscriptionPaymentCompleted)) { _ in
            showMerchantSubscriptionSheet = false
            showTrialStripePaymentSafari = false
            syncService.invalidateSyncThrottle()
            Task(priority: .userInitiated) {
                await authService.reconcileStripeSubscriptionFromServer(force: true)
                await authService.refreshBusinessesIfNeeded()
                await syncService.syncAfterServerMutation()
            }
        }
        .sheet(isPresented: $showMerchantSubscriptionSheet) {
            MerchantSubscriptionGateView()
                .environmentObject(authService)
                .environmentObject(revenueCatSubscriptionState)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTrialStripePaymentSafari) {
            InAppSafariView(
                url: LegalURLs.merchantStripeSubscriptionPaymentLinkWithPromo(prefilledEmail: authService.currentUserEmail)
            )
            .ignoresSafeArea()
        }
        .onChange(of: showMerchantSubscriptionSheet) { _, isShowing in
            if !isShowing {
                syncService.invalidateSyncThrottle()
                Task(priority: .utility) {
                    await authService.reconcileStripeSubscriptionFromServer(force: true)
                    await authService.refreshBusinessesIfNeeded()
                    await syncService.syncAfterServerMutation()
                }
            }
        }
        .onChange(of: showTrialStripePaymentSafari) { _, isShowing in
            if !isShowing {
                syncService.invalidateSyncThrottle()
                Task(priority: .utility) {
                    await authService.reconcileStripeSubscriptionFromServer(force: true)
                    await authService.refreshBusinessesIfNeeded()
                    await syncService.syncAfterServerMutation()
                }
            }
        }
        .sheet(item: $updateAppInfo) { info in
            AppUpdateView(appInfo: info, forcedUpdate: $forcedAppUpdate)
        }
        .onAppear {
            consumePostSignupPendingIfNotNeeded()
        }
        .task {
            await authService.reconcileStripeSubscriptionFromServer(force: true)
            await authService.refreshBusinessesIfNeeded()
            consumePostSignupPendingIfNotNeeded()
            await scheduleStartupVersionCheckIfNeeded()
        }
        .onChange(of: authService.merchantSubscriptionEligibilityResolved) { _, resolved in
            guard resolved else { return }
            consumePostSignupPendingIfNotNeeded()
        }
        .onChange(of: revenueCatSubscriptionState.hasPremiumEntitlement) { _, _ in
            consumePostSignupPendingIfNotNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            guard authService.currentScreen == .authenticated else { return }
            guard merchantSubscriptionPaywallBlocking else { return }
            Task(priority: .utility) {
                await authService.reconcileStripeSubscriptionFromServer(force: true)
                await authService.refreshBusinessesIfNeeded()
                syncService.invalidateSyncThrottle()
                await syncService.syncAfterServerMutation()
            }
        }
    }

    /// Paywall **avant** les onglets : inscription récente sans abonnement actif.
    private var shouldShowPostSignupSubscriptionGate: Bool {
        AuthStorage.pendingOpenMerchantSubscriptionSheetAfterSignup
            && AuthStorage.isLoggedIn
            && authService.currentScreen == .authenticated
            && !authService.isPlatformAdmin
            && !authService.subscriptionAccessUnlocked(revenueCatPremium: revenueCatSubscriptionState.hasPremiumEntitlement)
    }

    /// Consomme le flag post-inscription si admin ou déjà abonné (évite un état coincé).
    @MainActor
    private func consumePostSignupPendingIfNotNeeded() {
        guard AuthStorage.pendingOpenMerchantSubscriptionSheetAfterSignup else { return }
        if authService.isPlatformAdmin {
            AuthStorage.pendingOpenMerchantSubscriptionSheetAfterSignup = false
            return
        }
        if authService.subscriptionAccessUnlocked(revenueCatPremium: revenueCatSubscriptionState.hasPremiumEntitlement) {
            AuthStorage.pendingOpenMerchantSubscriptionSheetAfterSignup = false
        }
    }

    @MainActor
    private func scheduleStartupVersionCheckIfNeeded() async {
        guard !Self.suppressAppUpdateAvailableSheet else { return }
        guard !didScheduleStartupVersionCheck else { return }
        didScheduleStartupVersionCheck = true

        // Ne pas présenter la feuille de mise à jour pendant la phase critique de lancement:
        // l’écran fait déjà auth/bootstrap/sync et la feuille pouvait apparaître par-dessus
        // "Synchronisation...", ce qui compliquait le diagnostic et surchargeait le démarrage.
        for _ in 0..<20 {
            if !syncService.isSyncing { break }
            try? await Task.sleep(for: .milliseconds(250))
        }
        try? await Task.sleep(for: .seconds(1))

        guard authService.currentScreen == .authenticated else { return }
        guard updateAppInfo == nil else { return }

        if let result = await VersionCheckManager.shared.checkIfAppUpdateAvailable() {
            updateAppInfo = result
        }
    }

    /// Onglets + pastille d’essai + sync (masqué quand le paywall post–24 h bloque l’app).
    @ViewBuilder
    private var mainMerchantTabStack: some View {
        MainTabView()
            .safeAreaInset(edge: .top, spacing: 0) {
                if authService.isPlatformAdmin && authService.adminShowsMerchantWorkspace {
                    adminMerchantPilotBanner
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 52) {
                if authService.isMerchantTrialPeriodActive, let trialEnd = authService.merchantTrialEndsAt, shouldShowMerchantTrialSubscribePill, !isSoftwareKeyboardVisible {
                    MerchantTrialSubscribePillView(trialEndsAt: trialEnd) {
                        showTrialStripePaymentSafari = true
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 70)
                }
            }
            .overlay(alignment: .top) { syncIndicatorOverlay }
            .onChange(of: syncService.isSyncing) { _, syncing in
                if syncing {
                    showSyncSuccessChip = false
                    syncSuccessHideTask?.cancel()
                    syncSuccessHideTask = nil
                } else {
                    guard syncService.lastError == nil else { return }
                    showSyncSuccessChip = true
                    syncSuccessHideTask?.cancel()
                    syncSuccessHideTask = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2.2))
                        guard !Task.isCancelled else { return }
                        showSyncSuccessChip = false
                    }
                }
            }
            .onChange(of: authService.currentScreen) { _, screen in
                if screen == .authenticated {
                    tabRouter.applyInitialCommerceTabIfFlyerMissing()
                }
                guard screen != .authenticated else { return }
                showSyncSuccessChip = false
                syncSuccessHideTask?.cancel()
                syncSuccessHideTask = nil
            }
            .environmentObject(tabRouter)
            .environment(\.managedObjectContext, viewContext)
            .onAppear {
                tabRouter.applyInitialCommerceTabIfFlyerMissing()
                NotificationsService.shared.requestPermissionAndRegister()
                Task(priority: .utility) {
                    try? await Task.sleep(nanoseconds: 280_000_000)
                    await syncService.syncIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                isSoftwareKeyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                isSoftwareKeyboardVisible = false
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                guard authService.currentScreen == .authenticated else { return }
                let now = Date()
                Task(priority: .utility) { @MainActor in
                    guard now.timeIntervalSince(lastForegroundFullSyncAt) > 90 else { return }
                    if let lastSync = syncService.lastSyncDate, now.timeIntervalSince(lastSync) < 60 {
                        return
                    }
                    lastForegroundFullSyncAt = now
                    if !authService.subscriptionAccessUnlocked(revenueCatPremium: revenueCatSubscriptionState.hasPremiumEntitlement) {
                        await authService.reconcileStripeSubscriptionFromServer()
                        await authService.refreshBusinessesIfNeeded()
                    }
                    await syncService.syncAfterServerMutation()
                }
            }
            .onOpenURL { url in
                if relayOAuthUniversalLinkIfNeeded(url: url) { return }
                handleScanDeepLink(url: url)
            }
    }

    /// Après la fin des 24 h : pas d’abonnement actif → écran bloquant (remplace l’ancien bandeau « mode découverte »).
    private var merchantSubscriptionPaywallBlocking: Bool {
        authService.merchantSubscriptionEligibilityResolved
            && !authService.subscriptionAccessUnlocked(revenueCatPremium: revenueCatSubscriptionState.hasPremiumEntitlement)
            && !authService.isMerchantTrialPeriodActive
    }

    private var syncBannerTopPadding: CGFloat {
        authService.merchantSubscriptionEligibilityResolved
            && !authService.subscriptionAccessUnlocked(revenueCatPremium: revenueCatSubscriptionState.hasPremiumEntitlement)
            ? 68
            : 10
    }

    /// Pastille d’essai flottante : pas sur l’onglet Commerce (pastille intégrée dans `ProfileView`). Sinon Accueil racine + Campagnes.
    private var shouldShowMerchantTrialSubscribePill: Bool {
        guard (0 ... 2).contains(tabRouter.selectedTab) else { return false }
        if tabRouter.isMerchantFlyerHubPresented { return false }
        if tabRouter.isMyCardScreenPresented { return false }
        if tabRouter.selectedTab == 2 { return false }
        if tabRouter.selectedTab == 0 { return tabRouter.isDashboardAtRoot }
        return true
    }

    /// Affiche le bandeau (sync en cours ou succès).
    private var syncBannerShown: Bool {
        syncService.isSyncing || showSyncSuccessChip
    }

    /// Bandeau sync : **même gabarit** chargement / succès, transitions spring + crossfade (plus de rétrécissement brutal).
    private var syncIndicatorOverlay: some View {
        Group {
            if syncBannerShown {
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        if syncService.isSyncing {
                            ProgressView()
                                .scaleEffect(0.92)
                                .tint(.primary)
                                .transition(.opacity.combined(with: .scale(scale: 0.88, anchor: .center)))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.green)
                                .symbolEffect(.bounce, options: .nonRepeating, value: showSyncSuccessChip && !syncService.isSyncing)
                                .transition(.opacity.combined(with: .scale(scale: 0.88, anchor: .center)))
                        }
                    }
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)

                    Text(syncService.isSyncing ? "Synchronisation…" : "Synchronisé")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(syncService.isSyncing ? Color.primary : Color.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(minWidth: 152, alignment: .leading)
                        .contentTransition(.interpolate)
                        .accessibilityLabel(syncService.isSyncing ? "Synchronisation en cours" : "Synchronisé")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .glassEffect(.regular, cornerRadius: 22)
                .padding(.top, syncBannerTopPadding)
                .allowsHitTesting(false)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity.combined(with: .move(edge: .top))
                    )
                )
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: syncBannerShown)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: syncService.isSyncing)
    }

    /// Bandeau retour **Administration** quand l’admin pilote un commerce (interface commerçant).
    private var adminMerchantPilotBanner: some View {
        HStack(spacing: 12) {
            Button {
                authService.adminShowsMerchantWorkspace = false
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.backward.circle.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Administration")
                            .font(.subheadline.weight(.semibold))
                        if let slug = AuthStorage.currentBusinessSlug, !slug.isEmpty {
                            Text(slug)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    /// Lien `myfidpass://scan` (widget, Safari, etc.) : diffère la notification pour que l’onglet Accueil et
    /// `DashboardView` soient montés (sinon l’app s’ouvre sans lancer le scanner).
    /// Universal Links `https://myfidpass.fr/oauth/…` (retour OAuth) → relay `myfidpass://oauth-…` pour l’UI métriques.
    private func relayOAuthUniversalLinkIfNeeded(url: URL) -> Bool {
        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "https" || scheme == "http" else { return false }
        let host = url.host?.lowercased() ?? ""
        guard host == "myfidpass.fr" || host == "www.myfidpass.fr" else { return false }
        let path = url.path
        let oauthHost: String?
        if path.contains("/oauth/tiktok") {
            oauthHost = "oauth-tiktok"
        } else if path.contains("/oauth/meta") {
            oauthHost = "oauth-meta"
        } else if path.contains("/oauth/google-youtube") {
            oauthHost = "oauth-google-youtube"
        } else if path.contains("/oauth/google-business") {
            oauthHost = "oauth-google-business"
        } else {
            oauthHost = nil
        }
        guard let h = oauthHost else { return false }
        var c = URLComponents()
        c.scheme = "myfidpass"
        c.host = h
        c.queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        guard let relay = c.url else { return false }
        NotificationCenter.default.post(name: .myfidpassOAuthUniversalLinkRelay, object: relay)
        return true
    }

    private func handleScanDeepLink(url: URL) {
        guard url.scheme?.lowercased() == "myfidpass" else { return }
        let host = url.host?.lowercased() ?? ""
        guard host == "scan" else { return }
        guard authService.currentScreen == .authenticated else { return }
        withAnimation(MerchantMotion.tabSwitch) {
            tabRouter.selectedTab = 0
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .myfidpassOpenHomeScanner, object: nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            NotificationCenter.default.post(name: .myfidpassOpenHomeScanner, object: nil)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(SyncService(container: PersistenceController.preview.container))
        .environmentObject(AuthService())
}
