//
//  MerchantWorkspaceRole.swift
//  myfidpass
//
//  Rôle d’un utilisateur dans l’espace commerçant (API `user.workspace_role`).
//

import SwiftUI

/// Rôle métier dans un commerce (distinct de `is_admin` plateforme).
enum MerchantWorkspaceRole: String, Codable, CaseIterable, Sendable {
    /// Propriétaire : accès complet + facturation.
    case owner
    /// Responsable / gérant : même accès applicatif que le owner (gestion d’équipe, cartes, notifs) — la facturation peut rester côté owner côté API.
    case manager
    /// Employé : scan, consultation d’activité limitée, pas de pilotage commerce.
    case staff

    /// Chaîne renvoyée par `GET /api/auth/me` → `user.workspace_role`.
    static func resolve(fromAPIValue raw: String?) -> MerchantWorkspaceRole {
        let s = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if s.isEmpty { return .owner }
        if let exact = MerchantWorkspaceRole(rawValue: s) { return exact }
        switch s {
        case "employee", "employe", "collaborator", "collaborateur", "caissier", "caisse":
            return .staff
        default:
            return .owner
        }
    }

    var canOpenFullMerchantWorkspace: Bool {
        self != .staff
    }

    var canManageTeam: Bool {
        self == .owner || self == .manager
    }
}

// MARK: - Mode d’affichage accueil (aperçu carte vs bandeau employé)

/// Mode d’UI pour l’onglet Accueil : commerçant complet ou employé.
enum MerchantWorkspaceMode: Hashable, Sendable {
    case owner
    case staff
}

private struct MerchantWorkspaceModeKey: EnvironmentKey {
    static let defaultValue: MerchantWorkspaceMode = .owner
}

extension EnvironmentValues {
    var merchantWorkspaceMode: MerchantWorkspaceMode {
        get { self[MerchantWorkspaceModeKey.self] }
        set { self[MerchantWorkspaceModeKey.self] = newValue }
    }
}
