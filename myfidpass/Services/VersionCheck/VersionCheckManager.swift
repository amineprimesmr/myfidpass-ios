//
//  VersionCheckManager.swift
//  myfidpass
//
//  Vérification des mises à jour sur l’App Store (lookup iTunes).
//

import Foundation
import os.log
import SwiftUI

private let versionCheckLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "myfidpass", category: "VersionCheck")

@MainActor
final class VersionCheckManager {
    static let shared = VersionCheckManager()

    /// Incrémenter après changement de règle métier (réinitialise le « Plus tard » obsolète une fois).
    private static let policyVersionKey = "myfidpass.appUpdate.policyVersion"
    private static let currentPolicyVersion = 4

    private static let dismissedStoreVersionKey = "myfidpass.appUpdate.dismissedStoreVersion"

    /// Marque la version **App Store** pour laquelle l’utilisateur a choisi « Plus tard » ou ouvert la fiche (ne plus reproposer tant que le lookup renvoie la même chaîne).
    func markUpdatePromptDismissed(forStoreVersion storeVersion: String) {
        let v = storeVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty else { return }
        UserDefaults.standard.set(v, forKey: Self.dismissedStoreVersionKey)
    }

    func checkIfAppUpdateAvailable() async -> ReturnResult? {
        migratePolicyIfNeeded()

        do {
            guard let bundleID,
                  let lookupURL = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleID)") else {
                return nil
            }

            let data = try await URLSession.shared.data(from: lookupURL).0

            guard let rawJSON = (try JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let jsonResults = rawJSON["results"] as? [Any],
                  let jsonValue = jsonResults.first as? [String: Any],
                  let availableVersion = jsonValue["version"] as? String,
                  let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
                versionCheckLog.debug("VersionCheck: lookup JSON incomplet (pas de version store ou bundle local).")
                return nil
            }

            AppVersionUpdatePolicy.recordSuccessfulStoreLookup()

            let current = currentVersion.trimmingCharacters(in: .whitespacesAndNewlines)
            let available = availableVersion.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !current.isEmpty, !available.isEmpty else { return nil }

            let releaseNotes = (jsonValue["releaseNotes"] as? String) ?? ""
            let appLogo = (jsonValue["artworkUrl512"] as? String) ?? ""
            let trackId: Int? = {
                if let n = jsonValue["trackId"] as? Int { return n }
                if let n = jsonValue["trackId"] as? NSNumber { return n.intValue }
                return nil
            }()
            let appURL = (jsonValue["trackViewUrl"] as? String)?
                .components(separatedBy: "?").first
                ?? trackId.map { "https://apps.apple.com/app/id\($0)" }
                ?? ""

            // Une seule source de vérité : ordre **numérique** (comme Réglages iOS / App Store).
            guard isStoreVersionStrictlyNewerThanInstalled(store: available, installed: current) else {
                versionCheckLog.debug("VersionCheck: pas de MAJ (\(current, privacy: .public) ≥ store \(available, privacy: .public)).")
                return nil
            }

            if UserDefaults.standard.string(forKey: Self.dismissedStoreVersionKey) == available {
                versionCheckLog.debug("VersionCheck: MAJ \(available, privacy: .public) ignorée (Plus tard).")
                return nil
            }

            versionCheckLog.info("VersionCheck: MAJ disponible \(current, privacy: .public) → \(available, privacy: .public)")

            return ReturnResult(
                currentVersion: current,
                availableVersion: available,
                releaseNotes: releaseNotes,
                appLogo: appLogo,
                appURL: appURL,
                isMandatoryUpdate: AppVersionUpdatePolicy.isMandatoryUpdate(releaseNotes: releaseNotes)
            )
        } catch {
            versionCheckLog.error("VersionCheckManager error: \(error.localizedDescription)")
            return nil
        }
    }

    var bundleID: String? {
        Bundle.main.bundleIdentifier
    }

    // MARK: - Comparaison

    /// `true` si la version **publiée sur l’App Store** est **strictement supérieure** à celle installée.
    ///
    /// - **Ne pas** se fier seul à `String.compare(..., .numeric)` : pour App Store Connect, une version peut
    ///   apparaître comme **« 1.01 »** (équivalent fréquent de **1.0.1**), alors que la comparaison Foundation
    ///   classe **1.0.2** comme *plus ancienne* que **1.01** (segments 0 vs 1 au 2ᵉ rang).
    /// - On normalise le motif **X.0Y** (deux chiffres, 0 puis 1–9) en **X.0.Y** avant comparaison par segments entiers.
    private func isStoreVersionStrictlyNewerThanInstalled(store: String, installed: String) -> Bool {
        let a = normalizedVersionSegments(installed)
        let b = normalizedVersionSegments(store)
        guard !a.isEmpty, !b.isEmpty else {
            return installed.compare(store, options: .numeric) == .orderedAscending
        }
        return compareVersionSegments(a, b) == .orderedAscending
    }

    /// Segments entiers pour comparaison lexicographique (patch manquant = 0).
    private func normalizedVersionSegments(_ version: String) -> [Int] {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".").map { String($0) }
        guard !parts.isEmpty else { return [] }

        // Ex. App Store « 1.01 », « 2.03 » → 1.0.1, 2.0.3 (et non 1.1 vs 1.0.2).
        if parts.count == 2,
           let major = Int(parts[0]),
           parts[1].count == 2,
           let first = parts[1].first, first == "0",
           let patch = Int(parts[1].dropFirst()), patch >= 0 {
            return [major, 0, patch]
        }

        return parts.compactMap { Int($0) }
    }

    private func compareVersionSegments(_ a: [Int], _ b: [Int]) -> ComparisonResult {
        let n = max(a.count, b.count)
        for i in 0..<n {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x < y { return .orderedAscending }
            if x > y { return .orderedDescending }
        }
        return .orderedSame
    }

    private func migratePolicyIfNeeded() {
        let v = UserDefaults.standard.integer(forKey: Self.policyVersionKey)
        guard v < Self.currentPolicyVersion else { return }
        UserDefaults.standard.set(Self.currentPolicyVersion, forKey: Self.policyVersionKey)
        // Nouvelle politique : effacer un éventuel « Plus tard » saisi avec l’ancienne logique erronée.
        UserDefaults.standard.removeObject(forKey: Self.dismissedStoreVersionKey)
    }

    struct ReturnResult: Identifiable {
        /// Stable pour `sheet(item:)` — une entrée par version store proposée.
        var id: String { availableVersion }
        var currentVersion: String
        var availableVersion: String
        var releaseNotes: String
        var appLogo: String
        var appURL: String
        /// Mise à jour bloquante (notes App Store avec marqueur `[force]` / `!` / `UPDATE_REQUIRED`).
        var isMandatoryUpdate: Bool
    }
}
