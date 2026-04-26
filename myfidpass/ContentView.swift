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
    /// Évite les sync forcées en rafale (retour app, multitâche). Intervalle large = bandeau moins « nerveux ».
    @State private var lastForegroundFullSyncAt: Date = .distantPast
    /// Pastille « Synchronisé » après une sync réussie (masquée si une nouvelle sync démarre).
    @State private var showSyncSuccessChip = false
    @State private var syncSuccessHideTask: Task<Void, Never>?
    /// Anti-spam UX : on n'affiche le bandeau sync qu'après un court délai et on peut le masquer temporairement.
    @State private var syncBannerShowDelayTask: Task<Void, Never>?
    @State private var syncBannerVisibleForCurrentRun = false
    @State private var syncRunStartedAt: Date?
    @State private var syncBannerDismissedUntil: Date = .distantPast
    @State private var syncBannerDragOffset: CGFloat = 0
    @State private var didScheduleStartupVersionCheck = false
    /// Bandeau d’erreur sync : l’utilisateur peut masquer sans effacer `lastError` (détail dans Réglages).
    @State private var dismissedSyncErrorBanner = false
    @State private var isSoftwareKeyboardVisible = false
    /// Masque le bandeau sync pendant le tutoriel (le snapshot du tutoriel ne doit pas capturer ce bandeau).
    @AppStorage("myfidpass.homeTutorial.v1") private var homeTutorialCompleted = false

    var body: some View {
        Group {
            if merchantMustCompleteSubscriptionPaywall {
                MerchantSubscriptionGateView(isMandatory: true)
                    .environmentObject(authService)
                    .environmentObject(revenueCatSubscriptionState)
                    .environment(\.managedObjectContext, viewContext)
            } else {
                mainMerchantTabStack
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassOpenMerchantSubscriptionSheet)) { _ in
            guard !authService.isMerchantStaffUser else { return }
            showMerchantSubscriptionSheet = true
        }
        /// Ancienne notif « essai → Safari Stripe » : ouvre le paywall natif.
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassOpenMerchantTrialStripePaymentLink)) { _ in
            guard !authService.isMerchantStaffUser else { return }
            showMerchantSubscriptionSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassSubscriptionPaymentCompleted)) { _ in
            showMerchantSubscriptionSheet = false
            syncService.invalidateSyncThrottle()
            Task(priority: .userInitiated) {
                await authService.reconcileStripeSubscriptionFromServer(force: true)
                await authService.refreshBusinessesIfNeeded()
                await syncService.syncAfterServerMutation()
            }
        }
        /// Paywall depuis la pastille d’essai / Réglages / notif : **feuille** (sheet). Le flux post-création de compte reste une **page pleine** (`merchantMustCompleteSubscriptionPaywall` → `isMandatory: true` ci-dessus).
        .sheet(isPresented: $showMerchantSubscriptionSheet) {
            MerchantSubscriptionGateView(isMandatory: false)
                .environmentObject(authService)
                .environmentObject(revenueCatSubscriptionState)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
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
        .onChange(of: merchantMustCompleteSubscriptionPaywall) { wasBlocking, isBlocking in
            guard wasBlocking && !isBlocking else { return }
            guard authService.consumePendingHomeTutorialAfterSignup() else { return }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .myfidpassResetTutorial, object: nil)
            }
        }
        .sheet(item: $updateAppInfo) { info in
            AppUpdateView(appInfo: info, forcedUpdate: $forcedAppUpdate)
        }
        .task {
            await authService.reconcileStripeSubscriptionFromServer(force: true)
            await authService.refreshBusinessesIfNeeded()
            await scheduleStartupVersionCheckIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            guard authService.currentScreen == .authenticated else { return }
            guard merchantMustCompleteSubscriptionPaywall else { return }
            Task(priority: .utility) {
                await authService.reconcileStripeSubscriptionFromServer(force: true)
                await authService.refreshBusinessesIfNeeded()
                syncService.invalidateSyncThrottle()
                await syncService.syncAfterServerMutation()
            }
        }
    }

    /// Commerçant : accès aux onglets **uniquement** avec abonnement actif (IAP RevenueCat ou statut aligné API, ex. historique Stripe côté serveur).
    private var merchantMustCompleteSubscriptionPaywall: Bool {
        authService.merchantSubscriptionEligibilityResolved
            && !authService.isPlatformAdmin
            && !authService.subscriptionAccessUnlocked(revenueCatPremium: revenueCatSubscriptionState.hasPremiumEntitlement)
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

    /// Onglets + pastille d’essai + sync (masqué quand le paywall d’inscription / essai bloque l’app).
    @ViewBuilder
    private var mainMerchantTabStack: some View {
        MainTabView()
            .safeAreaInset(edge: .top, spacing: 0) {
                if authService.isPlatformAdmin && authService.adminShowsMerchantWorkspace {
                    adminMerchantPilotBanner
                }
            }
            .environment(\.isSoftwareKeyboardVisible, isSoftwareKeyboardVisible)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.2)) { isSoftwareKeyboardVisible = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.2)) { isSoftwareKeyboardVisible = false }
            }
            .overlay(alignment: .top) { if homeTutorialCompleted { topSyncAndErrorOverlay } }
            .onChange(of: syncService.lastError) { _, new in
                if new == nil { dismissedSyncErrorBanner = false }
            }
            .onChange(of: syncService.syncErrorRevision) { _, _ in
                dismissedSyncErrorBanner = false
            }
            .onChange(of: syncService.isSyncing) { _, syncing in
                if syncing {
                    showSyncSuccessChip = false
                    syncSuccessHideTask?.cancel()
                    syncSuccessHideTask = nil
                    syncRunStartedAt = Date()
                    syncBannerVisibleForCurrentRun = false
                    syncBannerDragOffset = 0
                    syncBannerShowDelayTask?.cancel()
                    if Date() >= syncBannerDismissedUntil {
                        syncBannerShowDelayTask = Task { @MainActor in
                            try? await Task.sleep(for: .seconds(1.2))
                            guard !Task.isCancelled else { return }
                            guard syncService.isSyncing else { return }
                            guard Date() >= syncBannerDismissedUntil else { return }
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                                syncBannerVisibleForCurrentRun = true
                            }
                        }
                    }
                } else {
                    syncBannerShowDelayTask?.cancel()
                    syncBannerShowDelayTask = nil
                    let runDuration = Date().timeIntervalSince(syncRunStartedAt ?? Date())
                    let shouldShowSuccess = syncBannerVisibleForCurrentRun || runDuration >= 2.4
                    syncBannerVisibleForCurrentRun = false
                    guard syncService.lastError == nil else { return }
                    guard Date() >= syncBannerDismissedUntil, shouldShowSuccess else {
                        showSyncSuccessChip = false
                        return
                    }
                    showSyncSuccessChip = true
                    syncSuccessHideTask?.cancel()
                    syncSuccessHideTask = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.8))
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
            .overlay(alignment: .bottom) {
                if shouldShowTrialSubscribePillInCurrentTab, !isSoftwareKeyboardVisible, let trialEnd = authService.merchantTrialEndsAt {
                    MerchantTrialSubscribePillView(trialEndsAt: trialEnd) {
                        showMerchantSubscriptionSheet = true
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, trialSubscribePillBottomPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
    }

    /// Au-dessus de la tab bar. `gap` négatif = pastille plus basse (plus proche des onglets).
    private var trialSubscribePillBottomPadding: CGFloat {
        let tabBarApprox: CGFloat = 52
        let gap: CGFloat = -10
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
            let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        else {
            return tabBarApprox + gap + 24
        }
        return window.safeAreaInsets.bottom + tabBarApprox + gap
    }

    /// Pastille essai affichée sur Accueil + Notifs (pas sur Commerce où un bandeau dédié existe déjà).
    private var shouldShowTrialSubscribePillInCurrentTab: Bool {
        guard !authService.isMerchantStaffUser else { return false }
        guard authService.isMerchantTrialPeriodActive, authService.merchantTrialEndsAt != nil else { return false }
        return tabRouter.selectedTab == 0 || tabRouter.selectedTab == 1
    }

    private var syncBannerTopPadding: CGFloat { 10 }

    private var syncErrorBannerVisible: Bool {
        !syncService.isSyncing
            && !dismissedSyncErrorBanner
            && !(syncService.lastError?.isEmpty ?? true)
    }

    private var topSyncAndErrorOverlay: some View {
        VStack(spacing: 8) {
            if syncErrorBannerVisible {
                syncFailureBanner
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity.combined(with: .move(edge: .top))
                        )
                    )
            }
            syncIndicatorOverlay
        }
        .padding(.top, syncBannerTopPadding)
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: syncErrorBannerVisible)
    }

    private var syncFailureBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("Synchronisation impossible")
                    .font(.caption.weight(.semibold))
                Text(syncService.lastError ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button {
                Task { await syncService.syncAfterServerMutation() }
            } label: {
                Text("Réessayer")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Button {
                dismissedSyncErrorBanner = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Fermer le message")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 420)
        .glassEffect(.regular, cornerRadius: 20)
    }

    /// Affiche le bandeau (sync en cours ou succès).
    private var syncBannerShown: Bool {
        Date() >= syncBannerDismissedUntil && (syncBannerVisibleForCurrentRun || showSyncSuccessChip)
    }

    /// Bandeau sync : **même gabarit** chargement / succès, transitions spring + crossfade (plus de rétrécissement brutal).
    private var syncIndicatorOverlay: some View {
        Group {
            if syncBannerShown {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        if syncService.isSyncing {
                            ProgressView()
                                .scaleEffect(1.08)
                                .tint(.primary)
                                .transition(.opacity.combined(with: .scale(scale: 0.88, anchor: .center)))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color.green)
                                .symbolEffect(.bounce, options: .nonRepeating, value: showSyncSuccessChip && !syncService.isSyncing)
                                .transition(.opacity.combined(with: .scale(scale: 0.88, anchor: .center)))
                        }
                    }
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(syncService.isSyncing ? "Synchronisation en cours" : "Synchronisé")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(syncService.isSyncing ? Color.primary : Color.green)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .contentTransition(.interpolate)
                        if syncService.isSyncing {
                            Text("Glissez vers le haut pour masquer")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(minWidth: 220, alignment: .leading)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(minHeight: 64)
                .glassEffect(.regular, cornerRadius: 24)
                .offset(y: syncBannerDragOffset)
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            syncBannerDragOffset = min(0, value.translation.height)
                        }
                        .onEnded { value in
                            if value.translation.height < -28 {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                                    showSyncSuccessChip = false
                                    syncBannerVisibleForCurrentRun = false
                                    syncBannerDragOffset = -60
                                }
                                syncBannerDismissedUntil = Date().addingTimeInterval(35)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                                        syncBannerDragOffset = 0
                                    }
                                }
                            } else {
                                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                                    syncBannerDragOffset = 0
                                }
                            }
                        }
                )
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
