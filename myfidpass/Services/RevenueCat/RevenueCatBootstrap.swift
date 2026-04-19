//
//  RevenueCatBootstrap.swift
//  myfidpass
//
//  Un seul point d'entrée `Purchases.configure`.
//  `RevenueCatConfig.resolvedApiKey` renvoie toujours une clé (production si fournie,
//  sinon sandbox) donc `Purchases` est toujours configuré.
//

import Foundation
import RevenueCat

enum RevenueCatBootstrap {
    private static var didAttemptConfigure = false

    static var isConfigured: Bool { Purchases.isConfigured }

    static func configureIfNeeded() {
        guard !didAttemptConfigure else { return }
        didAttemptConfigure = true

        let key = RevenueCatConfig.resolvedApiKey

        #if DEBUG
        Purchases.logLevel = .debug
        if !RevenueCatConfig.hasProductionKey {
            print("[RevenueCat] ⚠️ Pas de clé `appl_…` en prod — utilisation de la clé sandbox `test_`. " +
                  "Ajoute `RevenueCatPublicAPIKey` (appl_…) dans Info.plist avant l'Archive App Store.")
        }
        #endif

        Purchases.configure(withAPIKey: key)
    }
}
