//
//  AppVersionUpdateCheckModifier.swift
//  myfidpass
//
//  Lookup App Store au lancement (toujours) et au retour au premier plan (throttle 30 min).
//

import SwiftUI

private struct AppVersionUpdateCheckModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var updateAppInfo: VersionCheckManager.ReturnResult?
    @State private var didRunColdLaunchCheck = false

    func body(content: Content) -> some View {
        content
            .sheet(item: $updateAppInfo) { info in
                AppUpdateView(appInfo: info)
            }
            .task {
                guard !didRunColdLaunchCheck else { return }
                didRunColdLaunchCheck = true
                await performVersionCheck(ignoreThrottle: true, deferPresentation: true)
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                guard newPhase == .active, oldPhase != .active, didRunColdLaunchCheck else { return }
                Task {
                    await performVersionCheck(ignoreThrottle: false, deferPresentation: false)
                }
            }
    }

    @MainActor
    private func performVersionCheck(ignoreThrottle: Bool, deferPresentation: Bool) async {
        guard ignoreThrottle || AppVersionUpdatePolicy.shouldRunStoreLookup() else { return }
        if deferPresentation {
            // Laisse les autres feuilles de boot (paywall, etc.) se stabiliser.
            try? await Task.sleep(nanoseconds: 900_000_000)
        }
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
