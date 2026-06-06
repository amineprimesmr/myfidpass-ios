//
//  MembersListView.swift
//  myfidpass
//
//  Liste des membres avec recherche. Accessible depuis « Cartes actives » sur le tableau de bord.
//

import SwiftUI
import CoreData

struct MembersListView: View {
    @EnvironmentObject private var syncService: SyncService
    @StateObject private var dataService: DataService
    @State private var searchText = ""
    @State private var showDeleteAllConfirm = false
    @State private var isDeletingAll = false
    @State private var deleteAllError: String?
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        _dataService = StateObject(wrappedValue: DataService(context: context))
        self.context = context
    }

    private var template: CardTemplate? { dataService.currentCardTemplate() }
    private var allMembers: [ClientCard] {
        guard let t = template else { return [] }
        return dataService.uniqueClientCards(for: t).filter {
            !WalletPreviewMember.shouldExcludeFromMerchantActivity(clientEmail: $0.clientEmail)
        }
    }
    private var filteredMembers: [ClientCard] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return allMembers }
        return allMembers.filter {
            (($0.clientDisplayName ?? "").lowercased().contains(q)) ||
            (($0.clientEmail ?? "").lowercased().contains(q)) ||
            (($0.qrCodeValue ?? "").lowercased().contains(q))
        }
    }

    var body: some View {
        Group {
            if allMembers.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filteredMembers, id: \.objectID) { card in
                        NavigationLink {
                            MemberDetailView(card: card, context: context)
                                .environmentObject(syncService)
                                .environmentObject(dataService)
                        } label: {
                            MemberListRow(card: card)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(text: $searchText, prompt: "Nom, email ou identifiant…")
            }
        }
        .navigationTitle("Membres")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                if !allMembers.isEmpty {
                    Button {
                        showDeleteAllConfirm = true
                    } label: {
                        Label("Tout supprimer", systemImage: "person.crop.circle.badge.minus")
                    }
                    .disabled(isDeletingAll)
                }
            }
        }
        .alert("Supprimer tous les membres ?", isPresented: $showDeleteAllConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer tout", role: .destructive) {
                Task { await deleteAllMembersOnServer() }
            }
        } message: {
            Text("Toutes les cartes et l’historique côté serveur seront effacés. Irréversible.")
        }
        .alert("Erreur", isPresented: Binding(
            get: { deleteAllError != nil },
            set: { if !$0 { deleteAllError = nil } }
        )) {
            Button("OK") { deleteAllError = nil }
        } message: {
            if let deleteAllError { Text(deleteAllError) }
        }
        .refreshable {
            await syncService.syncAfterServerMutation()
        }
        .background(AppTheme.Colors.background)
    }

    private func deleteAllMembersOnServer() async {
        guard let slug = AuthStorage.currentBusinessSlug, let t = template else {
            await MainActor.run { deleteAllError = "Commerce non connecté." }
            return
        }
        await MainActor.run { isDeletingAll = true }
        defer { Task { @MainActor in isDeletingAll = false } }
        do {
            _ = try await APIClient.shared.request(.deleteAllDashboardMembers(slug: slug)) as DeleteAllMembersResponse
            await MainActor.run {
                dataService.deleteAllClientCards(for: t)
            }
            await syncService.syncAfterServerMutation()
        } catch {
            await MainActor.run {
                deleteAllError = (error as? APIError)?.errorDescription ?? "Suppression impossible."
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.Colors.primary.opacity(0.6))
            Text("Aucun membre")
                .font(AppTheme.Fonts.title3())
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("Les clients apparaîtront ici après leur premier scan.")
                .font(AppTheme.Fonts.body())
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct MemberListRow: View {
    let card: ClientCard

    private var lastVisitText: String? {
        guard let date = card.updatedAt else { return nil }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        f.locale = Locale(identifier: "fr_FR")
        return f.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.clientDisplayName ?? "Client")
                .font(AppTheme.Fonts.headline())
                .foregroundStyle(AppTheme.Colors.textPrimary)
            if let email = card.clientEmail, !email.isEmpty {
                Text(email)
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            HStack {
                Text("\(card.stampsCount) pt\(card.stampsCount > 1 ? "s" : "")")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.primary)
                if let t = lastVisitText {
                    Text("· \(t)")
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

