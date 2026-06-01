//
//  MerchantTeamManagementView.swift
//  myfidpass
//
//  Gestion d'équipe : vue d'ensemble, stats, fiches employés.
//

import SwiftUI
import Combine

@MainActor
final class MerchantTeamManagementViewModel: ObservableObject {
    @Published private(set) var members: [WorkspaceTeamMemberDTO] = []
    @Published private(set) var teamTotals: WorkspaceTeamTotalsDTO?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var staffCreateInFlight = false
    @Published var staffFormError: String?
    @Published var staffCreateEmail = ""
    @Published var staffCreateName = ""
    @Published var staffCreateRole = "staff"

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
            teamTotals = r.teamTotals
        } catch let e as APIError {
            if e.isHTTPResourceMissing {
                errorMessage = "Service équipe indisponible. Mettez l'API à jour puis réessayez."
            } else {
                errorMessage = TeamAPIError.message(from: e)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createStaffAccount(emailRaw: String, nameRaw: String?, role: String) async {
        staffFormError = nil
        let email = emailRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard MerchantOnboardingEmailValidation.isValid(email) else {
            staffFormError = "Saisissez une adresse e-mail valide."
            return
        }
        guard let slug else {
            staffFormError = "Aucun commerce sélectionné."
            return
        }
        errorMessage = nil
        successMessage = nil
        staffCreateInFlight = true
        defer { staffCreateInFlight = false }
        do {
            let trimmedName = nameRaw?.trimmingCharacters(in: .whitespacesAndNewlines)
            let roleNorm = role.lowercased() == "manager" ? "manager" : "staff"
            let body = WorkspaceTeamStaffAccountBody(
                email: email,
                name: (trimmedName?.isEmpty == false) ? trimmedName : nil,
                role: roleNorm
            )
            let r: WorkspaceTeamStaffAccountResponse = try await APIClient.shared.request(
                .businessTeamStaffAccount(slug: slug, body: body)
            )
            if r.ok == false {
                staffFormError = r.message ?? "Création refusée."
            } else {
                if r.emailSent == false, let err = r.emailError, !err.isEmpty {
                    staffFormError = err
                    successMessage = r.message ?? "Employé ajouté, mais l'e-mail n'a pas pu être envoyé."
                } else {
                    staffFormError = nil
                    successMessage = r.message
                        ?? (r.emailSent == false
                            ? "Employé ajouté. Il peut se connecter depuis l'app avec son e-mail."
                            : "Employé ajouté. Un e-mail d'invitation avec le lien de téléchargement a été envoyé.")
                }
                staffCreateEmail = ""
                staffCreateName = ""
                staffCreateRole = "staff"
            }
            await load()
        } catch let e as APIError {
            staffFormError = TeamAPIError.message(from: e)
        } catch {
            staffFormError = error.localizedDescription
        }
    }

    func canRevoke(_ member: WorkspaceTeamMemberDTO, currentUserEmail: String?, currentUserStaffLogin: String?) -> Bool {
        if member.isOwner { return false }
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
        return member.apiMemberId != nil
    }
}

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
                        TeamBanner(text: s, isError: false)
                    }
                    if let e = model.errorMessage, !e.isEmpty {
                        TeamBanner(text: e, isError: true)
                    }

                    overviewCard

                    GroupedSettingsCard {
                        Button {
                            model.staffFormError = nil
                            model.staffCreateEmail = ""
                            model.staffCreateName = ""
                            model.staffCreateRole = "staff"
                            showAddEmployeePopup = true
                        } label: {
                            HStack {
                                GroupedSettingsIconBox(systemName: "person.crop.circle.badge.plus")
                                Text("Ajouter un employé")
                                    .font(.body.weight(.semibold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                            }
                            .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
                            .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
                        }
                        .buttonStyle(.plain)
                        .disabled(model.staffCreateInFlight || model.isLoading)
                    }

                    membersCard
                }
                .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
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
        .task { await model.load() }
        .sheet(isPresented: $showAddEmployeePopup) {
            addEmployeeSheet
        }
    }

    private var overviewCard: some View {
        GroupedSettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Vue d'ensemble")
                    .font(.headline)
                Text("Suivez l'activité caisse de chaque membre : scans, crédits de points et récompenses.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let t = model.teamTotals {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        TeamStatTile(title: "Employés", value: "\(t.memberCount ?? employeeCount)", icon: "person.2")
                        TeamStatTile(title: "Scans (30 j)", value: "\(t.scans30d ?? 0)", icon: "qrcode.viewfinder")
                        TeamStatTile(title: "Scans (7 j)", value: "\(t.scans7d ?? 0)", icon: "calendar")
                        TeamStatTile(title: "Scans total", value: "\(t.scanCount ?? 0)", icon: "chart.bar")
                    }
                } else if model.isLoading {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
            .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
        }
    }

    private var employeeCount: Int {
        model.members.filter { !$0.isOwner }.count
    }

    private var membersCard: some View {
        GroupedSettingsCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Membres")
                        .font(.headline)
                    Spacer()
                    if model.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(.bottom, 12)

                if model.members.isEmpty, !model.isLoading {
                    Text("Aucun membre pour ce commerce.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.members) { member in
                        memberRow(member)
                        if member.id != model.members.last?.id {
                            GroupedSettingsRowDivider()
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
            .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
        }
    }

    @ViewBuilder
    private func memberRow(_ member: WorkspaceTeamMemberDTO) -> some View {
        if let apiId = member.apiMemberId {
            NavigationLink {
                MerchantTeamMemberDetailView(memberId: apiId, initialMember: member) {
                    Task { await model.load() }
                }
            } label: {
                memberRowContent(member)
            }
        } else {
            memberRowContent(member)
        }
    }

    private func memberRowContent(_ member: WorkspaceTeamMemberDTO) -> some View {
        HStack(alignment: .center, spacing: 12) {
            TeamMemberAvatar(name: member.displayName, role: member.role)
            VStack(alignment: .leading, spacing: 4) {
                Text(member.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(UIColor.label))
                Text(TeamFormatting.roleLabel(member.role))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                if let scans = member.scanCount, scans > 0 {
                    Text("\(scans) scan\(scans > 1 ? "s" : "") · \(member.scans7d ?? 0) cette semaine")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Aucune activité caisse")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if member.apiMemberId != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var addEmployeeSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("E-mail employé", text: $model.staffCreateEmail)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                    TextField("Prénom ou nom (optionnel)", text: $model.staffCreateName)
                        .textInputAutocapitalization(.words)
                    Picker("Rôle", selection: $model.staffCreateRole) {
                        Text("Employé").tag("staff")
                        Text("Gérant").tag("manager")
                    }
                } footer: {
                    Text("L'employé recevra un e-mail d'invitation avec les liens App Store et Google Play. Connexion par e-mail uniquement (code envoyé à la demande).")
                }
                if let err = model.staffFormError, !err.isEmpty {
                    Section {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Ajouter un employé")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { showAddEmployeePopup = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Inviter") {
                        Task {
                            await model.createStaffAccount(
                                emailRaw: model.staffCreateEmail,
                                nameRaw: model.staffCreateName,
                                role: model.staffCreateRole
                            )
                            if model.staffFormError == nil, model.successMessage != nil {
                                showAddEmployeePopup = false
                            }
                        }
                    }
                    .disabled(
                        model.staffCreateInFlight
                            || !MerchantOnboardingEmailValidation.isValid(
                                model.staffCreateEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            )
                    )
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    NavigationStack {
        MerchantTeamManagementView()
    }
    .environmentObject(AuthService())
}
