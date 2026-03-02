//
//  VersionCheckManager.swift
//  myfidpass
//
//  Vérification des mises à jour sur l’App Store (réutilisé depuis VersionAppCheck).
//

import SwiftUI

@MainActor
class VersionCheckManager {
    static let shared = VersionCheckManager()

    func checkIfAppUpdateAvailable() async -> ReturnResult? {
        do {
            guard let bundleID,
                  let lookupURL = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleID)") else {
                return nil
            }

            let data = try await URLSession.shared.data(from: lookupURL).0

            guard let rawJSON = (try JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                return nil
            }

            guard let jsonResults = rawJSON["results"] as? [Any] else {
                return nil
            }

            guard let jsonValue = jsonResults.first as? [String: Any] else {
                return nil
            }

            guard let availableVersion = jsonValue["version"] as? String,
                  let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                  let appLogo = jsonValue["artworkUrl512"] as? String,
                  let appURL = (jsonValue["trackViewUrl"] as? String)?.components(separatedBy: "?").first,
                  let releaseNotes = jsonValue["releaseNotes"] as? String else {
                return nil
            }

            if currentVersion.compare(availableVersion, options: .numeric) == .orderedAscending {
                return .init(
                    currentVersion: currentVersion,
                    availableVersion: availableVersion,
                    releaseNotes: releaseNotes,
                    appLogo: appLogo,
                    appURL: appURL
                )
            }

            return nil
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }

    var bundleID: String? {
        Bundle.main.bundleIdentifier
    }

    struct ReturnResult: Identifiable {
        private(set) var id: String = UUID().uuidString
        var currentVersion: String
        var availableVersion: String
        var releaseNotes: String
        var appLogo: String
        var appURL: String
    }
}
