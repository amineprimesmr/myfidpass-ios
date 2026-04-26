//
//  MerchantStatsAllMembersListScreen.swift
//  myfidpass
//
//  Feuille statistiques « Nouveaux membres » : liste de tous les membres (Core Data), filtres actif / inactif, tri, recherche.
//  Même contenu de référence que le tableau de bord « Membres », en visuel aligné sur les stats Commerce.
//

import CoreData
import SwiftUI

/// Membre considéré **actif** s’il y a une activité (mise à jour carte) dans les 30 derniers jours — aligné sur l’indicateur « inactifs 30 j. » côté API stats.
/// Nom distinct de `MemberActivityFilter` (hub Membres & activité dans `DataService`).
private enum AllMembersRecencyFilter: String, CaseIterable, Identifiable {
    case all = "Tous"
    case active = "Actifs"
    case inactive = "Inactifs (30 j.)"
    var id: String { rawValue }
}

private enum MemberRosterSort: String, CaseIterable, Identifiable {
    case dateNewest
    case dateOldest
    case pointsHigh
    case pointsLow
    case nameAZ
    case nameZA
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dateNewest: return "Date · plus récent"
        case .dateOldest: return "Date · plus ancien"
        case .pointsHigh: return "Points · du plus haut"
        case .pointsLow: return "Points · du plus bas"
        case .nameAZ: return "Nom · A → Z"
        case .nameZA: return "Nom · Z → A"
        }
    }
}

struct MerchantStatsAllMembersListScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var syncService: SyncService

    private let objectContext: NSManagedObjectContext

    @StateObject private var dataService: DataService
    @State private var searchText = ""
    @State private var activityFilter: AllMembersRecencyFilter = .all
    @State private var sort: MemberRosterSort = .dateNewest
    @State private var showFiltersSheet = false

    /// Même conteneur que le sheet / le profil : toujours passer le `viewContext` injecté.
    init(context: NSManagedObjectContext) {
        self.objectContext = context
        _dataService = StateObject(wrappedValue: DataService(context: context))
    }

    private var template: CardTemplate? { dataService.currentCardTemplate() }

    private var allMembers: [ClientCard] {
        guard let t = template else { return [] }
        return dataService.uniqueClientCards(for: t).filter {
            !WalletPreviewMember.shouldExcludeFromMerchantActivity(clientEmail: $0.clientEmail)
        }
    }

    private var filteredSortedMembers: [ClientCard] {
        var list = allMembers
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter {
                ($0.clientDisplayName ?? "").lowercased().contains(q)
                    || ($0.clientEmail ?? "").lowercased().contains(q)
                    || ($0.qrCodeValue ?? "").lowercased().contains(q)
            }
        }
        let threshold = Self.inactiveAfterDate
        list = list.filter { card in
            switch activityFilter {
            case .all: return true
            case .active: return isActive(card, threshold: threshold)
            case .inactive: return !isActive(card, threshold: threshold)
            }
        }
        switch sort {
        case .dateNewest:
            list.sort { a, b in (a.resolvedLastActivity) > (b.resolvedLastActivity) }
        case .dateOldest:
            list.sort { a, b in (a.resolvedLastActivity) < (b.resolvedLastActivity) }
        case .pointsHigh:
            list.sort { $0.stampsCount > $1.stampsCount }
        case .pointsLow:
            list.sort { $0.stampsCount < $1.stampsCount }
        case .nameAZ:
            list.sort { (a, b) in
                (a.clientDisplayName ?? "").localizedCaseInsensitiveCompare(b.clientDisplayName ?? "") == .orderedAscending
            }
        case .nameZA:
            list.sort { (a, b) in
                (a.clientDisplayName ?? "").localizedCaseInsensitiveCompare(b.clientDisplayName ?? "") == .orderedDescending
            }
        }
        return list
    }

    private static var inactiveAfterDate: Date {
        Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date.distantPast
    }

    private func isActive(_ card: ClientCard, threshold: Date) -> Bool {
        card.resolvedLastActivity > threshold
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CommerceStatisticsTheme.newMembersSheetBackground
                    .ignoresSafeArea()

                if template == nil {
                    Text("Aucun programme carte.")
                        .font(CommerceStatisticsTheme.statsText(size: 16, weight: .medium))
                        .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
                } else if allMembers.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .navigationTitle("Nouveaux membres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CommerceStatsBackCircleButton(action: { dismiss() })
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFiltersSheet = true
                    } label: {
                        Label("Filtre et tri", systemImage: "line.3.horizontal.decrease.circle")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(CommerceStatisticsTheme.accentBlue)
                    }
                    .accessibilityLabel("Filtre et tri")
                }
            }
            .tint(CommerceStatisticsTheme.accentBlue)
            .toolbarBackground(CommerceStatisticsTheme.newMembersSheetBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Nom, e-mail, QR…"
        )
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassRemoteSyncDidMerge)) { _ in
            dataService.bumpRefreshAfterRemoteMerge()
        }
        .background(CommerceStatisticsTheme.newMembersSheetBackground)
        .sheet(isPresented: $showFiltersSheet) {
            filterSortSheet
                .environment(\.colorScheme, .dark)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
            Text("Aucun membre pour l’instant")
                .font(CommerceStatisticsTheme.statsText(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Text("Les clients apparaissent ici après scan ou ajout de carte.")
                .font(CommerceStatisticsTheme.statsText(size: 14, weight: .regular))
                .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private var listContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Liste de tous les membres")
                    .font(CommerceStatisticsTheme.statsText(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(filteredSortedMembers.count) sur \(allMembers.count)")
                    .font(CommerceStatisticsTheme.statsText(size: 13, weight: .medium))
                    .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 10)

            List {
                ForEach(filteredSortedMembers, id: \.objectID) { card in
                    NavigationLink {
                        MemberDetailView(card: card, context: objectContext)
                            .environmentObject(syncService)
                            .environmentObject(dataService)
                    } label: {
                        memberRow(card)
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(CommerceStatisticsTheme.pillBackground.opacity(0.65))
                    )
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func memberRow(_ card: ClientCard) -> some View {
        let active = isActive(card, threshold: Self.inactiveAfterDate)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.clientDisplayName ?? "Client")
                    .font(CommerceStatisticsTheme.statsText(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Text(active ? "Actif" : "Inactif")
                    .font(CommerceStatisticsTheme.statsText(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(active ? CommerceStatisticsTheme.positive.opacity(0.22) : Color.white.opacity(0.1))
                    )
                    .foregroundStyle(active ? CommerceStatisticsTheme.positive : CommerceStatisticsTheme.secondaryLabel)
            }
            if let email = card.clientEmail, !email.isEmpty {
                Text(email)
                    .font(CommerceStatisticsTheme.statsText(size: 12, weight: .regular))
                    .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
            }
            HStack(spacing: 8) {
                Text("\(card.stampsCount) pt\(card.stampsCount == 1 ? "" : "s")")
                    .font(CommerceStatisticsTheme.statsText(size: 13, weight: .semibold))
                    .foregroundStyle(CommerceStatisticsTheme.accentBlue)
                if let t = lastActivityLabel(card) {
                    Text("· \(t)")
                        .font(CommerceStatisticsTheme.statsText(size: 12, weight: .medium))
                        .foregroundStyle(CommerceStatisticsTheme.secondaryLabel)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func lastActivityLabel(_ card: ClientCard) -> String? {
        let d = card.resolvedLastActivity
        if d == .distantPast { return "Jamais" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        f.locale = Locale(identifier: "fr_FR")
        return f.localizedString(for: d, relativeTo: Date())
    }

    private var filterSortSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Afficher", selection: $activityFilter) {
                        ForEach(AllMembersRecencyFilter.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                } header: {
                    Text("Filtre d’activité (30 j.)")
                }
                Section {
                    Picker("Trier par", selection: $sort) {
                        ForEach(MemberRosterSort.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
                } header: {
                    Text("Tri")
                }
            }
            .scrollContentBackground(.hidden)
            .background(CommerceStatisticsTheme.newMembersSheetBackground)
            .navigationTitle("Filtre et tri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { showFiltersSheet = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(CommerceStatisticsTheme.newMembersSheetBackground)
    }
}

private extension ClientCard {
    var resolvedLastActivity: Date {
        updatedAt ?? createdAt ?? .distantPast
    }
}
