//
//  APIDTOs+13_POST.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

// MARK: - POST .../integration/scan

struct ScanResponse: Decodable {
    /// Optionnel : certaines réponses d’erreur partielles ou évolutions API peuvent omettre `member` ; le solde peut venir de `new_balance` / `points_added`.
    let member: ScanMemberDTO?
    let pointsAdded: Int?
    let newBalance: Int?
    /// `true` si le plafond `scan_max_points_per_transaction` a réduit le crédit.
    let pointsCapped: Bool?
    let pointsRequested: Int?
    /// Programme tampons : la carte était complète sur ce crédit → récompense max, compteur remis à zéro côté serveur.
    let stampCycleCompleted: Bool?
    let stampCyclesCompleted: Int?
}

struct ScanMemberDTO: Decodable {
    let id: String?
    let name: String?
    let email: String?
    let points: Int?
    let lastVisitAt: String?
}

