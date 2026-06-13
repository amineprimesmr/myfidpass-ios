//
//  APIDTOs+19_GET.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

// MARK: - GET/POST/DELETE …/dashboard/team (espace commerçant, rôles)

/// Liste des accès « équipe » pour un commerce (owner, manager, staff).
struct WorkspaceTeamListResponse: Decodable {
    let members: [WorkspaceTeamMemberDTO]
    let teamTotals: WorkspaceTeamTotalsDTO?

    enum CodingKeys: String, CodingKey {
        case members
        case items
        case teamTotals = "team_totals"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let m = try c.decodeIfPresent([WorkspaceTeamMemberDTO].self, forKey: .members) {
            members = m
        } else if let i = try c.decodeIfPresent([WorkspaceTeamMemberDTO].self, forKey: .items) {
            members = i
        } else {
            members = []
        }
        teamTotals = try c.decodeIfPresent(WorkspaceTeamTotalsDTO.self, forKey: .teamTotals)
    }
}

struct WorkspaceTeamTotalsDTO: Decodable {
    let scanCount: Int?
    let scans7d: Int?
    let scans30d: Int?
    let memberCount: Int?

    enum CodingKeys: String, CodingKey {
        case scanCount = "scan_count"
        case scans7d = "scans_7d"
        case scans30d = "scans_30d"
        case memberCount = "member_count"
    }
}

struct WorkspaceTeamMemberDTO: Decodable, Identifiable, Hashable {
    let membershipId: String?
    let userId: String?
    let email: String?
    let staffLogin: String?
    let name: String?
    let role: String?
    let status: String?
    let createdAt: String?
    let invitedByLabel: String?
    let scanCount: Int?
    let pointsAddCount: Int?
    let rewardRedeemCount: Int?
    let pointsCorrectionCount: Int?
    let pointsIssued: Int?
    let amountEurSum: Double?
    let lastActivityAt: String?
    let scans7d: Int?
    let scans30d: Int?

    var id: String {
        if let m = membershipId?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty { return "m:\(m)" }
        if let u = userId?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty { return "u:\(u)" }
        if let s = staffLogin?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { return "s:\(s)" }
        if let e = email?.trimmingCharacters(in: .whitespacesAndNewlines), !e.isEmpty { return "e:\(e)" }
        return "row:\(name ?? ""):\(status ?? ""):\(role ?? "")"
    }

    /// Identifiant API pour GET/PATCH/DELETE (membership_id prioritaire, sinon user_id).
    var apiMemberId: String? {
        if let m = membershipId?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty { return m }
        if let u = userId?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty { return u }
        return nil
    }

    var displayName: String {
        let n = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { return n }
        let s = (staffLogin ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty { return s }
        let e = (email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !e.isEmpty { return e }
        return "Membre"
    }

    var isOwner: Bool {
        (role ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "owner"
    }

    enum CodingKeys: String, CodingKey {
        case membershipId = "membership_id"
        case userId = "user_id"
        case email, name, role, status
        case staffLogin = "staff_login"
        case createdAt = "created_at"
        case invitedByLabel = "invited_by_label"
        case scanCount = "scan_count"
        case pointsAddCount = "points_add_count"
        case rewardRedeemCount = "reward_redeem_count"
        case pointsCorrectionCount = "points_correction_count"
        case pointsIssued = "points_issued"
        case amountEurSum = "amount_eur_sum"
        case lastActivityAt = "last_activity_at"
        case scans7d = "scans_7d"
        case scans30d = "scans_30d"
    }
}

struct WorkspaceTeamMemberDetailResponse: Decodable {
    let member: WorkspaceTeamMemberDTO
    let recentActivity: [WorkspaceTeamActivityDTO]

    enum CodingKeys: String, CodingKey {
        case member
        case recentActivity = "recent_activity"
    }
}

struct WorkspaceTeamActivityDTO: Decodable, Identifiable {
    let id: String
    let type: String?
    let points: Int?
    let createdAt: String?
    let memberId: String?
    let memberName: String?
    let amountEur: Double?

    enum CodingKeys: String, CodingKey {
        case id, type, points
        case createdAt = "created_at"
        case memberId = "member_id"
        case memberName = "member_name"
        case amountEur = "amount_eur"
    }
}

struct WorkspaceTeamMemberPatchBody: Encodable {
    let name: String?
    let role: String?
}

struct WorkspaceTeamMemberPatchResponse: Decodable {
    let ok: Bool?
    let member: WorkspaceTeamMemberDTO?
}

struct WorkspaceTeamResendAccessResponse: Decodable {
    let ok: Bool?
    let message: String?
    let emailSent: Bool?
    let emailError: String?

    enum CodingKeys: String, CodingKey {
        case ok, message
        case emailSent = "email_sent"
        case emailError = "email_error"
    }
}

struct WorkspaceTeamInviteResponse: Decodable {
    let ok: Bool?
    let message: String?
    /// Présent si le backend a tenté d’envoyer un e-mail transactionnel (Resend/SMTP).
    let emailSent: Bool?

    enum CodingKeys: String, CodingKey {
        case ok, message
        case emailSent = "email_sent"
    }
}

struct WorkspaceTeamInviteBody: Encodable {
    let email: String
    let name: String?
    let role: String?
}

/// POST …/dashboard/team/staff-accounts — création d’un employé par e-mail (connexion OTP).
struct WorkspaceTeamStaffAccountBody: Encodable {
    let email: String
    let name: String?
    let role: String?
}

struct WorkspaceTeamStaffAccountResponse: Decodable {
    let ok: Bool?
    let message: String?
    let userId: String?
    let email: String?
    let emailSent: Bool?
    let emailError: String?

    enum CodingKeys: String, CodingKey {
        case ok, message, email
        case userId = "user_id"
        case emailSent = "email_sent"
        case emailError = "email_error"
    }
}

