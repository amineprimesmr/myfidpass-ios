//
//  MerchantTeamMemberDetailView.swift
//  myfidpass
//
//  Fiche employé : stats caisse, activité récente, gestion du compte.
//

import SwiftUI
import Combine

@MainActor
final class MerchantTeamMemberDetailViewModel: ObservableObject {
    @Published private(set) var member: WorkspaceTeamMemberDTO?
    @Published private(set) var activity: [WorkspaceTeamActivityDTO] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var actionInFlight = false

    let memberId: String

    init(memberId: String, initialMember: WorkspaceTeamMemberDTO? = nil) {
        self.memberId = memberId
        self.member = initialMember
    }

    private var slug: String? {
        let s = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return s.isEmpty ? nil : s
    }

    func load() async {
        guard let slug else {
            errorMessage = "Aucun commerce sélectionné."
            return
        }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let r: WorkspaceTeamMemberDetailResponse = try await APIClient.shared.request(
                .businessTeamMemberDetail(slug: slug, memberId: memberId)
            )
            member = r.member
            activity = r.recentActivity
        } catch let e as APIError {
            errorMessage = TeamAPIError.message(from: e)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateRole(_ role: String) async {
        guard let slug, let current = member, !current.isOwner else { return }
        actionInFlight = true
        defer { actionInFlight = false }
        errorMessage = nil
        successMessage = nil
        do {
            let body = WorkspaceTeamMemberPatchBody(name: nil, role: role)
            let r: WorkspaceTeamMemberPatchResponse = try await APIClient.shared.request(
                .businessTeamMemberPatch(slug: slug, memberId: memberId, body: body)
            )
            if let updated = r.member { self.member = updated }
            successMessage = role == "manager" ? "Rôle mis à jour : gérant." : "Rôle mis à jour : employé."
            await load()
        } catch let e as APIError {
            errorMessage = TeamAPIError.message(from: e)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateName(_ name: String) async {
        guard let slug, let current = member, !current.isOwner else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Le nom ne peut pas être vide."
            return
        }
        actionInFlight = true
        defer { actionInFlight = false }
        errorMessage = nil
        successMessage = nil
        do {
            let body = WorkspaceTeamMemberPatchBody(name: trimmed, role: nil)
            let r: WorkspaceTeamMemberPatchResponse = try await APIClient.shared.request(
                .businessTeamMemberPatch(slug: slug, memberId: memberId, body: body)
            )
            if let updated = r.member { self.member = updated }
            successMessage = "Nom mis à jour."
            await load()
        } catch let e as APIError {
            errorMessage = TeamAPIError.message(from: e)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resendAccessEmail() async {
        guard let slug, let current = member, !current.isOwner else { return }
        actionInFlight = true
        defer { actionInFlight = false }
        errorMessage = nil
        successMessage = nil
        do {
            let r: WorkspaceTeamResendAccessResponse = try await APIClient.shared.request(
                .businessTeamMemberResendAccess(slug: slug, memberId: memberId)
            )
            successMessage = r.message ?? (r.emailSent == true ? "E-mail d'invitation envoyé." : "E-mail non envoyé.")
        } catch let e as APIError {
            errorMessage = TeamAPIError.message(from: e)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct MerchantTeamMemberDetailView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: MerchantTeamMemberDetailViewModel
    @State private var showRenameAlert = false
    @State private var renameDraft = ""
    @State private var showRevokeConfirmation = false
    @State private var revokeInFlight = false
    var onRevoked: (() -> Void)?

    init(memberId: String, initialMember: WorkspaceTeamMemberDTO? = nil, onRevoked: (() -> Void)? = nil) {
        _model = StateObject(wrappedValue: MerchantTeamMemberDetailViewModel(memberId: memberId, initialMember: initialMember))
        self.onRevoked = onRevoked
    }

    var body: some View {
        ZStack {
            GroupedSettingsMetrics.pageBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: GroupedSettingsMetrics.interCardSpacing) {
                    bannerMessages
                    if model.isLoading && model.member == nil {
                        ProgressView("Chargement…")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if let m = model.member {
                        profileCard(m)
                        statsCard(m)
                        if !model.activity.isEmpty {
                            activityCard
                        }
                        if !m.isOwner {
                            managementCard(m)
                        }
                    }
                }
                .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(model.member?.displayName ?? "Employé")
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
        .task { await model.load() }
        .alert("Modifier le nom", isPresented: $showRenameAlert) {
            TextField("Nom affiché", text: $renameDraft)
            Button("Annuler", role: .cancel) {}
            Button("Enregistrer") {
                Task { await model.updateName(renameDraft) }
            }
        }
        .confirmationDialog(
            "Retirer l'accès de cet employé ?",
            isPresented: $showRevokeConfirmation,
            titleVisibility: .visible
        ) {
            Button("Retirer l'accès", role: .destructive) {
                Task { await performRevoke() }
            }
            Button("Annuler", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var bannerMessages: some View {
        if let s = model.successMessage, !s.isEmpty {
            TeamBanner(text: s, isError: false)
        }
        if let e = model.errorMessage, !e.isEmpty {
            TeamBanner(text: e, isError: true)
        }
    }

    private func profileCard(_ m: WorkspaceTeamMemberDTO) -> some View {
        GroupedSettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    TeamMemberAvatar(name: m.displayName, role: m.role)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(m.displayName)
                            .font(.title3.weight(.semibold))
                        Text(TeamFormatting.roleLabel(m.role))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                if let email = m.email, !email.isEmpty {
                    labeledRow("E-mail", value: email)
                }
                if let staff = m.staffLogin, !staff.isEmpty {
                    labeledRow("Identifiant", value: staff)
                }
                if let created = TeamFormatting.formatDate(m.createdAt) {
                    labeledRow("Ajouté le", value: created)
                }
                if let inv = m.invitedByLabel, !inv.isEmpty {
                    labeledRow("Invité par", value: inv)
                }
                if let last = TeamFormatting.formatRelative(m.lastActivityAt) {
                    labeledRow("Dernière activité", value: last)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
            .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
        }
    }

    private func statsCard(_ m: WorkspaceTeamMemberDTO) -> some View {
        GroupedSettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Activité caisse")
                    .font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    TeamStatTile(title: "Scans total", value: "\(m.scanCount ?? 0)", icon: "qrcode.viewfinder")
                    TeamStatTile(title: "7 jours", value: "\(m.scans7d ?? 0)", icon: "calendar")
                    TeamStatTile(title: "30 jours", value: "\(m.scans30d ?? 0)", icon: "calendar.badge.clock")
                    TeamStatTile(title: "Crédits pts", value: "\(m.pointsAddCount ?? 0)", icon: "plus.circle")
                    TeamStatTile(title: "Récompenses", value: "\(m.rewardRedeemCount ?? 0)", icon: "gift")
                    TeamStatTile(title: "Points attribués", value: "\(m.pointsIssued ?? 0)", icon: "star")
                }
                if let eur = m.amountEurSum, eur > 0 {
                    Text("Montants saisis : \(TeamFormatting.formatEuro(eur))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
            .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
        }
    }

    private var activityCard: some View {
        GroupedSettingsCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("Activité récente")
                    .font(.headline)
                    .padding(.bottom, 12)
                ForEach(model.activity) { row in
                    activityRow(row)
                    if row.id != model.activity.last?.id {
                        GroupedSettingsRowDivider()
                            .padding(.vertical, 8)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
            .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
        }
    }

    private func managementCard(_ m: WorkspaceTeamMemberDTO) -> some View {
        GroupedSettingsCard {
            VStack(spacing: 0) {
                if canManageMember(m) {
                    Button {
                        renameDraft = m.name ?? ""
                        showRenameAlert = true
                    } label: {
                        GroupedSettingsNavigationRow(icon: "pencil", title: "Modifier le nom", showsChevron: false)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.actionInFlight)
                    GroupedSettingsRowDivider()

                    Menu {
                        Button("Employé") { Task { await model.updateRole("staff") } }
                        Button("Gérant") { Task { await model.updateRole("manager") } }
                    } label: {
                        GroupedSettingsNavigationRow(
                            icon: "person.badge.key",
                            title: "Changer le rôle",
                            value: TeamFormatting.roleLabel(m.role),
                            showsChevron: true
                        )
                    }
                    .disabled(model.actionInFlight)
                    GroupedSettingsRowDivider()

                    if m.email != nil {
                        Button {
                            Task { await model.resendAccessEmail() }
                        } label: {
                            GroupedSettingsNavigationRow(icon: "envelope.badge", title: "Renvoyer l'e-mail d'invitation", showsChevron: false)
                        }
                        .buttonStyle(.plain)
                        .disabled(model.actionInFlight)
                        GroupedSettingsRowDivider()
                    }
                }

                if canRevoke(m) {
                    Button {
                        showRevokeConfirmation = true
                    } label: {
                        HStack(spacing: 12) {
                            GroupedSettingsIconBox(systemName: "person.crop.circle.badge.minus", destructive: true)
                            Text("Retirer l'accès")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color(UIColor.systemRed))
                            Spacer()
                        }
                        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
                        .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
                    }
                    .buttonStyle(.plain)
                    .disabled(revokeInFlight || model.actionInFlight)
                }
            }
        }
    }

    private func labeledRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private func activityRow(_ row: WorkspaceTeamActivityDTO) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: TeamFormatting.activityIcon(row.type))
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(TeamFormatting.activityLabel(row))
                    .font(.subheadline.weight(.medium))
                if let client = row.memberName, !client.isEmpty {
                    Text(client)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let when = TeamFormatting.formatRelative(row.createdAt) {
                    Text(when)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func canManageMember(_ m: WorkspaceTeamMemberDTO) -> Bool {
        authService.canManageMerchantTeam && !m.isOwner
    }

    private func canRevoke(_ m: WorkspaceTeamMemberDTO) -> Bool {
        guard authService.canManageMerchantTeam, !m.isOwner else { return false }
        if let em = m.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           let cur = authService.currentUserEmail?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !em.isEmpty, !cur.isEmpty, em == cur { return false }
        return m.apiMemberId != nil
    }

    private func performRevoke() async {
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            model.errorMessage = "Aucun commerce sélectionné."
            return
        }
        revokeInFlight = true
        defer { revokeInFlight = false }
        do {
            let _: EmptyResponse = try await APIClient.shared.request(
                .businessTeamRevoke(slug: slug, membershipId: model.memberId),
                responseType: EmptyResponse.self
            )
            onRevoked?()
            dismiss()
        } catch let e as APIError {
            model.errorMessage = TeamAPIError.message(from: e)
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Composants partagés équipe

enum TeamAPIError {
    static func message(from error: APIError) -> String? {
        switch error {
        case .server(let code, let msg):
            if code == 404 { return msg ?? "Employé introuvable ou accès déjà retiré." }
            if code == 400 { return msg ?? "Action impossible." }
            if code == 403 { return msg ?? "Action réservée au responsable du commerce." }
            return msg ?? error.errorDescription
        default:
            return error.errorDescription
        }
    }
}

enum TeamFormatting {
    static func roleLabel(_ role: String?) -> String {
        switch (role ?? "").lowercased() {
        case "owner": return "Propriétaire"
        case "manager": return "Gérant"
        case "staff": return "Employé"
        default: return role ?? "—"
        }
    }

    static func formatEuro(_ value: Double) -> String {
        "\(StatsFR.formatTransactionEuro(value)) €"
    }

    static func formatDate(_ iso: String?) -> String? {
        guard let iso, !iso.isEmpty else { return nil }
        let parsers: [ISO8601DateFormatter] = {
            let f1 = ISO8601DateFormatter()
            f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime]
            return [f1, f2]
        }()
        for p in parsers {
            if let d = p.date(from: iso) {
                let out = DateFormatter()
                out.locale = Locale(identifier: "fr_FR")
                out.dateStyle = .medium
                out.timeStyle = .none
                return out.string(from: d)
            }
        }
        if iso.count >= 10 { return String(iso.prefix(10)) }
        return iso
    }

    static func formatRelative(_ iso: String?) -> String? {
        guard let iso, !iso.isEmpty else { return nil }
        let parsers: [ISO8601DateFormatter] = {
            let f1 = ISO8601DateFormatter()
            f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime]
            return [f1, f2]
        }()
        var date: Date?
        for p in parsers { date = p.date(from: iso); if date != nil { break } }
        if date == nil, iso.count >= 19 {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd HH:mm:ss"
            date = f.date(from: String(iso.prefix(19)))
        }
        guard let date else { return formatDate(iso) }
        let rel = RelativeDateTimeFormatter()
        rel.locale = Locale(identifier: "fr_FR")
        rel.unitsStyle = .short
        return rel.localizedString(for: date, relativeTo: Date())
    }

    static func activityIcon(_ type: String?) -> String {
        switch (type ?? "").lowercased() {
        case "points_add": return "plus.circle"
        case "reward_redeem": return "gift"
        case "points_correction": return "arrow.triangle.2.circlepath"
        default: return "doc.text"
        }
    }

    static func activityLabel(_ row: WorkspaceTeamActivityDTO) -> String {
        switch (row.type ?? "").lowercased() {
        case "points_add":
            var s = "Crédit de points"
            if let p = row.points, p != 0 { s += " (+\(p))" }
            if let e = row.amountEur, e > 0 { s += " · \(formatEuro(e))" }
            return s
        case "reward_redeem":
            return "Récompense utilisée"
        case "points_correction":
            return "Correction de points"
        default:
            return row.type ?? "Opération caisse"
        }
    }
}

struct TeamBanner: View {
    let text: String
    var isError: Bool

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isError ? Color(UIColor.systemRed) : Color(UIColor.systemGreen).opacity(0.95))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct TeamStatTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct TeamMemberAvatar: View {
    let name: String
    let role: String?

    var body: some View {
        ZStack {
            Circle()
                .fill(avatarColor.opacity(0.18))
                .frame(width: 48, height: 48)
            Text(initials)
                .font(.headline.weight(.semibold))
                .foregroundStyle(avatarColor)
        }
    }

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }
        if parts.isEmpty { return "?" }
        return parts.joined().uppercased()
    }

    private var avatarColor: Color {
        switch (role ?? "").lowercased() {
        case "owner": return .orange
        case "manager": return .blue
        default: return .green
        }
    }
}
