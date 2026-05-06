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
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var authService: AuthService
    @StateObject private var tabRouter = MainTabRouter()
    @State private var showMerchantSubscriptionSheet = false
    @State private var showGlobalSettingsSheet = false
    /// Pastille « Synchronisé » après une sync réussie (masquée si une nouvelle sync démarre).
    @State private var showSyncSuccessChip = false
    @State private var syncSuccessHideTask: Task<Void, Never>?
    /// Anti-spam UX : on n'affiche le bandeau sync qu'après un court délai et on peut le masquer temporairement.
    @State private var syncBannerShowDelayTask: Task<Void, Never>?
    @State private var syncBannerVisibleForCurrentRun = false
    @State private var syncRunStartedAt: Date?
    @State private var syncBannerDismissedUntil: Date = .distantPast
    @State private var syncBannerDragOffset: CGFloat = 0
    /// Bandeau d’erreur sync : l’utilisateur peut masquer sans effacer `lastError` (détail dans Réglages).
    @State private var dismissedSyncErrorBanner = false
    @State private var isSoftwareKeyboardVisible = false
    @State private var softwareKeyboardHeight: CGFloat = 0
    /// Anti-flash: garde la pastille cachée un court instant après un événement clavier.
    @State private var suppressTrialPillUntil: Date = .distantPast
    /// Masque le bandeau sync pendant le tutoriel (le snapshot du tutoriel ne doit pas capturer ce bandeau).
    @AppStorage("myfidpass.homeTutorial.v1") private var homeTutorialCompleted = false

    var body: some View {
        Group {
            if merchantMustCompleteSubscriptionPaywall {
                MerchantSubscriptionGateView(isMandatory: true)
                    .environmentObject(authService)
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
            Task { await runPostPaywallRefreshPipeline() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassOpenGlobalSettingsSheet)) { _ in
            showGlobalSettingsSheet = true
        }
        /// Paywall depuis la pastille d’essai / Réglages / notif : **feuille** (sheet). Le flux post-création de compte reste une **page pleine** (`merchantMustCompleteSubscriptionPaywall` → `isMandatory: true` ci-dessus).
        .sheet(isPresented: $showMerchantSubscriptionSheet) {
            MerchantSubscriptionGateView(isMandatory: false)
                .environmentObject(authService)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showGlobalSettingsSheet) {
            NavigationStack {
                SettingsView()
                    .environmentObject(authService)
                    .environmentObject(syncService)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .onChange(of: showMerchantSubscriptionSheet) { _, isShowing in
            if !isShowing {
                Task { await runPostPaywallRefreshPipeline() }
            }
        }
        .onChange(of: merchantMustCompleteSubscriptionPaywall) { wasBlocking, isBlocking in
            guard wasBlocking && !isBlocking else { return }
            processPendingPostSignupHomeTutorial()
        }
        .task {
            await authService.reconcileStripeSubscriptionFromServer(force: true)
        }
    }

    /// Commerçant : accès aux onglets **uniquement** avec essai actif ou abonnement Stripe reflété par l’API.
    private var merchantMustCompleteSubscriptionPaywall: Bool {
        authService.merchantSubscriptionEligibilityResolved
            && !authService.isPlatformAdmin
            && !authService.subscriptionAccessUnlocked()
    }

    /// Après inscription : marqueur « lancer le tutoriel une fois l’écran débloqué » (paywall ou accès direct).
    /// N’envoie `myfidpassResetTutorial` que si le tutoriel était déjà enregistré comme terminé : sinon le
    /// premier `OneTimeOnBoarding` tourne déjà, et une notif forçait un second montage = flashs et saccades.
    @MainActor
    private func processPendingPostSignupHomeTutorial() {
        guard authService.pendingHomeTutorialAfterSignup else { return }
        _ = authService.consumePendingHomeTutorialAfterSignup()
        guard !HomeTutorialTemporaryDisable.isOn else { return }
        if homeTutorialCompleted {
            NotificationCenter.default.post(name: .myfidpassResetTutorial, object: nil)
        }
    }

    /// Onglets + pastille d’essai + sync (masqué quand le paywall d’inscription / essai bloque l’app).
    @ViewBuilder
    private var mainMerchantTabStack: some View {
        MainTabView()
            .onAppear { processPendingPostSignupHomeTutorial() }
            .safeAreaInset(edge: .top, spacing: 0) {
                if authService.isPlatformAdmin && authService.adminShowsMerchantWorkspace {
                    adminMerchantPilotBanner
                }
            }
            .environment(\.isSoftwareKeyboardVisible, isSoftwareKeyboardVisible)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                suppressTrialPillUntil = Date().addingTimeInterval(0.7)
                applyKeyboardState(from: note)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                suppressTrialPillUntil = Date().addingTimeInterval(0.35)
                softwareKeyboardHeight = 0
                isSoftwareKeyboardVisible = false
            }
            .overlay(alignment: .top) {
                if (homeTutorialCompleted || HomeTutorialTemporaryDisable.isOn) && !floatingOverlaysSuppressed {
                    topSyncAndErrorOverlay
                }
            }
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
                            // N'afficher la bannière que pour une sync réellement longue.
                            try? await Task.sleep(for: .seconds(3.2))
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
                    // Plus de pastille "Synchronisé" sur les sync courtes/moyennes : c'est visuellement trop bruyant.
                    let shouldShowSuccess = syncBannerVisibleForCurrentRun && runDuration >= 7.0
                    syncBannerVisibleForCurrentRun = false
                    guard syncService.lastError == nil else { return }
                    guard Date() >= syncBannerDismissedUntil, shouldShowSuccess else {
                        showSyncSuccessChip = false
                        return
                    }
                    showSyncSuccessChip = true
                    syncSuccessHideTask?.cancel()
                    syncSuccessHideTask = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.1))
                        guard !Task.isCancelled else { return }
                        showSyncSuccessChip = false
                    }
                }
            }
            .onChange(of: authService.currentScreen) { _, screen in
                guard screen != .authenticated else { return }
                showSyncSuccessChip = false
                syncSuccessHideTask?.cancel()
                syncSuccessHideTask = nil
            }
            .environmentObject(tabRouter)
            .environment(\.managedObjectContext, viewContext)
            .onAppear {
                Task { await NotificationsService.shared.refreshMerchantCardSetupReminder() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .myfidpassCardPreviewDisplayDidChange)) { _ in
                Task { await NotificationsService.shared.refreshMerchantCardSetupReminder() }
            }
            .onOpenURL { url in
                if relayOAuthUniversalLinkIfNeeded(url: url) { return }
                handleScanDeepLink(url: url)
            }
            .overlay(alignment: .bottom) {
                // Pendant le tutoriel d’accueil, la pastille est **au-dessus** de MainTabView : elle
                // recevait les touchers (ou la fenêtre 2) → ouverture paywall. Masquée tant que le
                // tutoriel n’est pas terminé.
                if homeTutorialCompleted || HomeTutorialTemporaryDisable.isOn,
                   shouldShowTrialSubscribePillInCurrentTab,
                   !showMerchantSubscriptionSheet,
                   !showGlobalSettingsSheet,
                   let trialEnd = authService.merchantTrialEndsAt {
                    MerchantTrialSubscribePillView(trialEndsAt: trialEnd) {
                        showMerchantSubscriptionSheet = true
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, trialSubscribePillBottomPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
    }

    /// Attend la fin de l'animation de fermeture du paywall avant de déclencher la charge réseau,
    /// sinon l'animation peut sembler "cassée" ou saccadée.
    @MainActor
    private func runPostPaywallRefreshPipeline() async {
        syncService.invalidateSyncThrottle()
        try? await Task.sleep(nanoseconds: 450_000_000)
        await authService.reconcileStripeSubscriptionFromServer(force: true)
        await syncService.syncAfterServerMutation()
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
        guard !floatingOverlaysSuppressed else { return false }
        if tabRouter.selectedTab == 0 {
            // Ne jamais afficher tant que l'accueil n'a pas publié explicitement son mode setup.
            guard tabRouter.hasResolvedDashboardSetupMode else { return false }
            // Mode configuration accueil : ne jamais afficher la pastille paiement.
            if tabRouter.isDashboardSetupMode { return false }
            // Filet de sécurité pour éviter un flash pendant le tout premier montage.
            if !tabRouter.isDashboardAtRoot { return false }
        }
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
        !floatingOverlaysSuppressed
            && Date() >= syncBannerDismissedUntil
            && (syncBannerVisibleForCurrentRun || showSyncSuccessChip)
    }

    /// Même logique de suppression temporaire pour toutes les surcouches flottantes.
    private var floatingOverlaysSuppressed: Bool {
        isSoftwareKeyboardVisible || softwareKeyboardHeight > 0 || Date() < suppressTrialPillUntil
    }

    /// Bandeau sync : **même gabarit** chargement / succès, transitions spring + crossfade (plus de rétrécissement brutal).
    private var syncIndicatorOverlay: some View {
        let isBannerInProgress = syncService.isSyncing
        return Group {
            if syncBannerShown {
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        if isBannerInProgress {
                            ProgressView()
                                .scaleEffect(0.95)
                                .tint(.primary)
                                .transition(.opacity.combined(with: .scale(scale: 0.88, anchor: .center)))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(Color.green)
                                .symbolEffect(.bounce, options: .nonRepeating, value: showSyncSuccessChip && !syncService.isSyncing)
                                .transition(.opacity.combined(with: .scale(scale: 0.88, anchor: .center)))
                        }
                    }
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isBannerInProgress
                             ? "Synchronisation en cours"
                             : "Synchronisé")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isBannerInProgress ? Color.primary : Color.green)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .contentTransition(.interpolate)
                        if isBannerInProgress {
                            Text("Glissez vers le haut pour masquer")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(minWidth: 250, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .frame(minHeight: 50)
                .frame(maxWidth: 360)
                .glassEffect(.regular, cornerRadius: 999)
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
                                // Si l'utilisateur la masque, ne pas la remontrer immédiatement.
                                syncBannerDismissedUntil = Date().addingTimeInterval(120)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            NotificationCenter.default.post(name: .myfidpassOpenHomeScanner, object: nil)
        }
    }

    /// Détermine si le clavier logiciel est réellement visible à partir de la frame finale iOS.
    private func keyboardOverlapHeight(from note: Notification) -> CGFloat {
        guard let value = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return 0
        }
        let keyboardFrame = value.cgRectValue
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first else {
            let screen = UIScreen.main.bounds
            return max(0, screen.maxY - keyboardFrame.minY)
        }
        let overlap = window.bounds.intersection(keyboardFrame).height
        return max(0, overlap)
    }

    private func applyKeyboardState(from note: Notification) {
        let overlap = keyboardOverlapHeight(from: note)
        let visible = overlap > 0
        guard softwareKeyboardHeight != overlap || isSoftwareKeyboardVisible != visible else { return }
        softwareKeyboardHeight = overlap
        isSoftwareKeyboardVisible = visible
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(SyncService(container: PersistenceController.preview.container))
        .environmentObject(AuthService())
}
