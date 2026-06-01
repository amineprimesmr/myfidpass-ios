//
//  MerchantAppAccountToken.swift
//  myfidpass
//
//  UUID stable envoyé à StoreKit (`appAccountToken`) — vérifié côté API lors du sync Apple.
//

import CryptoKit
import Foundation

enum MerchantAppAccountToken {
    /// Token passé à `Product.PurchaseOption.appAccountToken` pour lier l’achat au compte MyFidpass.
    static func uuid(forUserId userId: String) -> UUID? {
        let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = UUID(uuidString: trimmed) {
            return direct
        }
        let digest = SHA256.hash(data: Data("myfidpass.appAccountToken.v1:\(trimmed)".utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            )
        )
    }

    static func currentUserToken() -> UUID? {
        guard let userId = AuthStorage.userId else { return nil }
        return uuid(forUserId: userId)
    }
}
