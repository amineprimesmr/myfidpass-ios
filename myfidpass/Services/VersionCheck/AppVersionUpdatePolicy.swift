//
//  AppVersionUpdatePolicy.swift
//  myfidpass
//
//  Règles de prompting (optionnel vs obligatoire) et cadence des lookups store.
//

import Foundation

enum AppVersionUpdatePolicy {
    private static let lastLookupAtKey = "myfidpass.appUpdate.lastLookupAt"
    /// Évite de spammer l’API iTunes / Play à chaque passage au premier plan.
    static let minimumLookupInterval: TimeInterval = 30 * 60

    static func shouldRunStoreLookup(now: Date = Date()) -> Bool {
        let last = UserDefaults.standard.object(forKey: lastLookupAtKey) as? Date ?? .distantPast
        return now.timeIntervalSince(last) >= minimumLookupInterval
    }

    /// Enregistre un lookup **réussi** (réponse iTunes parsée) — pas en cas d’échec réseau.
    static func recordSuccessfulStoreLookup(at date: Date = Date()) {
        UserDefaults.standard.set(date, forKey: lastLookupAtKey)
    }

    /// Marqueurs App Store Connect (notes de version, invisible pour l’utilisateur final) :
    /// `[force]`, `[myfidpass_force]`, `UPDATE_REQUIRED`, ou première ligne commençant par `!`.
    static func isMandatoryUpdate(releaseNotes: String) -> Bool {
        let trimmed = releaseNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lower = trimmed.lowercased()
        if lower.contains("[force]") || lower.contains("[myfidpass_force]") { return true }
        if lower.contains("update_required") { return true }
        if trimmed.first == "!" { return true }
        return false
    }
}
