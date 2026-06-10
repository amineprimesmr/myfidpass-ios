//
//  MerchantAppleSubscriptionProducts.swift
//  myfidpass
//
//  Identifiants des abonnements auto-renouvelables App Store Connect (StoreKit 2).
//  Doivent correspondre exactement aux produits IAP soumis avec la build.
//

import Foundation

enum MerchantAppleSubscriptionProducts {
    /// **Temporaire** : masquer l’annuel dans l’app (paywall + achat). Repasser à `false` pour réactiver.
    static let annualPlansTemporarilyDisabled = true

    /// Mensuel — 1 commerce (`MFPmensuel`).
    static let monthly = "MFPmensuel"
    /// Annuel — 1 commerce (`MFPannuel`).
    static let annual = "MFPannuel"
    /// Mensuel multi-commerces (2 à 5 emplacements) — IDs App Store Connect approuvés.
    static let slots2 = "com.myfidpass.merchant.slots2.monthly"
    static let slots3 = "com.myfidpass.merchant.slots3.monthly"
    static let slots4 = "com.myfidpass.merchant.slots4.monthly"
    static let slots5 = "com.myfidpass.merchant.slots5.monthly"

    static var all: [String] {
        if annualPlansTemporarilyDisabled {
            return [monthly, slots2, slots3, slots4, slots5]
        }
        return [monthly, annual, slots2, slots3, slots4, slots5]
    }

    /// Nombre de commerces (1–5) pour un identifiant produit App Store.
    static func commerceSlots(for productId: String) -> Int {
        switch productId {
        case monthly, annual: return 1
        case slots2: return 2
        case slots3: return 3
        case slots4: return 4
        case slots5: return 5
        default: return 1
        }
    }

    /// Identifiant IAP pour un forfait donné. L’annuel n’existe que pour 1 commerce.
    static func productId(slots: Int, annual wantsAnnual: Bool) -> String? {
        let n = min(5, max(1, slots))
        if wantsAnnual, !annualPlansTemporarilyDisabled {
            return n == 1 ? Self.annual : nil
        }
        switch n {
        case 1: return monthly
        case 2: return slots2
        case 3: return slots3
        case 4: return slots4
        case 5: return slots5
        default: return nil
        }
    }

    static func isAnnual(_ productId: String) -> Bool {
        productId == annual
    }

    static func supportsAnnualPlan(slots: Int) -> Bool {
        guard !annualPlansTemporarilyDisabled else { return false }
        return min(5, max(1, slots)) == 1
    }

    /// Palier IAP à proposer (1–5) selon commerces utilisés / quota payé.
    /// - Sous-forfait (`used > allowed`) : au minimum `used` (ex. 2 commerces, quota 1 → forfait **2**).
    /// - Quota plein + ajout : `used + 1` (ex. 2 commerces, quota 2 → forfait **3** pour un 3ᵉ).
    static func slotsToPurchase(
        usedBusinesses: Int,
        allowedBusinesses: Int,
        addingAnotherCommerce: Bool
    ) -> Int {
        let used = min(5, max(0, usedBusinesses))
        let allowed = min(5, max(1, allowedBusinesses))
        if used > allowed {
            return min(5, used)
        }
        if addingAnotherCommerce, used >= allowed {
            return min(5, used + 1)
        }
        return min(5, max(used, allowed))
    }
}
