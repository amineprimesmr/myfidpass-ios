//
//  ContentView.swift
//  myfidpass
//
//  Point d’entrée principal : app commerçant (accueil, carte, profil, espace pro).
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var authService: AuthService
    @StateObject private var tabRouter = MainTabRouter()
    @State private var updateAppInfo: VersionCheckManager.ReturnResult?
    @State private var forcedAppUpdate = false
    @State private var showMerchantSubscriptionSheet = false
    /// Évite les sync forcées en rafale lors des transitions de scène (iOS peut envoyer plusieurs `.active`).
    @State private var lastForegroundFullSyncAt: Date = .distantPast

    var body: some View {
        MainTabView()
            .safeAreaInset(edge: .top, spacing: 0) {
                if authService.merchantSubscriptionEligibilityResolved && !authService.hasActiveMerchantSubscription {
                    MerchantFreemiumBannerView {
                        showMerchantSubscriptionSheet = true
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                }
            }
            .overlay(alignment: .top) { syncIndicatorOverlay }
            .environmentObject(tabRouter)
            .environment(\.managedObjectContext, viewContext)
            .onAppear {
                NotificationsService.shared.requestPermissionAndRegister()
                Task(priority: .utility) {
                    try? await Task.sleep(nanoseconds: 280_000_000)
                    await syncService.syncIfNeeded()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                // SaaS → app : au retour au premier plan, tirer l’état serveur (debounce léger).
                guard authService.currentScreen == .authenticated else { return }
                let now = Date()
                guard now.timeIntervalSince(lastForegroundFullSyncAt) > 6 else { return }
                lastForegroundFullSyncAt = now
                Task(priority: .utility) {
                    await syncService.syncAfterServerMutation()
                }
            }
            .onOpenURL { url in
                handleScanDeepLink(url: url)
            }
            .sheet(isPresented: $showMerchantSubscriptionSheet) {
                MerchantSubscriptionGateView()
                    .environmentObject(authService)
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $updateAppInfo) { info in
                AppUpdateView(appInfo: info, forcedUpdate: $forcedAppUpdate)
            }
            .task {
                await authService.refreshBusinessesIfNeeded()
                if let result = await VersionCheckManager.shared.checkIfAppUpdateAvailable() {
                    updateAppInfo = result
                    // Option : forcer la mise à jour si les release notes contiennent "!" (ex. "! Important")
                    // forcedAppUpdate = result.releaseNotes.contains("!")
                }
            }
    }

    /// Bandeau discret quand une sync complète tourne (membres, transactions, réglages).
    private var syncIndicatorOverlay: some View {
        Group {
            if syncService.isSyncing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.88)
                    Text("Synchronisation…")
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(
                    .top,
                    authService.merchantSubscriptionEligibilityResolved && !authService.hasActiveMerchantSubscription ? 68 : 10
                )
                .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: syncService.isSyncing)
    }

    /// Lien `myfidpass://scan` (widget, Safari, etc.) : diffère la notification pour que l’onglet Accueil et
    /// `DashboardView` soient montés (sinon l’app s’ouvre sans lancer le scanner).
    private func handleScanDeepLink(url: URL) {
        guard url.scheme?.lowercased() == "myfidpass" else { return }
        let host = url.host?.lowercased() ?? ""
        guard host == "scan" else { return }
        guard authService.currentScreen == .authenticated else { return }
        tabRouter.selectedTab = 0
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
