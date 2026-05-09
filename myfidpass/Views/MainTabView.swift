//
//  MainTabView.swift
//  myfidpass
//
//  Navigation principale : Accueil, Campagnes, Commerce. (Flyer : Compte ou hub depuis Accueil)
//

import SwiftUI
import CoreData

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var tabRouter: MainTabRouter
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService

    /// UUID modifié pour relancer le tutoriel (debug).
    @State private var tutorialTrigger = UUID()
    @State private var showAddCommerceSheet = false

    var body: some View {
        Group {
            if HomeTutorialTemporaryDisable.isOn {
                /// Même sans overlay tutoriel, fournir le coordinator (voir `OnBoardingEnvironmentPlaceholder`).
                OnBoardingEnvironmentPlaceholder { tabContent }
            } else {
                OneTimeOnBoarding(
                    appStorageID: "myfidpass.homeTutorial.v1",
                    content: {
                        tabContent
                    },
                    beginOnboarding: {
                        // Après **1 s** sur l’accueil (`OneTimeOnBoarding`), enregistre chaque onglet pour
                        // `.onBoarding` (TabView paresseux) — **sans** animation (géré par `isTutorialTabPriming`
                        // + calque) pour ne pas donner l’impression que l’app « se pilote toute seule » avant l’overlay.
                        if !authService.isMerchantStaffUser {
                            for tab in [1, 2, 0] {
                                await MainActor.run {
                                    var tx = Transaction()
                                    tx.disablesAnimations = true
                                    withTransaction(tx) { tabRouter.selectedTab = tab }
                                }
                                try? await Task.sleep(nanoseconds: 120_000_000)
                            }
                        } else {
                            await MainActor.run {
                                var tx = Transaction()
                                tx.disablesAnimations = true
                                withTransaction(tx) { tabRouter.selectedTab = 0 }
                            }
                        }
                        /// Laisse onGeometryChange / layout se stabiliser avant la 1ʳᵉ capture.
                        try? await Task.sleep(nanoseconds: 200_000_000)
                    },
                    onBoardingFinished: {},
                    onBeforeStep: { step in
                        // step = index 0-based dans orderedItems
                        // 0 → carte (tab 0), 1 → scanner (tab 0), 2 → notifs (tab 1), 3 → commerce (tab 2)
                        let useInstant = await MainActor.run { tabRouter.isTutorialTabPriming }
                        if step <= 1 {
                            await MainActor.run {
                                if useInstant {
                                    var tx = Transaction()
                                    tx.disablesAnimations = true
                                    withTransaction(tx) { tabRouter.selectedTab = 0 }
                                } else {
                                    withAnimation(MerchantMotion.tabSwitch) { tabRouter.selectedTab = 0 }
                                }
                            }
                            try? await Task.sleep(nanoseconds: useInstant ? 220_000_000 : 400_000_000)
                        } else if step == 2 {
                            await MainActor.run {
                                if useInstant {
                                    var tx = Transaction()
                                    tx.disablesAnimations = true
                                    withTransaction(tx) { tabRouter.selectedTab = 1 }
                                } else {
                                    withAnimation(MerchantMotion.tabSwitch) { tabRouter.selectedTab = 1 }
                                }
                            }
                            try? await Task.sleep(nanoseconds: useInstant ? 200_000_000 : 650_000_000)
                        } else {
                            await MainActor.run {
                                if useInstant {
                                    var tx = Transaction()
                                    tx.disablesAnimations = true
                                    withTransaction(tx) { tabRouter.selectedTab = 2 }
                                } else {
                                    withAnimation(MerchantMotion.tabSwitch) { tabRouter.selectedTab = 2 }
                                }
                            }
                            try? await Task.sleep(nanoseconds: useInstant ? 200_000_000 : 650_000_000)
                        }
                    }
                )
            }
        }
        .overlay {
            if authService.isBusinessSwitching {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.22), value: authService.isBusinessSwitching)
        .id(tutorialTrigger)
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassResetTutorial)) { _ in
            guard !HomeTutorialTemporaryDisable.isOn else { return }
            UserDefaults.standard.set(false, forKey: "myfidpass.homeTutorial.v1")
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) { tabRouter.selectedTab = 0 }
            tutorialTrigger = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassOpenAddCommerceSheet)) { _ in
            showAddCommerceSheet = true
        }
        .sheet(isPresented: $showAddCommerceSheet) {
            AddCommerceSheet()
                .environmentObject(authService)
                .environmentObject(syncService)
        }
    }

    private var tabContent: some View {
        Group {
            if authService.isMerchantStaffUser {
                staffTabView
            } else {
                fullMerchantTabView
            }
        }
        .allowsHitTesting(!authService.isBusinessSwitching)
        .tabViewStyle(.automatic)
        .tint(AppTheme.Colors.primary)
        .applyMerchantTabBarTransitionIfNotTutorialPriming(tabRouter: tabRouter)
        .onChange(of: tabRouter.selectedTab) { oldValue, newValue in
            guard oldValue != newValue else { return }
            guard !tabRouter.isTutorialTabPriming else { return }
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.prepare()
            impact.impactOccurred(intensity: 1.0)
            if !authService.isMerchantStaffUser, newValue == 2 {
                NotificationCenter.default.post(name: .myfidpassCommerceStatsTabDidBecomeSelected, object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassOpenCampaignsTab)) { _ in
            guard !authService.isMerchantStaffUser else { return }
            tabRouter.selectedTab = 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassSelectMerchantHomeTab)) { _ in
            guard !authService.isMerchantStaffUser else { return }
            tabRouter.selectedTab = 0
        }
        .onAppear {
            if authService.isMerchantStaffUser, tabRouter.selectedTab > 1 {
                tabRouter.selectedTab = 0
            }
        }
        .onChange(of: authService.merchantWorkspaceRole) { _, _ in
            if authService.isMerchantStaffUser, tabRouter.selectedTab > 1 {
                tabRouter.selectedTab = 0
            }
        }
    }

    /// Onglets complets (responsable / propriétaire).
    private var fullMerchantTabView: some View {
        TabView(selection: $tabRouter.selectedTab) {
            DashboardView(context: viewContext)
                .tabItem {
                    Image(systemName: "house.fill")
                }
                .tag(0)

            NavigationStack {
                CampaignNotificationsView(context: viewContext)
            }
            .tabItem {
                Image(systemName: "bell.badge.fill")
            }
            .tag(1)

            ProfileView(context: viewContext)
                .tabItem {
                    Image(systemName: "chart.xyaxis.line")
                }
                .tag(2)
        }
    }

    /// Employé : accueil (scan + activité) + compte (déconnexion, synchro) — pas de notifs marketing ni fiche Commerce.
    private var staffTabView: some View {
        TabView(selection: $tabRouter.selectedTab) {
            DashboardView(context: viewContext)
                .environment(\.merchantWorkspaceMode, .staff)
                .tabItem {
                    Image(systemName: "house.fill")
                }
                .tag(0)

            StaffAccountView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                }
                .tag(1)
        }
    }
}


// MARK: - Transitions d’onglet (hors préparation tutoriel)

private extension View {
    /// Pas de ressort sur la barre d’onglets pendant le chargement caché du tutoriel.
    @ViewBuilder
    func applyMerchantTabBarTransitionIfNotTutorialPriming(tabRouter: MainTabRouter) -> some View {
        self
    }
}

#Preview {
    MainTabView()
        .environmentObject(MainTabRouter())
        .environmentObject(AuthService())
        .environmentObject(SyncService(container: PersistenceController.preview.container))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
