//
//  DashboardActivityFullView.swift
//  myfidpass
//
//  Hub unifié « Membres & activité » : tous les membres, tri par passages récents,
//  filtres (tout / scans / créations), recherche et fiche membre comme l’ancienne liste.
//

import SwiftUI
import CoreData

struct DashboardActivityFullView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var syncService: SyncService
    @StateObject private var dataService: DataService
    @State private var filter: MemberActivityFilter
    @State private var searchText = ""
    @State private var memberDetailSheetItem: MemberDetailSheetItem?

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext, initialFilter: MemberActivityFilter = .all) {
        self.context = context
        _dataService = StateObject(wrappedValue: DataService(context: context))
        _filter = State(initialValue: initialFilter)
    }

    private var palette: DashboardRevolutPalette { DashboardRevolutPalette(colorScheme: colorScheme) }

    private var summaries: [MemberActivitySummary] {
        let _ = dataService.updateTrigger
        return dataService.memberActivitySummaries(filter: filter)
    }

    private var filteredSummaries: [MemberActivitySummary] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return summaries }
        return summaries.filter {
            (($0.card.clientDisplayName ?? "").lowercased().contains(q))
                || (($0.card.clientEmail ?? "").lowercased().contains(q))
                || (($0.card.qrCodeValue ?? "").lowercased().contains(q))
        }
    }

    var body: some View {
        let _ = dataService.updateTrigger
        List {
            Section {
                Picker("Affichage", selection: $filter) {
                    ForEach(MemberActivityFilter.allCases) { f in
                        Text(f.segmentTitle).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
            .listRowSeparator(.hidden)

            if filteredSummaries.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: emptyIcon,
                    description: Text(emptyDescription)
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(filteredSummaries) { summary in
                    Button {
                        memberDetailSheetItem = MemberDetailSheetItem(objectID: summary.card.objectID)
                    } label: {
                        RevolutMemberActivityRow(summary: summary, palette: palette)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(palette.card)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 2)
                    )
                    .listRowInsets(EdgeInsets(top: 2, leading: 14, bottom: 2, trailing: 14))
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(10)
        .scrollContentBackground(.hidden)
        .background(palette.canvas)
        .navigationTitle("Membres")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(palette.canvas, for: .navigationBar)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Nom, e-mail ou code…")
        .refreshable {
            await syncService.syncAfterServerMutation()
        }
        .sheet(item: $memberDetailSheetItem) { item in
            if let card = context.object(with: item.objectID) as? ClientCard {
                MemberDetailView(card: card, context: context)
                    .environmentObject(syncService)
                    .environmentObject(dataService)
                    .memberDetailSheetChrome()
            }
        }
    }

    private var emptyTitle: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Aucun résultat"
        }
        switch filter {
        case .all: return "Aucun membre"
        case .scans: return "Aucun scan"
        case .newCards: return "Aucune carte en attente"
        }
    }

    private var emptyIcon: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "magnifyingglass"
        }
        switch filter {
        case .all: return "person.2.slash"
        case .scans: return "qrcode.viewfinder"
        case .newCards: return "person.crop.circle.badge.plus"
        }
    }

    private var emptyDescription: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Essayez un autre nom ou identifiant."
        }
        switch filter {
        case .all:
            return "Synchronisez ou attendez le premier ajout de carte."
        case .scans:
            return "Les passages enregistrés apparaîtront ici, triés du plus récent au plus ancien."
        case .newCards:
            return "Les membres sans aucun scan sont listés ici. Tous vos membres ont déjà été scannés au moins une fois."
        }
    }
}
