//
//  MainTabView.swift
//  myfidpass
//
//  Navigation principale : Accueil, Campagnes, Commerce. (Flyer : Compte ou hub depuis Accueil)
//

import SwiftUI
import CoreData
import UIKit

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.isSoftwareKeyboardVisible) private var isSoftwareKeyboardVisible
    @Environment(\.merchantSubscribePillSuppressed) private var merchantSubscribePillSuppressed
    @EnvironmentObject private var tabRouter: MainTabRouter
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var dataService: DataService
    @EnvironmentObject private var memberSearchCoordinator: MerchantMemberSearchCoordinator

    @State private var showAddCommerceSheet = false
    @State private var tabBarBottomClearance: CGFloat = TabBarBottomClearance.stableFallback
    @State private var subscribePillClearanceRefreshTask: Task<Void, Never>?

    var body: some View {
        tabContent
            .onAppear {
                refreshSubscribePillClearance()
            }
            .onChange(of: tabRouter.selectedTab) { _, _ in
                refreshSubscribePillClearance()
            }
            .overlay(alignment: .bottom) {
                merchantSubscribePillOverlay
                    .allowsHitTesting(shouldShowSubscribePill)
                    .animation(nil, value: tabRouter.selectedTab)
                    .animation(nil, value: tabBarBottomClearance)
            }
            .overlay {
                if authService.isBusinessSwitching {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.22), value: authService.isBusinessSwitching)
            .onReceive(NotificationCenter.default.publisher(for: .myfidpassOpenAddCommerceSheet)) { _ in
                showAddCommerceSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .myfidpassOpenMemberSearch)) { _ in
                memberSearchCoordinator.activate()
            }
            .onChange(of: tabRouter.selectedTab) { _, _ in
                if memberSearchCoordinator.isActive {
                    memberSearchCoordinator.dismiss()
                }
            }
            .sheet(isPresented: $showAddCommerceSheet) {
                AddCommerceSheet()
                    .environmentObject(authService)
                    .environmentObject(syncService)
            }
    }

    private var tabContent: some View {
        Group {
            if authService.usesFullMerchantTabLayout {
                fullMerchantTabView
            } else {
                staffTabView
            }
        }
        .tabViewStyle(.automatic)
        .tint(AppTheme.Colors.primary)
        .onChange(of: tabRouter.selectedTab) { oldValue, newValue in
            guard oldValue != newValue else { return }
            MerchantUXFeedback.shared.play(.tabSwitch)
            if authService.usesFullMerchantTabLayout, newValue == 2 {
                NotificationCenter.default.post(name: .myfidpassCommerceStatsTabDidBecomeSelected, object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassSelectMerchantHomeTab)) { _ in
            guard authService.usesFullMerchantTabLayout else { return }
            withAnimation(MerchantMotion.tabSwitch) {
                tabRouter.selectedTab = 0
            }
        }
        .onAppear {
            MerchantUXFeedback.shared.prepare()
            if !authService.usesFullMerchantTabLayout, tabRouter.selectedTab > 1 {
                tabRouter.selectedTab = 0
            }
        }
        .onChange(of: authService.merchantWorkspaceRole) { _, _ in
            if !authService.usesFullMerchantTabLayout, tabRouter.selectedTab > 1 {
                tabRouter.selectedTab = 0
            }
        }
    }

    /// Pastille flottante — position stable au-dessus de la tab bar (mesure ponctuelle, sans flicker).
    @ViewBuilder
    private var merchantSubscribePillOverlay: some View {
        if shouldShowSubscribePill {
            MerchantSubscribePillView {
                NotificationCenter.default.postOpenMerchantSubscriptionFromSession(
                    usedBusinesses: authService.usedBusinesses,
                    allowedBusinesses: authService.allowedBusinesses,
                    hasActiveSubscription: authService.hasEncashedMerchantSubscription
                )
            }
            .padding(.horizontal, 14)
            .padding(.bottom, tabBarBottomClearance)
        }
    }

    private func refreshSubscribePillClearance() {
        subscribePillClearanceRefreshTask?.cancel()
        subscribePillClearanceRefreshTask = Task { @MainActor in
            // Mesures rapides (sans pause 380 ms) : la UITabBar surestime souvent la marge au 1er layout.
            let delays: [UInt64] = [0, 80_000_000, 200_000_000]
            for delay in delays {
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: delay)
                }
                guard !Task.isCancelled else { return }
                applySubscribePillClearanceIfNeeded(TabBarBottomClearance.remeasureFromKeyWindow())
            }
        }
    }

    /// N’applique que si la pastille peut descendre ou bouger légèrement — jamais un gros saut vers le haut.
    private func applySubscribePillClearanceIfNeeded(_ measured: CGFloat) {
        guard abs(tabBarBottomClearance - measured) > 0.5 else { return }
        let mayMoveDown = measured < tabBarBottomClearance - 0.5
        let smallNudge = abs(measured - tabBarBottomClearance) <= 4
        guard mayMoveDown || smallNudge else { return }
        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            tabBarBottomClearance = measured
        }
    }

    /// Pastille promo tant que l’abo payant n’est pas actif — uniquement sur les racines Accueil / Notifs / Stats.
    private var shouldShowSubscribePill: Bool {
        guard !authService.isPlatformAdmin else { return false }
        guard !authService.isMerchantStaffUser else { return false }
        guard !authService.hasEncashedMerchantSubscription else { return false }
        guard !isSoftwareKeyboardVisible else { return false }
        guard !merchantSubscribePillSuppressed else { return false }
        guard !tabRouter.isDashboardSetupMode else { return false }
        switch tabRouter.selectedTab {
        case 0:
            return tabRouter.isDashboardAtRoot && !tabRouter.isHomeSidebarExpanded
        case 1:
            return true
        case 2:
            return tabRouter.isCommerceStatsAtRoot
        default:
            return false
        }
    }

    /// Onglets complets (responsable / propriétaire).
    private var fullMerchantTabView: some View {
        let selected = tabRouter.selectedTab
        return TabView(selection: $tabRouter.selectedTab) {
            MerchantLazyTabContent(tag: 0, selection: selected) {
                DashboardView()
                    .environment(\.merchantTabIsActive, selected == 0)
            }
            .tabItem {
                Image(systemName: "house.fill")
            }
            .tag(0)

            MerchantLazyTabContent(tag: 1, selection: selected) {
                NavigationStack {
                    CampaignNotificationsView()
                }
                .environment(\.merchantTabIsActive, selected == 1)
            }
            .tabItem {
                Image(systemName: "bell.badge.fill")
            }
            .tag(1)

            MerchantLazyTabContent(tag: 2, selection: selected) {
                ProfileView()
                    .environment(\.merchantTabIsActive, selected == 2)
            }
            .tabItem {
                Image(systemName: "chart.xyaxis.line")
            }
            .tag(2)
        }
    }

    /// Employé : accueil (scan + activité) + compte (déconnexion, synchro).
    private var staffTabView: some View {
        let selected = tabRouter.selectedTab
        return TabView(selection: $tabRouter.selectedTab) {
            MerchantLazyTabContent(tag: 0, selection: selected) {
                DashboardView()
                    .environment(\.merchantWorkspaceMode, .staff)
                    .environment(\.merchantTabIsActive, selected == 0)
            }
            .tabItem {
                Image(systemName: "house.fill")
            }
            .tag(0)

            MerchantLazyTabContent(tag: 1, selection: selected) {
                NavigationStack {
                    StaffAccountView()
                        .environmentObject(authService)
                        .environmentObject(syncService)
                }
                .environment(\.merchantTabIsActive, selected == 1)
            }
            .tabItem {
                Image(systemName: "person.crop.circle")
            }
            .tag(1)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(MainTabRouter())
        .environmentObject(AuthService())
        .environmentObject(SyncService(container: PersistenceController.preview.container))
        .environmentObject(MerchantMemberSearchCoordinator())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

