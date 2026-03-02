//
//  MembersListView.swift
//  myfidpass
//
//  Liste des membres avec recherche. Accessible depuis « Cartes actives » sur le tableau de bord.
//

import SwiftUI
import CoreData

struct MembersListView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var syncService: SyncService
    @StateObject private var dataService: DataService
    @State private var searchText = ""
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        _dataService = StateObject(wrappedValue: DataService(context: context))
        self.context = context
    }

    private var template: CardTemplate? { dataService.currentCardTemplate() }
    private var allMembers: [ClientCard] {
        guard let t = template else { return [] }
        return dataService.clientCards(for: t)
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
            ToolbarItem(placement: .cancellationAction) {
                Button("Fermer") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    CategoriesManagementView(context: context)
                        .environmentObject(syncService)
                } label: {
                    Label("Catégories", systemImage: "folder.badge.gearshape")
                }
            }
        }
        .refreshable {
            await syncService.syncIfNeeded()
        }
        .background(AppTheme.Colors.background)
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

