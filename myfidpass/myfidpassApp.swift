//
//  myfidpassApp.swift
//  myfidpass
//
//  Created by Amine Ennasri on 27/02/2026.
//

import SwiftUI
import CoreData

@main
struct myfidpassApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let persistenceController = PersistenceController.shared
    @StateObject private var authService: AuthService
    @StateObject private var syncService: SyncService
    @StateObject private var dataService: DataService
    @StateObject private var appState = AppState.shared

    init() {
        MerchantUXFeedback.shared.prepare()
        let auth = AuthService()
        let container = PersistenceController.shared.container
        _authService = StateObject(wrappedValue: auth)
        _syncService = StateObject(
            wrappedValue: SyncService(container: container, authService: auth)
        )
        _dataService = StateObject(
            wrappedValue: DataService(context: container.viewContext)
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .overlay(alignment: .top) { errorBanner }
            .environmentObject(authService)
            .environmentObject(syncService)
            .environmentObject(dataService)
            .environmentObject(appState)
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .preferredColorScheme(.light)
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let message = appState.errorMessage {
            Text(message)
                .font(.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { appState.clearError() }
        }
    }
}
