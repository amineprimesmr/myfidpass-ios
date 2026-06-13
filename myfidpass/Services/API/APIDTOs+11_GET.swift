//
//  APIDTOs+11_GET.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

// MARK: - GET .../dashboard/transactions

struct BusinessTransactionsResponse: Decodable {
    let transactions: [TransactionDTO]
    let total: Int?

    /// 1ʳᵉ phase sync : liste vide (le synthétiseur `init(from:)` seul n’expose pas d’init membre public).
    init(transactions: [TransactionDTO], total: Int?) {
        self.transactions = transactions
        self.total = total
    }
}

struct TransactionDTO: Decodable {
    let id: String?
    let memberId: String?
    let memberName: String?
    let memberEmail: String?
    let type: String?
    let points: Int?
    let metadata: String?
    let createdAt: String?
}

