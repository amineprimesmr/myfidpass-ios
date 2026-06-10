//
//  LoyaltyNetworkSettingsView.swift
//  myfidpass
//
//  Réseau fidélité : regrouper plusieurs adresses (ex. NBK Nord + Sud) — une carte, un solde.
//

import SwiftUI
import Combine

@MainActor
final class LoyaltyNetworkSettingsViewModel: ObservableObject {
    @Published private(set) var groups: [LoyaltyGroupSummaryDTO] = []
    @Published private(set) var selectedDetail: LoyaltyGroupDetailResponse?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var newGroupName = ""
    @Published var createInFlight = false
    @Published private(set) var businesses: [BusinessDTO] = []

    var ownedBusinesses: [BusinessDTO] {
        businesses.filter { !$0.id.hasPrefix("pending-") }
    }

    var unlinkedBusinesses: [BusinessDTO] {
        ownedBusinesses.filter { !$0.isInLoyaltyNetwork }
    }

    func refreshBusinesses() async {
        do {
            let me: AuthMeResponse = try await APIClient.shared.request(.authMe)
            businesses = me.businesses
        } catch {
            // Non bloquant : la liste réseau reste utilisable.
        }
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        await refreshBusinesses()
        do {
            let r: LoyaltyGroupsListResponse = try await APIClient.shared.request(.loyaltyGroupsList)
            groups = r.loyaltyGroups
            if let first = groups.first {
                await loadDetail(id: first.id)
            } else {
                selectedDetail = nil
            }
        } catch let e as APIError {
            errorMessage = e.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadDetail(id: String) async {
        do {
            let r: LoyaltyGroupDetailResponse = try await APIClient.shared.request(.loyaltyGroupDetail(id: id))
            selectedDetail = r
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createGroup(linkBusinessIds: [String]) async {
        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count >= 2 else {
            errorMessage = "Donnez un nom au réseau (ex. « NBK »)."
            return
        }
        createInFlight = true
        errorMessage = nil
        successMessage = nil
        defer { createInFlight = false }
        do {
            let body = LoyaltyGroupCreateBody(
                name: name,
                businessIds: linkBusinessIds.isEmpty ? nil : linkBusinessIds
            )
            let r: LoyaltyGroupCreateResponse = try await APIClient.shared.request(.loyaltyGroupsCreate(body: body))
            newGroupName = ""
            successMessage = "Réseau « \(r.loyaltyGroup.name) » créé."
            await refreshBusinesses()
            await load()
            await loadDetail(id: r.loyaltyGroup.id)
        } catch let e as APIError {
            errorMessage = e.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func linkBusiness(groupId: String, business: BusinessDTO) async {
        errorMessage = nil
        successMessage = nil
        do {
            let body = LoyaltyGroupLinkBusinessBody(businessId: business.id, slug: nil)
            let _: LoyaltyGroupLinkBusinessResponse = try await APIClient.shared.request(
                .loyaltyGroupLinkBusiness(groupId: groupId, body: body)
            )
            successMessage = "« \(business.name) » ajouté au réseau."
            await refreshBusinesses()
            await loadDetail(id: groupId)
            await load()
        } catch let e as APIError {
            errorMessage = e.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unlinkBusiness(groupId: String, business: LoyaltyGroupBusinessLinkDTO) async {
        errorMessage = nil
        successMessage = nil
        do {
            let _: LoyaltyGroupOkResponse = try await APIClient.shared.request(
                .loyaltyGroupUnlinkBusiness(groupId: groupId, businessId: business.id)
            )
            successMessage = "« \(business.name) » retiré du réseau."
            await refreshBusinesses()
            await loadDetail(id: groupId)
            await load()
        } catch let e as APIError {
            errorMessage = e.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteGroup(id: String) async {
        errorMessage = nil
        do {
            let _: LoyaltyGroupOkResponse = try await APIClient.shared.request(.loyaltyGroupDelete(id: id))
            successMessage = "Réseau supprimé."
            selectedDetail = nil
            await refreshBusinesses()
            await load()
        } catch let e as APIError {
            errorMessage = e.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct LoyaltyNetworkSettingsView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var viewModel = LoyaltyNetworkSettingsViewModel()
    @State private var showCreateSheet = false
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GroupedSettingsMetrics.interCardSpacing) {
                introCard

                if let msg = viewModel.successMessage {
                    statusBanner(msg, tint: AppTheme.Colors.primary)
                }
                if let err = viewModel.errorMessage {
                    statusBanner(err, tint: .red)
                }

                if viewModel.isLoading && viewModel.groups.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if let detail = viewModel.selectedDetail {
                    activeNetworkCard(detail)
                } else {
                    createPromptCard
                }
            }
            .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(GroupedSettingsMetrics.pageBackground.ignoresSafeArea())
        .navigationTitle("Réseau fidélité")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.load()
            _ = await authService.refreshMerchantBillingStateFromServer(force: true)
        }
        .sheet(isPresented: $showCreateSheet) {
            createNetworkSheet
        }
        .alert("Supprimer ce réseau ?", isPresented: $confirmDelete) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                if let id = viewModel.selectedDetail?.loyaltyGroup.id {
                    Task { await viewModel.deleteGroup(id: id) }
                }
            }
        } message: {
            Text("Les commerces redeviennent indépendants. Les cartes clients existantes restent valides localement.")
        }
    }

    private var introCard: some View {
        GroupedSettingsCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Carte partagée")
                    .font(.headline)
                Text(
                    "Liez plusieurs adresses d’une même enseigne (ex. NBK Nord et NBK Sud) : vos clients gardent une seule carte et un seul solde, utilisable dans tous les points du réseau."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func activeNetworkCard(_ detail: LoyaltyGroupDetailResponse) -> some View {
        GroupedSettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(detail.loyaltyGroup.name)
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Text("\(detail.businesses.count) adresse\(detail.businesses.count > 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if detail.businesses.isEmpty {
                    Text("Aucun commerce lié pour l’instant.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(detail.businesses) { biz in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(biz.organizationName?.isEmpty == false ? biz.organizationName! : biz.name)
                                    .font(.body.weight(.medium))
                                Text(biz.slug)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if detail.businesses.count > 1 {
                                Button("Retirer") {
                                    Task { await viewModel.unlinkBusiness(groupId: detail.loyaltyGroup.id, business: biz) }
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                            }
                        }
                        if biz.id != detail.businesses.last?.id {
                            GroupedSettingsRowDivider()
                        }
                    }
                }

                if !viewModel.unlinkedBusinesses.isEmpty {
                    GroupedSettingsRowDivider()
                    Text("Ajouter une adresse")
                        .font(.subheadline.weight(.semibold))
                    ForEach(viewModel.unlinkedBusinesses, id: \.id) { biz in
                        Button {
                            Task { await viewModel.linkBusiness(groupId: detail.loyaltyGroup.id, business: biz) }
                        } label: {
                            HStack {
                                Text(biz.name)
                                    .foregroundStyle(Color(UIColor.label))
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(AppTheme.Colors.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                GroupedSettingsRowDivider()
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Text("Supprimer le réseau")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }

        if viewModel.groups.count > 1 {
            GroupedSettingsSectionLabel("Autres réseaux")
            ForEach(viewModel.groups.filter { $0.id != detail.loyaltyGroup.id }) { g in
                GroupedSettingsCard {
                    Button {
                        Task { await viewModel.loadDetail(id: g.id) }
                    } label: {
                        HStack {
                            Text(g.name)
                            Spacer()
                            Text("\(g.businessCount ?? 0)")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var createPromptCard: some View {
        GroupedSettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Aucun réseau actif")
                    .font(.headline)
                Text("Créez un réseau pour partager la fidélité entre vos adresses.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    showCreateSheet = true
                } label: {
                    Text("Créer un réseau")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.Colors.primary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.ownedBusinesses.count < 2)
                if viewModel.ownedBusinesses.count < 2 {
                    Text("Ajoutez au moins deux adresses pour activer un réseau.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var createNetworkSheet: some View {
        NavigationStack {
            Form {
                Section("Nom du réseau") {
                    TextField("Ex. NBK, Chicken Street…", text: $viewModel.newGroupName)
                        .textInputAutocapitalization(.words)
                }
                if viewModel.ownedBusinesses.count >= 2 {
                    Section {
                        ForEach(viewModel.ownedBusinesses, id: \.id) { biz in
                            Text(biz.name)
                        }
                    } header: {
                        Text("Adresses à regrouper")
                    } footer: {
                        Text("Toutes vos adresses seront liées. Vous pourrez en retirer une plus tard.")
                    }
                }
            }
            .navigationTitle("Nouveau réseau")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { showCreateSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        let ids = viewModel.ownedBusinesses.map(\.id)
                        Task {
                            await viewModel.createGroup(linkBusinessIds: ids)
                            if viewModel.errorMessage == nil {
                                showCreateSheet = false
                                _ = await authService.refreshMerchantBillingStateFromServer(force: true)
                            }
                        }
                    }
                    .disabled(viewModel.createInFlight || viewModel.newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func statusBanner(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
