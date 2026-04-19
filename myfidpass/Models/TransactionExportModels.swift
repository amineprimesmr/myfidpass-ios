//
//  TransactionExportModels.swift
//  myfidpass
//
//  Réponse JSON de GET .../dashboard/transactions/export?format=json
//

import Foundation

struct TransactionExportJSONResponse: Decodable {
    let businessName: String?
    let slug: String?
    let generatedAt: String?
    let periodLabel: String?
    let totalMatching: Int?
    let returnedCount: Int?
    let truncated: Bool?
    let filters: TransactionExportFilters?
    let summary: TransactionExportSummary?
    let transactions: [TransactionExportRow]
}

struct TransactionExportFilters: Decodable {
    let days: Int?
    let from: String?
    let to: String?
    let types: String?
    let typeLegacy: String?
    let memberId: String?
}

struct TransactionExportSummary: Decodable {
    let rowCount: Int?
    let byType: [String: Int]?
    let pointsCreditedTotal: Int?
    let pointsDebitedTotal: Int?
}

struct TransactionExportRow: Decodable {
    let id: String?
    let memberId: String?
    let memberName: String?
    let memberEmail: String?
    let type: String?
    let typeLabel: String?
    let detail: String?
    let points: Int?
    let createdAt: String?
}
