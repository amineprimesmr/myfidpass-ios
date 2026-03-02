//
//  MainTabView.swift
//  myfidpass
//
//  Navigation principale : Dashboard, Scanner, Ma Carte, Profil.
//

import SwiftUI
import CoreData

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(context: viewContext)
                .tabItem {
                    Label("Tableau de bord", systemImage: "chart.bar.fill")
                }
                .tag(0)

            ScannerView(context: viewContext)
                .tabItem {
                    Label("Scanner", systemImage: "qrcode.viewfinder")
                }
                .tag(1)

            MyCardView(context: viewContext)
                .tabItem {
                    Label("Ma Carte", systemImage: "creditcard.fill")
                }
                .tag(2)

            ProfileView(context: viewContext)
                .tabItem {
                    Label("Profil", systemImage: "person.crop.circle.fill")
                }
                .tag(3)
        }
        .tabViewStyle(.automatic)
        .tint(AppTheme.Colors.primary)
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
