//
//  AppUpdateView.swift
//  myfidpass
//
//  Feuille « Mise à jour disponible » : uniquement si la version App Store est **strictement** supérieure à l’installée
//  (comparaison robuste + « Plus tard » mémorisé par version store).
//

import SwiftUI

struct AppUpdateView: View {
    var appInfo: VersionCheckManager.ReturnResult
    private var forcedUpdate: Bool { appInfo.isMandatoryUpdate }
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    /// « Mettre à jour » ouvre l’App Store : ne pas mémoriser « Plus tard » dans ce cas.
    @State private var skipPersistDismissed = false

    var body: some View {
        VStack(spacing: 15) {
            updateIllustration

            VStack(spacing: 8) {
                Text("Mise à jour disponible")
                    .font(.title.bold())

                Text("Une nouvelle version de l’app est disponible : **\(appInfo.currentVersion)** → **\(appInfo.availableVersion)**.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(.horizontal, 20)
            .padding(.top, 15)
            .padding(.bottom, 5)

            VStack(spacing: 8) {
                if let appURL = URL(string: appInfo.appURL) {
                    Button {
                        skipPersistDismissed = true
                        openURL(appURL)
                        if !forcedUpdate {
                            dismiss()
                        }
                    } label: {
                        Text("Mettre à jour")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(AppTheme.Colors.primary)
                }

                if !forcedUpdate {
                    Button {
                        dismiss()
                    } label: {
                        Text("Plus tard")
                            .fontWeight(.medium)
                            .padding(.vertical, 5)
                            .contentShape(.rect)
                    }
                }
            }
        }
        .padding([.horizontal, .top], 20)
        .onDisappear {
            guard !forcedUpdate else { return }
            guard !skipPersistDismissed else { return }
            VersionCheckManager.shared.markUpdatePromptDismissed(forStoreVersion: appInfo.availableVersion)
        }
        .appUpdateSheetPresentationChrome()
        .presentationDetents([.height(450)])
        .interactiveDismissDisabled(forcedUpdate)
        .presentationBackground(.background)
    }

    private var updateIllustration: some View {
        ZStack {
            Image(systemName: "arrow.down.app.fill")
                .font(.system(size: 100))
                .foregroundStyle(AppTheme.Colors.primary.opacity(0.3))

            if let appLogo = URL(string: appInfo.appLogo) {
                AsyncImage(url: appLogo) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .offset(y: -10)
            }
        }
        .frame(height: 140)
    }

}

// MARK: - Feuille : coins système iOS 26 vs rayon fixe < 26 (évite `presentationCornerRadius(nil)` hors garde API)

private extension View {
    @ViewBuilder
    func appUpdateSheetPresentationChrome() -> some View {
        if #available(iOS 26, *) {
            self
                .padding(.bottom, 30)
                .presentationCornerRadius(nil)
                .ignoresSafeArea(.all, edges: .all)
        } else {
            self
                .padding(.bottom, 10)
                .presentationCornerRadius(30)
                .ignoresSafeArea(.all, edges: [])
        }
    }
}
