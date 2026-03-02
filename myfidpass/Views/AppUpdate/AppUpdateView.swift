//
//  AppUpdateView.swift
//  myfidpass
//
//  Écran de mise à jour disponible (réutilisé depuis VersionAppCheck). S’affiche à chaque ouverture si une nouvelle version est sur l’App Store.
//

import SwiftUI

struct AppUpdateView: View {
    var appInfo: VersionCheckManager.ReturnResult
    @Binding var forcedUpdate: Bool
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL

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
        .fontDesign(.rounded)
        .padding([.horizontal, .top], 20)
        .padding(.bottom, isiOS26 ? 30 : 10)
        .presentationDetents([.height(450)])
        .presentationCornerRadius(isiOS26 ? nil : 30)
        .interactiveDismissDisabled(forcedUpdate)
        .presentationBackground(.background)
        .ignoresSafeArea(.all, edges: isiOS26 ? .all : [])
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

    private var isiOS26: Bool {
        if #available(iOS 26, *) {
            return true
        }
        return false
    }
}
