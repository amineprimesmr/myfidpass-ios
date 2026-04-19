//
//  RevenueCatSubscriptionState.swift
//  myfidpass
//
//  Abonnements natifs (StoreKit) via RevenueCat : paywall, restore, alignement utilisateur avec le compte MyFidpass.
//

import Foundation
import Combine
import RevenueCat

@MainActor
final class RevenueCatSubscriptionState: NSObject, ObservableObject {
    @Published private(set) var hasPremiumEntitlement = false
    @Published private(set) var lastErrorMessage: String?

    override init() {
        super.init()
        Purchases.shared.delegate = self
        refreshFromCachedCustomerInfo()
    }

    /// Appeler une fois au lancement, **après** `Purchases.configure`.
    func refreshFromCachedCustomerInfo() {
        let info = Purchases.shared.cachedCustomerInfo
        applyCustomerInfo(info)
    }

    func refreshCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            applyCustomerInfo(info)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Associe l’utilisateur MyFidpass au client RevenueCat (`Purchases.logIn`).
    func syncWithAppAccount() async {
        guard AuthStorage.isLoggedIn else {
            await logOutRevenueCat()
            return
        }
        guard let appUserId = AuthStorage.revenueCatAppUserID, !appUserId.isEmpty else {
            await refreshCustomerInfo()
            return
        }
        do {
            let (info, _) = try await Purchases.shared.logIn(appUserId)
            applyCustomerInfo(info)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func logOutRevenueCat() async {
        do {
            _ = try await Purchases.shared.logOut()
            hasPremiumEntitlement = false
            lastErrorMessage = nil
        } catch {
            hasPremiumEntitlement = false
            lastErrorMessage = error.localizedDescription
        }
    }

    private func applyCustomerInfo(_ info: CustomerInfo?) {
        guard let info else {
            hasPremiumEntitlement = false
            return
        }
        let active = info.entitlements[RevenueCatConfig.premiumEntitlementId]?.isActive == true
        hasPremiumEntitlement = active
    }
}

extension RevenueCatSubscriptionState: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.applyCustomerInfo(customerInfo)
        }
    }
}

extension AuthService {
    /// Accès « abonnement payant » : Stripe (API) **ou** achat App Store via RevenueCat.
    func subscriptionAccessUnlocked(revenueCatPremium: Bool) -> Bool {
        if isPlatformAdmin { return true }
        if revenueCatPremium { return true }
        return hasActiveMerchantSubscription
    }
}
