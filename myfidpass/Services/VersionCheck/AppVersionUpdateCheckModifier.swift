//
//  AppVersionUpdateCheckModifier.swift
//  myfidpass
//
//  Lookup App Store au lancement et au retour au premier plan (VersionAppCheck).
//

import SwiftUI

private struct AppVersionUpdateCheckModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var updateAppInfo: VersionCheckManager.ReturnResult?
    @State private var lookupToken = 0

    func body(content: Content) -> some View {
        content
            .sheet(item: $updateAppInfo) { info in
                AppUpdateView(appInfo: info)
            }
            .task(id: lookupToken) {
                await runStoreVersionLookupIfNeeded()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                guard newPhase == .active, oldPhase != .active else { return }
                lookupToken += 1
            }
    }

    @MainActor
    private func runStoreVersionLookupIfNeeded() async {
        guard AppVersionUpdatePolicy.shouldRunStoreLookup() else { return }
        AppVersionUpdatePolicy.recordStoreLookupAttempt()
        if let result = await VersionCheckManager.shared.checkIfAppUpdateAvailable() {
            updateAppInfo = result
        }
    }
}

extension View {
    /// Vérifie une version App Store plus récente et affiche `AppUpdateView` si besoin.
    func appVersionUpdateCheck() -> some View {
        modifier(AppVersionUpdateCheckModifier())
    }
}
