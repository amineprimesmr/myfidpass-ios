//
//  APIDTOs+10_GET.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

// MARK: - GET .../dashboard/members

struct BusinessMembersResponse: Decodable {
    let members: [MemberDTO]
    let total: Int?

    private enum CodingKeys: String, CodingKey { case members, total }

    /// 1ʳᵉ phase sync / tests : conteneur vide (pas fourni par le membre `init(from:)` seul).
    init(members: [MemberDTO], total: Int?) {
        self.members = members
        self.total = total
    }

    /// Décodage large : ignore les entrées sans `id` (au lieu de faire échouer toute la page).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rows = try c.decodeIfPresent([MemberAPIRow].self, forKey: .members) ?? []
        members = rows.compactMap { $0.toMemberDTO() }
        total = try c.decodeIfPresent(Int.self, forKey: .total)
    }
}

/// Décodage intermédiaire : id optionnel côté fil, transformé en `MemberDTO?`.
private struct MemberAPIRow: Decodable {
    let id: String?
    let name: String?
    let email: String?
    let points: Int?
    let createdAt: String?
    let lastVisitAt: String?
    func toMemberDTO() -> MemberDTO? {
        let trimmed = (id ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return MemberDTO(
            id: trimmed,
            name: name,
            email: email,
            points: points,
            createdAt: createdAt,
            lastVisitAt: lastVisitAt
        )
    }
}

struct MemberDTO: Decodable {
    let id: String
    let name: String?
    let email: String?
    let points: Int?
    let createdAt: String?
    let lastVisitAt: String?

    /// Utilisé par le décodage large des listes ; le décodage JSON direct d’un seul `MemberDTO` reste le synthétiseur.
    fileprivate init(
        id: String,
        name: String?,
        email: String?,
        points: Int?,
        createdAt: String?,
        lastVisitAt: String?
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.points = points
        self.createdAt = createdAt
        self.lastVisitAt = lastVisitAt
    }
}

