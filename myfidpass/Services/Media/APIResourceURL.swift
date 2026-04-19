//
//  APIResourceURL.swift
//  myfidpass
//
//  Résolution des URLs médias (backend renvoie souvent `/api/...` sans hôte) et distinction
//  chemin sandbox vs chemin API — évite de traiter `/api/businesses/…/logo` comme un fichier local.
//

import Foundation

enum APIResourceURL {
    /// Résout une URL absolue : `https://…`, ou chemin `/api/…` / `api/…` relatif à `APIConfig.baseURL`.
    static func resolved(from string: String) -> URL? {
        let t = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if let u = URL(string: t), let scheme = u.scheme, scheme == "http" || scheme == "https" {
            return u
        }
        if t.hasPrefix("/") {
            return URL(string: t, relativeTo: APIConfig.baseURL)?.absoluteURL
        }
        if !t.contains("://") {
            let withSlash = t.hasPrefix("/") ? t : "/\(t)"
            return URL(string: withSlash, relativeTo: APIConfig.baseURL)?.absoluteURL
        }
        return nil
    }

    static func isOurAPIHost(_ url: URL) -> Bool {
        url.host() == APIConfig.baseURL.host()
    }

    /// Fichier image local (photothèque, Documents). Retourne `nil` si la chaîne est une ressource API (`/api/…`).
    static func localImageFilePathIfPresent(_ raw: String) -> String? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if t.hasPrefix("file:") {
            return URL(string: t)?.path
        }
        if t.contains("CardLogos"), let full = CardLogoStorage.fullPath(forRelative: t) {
            return full
        }
        // Ne jamais confondre avec un chemin fichier Unix
        if t.hasPrefix("/api/") {
            return nil
        }
        if t.hasPrefix("/var/") || t.hasPrefix("/private/") {
            return t
        }
        // Chemins absolus hors /api (ex. certains chemins sandbox)
        if t.hasPrefix("/"), t.contains("CardLogos") || t.contains("/Documents/") || t.contains("/tmp/") {
            return t
        }
        // Autre chemin absolu (ex. simulateur /Users/…) : uniquement si le fichier existe.
        if t.hasPrefix("/"), !t.hasPrefix("/api/"), FileManager.default.fileExists(atPath: t) {
            return t
        }
        return nil
    }
}
