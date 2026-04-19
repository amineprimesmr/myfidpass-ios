//
//  RevenueCatBootstrap.swift
//  myfidpass
//
//  Un seul point d’entrée `Purchases.configure` (app + préviews SwiftUI).
//

import Foundation
import RevenueCat

enum RevenueCatBootstrap {
    private static var didConfigure = false

    static func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
    }
}
