//
//  APIConfig.swift
//  myfidpass
//
//  Configuration de l’API pour production. Modifier baseURL si ton backend a une autre adresse.
//

import Foundation

enum APIConfig {
    /// URL de base de l’API (logiciel / backend). Remplacer par ta vraie URL en production.
    static var baseURL: URL {
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["MYFIDPASS_API_URL"],
           let url = URL(string: override) {
            return url
        }
        #endif
        return URL(string: "https://api.myfidpass.fr")!
    }

    static var isProduction: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
}
