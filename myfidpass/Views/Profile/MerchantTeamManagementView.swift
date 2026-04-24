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
    @Published var inviteInFlight = false
    @Published var revokeInFlight = false
    @Published var showRevokeConfirmation = false
    @Published var pendingRevokeId: String?
    @Published var showInviteSheet = false
    @Published var inviteEmail = ""
    @Published var inviteName = ""

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
            if case .notFound = e {
                errorMessage = "Service équipe indisponible (404). Déployez l’API `GET .../dashboard/team` (voir le contrat d’intégration)."
            } else {
                errorMessage = e.errorDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendInvite() async {
        let trimmed = inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@") else {
            errorMessage = "E-mail invalide."
            return
        }
        guard let slug else { return }
        let nameTrim = inviteName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name: String? = nameTrim.isEmpty ? nil : nameTrim
        errorMessage = nil
        successMessage = nil
        inviteInFlight = true
        defer { inviteInFlight = false }
        do {
            let body = WorkspaceTeamInviteBody(email: trimmed, name: name, role: "staff")
            let r: WorkspaceTeamInviteResponse = try await APIClient.shared.request(
                .businessTeamInvite(slug: slug, body: body)
            )
            if r.ok == false {
                errorMessage = r.message ?? "Invitation refusée."
            } else {
                if r.emailSent == true {
                    successMessage = (r.message?.isEmpty == false) ? (r.message ?? "") : "Accès activé. Un e-mail d’information a été envoyé à l’adresse indiquée."
                } else if r.emailSent == false {
                    successMessage = (r.message?.isEmpty == false)
                        ? "\(r.message ?? "") (e-mail non envoyé : vérifiez Resend/SMTP sur le serveur.)"
                        : "Accès activé. Aucun e-mail n’a pu être envoyé (configuration serveur) — l’employé verra le commerce après connexion."
                } else {
                    successMessage = (r.message?.isEmpty == false) ? (r.message ?? "") : "Invitation enregistrée. L’employé verra le commerce après connexion."
                }
                showInviteSheet = false
                inviteEmail = ""
                inviteName = ""
            }
            await load()
        } catch let e as APIError {
            errorMessage = e.errorDescription
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

    func canRevoke(_ member: WorkspaceTeamMemberDTO, currentUserEmail: String?) -> Bool {
        let r = (member.role ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if r == "owner" { return false }
        if let em = member.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           let cur = currentUserEmail?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !em.isEmpty, !cur.isEmpty, em == cur {
            return false
        }
        return revokeableId(for: member) != nil
    }
}

// MARK: - Vue

struct MerchantTeamManagementView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var model = MerchantTeamManagementViewModel()

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
                            .padding(14)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    if let e = model.errorMessage, !e.isEmpty {
                        Text(e)
                            .font(.subheadline)
                            .foregroundStyle(Color(UIColor.label))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    GroupedSettingsCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Inviter un employé")
                                .font(.headline)
                            Text(
                                "Un employé a un compte distinct avec le rôle « employé » : scan, points et dernières transactions, sans personnalisation de la carte ni campagnes. Le compte reçoit `workspace_role: staff` sur GET /me."
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    GroupedSettingsCard {
                        Button {
                            model.showInviteSheet = true
                        } label: {
                            HStack {
                                GroupedSettingsIconBox(systemName: "person.badge.plus")
                                Text("Inviter par e-mail")
                                    .font(.body.weight(.semibold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(model.inviteInFlight || model.isLoading)
                    }

                    if model.isLoading && model.members.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 24)
                    } else {
                        GroupedSettingsCard {
                            if model.members.isEmpty {
                                Text("Aucun membre d’équipe listé. Vérifiez que l’API renvoie des entrées, ou invitéz un collaborateur ci-dessus.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(model.members) { m in
                                        teamRow(m)
                                        if m.id != model.members.last?.id {
                                            GroupedSettingsRowDivider()
                                        }
                                    }
                                }
                            }
                        }
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
        .sheet(isPresented: $model.showInviteSheet) {
            inviteSheet
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
    }

    @ViewBuilder
    private func teamRow(_ m: WorkspaceTeamMemberDTO) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text((m.name?.isEmpty == false) ? (m.name ?? "—") : (m.email ?? "Utilisateur"))
                    .font(.body.weight(.semibold))
                if let e = m.email, !e.isEmpty {
                    Text(e)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let r = m.role, !r.isEmpty {
                    Text("Rôle : \(r)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 8)
            if let rid = model.revokeableId(for: m), model.canRevoke(m, currentUserEmail: authService.currentUserEmail) {
                Button {
                    model.requestRevoke(id: rid)
                } label: {
                    Text("Retirer")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.revokeInFlight)
            }
        }
        .padding(.vertical, 4)
    }

    private var inviteSheet: some View {
        NavigationStack {
            List {
                Section {
                    TextField("E-mail", text: $model.inviteEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    TextField("Prénom (optionnel)", text: $model.inviteName)
                } header: {
                    Text("L’API envoie l’e-mail d’invitation (selon configuration serveur).")
                }
            }
            .navigationTitle("Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { model.showInviteSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if model.inviteInFlight {
                        ProgressView()
                    } else {
                        Button("Envoyer") {
                            Task { await model.sendInvite() }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MerchantTeamManagementView()
    }
    .environmentObject(AuthService())
}
