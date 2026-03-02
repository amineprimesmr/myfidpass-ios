//
//  ContentView.swift
//  VersionAppCheck
//
//  Created by Balaji Venkatesh on 09/10/25.
//

import SwiftUI

struct ContentView: View {
    @State private var updateAppInfo: VersionCheckManager.ReturnResult?
    @State private var forcedAppUpdate: Bool = false
    var body: some View {
        NavigationStack {
            List {
                Section("Usage") {
                    Text(
                        """
                        VersionCheckManager
                            .shared
                            .checkIfAppUpdateAvailable()
                        """
                    )
                    .font(.callout)
                    .monospaced()
                }
            }
            .navigationTitle("App Update")
        }
        .sheet(item: $updateAppInfo) { info in
            AppUpdateView(appInfo: info, forcedUpdate: $forcedAppUpdate)
        }
        .task {
            if let result = await VersionCheckManager.shared.checkIfAppUpdateAvailable() {
                updateAppInfo = result
                
                /// Use release notes to determine whether to show or not the update view with forced update or not!
                
//                let notes = result.releaseNotes
                
//                if notes.contains("!") {
//                    /// Means Important Update
//                    forcedAppUpdate = true
//                    updateAppInfo = result
//                } else if notes.contains("|") {
//                    /// Means Optional Update
//                    forcedAppUpdate = false
//                    updateAppInfo = result
//                } else {
//                    /// Don't need to show the update Page
//                }
            } else {
                print("No Updates Available!")
            }
        }
    }
}

struct AppUpdateView: View {
    var appInfo: VersionCheckManager.ReturnResult
    @Binding var forcedUpdate: Bool
    /// View Properties
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    var body: some View {
        VStack(spacing: 15) {
            Image(.appUpdate)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .overlay {
                    GeometryReader {
                        let size = $0.size
                        let actualImageSize = CGSize(width: 399, height: 727)
                        let ratio = min(
                            size.width / actualImageSize.width,
                            size.height / actualImageSize.height
                        )
                        
                        let logoSize = CGSize(width: 100 * ratio, height: 100 * ratio)
                        let logoPlacement = CGSize(width: 173 * ratio, height: 365 * ratio)
                        
                        if let appLogo = URL(string: appInfo.appLogo) {
                            AsyncImage(url: appLogo) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: logoSize.width, height: logoSize.height)
                                    .clipShape(.rect(cornerRadius: 30 * ratio))
                                    .offset(logoPlacement)
                            } placeholder: {
                                
                            }
                        }
                    }
                }
            
            VStack(spacing: 8) {
                Text("App Update Available")
                    .font(.title.bold())
                
                Text("There is an app update available from\nversion **\(appInfo.currentVersion)** to version **\(appInfo.availableVersion)**!")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
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
                        Text("Update App")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                }
                
                if !forcedUpdate {
                    Button {
                        dismiss()
                    } label: {
                        Text("No Thanks!")
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
    
    var isiOS26: Bool {
        if #available(iOS 26, *) {
            return true
        }
        
        return false
    }
}

#Preview {
    ContentView()
}
