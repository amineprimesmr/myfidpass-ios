//
//  MerchantAppleAppTransaction.swift
//  myfidpass
//
//  Identifiant App Store requis pour signer l’éligibilité à l’offre intro 1 € (JWS serveur).
//

import Foundation
import StoreKit

enum MerchantAppleAppTransaction {
    /// `appTransactionID` — même valeur attendue par POST /api/payment/apple/introductory-offer-eligibility.
    static func currentAppTransactionID() async -> String? {
        guard let result = try? await AppTransaction.shared else { return nil }
        guard case .verified(let transaction) = result else { return nil }
        let id = transaction.appTransactionID.trimmingCharacters(in: .whitespacesAndNewlines)
        return id.isEmpty ? nil : id
    }
}
