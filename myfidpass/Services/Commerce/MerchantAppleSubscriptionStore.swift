//
//  MerchantAppleSubscriptionStore.swift
//  myfidpass
//
//  Achats in-app App Store (StoreKit 2) + synchronisation API MyFidpass.
//

import Combine
import Foundation
import StoreKit
import UIKit

@MainActor
final class MerchantAppleSubscriptionStore: ObservableObject {
    static let shared = MerchantAppleSubscriptionStore()

    @Published private(set) var productsById: [String: Product] = [:]
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var loadProductsError: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { await listenForTransactionUpdates() }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProductsIfNeeded(force: Bool = false) async {
        if !force, !productsById.isEmpty, !isLoadingProducts { return }
        if isLoadingProducts { return }
        isLoadingProducts = true
        loadProductsError = nil
        defer { isLoadingProducts = false }
        do {
            let products = try await Product.products(for: MerchantAppleSubscriptionProducts.all)
            var map = productsById
            for p in products {
                map[p.id] = p
            }
            productsById = map
            let hasAny = MerchantAppleSubscriptionProducts.all.contains { map[$0] != nil }
            if !hasAny {
                loadProductsError = "Abonnements App Store indisponibles. Vérifiez App Store Connect ou réessayez plus tard."
            }
        } catch {
            loadProductsError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func isProductAvailable(slots: Int, annual: Bool) -> Bool {
        product(slots: slots, annual: annual) != nil
    }

    func product(slots: Int, annual: Bool) -> Product? {
        guard let id = MerchantAppleSubscriptionProducts.productId(slots: slots, annual: annual) else { return nil }
        return productsById[id]
    }

    func displayPriceLine(slots: Int, annual: Bool) -> String? {
        product(slots: slots, annual: annual)?.displayPrice
    }

    /// Prix affiché de l’offre introductive App Store (ex. « 1,00 € »), si configurée sur le produit.
    func introductoryOfferDisplayPrice(slots: Int, annual: Bool) -> String? {
        product(slots: slots, annual: annual)?
            .subscription?
            .introductoryOffer?
            .displayPrice
    }

    /// Offre découverte configurée sur le produit App Store Connect (payAsYouGo 1 €, etc.).
    func hasIntroductoryOfferConfigured(slots: Int, annual: Bool) -> Bool {
        product(slots: slots, annual: annual)?.subscription?.introductoryOffer != nil
    }

    /// Éligibilité offre introductive — une seule par **groupe** d’abonnements et par Apple ID (règle Apple).
    func isEligibleForIntroOffer(slots: Int, annual: Bool) async -> Bool {
        guard hasIntroductoryOfferConfigured(slots: slots, annual: annual),
              let subscription = product(slots: slots, annual: annual)?.subscription
        else { return false }
        return await subscription.isEligibleForIntroOffer
    }

    /// Achat in-app avec 1 € au 1er mois possible sur ce produit et ce compte Apple.
    func canPurchaseWithAppleIntroOffer(slots: Int, annual: Bool) async -> Bool {
        guard hasIntroductoryOfferConfigured(slots: slots, annual: annual) else { return false }
        return await isEligibleForIntroOffer(slots: slots, annual: annual)
    }

    /// Achat in-app + validation serveur. Retourne la réponse API (statut abonnement côté MyFidpass).
    /// Toujours passe par `product.purchase()` (comme l’annuel) — pas de « restauration silencieuse » mensuelle.
    /// JWS serveur pour forcer l’offre intro 1 € (commerçant MyFidpass sans abo payant).
    func fetchIntroductoryOfferEligibilityJWS(productId: String, appTransactionId: String) async throws -> PaymentAppleIntroOfferEligibilityResponse {
        let payload = PaymentAppleIntroOfferEligibilityRequest(
            productId: productId,
            transactionId: appTransactionId
        )
        return try await APIClient.shared.request(
            .paymentAppleIntroOfferEligibility(payload: payload),
            responseType: PaymentAppleIntroOfferEligibilityResponse.self
        )
    }

    @discardableResult
    func purchase(slots: Int, annual: Bool, appAccountToken: UUID? = MerchantAppAccountToken.currentUserToken()) async throws -> PaymentAppleSyncResponse {
        await loadProductsIfNeeded()
        if product(slots: slots, annual: annual) == nil {
            await loadProductsIfNeeded(force: true)
        }
        guard let product = product(slots: slots, annual: annual) else {
            let productId = MerchantAppleSubscriptionProducts.productId(slots: slots, annual: annual) ?? "?"
            throw MerchantAppleSubscriptionStoreError.productNotFound(
                productId: productId,
                slots: slots
            )
        }
        var options: Set<Product.PurchaseOption> = []
        if let token = appAccountToken {
            options.insert(.appAccountToken(token))
        }
        let storeEligible = await isEligibleForIntroOffer(slots: slots, annual: annual)
        if !storeEligible, hasIntroductoryOfferConfigured(slots: slots, annual: annual) {
            if let jws = await resolveIntroductoryOfferEligibilityJWS(product: product) {
                options.insert(jws)
            }
        }
        let result = try await product.purchase(options: options)
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            let response = try await syncTransactionToBackend(
                transaction,
                signedTransactionInfo: Self.jwsRepresentation(from: verification)
            )
            await transaction.finish()
            return response
        case .userCancelled:
            throw MerchantAppleSubscriptionStoreError.userCancelled
        case .pending:
            throw MerchantAppleSubscriptionStoreError.pending
        @unknown default:
            throw MerchantAppleSubscriptionStoreError.unknown
        }
    }

    /// Restaure les achats App Store et synchronise avec l’API.
    @discardableResult
    func restorePurchasesOnBackend() async throws -> PaymentAppleSyncResponse? {
        var lastResponse: PaymentAppleSyncResponse?
        var synced = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            guard Self.shouldSyncTransactionToBackend(transaction) else { continue }
            lastResponse = try await syncTransactionToBackend(
                transaction,
                signedTransactionInfo: Self.jwsRepresentation(from: entitlement)
            )
            synced = true
        }
        if !synced {
            throw MerchantAppleSubscriptionStoreError.noActiveSubscription
        }
        return lastResponse
    }

    private func listenForTransactionUpdates() async {
        for await update in Transaction.updates {
            guard case .verified(let transaction) = update else { continue }
            guard Self.shouldSyncTransactionToBackend(transaction) else {
                await transaction.finish()
                continue
            }
            do {
                _ = try await syncTransactionToBackend(
                    transaction,
                    signedTransactionInfo: Self.jwsRepresentation(from: update)
                )
                await transaction.finish()
            } catch {
                // Webhook / retry au prochain lancement ou reconcile manuel
            }
        }
    }

    /// N’envoie au serveur que les abonnements MyFidpass encore valides (évite sandbox / JWS incomplet → faux « actif »).
    private static func shouldSyncTransactionToBackend(_ transaction: Transaction) -> Bool {
        guard MerchantAppleSubscriptionProducts.all.contains(transaction.productID) else { return false }
        if transaction.revocationDate != nil { return false }
        if let exp = transaction.expirationDate, exp <= Date() { return false }
        return true
    }

    @discardableResult
    /// Aligné API : abonnement encaissé (pas seul essai application).
    static func syncResponseIndicatesPaidAccess(_ response: PaymentAppleSyncResponse) -> Bool {
        if response.hasPaidMerchantSubscription == true { return true }
        guard response.hasActiveSubscription == true else { return false }
        let status = response.subscriptionStatus?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return status == "active" || status == "trialing" || status == "past_due"
    }

    private func syncTransactionToBackend(
        _ transaction: Transaction,
        signedTransactionInfo: String?
    ) async throws -> PaymentAppleSyncResponse {
        let payload = PaymentAppleSyncTransactionPayload(
            signedTransactionInfo: signedTransactionInfo,
            transactionId: String(transaction.id)
        )
        do {
            return try await APIClient.shared.request(
                .paymentAppleSyncTransaction(payload: payload)
            )
        } catch let error as APIError {
            if case .server(_, let message) = error {
                let lower = (message ?? "").lowercased()
                if lower.contains("autre compte myfidpass") || lower.contains("déjà lié") {
                    throw MerchantAppleSubscriptionStoreError.subscriptionLinkedToOtherAccount
                }
            }
            throw error
        }
    }

    private static func jwsRepresentation(from verification: VerificationResult<Transaction>) -> String? {
        let jws = verification.jwsRepresentation.trimmingCharacters(in: .whitespacesAndNewlines)
        return jws.isEmpty ? nil : jws
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    /// Option d’achat : éligibilité intro 1 € signée par l’API (iOS 15+, API renforcée en 18.4).
    private func resolveIntroductoryOfferEligibilityJWS(product: Product) async -> Product.PurchaseOption? {
        guard let appTxId = await MerchantAppleAppTransaction.currentAppTransactionID() else { return nil }
        do {
            let response = try await fetchIntroductoryOfferEligibilityJWS(
                productId: product.id,
                appTransactionId: appTxId
            )
            guard response.allowIntroductoryOffer == true,
                  let compact = response.compactJws?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !compact.isEmpty
            else { return nil }
            return Product.PurchaseOption.introductoryOfferEligibility(compactJWS: compact)
        } catch {
            return nil
        }
    }

    /// Feuille système de saisie / échange d’un code promo offre App Store.
    static func presentOfferCodeRedemptionSheet() {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard let scene else { return }
        if #available(iOS 16.0, *) {
            Task { @MainActor in
                try? await AppStore.presentOfferCodeRedeemSheet(in: scene)
            }
        } else {
            SKPaymentQueue.default().presentCodeRedemptionSheet()
        }
    }
}

enum MerchantAppleSubscriptionStoreError: LocalizedError {
    case productsUnavailable
    case productNotFound(productId: String, slots: Int)
    case userCancelled
    case pending
    case noActiveSubscription
    case subscriptionLinkedToOtherAccount
    case unknown

    var errorDescription: String? {
        switch self {
        case .productsUnavailable:
            return "Impossible de charger les offres App Store."
        case .productNotFound(_, let slots):
            let label = slots == 1 ? "1 commerce" : "\(slots) commerces"
            return "L’offre App Store « \(label) » n’est pas encore disponible sur cet appareil. Soumettez les abonnements avec la build sur App Store Connect, ou réessayez dans quelques minutes."
        case .userCancelled:
            return nil
        case .pending:
            return "Achat en attente d’approbation (Ask to Buy). Réessayez lorsque l’achat est confirmé."
        case .noActiveSubscription:
            return "Aucun abonnement actif trouvé sur ce compte Apple."
        case .subscriptionLinkedToOtherAccount:
            return "Cet abonnement App Store est déjà lié à un autre compte MyFidpass. Connectez-vous avec le compte qui a souscrit, ou utilisez le même Apple ID sur le bon compte."
        case .unknown:
            return "L’achat n’a pas pu être finalisé."
        }
    }
}
