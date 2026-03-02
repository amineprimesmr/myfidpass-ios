//
//  VersionCheckManager.swift
//  VersionAppCheck
//
//  Created by Balaji Venkatesh on 10/10/25.
//

import SwiftUI

@MainActor
class VersionCheckManager {
    static let shared = VersionCheckManager()
    
    func checkIfAppUpdateAvailable() async -> ReturnResult? {
        do {
            /// NOTE: You can also use App ID Directly as well
            /// EG: "https://itunes.apple.com/lookup?id=\(appID)"
            guard let bundleID,
                let lookupURL = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleID)") else {
                return nil
            }
            
            let data = try await URLSession.shared.data(from: lookupURL).0
            
            guard let rawJSON = (try JSONSerialization.jsonObject(with: data)) as? Dictionary<String, Any> else {
                return nil
            }
            
            guard let jsonResults = rawJSON["results"] as? [Any] else {
                return nil
            }
            
            guard let jsonValue = jsonResults.first as? Dictionary<String, Any> else {
                return nil
            }
            
            /// Extra Data from the jsonValue!
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
        return Bundle.main.bundleIdentifier
        /// FOR TESTING PURPOSE
        //return "Use any of the live app bundle IDs"
    }
    
    struct ReturnResult: Identifiable {
        private(set) var id: String = UUID().uuidString
        var currentVersion: String
        var availableVersion: String
        var releaseNotes: String
        var appLogo: String
        var appURL: String
        /// Add more properties according to your needs!
    }
}
