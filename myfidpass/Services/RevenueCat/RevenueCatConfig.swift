//
//  RevenueCatConfig.swift
//  myfidpass
//
//  Clés API (tableau RevenueCat → Project → API keys). Les clés **test_** / **sandbox** sont pour
//  le simulateur et TestFlight en mode sandbox StoreKit.
//

import Foundation

enum RevenueCatConfig {
    /// Identifiant d’**entitlement** à créer dans RevenueCat (Project → Entitlements) avec le **même** nom.
    /// Ex. : `myfidpass_premium` — relie-le à ton produit d’abonnement App Store.
    static let premiumEntitlementId = "myfidpass_premium"

    #if DEBUG
    /// Clé **test** du projet (dashboard → Install SDK). Remplace par la clé **appl_** en prod quand tu publies.
    static let apiKey = "test_oqYHcxthTCTLpnuDmJLj0lZCHwS"
    #else
    /// Remplace par la clé publique **Apple** (préfixe `appl_`) depuis RevenueCat → API keys → app.
    static let apiKey = "REPLACE_WITH_APPL_PUBLIC_KEY"
    #endif
}
