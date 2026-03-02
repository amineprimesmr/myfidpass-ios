//
//  ContentView.swift
//  myfidpass
//
//  Point d’entrée principal : app commerçant (Dashboard, Scanner, Ma Carte, Profil).
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var syncService: SyncService
    @State private var updateAppInfo: VersionCheckManager.ReturnResult?
    @State private var forcedAppUpdate = false

    var body: some View {
        MainTabView()
            .environment(\.managedObjectContext, viewContext)
            .onAppear {
                NotificationsService.shared.requestPermissionAndRegister()
                Task(priority: .utility) {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    await syncService.syncIfNeeded()
                }
            }
            .sheet(item: $updateAppInfo) { info in
                AppUpdateView(appInfo: info, forcedUpdate: $forcedAppUpdate)
            }
            .task {
                if let result = await VersionCheckManager.shared.checkIfAppUpdateAvailable() {
                    updateAppInfo = result
                    // Option : forcer la mise à jour si les release notes contiennent "!" (ex. "! Important")
                    // forcedAppUpdate = result.releaseNotes.contains("!")
                }
            }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(SyncService(context: PersistenceController.preview.container.viewContext))
}
