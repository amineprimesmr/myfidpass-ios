//
//  MainTabView.swift
//  myfidpass
//
//  Navigation principale : Accueil, Campagnes, Commerce. (Flyer depuis Commerce → navigation)
//

import SwiftUI
import CoreData

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var tabRouter: MainTabRouter

    var body: some View {
        TabView(selection: $tabRouter.selectedTab) {
            DashboardView(context: viewContext)
                .tabItem {
                    Label("Accueil", systemImage: "house.fill")
                }
                .tag(0)

            NavigationStack {
                CampaignNotificationsView(context: viewContext)
            }
            .tabItem {
                Label("Notifs", systemImage: "bell.badge.fill")
            }
            .tag(1)

            ProfileView(context: viewContext)
                .tabItem {
                    Label("Commerce", systemImage: "person.crop.circle.fill")
                }
                .tag(2)
        }
        .tabViewStyle(.automatic)
        .tint(AppTheme.Colors.primary)
        .animation(MerchantMotion.tabSwitch, value: tabRouter.selectedTab)
        .sensoryFeedback(.selection, trigger: tabRouter.selectedTab)
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassOpenCampaignsTab)) { _ in
            withAnimation(MerchantMotion.tabSwitch) {
                tabRouter.selectedTab = 1
            }
        }
        /// Pastille essai / abo : voir `ContentView` (`safeAreaInset` sur `TabView` ne réserve pas assez au-dessus de la tab bar).
    }
}

#Preview {
    MainTabView()
        .environmentObject(MainTabRouter())
        .environmentObject(SyncService(container: PersistenceController.preview.container))
        .environmentObject(RevenueCatSubscriptionState())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
