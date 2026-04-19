//
//  RevenueCatConfig.swift
//  myfidpass
//
//  Résolution de la clé publique RevenueCat, tolérante aux placeholders.
//
//  Priorité :
//    1. `REVENUECAT_APPLE_PUBLIC_KEY` (variable d'env sur le schéma Run)
//    2. `RevenueCatPublicAPIKey` dans Info.plist (préfixée `appl_`)
//    3. Fallback clé `test_` (sandbox) — permet le paywall même sans clé de prod.
//

import Foundation

enum RevenueCatConfig {
    static let premiumEntitlementId = "myfidpass_premium"

    /// Marqueurs « placeholder » : si la valeur les contient, on considère qu'il n'y a pas de clé.
    private static let placeholderMarkers: [String] = [
        "REPLACE", "REMPLACE", "XXXX", "YOUR_KEY", "TODO", "CHANGEME"
    ]

    /// Clé sandbox RevenueCat (projet MyFidpass). Sert de fallback pour que le paywall
    /// s'initialise même sans clé `appl_…` de production.
    private static let sandboxApiKey = "test_oqYHcxfhTCTLpnuDmJLjOlZCHwS"

    /// Clé `appl_…` extraite de l'environnement ou du bundle. `nil` si absente / placeholder / mal préfixée.
    private static var configuredAppStoreKey: String? {
        let env = ProcessInfo.processInfo.environment["REVENUECAT_APPLE_PUBLIC_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let plist = (Bundle.main.object(forInfoDictionaryKey: "RevenueCatPublicAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let raw = env.isEmpty ? plist : env

        guard !raw.isEmpty else { return nil }
        guard raw.hasPrefix("appl_"), raw.count > 12 else { return nil }
        let upper = raw.uppercased()
        if placeholderMarkers.contains(where: { upper.contains($0) }) { return nil }
        return raw
    }

    /// Clé utilisée par `Purchases.configure`. Toujours non-nil :
    /// - clé `appl_…` si présente et valide dans Info.plist / env,
    /// - sinon clé `test_…` (sandbox RevenueCat).
    static var resolvedApiKey: String {
        if let appStore = configuredAppStoreKey { return appStore }
        return sandboxApiKey
    }

    /// `true` si une vraie clé production (`appl_…`) est configurée.
    static var hasProductionKey: Bool { configuredAppStoreKey != nil }
}
