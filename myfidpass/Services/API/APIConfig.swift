//
//  APIConfig.swift
//  myfidpass
//
//  Configuration de l’API pour production. Modifier baseURL si ton backend a une autre adresse.
//

import Foundation

enum APIConfig {
    /// URL de base de l’API (production).
    static var baseURL: URL {
        URL(string: "https://api.myfidpass.fr")!
    }

    /// Page statique `flyer-embed.html` : même rendu canvas que le SaaS (aperçu dans l’app).
    static var flyerEmbedURL: URL {
        URL(string: "https://www.myfidpass.fr/flyer-embed.html")!
    }

    /// Page statique `qr-game-embed.html` : écran jeu QR après scan (aperçu sous la palette — pas le poster flyer).
    static var qrGameEmbedURL: URL {
        URL(string: "https://www.myfidpass.fr/qr-game-embed.html")!
    }
}
