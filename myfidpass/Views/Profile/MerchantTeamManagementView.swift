//
//  MerchantTeamManagementView.swift
//  myfidpass
//
//  Gestion d’équipe : liste, invitation (e-mail), révocation d’accès.
//  Voir `Docs/CONTRAT_API_LOGICIEL.md` (section « Équipe »).
//

import SwiftUI
import Combine

@MainActor
final class MerchantTeamManagementViewModel: ObservableObject {
    @Published private(set) var members: [WorkspaceTeamMemberDTO] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var revokeInFlight = false
    @Published var showRevokeConfirmation = false
    @Published var pendingRevokeId: String?
    @Published var staffCreatePassword = ""
    /// Nom affiché et base de l’identifiant de connexion (normalisé côté app pour `staff_login`).
    @Published var staffCreateName = ""
    @Published var staffCreateInFlight = false
    /// Erreurs affichées dans le formulaire inline « Ajouter un employé ».
    @Published var staffFormError: String?
    /// Champ popup : identifiant employé (simple).
    @Published var staffCreateLogin = ""

    private var slug: String? {
        let s = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return s.isEmpty ? nil : s
    }

    func load() async {
        errorMessage = nil
        guard let slug else {
            errorMessage = "Aucun commerce sélectionné."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let r: WorkspaceTeamListResponse = try await APIClient.shared.request(.businessTeamList(slug: slug))
            members = r.members
        } catch let e as APIError {
            if e.isHTTPResourceMissing {
                errorMessage = "Service équipe indisponible (404). Déployez l’API `GET .../dashboard/team` (voir le contrat d’intégration)."
            } else {
                errorMessage = e.errorDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestRevoke(id: String) {
        errorMessage = nil
        successMessage = nil
        pendingRevokeId = id
        showRevokeConfirmation = true
    }

    func createStaffAccount(loginRaw: String) async {
        staffFormError = nil
        let loginInput = loginRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !loginInput.isEmpty else {
            staffFormError = "Saisissez l’identifiant employé."
            return
        }
        let login = normalizedStaffLogin(from: loginInput)
        guard !login.isEmpty else {
            staffFormError = "Identifiant invalide après normalisation. Utilisez des lettres ou chiffres (3–32 caractères une fois formaté)."
            return
        }
        guard login.range(of: "^[a-z0-9][a-z0-9_-]{1,30}[a-z0-9]$", options: .regularExpression) != nil else {
            staffFormError = "L’identifiant doit respecter 3–32 caractères (a-z, 0-9, _ et -)."
            return
        }
        let pw = staffCreatePassword
        guard pw.count >= 3 else {
            staffFormError = "Le mot de passe doit faire au moins 3 caractères. Choisissez-le et saisissez-le vous-même."
            return
        }
        guard let slug else {
            staffFormError = "Aucun commerce sélectionné. Fermez cette feuille, ouvrez l’onglet d’accueil commerçant et assurez-vous qu’un commerce est actif, puis réessayez."
            return
        }
        errorMessage = nil
        successMessage = nil
        staffCreateInFlight = true
        defer { staffCreateInFlight = false }
        do {
            let body = WorkspaceTeamStaffAccountBody(staffLogin: login, password: pw, name: loginInput, role: "staff")
            let r: WorkspaceTeamStaffAccountResponse = try await APIClient.shared.request(
                .businessTeamStaffAccount(slug: slug, body: body)
            )
            if r.ok == false {
                staffFormError = r.message ?? "Création refusée."
            } else {
                staffFormError = nil
                successMessage = r.message
                    ?? "Compte employé créé. L’employé se connecte avec l’identifiant affiché sous le nom (identifiant normalisé) et le mot de passe choisi."
                staffCreateLogin = ""
            }
            await load()
        } catch let e as APIError {
            staffFormError = e.errorDescription
        } catch {
            staffFormError = error.localizedDescription
        }
    }

    func isValidStaffLogin(_ raw: String) -> Bool {
        let login = normalizedStaffLogin(from: raw)
        return login.range(of: "^[a-z0-9][a-z0-9_-]{1,30}[a-z0-9]$", options: .regularExpression) != nil
    }

    /// Dérive le `staff_login` attendu par l’API (même règles que l’ancien `suggestedStaffLogin`).
    func normalizedStaffLogin(from name: String) -> String {
        var out = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[^a-z0-9_-]", with: "", options: .regularExpression)
        if out.count < 3 { out += "emp" }
        out = String(out.prefix(32))
        if let f = out.first, !f.isLetter && !f.isNumber {
            out = "e" + out
        }
        if out.isEmpty { out = "employe" }
        return out
    }

    func performRevoke() async {
        guard let rawId = pendingRevokeId else { return }
        showRevokeConfirmation = false
        pendingRevokeId = nil
        guard let slug else { return }
        let id = rawId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        revokeInFlight = true
        defer { revokeInFlight = false }
        do {
            let _: EmptyResponse = try await APIClient.shared.request(
                .businessTeamRevoke(slug: slug, membershipId: id),
                responseType: EmptyResponse.self
            )
            successMessage = "Accès retiré."
            await load()
        } catch let e as APIError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revokeableId(for member: WorkspaceTeamMemberDTO) -> String? {
        if let m = member.membershipId?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty { return m }
        if let u = member.userId?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty { return u }
        return nil
    }

    func canRevoke(_ member: WorkspaceTeamMemberDTO, currentUserEmail: String?, currentUserStaffLogin: String?) -> Bool {
        let r = (member.role ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if r == "owner" { return false }
        if let em = member.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           let cur = currentUserEmail?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !em.isEmpty, !cur.isEmpty, em == cur {
            return false
        }
        if let sl = member.staffLogin?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           let curS = currentUserStaffLogin?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !sl.isEmpty, !curS.isEmpty, sl == curS {
            return false
        }
        return revokeableId(for: member) != nil
    }
}

// MARK: - Vue

struct MerchantTeamManagementView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var model = MerchantTeamManagementViewModel()
    @State private var showAddEmployeePopup = false

    var body: some View {
        ZStack {
            GroupedSettingsMetrics.pageBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: GroupedSettingsMetrics.interCardSpacing) {
                    if let s = model.successMessage, !s.isEmpty {
                        Text(s)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color(UIColor.systemGreen).opacity(0.95))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(14)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    if let e = model.errorMessage, !e.isEmpty {
                        Text(e)
                            .font(.subheadline)
                            .foregroundStyle(Color(UIColor.label))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(14)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    GroupedSettingsCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Équipe")
                                .font(.headline)
                            Text("Ajoutez rapidement un employé, puis gérez les accès dans la liste ci-dessous.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                            if let err = model.staffFormError, !err.isEmpty {
                                Text(err)
                                    .font(.footnote)
                                    .foregroundStyle(Color(UIColor.systemRed))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
                        .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
                    }

                    GroupedSettingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Button {
                                model.staffFormError = nil
                                model.staffCreateLogin = ""
                                model.staffCreatePassword = ""
                                showAddEmployeePopup = true
                            } label: {
                                HStack {
                                    GroupedSettingsIconBox(systemName: "person.crop.circle.badge.plus")
                                    Text("+ Ajouter un employé")
                                        .font(.body.weight(.semibold))
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(model.staffCreateInFlight || model.isLoading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
                        .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
                    }

                    GroupedSettingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            if model.isLoading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("Mise à jour de la liste équipe…")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if model.members.isEmpty {
                                Text("Aucun membre d’équipe listé pour ce commerce.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(model.members) { m in
                                        teamRow(m)
                                        if m.id != model.members.last?.id {
                                            teamRowDivider
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
                        .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
                    }
                }
                .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Équipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(model.isLoading)
            }
        }
        .task {
            await model.load()
        }
        .confirmationDialog(
            "Retirer l’accès de cet utilisateur ?",
            isPresented: $model.showRevokeConfirmation,
            titleVisibility: .visible
        ) {
            Button("Retirer l’accès", role: .destructive) {
                Task { await model.performRevoke() }
            }
            Button("Annuler", role: .cancel) {
                model.pendingRevokeId = nil
            }
        }
        .alert("Ajouter un employé", isPresented: $showAddEmployeePopup) {
            TextField("Identifiant employé", text: $model.staffCreateLogin)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("Mot de passe employé", text: $model.staffCreatePassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Annuler", role: .cancel) {}
            Button("Créer") {
                Task { @MainActor in
                    await model.createStaffAccount(loginRaw: model.staffCreateLogin)
                }
            }
            .disabled(
                model.staffCreateInFlight
                    || model.staffCreateLogin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || !model.isValidStaffLogin(model.staffCreateLogin)
                    || model.staffCreatePassword.count < 3
            )
        } message: {
            Text("Utilisez 3 à 32 caractères pour l’identifiant (a-z, 0-9, _ et -), puis un mot de passe d’au moins 3 caractères.")
        }
    }

    private var teamRowDivider: some View {
        Divider()
            .padding(.vertical, 8)
    }

    @ViewBuilder
    private func teamRow(_ m: WorkspaceTeamMemberDTO) -> some View {
        let name = (m.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let email = (m.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let staff = (m.staffLogin ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let primary = teamMemberPrimaryLine(name: name, email: email, staff: staff)
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(primary)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(UIColor.label))
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                if !staff.isEmpty, primary.caseInsensitiveCompare(staff) != .orderedSame {
                    Text("Identifiant : \(staff)")
                        .font(.subheadline)
                        .foregroundStyle(Color(UIColor.secondaryLabel))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                if !email.isEmpty {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(Color(UIColor.secondaryLabel))
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                if let stats = teamMemberLoyaltyStatsLine(m) {
                    Text(stats)
                        .font(.caption)
                        .foregroundStyle(Color(UIColor.secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let roleLine = teamMemberRoleLine(m.role) {
                    Text(roleLine)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(UIColor.tertiaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            if let rid = model.revokeableId(for: m),
               model.canRevoke(m, currentUserEmail: authService.currentUserEmail, currentUserStaffLogin: authService.currentUserStaffLogin) {
                Button {
                    model.requestRevoke(id: rid)
                } label: {
                    Text("Retirer")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.revokeInFlight)
                .fixedSize(horizontal: true, vertical: true)
            }
        }
        .padding(.vertical, 6)
    }

    private func teamMemberPrimaryLine(name: String, email: String, staff: String) -> String {
        if !name.isEmpty { return name }
        if !staff.isEmpty { return staff }
        if !email.isEmpty { return email }
        return "Membre"
    }

    private func teamMemberLoyaltyStatsLine(_ m: WorkspaceTeamMemberDTO) -> String? {
        let add = m.pointsAddCount ?? 0
        let rede = m.rewardRedeemCount ?? 0
        let pts = m.pointsIssued ?? 0
        let eur = m.amountEurSum ?? 0
        if add == 0, rede == 0, pts == 0, eur == 0 { return nil }
        var parts: [String] = []
        if add > 0 { parts.append("\(add) crédit(s) caisse") }
        if rede > 0 { parts.append("\(rede) récompense(s)") }
        if pts > 0 { parts.append("\(pts) pts attribués") }
        if eur > 0 {
            let f = NumberFormatter()
            f.locale = Locale(identifier: "fr_FR")
            f.numberStyle = .decimal
            f.maximumFractionDigits = 2
            if let s = f.string(from: NSNumber(value: eur)) {
                parts.append("\(s) € (montants saisis)")
            }
        }
        guard !parts.isEmpty else { return nil }
        return "Fidélité : " + parts.joined(separator: " · ")
    }

    private func teamMemberRoleLine(_ role: String?) -> String? {
        let r = (role ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !r.isEmpty else { return nil }
        switch r {
        case "owner": return "Rôle : propriétaire"
        case "manager": return "Rôle : gérant"
        case "staff": return "Rôle : employé"
        default: return "Rôle : \(r)"
        }
    }

}

#Preview {
    NavigationStack {
        MerchantTeamManagementView()
    }
    .environmentObject(AuthService())
}
