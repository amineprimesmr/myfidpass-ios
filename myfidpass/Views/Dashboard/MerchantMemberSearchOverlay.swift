//
//  MerchantMemberSearchOverlay.swift
//  myfidpass
//
//  Recherche client inline : barre dans la top bar, résultats liquid glass sur la page active.
//

import Combine
import CoreData
import SwiftUI
import UIKit

// MARK: - Coordinateur

@MainActor
final class MerchantMemberSearchCoordinator: ObservableObject {
    @Published private(set) var isActive = false
    @Published var searchText = ""
    @Published private(set) var focusRequest = 0

    /// Callback enregistré par l’onglet actif pour ouvrir la fiche membre.
    var onSelectMember: ((NSManagedObjectID) -> Void)?

    private var teardownWorkItem: DispatchWorkItem?

    var isPresented: Bool { isActive }

    func present() { activate() }

    func activate() {
        teardownWorkItem?.cancel()
        teardownWorkItem = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(MerchantMotion.searchBarMorph) {
            isActive = true
        }
        MerchantUXFeedback.shared.play(.tap)
    }

    /// Ouvre la recherche et place le curseur dans le champ (clavier).
    func activateWithKeyboard() {
        activate()
        focusRequest &+= 1
    }

    func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(MerchantMotion.searchBarMorph) {
            isActive = false
        }
        scheduleTeardown {
            self.searchText = ""
        }
    }

    func selectMember(_ card: ClientCard) {
        selectMember(objectID: card.objectID)
    }

    func selectMember(objectID: NSManagedObjectID) {
        MerchantUXFeedback.shared.play(.emphasis)
        guard let onSelectMember else { return }
        onSelectMember(objectID)
        dismiss()
    }

    private func scheduleTeardown(cleanup: @escaping () -> Void) {
        teardownWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            cleanup()
            self?.teardownWorkItem = nil
        }
        teardownWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
    }

    func cancelPendingTeardown() {
        teardownWorkItem?.cancel()
        teardownWorkItem = nil
    }
}

// MARK: - Modèle

struct MerchantMemberSearchRowData: Identifiable {
    let objectID: NSManagedObjectID
    let displayName: String
    let searchBlob: String
    let shortDateLabel: String?
    let lastTransactionLine: String
    let initials: String
    let avatarColor: Color
    let lastActivity: Date

    var id: NSManagedObjectID { objectID }

    static func build(from card: ClientCard) -> MerchantMemberSearchRowData {
        let name = (card.clientDisplayName ?? "Client").trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }.joined()
        let initials = letters.isEmpty ? "?" : letters.uppercased()

        let stamps = (card.stamps?.allObjects as? [Stamp]) ?? []
        let latestStamp = stamps.max { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        let lastActivity = latestStamp?.createdAt ?? card.updatedAt ?? card.createdAt ?? .distantPast

        let shortDateLabel: String? = {
            guard lastActivity != .distantPast else { return nil }
            return Self.shortDateFormatter.string(from: lastActivity)
        }()

        let lastTransactionLine: String = {
            if let stamp = latestStamp {
                let note = stamp.note
                return MerchantTransactionEventLabels.eventTitle(
                    type: MerchantTransactionEventLabels.parseType(fromStampNote: note),
                    points: MerchantTransactionEventLabels.parsePoints(fromStampNote: note),
                    isVisit: MerchantTransactionEventLabels.parseVisit(fromStampNote: note),
                    rewardLabel: MerchantTransactionEventLabels.parseRewardLabel(fromStampNote: note),
                    context: .dashboardFeed
                )
            }
            if card.createdAt != nil { return "Nouveau membre" }
            return "Aucune activité"
        }()

        let searchBlob = [
            card.clientDisplayName,
            card.clientEmail,
            card.qrCodeValue,
            card.clientIdentifier,
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return MerchantMemberSearchRowData(
            objectID: card.objectID,
            displayName: name.isEmpty ? "Client" : name,
            searchBlob: searchBlob,
            shortDateLabel: shortDateLabel,
            lastTransactionLine: lastTransactionLine,
            initials: initials,
            avatarColor: MerchantMemberSearchAvatarPalette.color(for: card),
            lastActivity: lastActivity
        )
    }

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.setLocalizedDateFormatFromTemplate("dMMM")
        return f
    }()
}

@MainActor
final class MerchantMemberSearchModel: ObservableObject {
    @Published private(set) var entries: [MerchantMemberSearchRowData] = []
    @Published private(set) var programIsStamps = false

    private let dataService: DataService

    init(dataService: DataService) {
        self.dataService = dataService
        reload()
    }

    func reload() {
        _ = dataService.updateTrigger
        let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !slug.isEmpty {
            let snap = CardPreviewDisplaySnapshotStore.load(slug: slug)
            programIsStamps = (snap?.programType ?? "stamps").lowercased() == "stamps"
        } else {
            programIsStamps = true
        }
        guard let template = dataService.currentCardTemplate() else {
            entries = []
            return
        }
        entries = dataService.uniqueClientCards(for: template)
            .filter { !WalletPreviewMember.shouldExcludeFromMerchantActivity(clientEmail: $0.clientEmail) }
            .map { MerchantMemberSearchRowData.build(from: $0) }
            .sorted { $0.lastActivity > $1.lastActivity }
    }

    func matches(query: String) -> [MerchantMemberSearchRowData] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return entries.filter { $0.searchBlob.contains(q) }
    }

    var catalogEntries: [MerchantMemberSearchRowData] { entries }
}

// MARK: - Résultats inline (page active)

struct MerchantMemberSearchInlineSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var coordinator: MerchantMemberSearchCoordinator
    @EnvironmentObject private var dataService: DataService
    @EnvironmentObject private var syncService: SyncService

    var onSelectMember: ((NSManagedObjectID) -> Void)? = nil

    var body: some View {
        if coordinator.isActive {
            MerchantMemberSearchInlineSectionContent(
                coordinator: coordinator,
                dataService: dataService,
                syncService: syncService,
                onSelectMember: onSelectMember
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

private struct MerchantMemberSearchInlineSectionContent: View {
    @ObservedObject var coordinator: MerchantMemberSearchCoordinator
    @ObservedObject var syncService: SyncService
    @StateObject private var model: MerchantMemberSearchModel

    var onSelectMember: ((NSManagedObjectID) -> Void)?

    init(
        coordinator: MerchantMemberSearchCoordinator,
        dataService: DataService,
        syncService: SyncService,
        onSelectMember: ((NSManagedObjectID) -> Void)?
    ) {
        self.coordinator = coordinator
        self.syncService = syncService
        self.onSelectMember = onSelectMember
        _model = StateObject(wrappedValue: MerchantMemberSearchModel(dataService: dataService))
    }

    private var trimmedQuery: String {
        coordinator.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resultEntries: [MerchantMemberSearchRowData] {
        model.matches(query: coordinator.searchText)
    }

    private var visibleEntries: [MerchantMemberSearchRowData] {
        if trimmedQuery.isEmpty { return model.catalogEntries }
        return resultEntries
    }

    var body: some View {
        Group {
            if trimmedQuery.isEmpty, model.catalogEntries.isEmpty {
                emptyCatalogState
            } else if !trimmedQuery.isEmpty, resultEntries.isEmpty {
                noResultsState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 {
                            rowDivider
                        }
                        memberResultButton(
                            entry,
                            highlight: trimmedQuery.isEmpty ? nil : trimmedQuery
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(nil, value: trimmedQuery)
            }
        }
        .padding(.bottom, 8)
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassMerchantCoreDataDidMergeFromSync)) { _ in
            model.reload()
        }
        .task(id: coordinator.isActive) {
            guard coordinator.isActive else { return }
            model.reload()
            await syncService.syncAfterServerMutation()
            model.reload()
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 88)
    }

    private func memberResultButton(_ entry: MerchantMemberSearchRowData, highlight: String? = nil) -> some View {
        Button {
            if let onSelectMember {
                MerchantUXFeedback.shared.play(.emphasis)
                onSelectMember(entry.objectID)
                coordinator.dismiss()
            } else {
                coordinator.selectMember(objectID: entry.objectID)
            }
        } label: {
            MerchantMemberSearchResultRow(entry: entry, highlight: highlight)
        }
        .buttonStyle(.plain)
    }

    private var emptyCatalogState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.28))
            Text("Pas encore de clients")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.black)
            Text("Scannez une carte Wallet ou attendez la synchronisation.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.48))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }

    private var noResultsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.28))
            Text("Aucun client trouvé")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.black)
            Text("Essayez le prénom, l’e-mail ou une partie de l’identifiant carte.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.48))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
    }
}

// MARK: - Ligne résultat (style Revolut « Virements »)

struct MerchantMemberSearchResultRow: View {
    let entry: MerchantMemberSearchRowData
    var highlight: String?

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            MerchantMemberSearchAvatar(initials: entry.initials, tint: entry.avatarColor)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    highlightedName
                    Spacer(minLength: 4)
                    if let dateLabel = entry.shortDateLabel {
                        Text(dateLabel)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.38))
                            .lineLimit(1)
                    }
                }
                Text(entry.lastTransactionLine)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.48))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var highlightedName: some View {
        let name = entry.displayName
        if let q = highlight?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty,
           let range = name.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) {
            let before = String(name[name.startIndex..<range.lowerBound])
            let match = String(name[range])
            let after = String(name[range.upperBound...])
            (
                Text(before)
                + Text(match).foregroundStyle(Color(red: 0.22, green: 0.45, blue: 0.95)).bold()
                + Text(after)
            )
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Color.black)
            .lineLimit(1)
        } else {
            Text(name)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.black)
                .lineLimit(1)
        }
    }
}

private struct MerchantMemberSearchAvatar: View {
    let initials: String
    let tint: Color

    private static let showsFlyerBadge = UIImage(named: "FlyerMyfidpassIcon") != nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(tint)
                .frame(width: 52, height: 52)
                .overlay {
                    Text(initials)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }

            Circle()
                .fill(Color.white)
                .frame(width: 22, height: 22)
                .overlay {
                    Group {
                        if Self.showsFlyerBadge {
                            Image("FlyerMyfidpassIcon")
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(tint)
                        }
                    }
                    .frame(width: 14, height: 14)
                    .clipShape(Circle())
                }
                .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                .offset(x: 2, y: 2)
        }
        .frame(width: 56, height: 56)
    }
}

private enum MerchantMemberSearchAvatarPalette {
    private static let colors: [Color] = [
        Color(red: 0.18, green: 0.72, blue: 0.52),
        Color(red: 0.95, green: 0.58, blue: 0.22),
        Color(red: 0.32, green: 0.52, blue: 0.96),
        Color(red: 0.58, green: 0.38, blue: 0.92),
        Color(red: 0.22, green: 0.68, blue: 0.78),
        Color(red: 0.92, green: 0.38, blue: 0.42),
    ]

    static func color(for card: ClientCard) -> Color {
        let key = card.clientEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? card.clientDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? card.qrCodeValue
            ?? ""
        let hash = abs(key.hashValue)
        return colors[hash % colors.count]
    }
}

// MARK: - Enregistrement handler (onglet actif)

struct MerchantMemberSearchTabBinding: ViewModifier {
    @Environment(\.merchantTabIsActive) private var merchantTabIsActive
    @EnvironmentObject private var coordinator: MerchantMemberSearchCoordinator

    let onSelectMember: (NSManagedObjectID) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear { updateHandler() }
            .onChange(of: merchantTabIsActive) { _, _ in updateHandler() }
    }

    private func updateHandler() {
        guard merchantTabIsActive else { return }
        coordinator.onSelectMember = onSelectMember
    }
}

extension View {
    func merchantMemberSearchTabBinding(onSelectMember: @escaping (NSManagedObjectID) -> Void) -> some View {
        modifier(MerchantMemberSearchTabBinding(onSelectMember: onSelectMember))
    }
}
