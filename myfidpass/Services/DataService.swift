//
//  DataService.swift
//  myfidpass
//
//  Service d’accès et de mise à jour des données (Business, CardTemplate, ClientCard, Stamp).
//  Prêt pour branchement API / CloudKit plus tard.
//

import Combine
import CoreData
import Foundation
import os.log

private let dataServiceLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "myfidpass", category: "DataService")

/// Filtre du hub « Membres & activité » (accueil unifié).
enum MemberActivityFilter: Int, Hashable, CaseIterable, Identifiable {
    case all
    case scans
    case newCards

    var id: Int { rawValue }

    var segmentTitle: String {
        switch self {
        case .all: return "Tout"
        case .scans: return "Scans"
        case .newCards: return "Créations"
        }
    }
}

/// Membre + dernière date de scan (pour tri et affichage).
struct MemberActivitySummary: Identifiable {
    let card: ClientCard
    /// Dernier passage enregistré (tampon), si connu localement.
    let lastScanDate: Date?

    var id: NSManagedObjectID { card.objectID }

    /// Clé de tri : scan récent d’abord, sinon date de création de la carte.
    var sortKey: Date { lastScanDate ?? card.createdAt ?? .distantPast }

    var hasScanHistory: Bool { lastScanDate != nil || card.stampsCount > 0 }
}

/// Ligne du fil d’activité (nouvelle carte ou scan).
struct DashboardActivityEntry: Identifiable, Equatable {
    enum Kind: Equatable {
        case newCard
        case scan
    }

    let id: String
    let date: Date
    let clientName: String
    let kind: Kind
    /// Carte représentative du membre (scan = carte du tampon ; « nouvelle carte » = première carte du groupe logique).
    let cardObjectID: NSManagedObjectID
    /// Points crédités sur ce scan si connus (encodés dans `Stamp.note` après sync API, suffixe `|p:N`).
    let scanPointsGranted: Int?

    var eventTitle: String {
        switch kind {
        case .newCard: return "Nouvelle carte"
        case .scan: return "Scan"
        }
    }

    var systemImage: String {
        switch kind {
        case .newCard: return "person.crop.circle.badge.plus"
        case .scan: return "qrcode.viewfinder"
        }
    }
}

/// Membre technique créé pour « Tester dans l’Apple Wallet » (`MyCardView.ensurePreviewMemberIdForWallet`) — pas une vraie transaction / client.
enum WalletPreviewMember {
    static func shouldExcludeFromMerchantActivity(clientEmail: String?) -> Bool {
        guard let raw = clientEmail?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty else { return false }
        return raw.hasPrefix("wallet-apercu.") && raw.hasSuffix("@example.com")
    }
}

@MainActor
final class DataService: ObservableObject {
    private let viewContext: NSManagedObjectContext
    /// Déclenche les mises à jour des vues qui utilisent ce service.
    @Published private(set) var updateTrigger: Int = 0

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }

    /// Après une sync serveur (contexte en arrière-plan fusionné dans le viewContext) : forcer le recalcul des feeds.
    func bumpRefreshAfterRemoteMerge() {
        updateTrigger += 1
    }

    // MARK: - Business

    func currentBusiness() -> Business? {
        let request = Business.fetchRequest()
        if let slug = AuthStorage.currentBusinessSlug, !slug.isEmpty {
            request.predicate = NSPredicate(format: "slug == %@", slug)
            request.fetchLimit = 1
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Business.updatedAt, ascending: false)]
            if let b = try? viewContext.fetch(request).first { return b }
            // Ne pas retomber sur un autre commerce (ex. ancienne ligne sans slug) : évite « Mon commerce » à la place du bon établissement.
            return nil
        }
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Business.updatedAt, ascending: false)]
        if let b = try? viewContext.fetch(request).first { return b }
        let fallback = Business.fetchRequest()
        fallback.fetchLimit = 1
        fallback.sortDescriptors = [NSSortDescriptor(keyPath: \Business.createdAt, ascending: true)]
        return try? viewContext.fetch(fallback).first
    }

    func createOrGetCurrentBusiness(name: String = "Mon Commerce", email: String? = nil) -> Business {
        if let existing = currentBusiness() { return existing }
        let b = Business(context: viewContext)
        b.id = UUID()
        b.slug = AuthStorage.currentBusinessSlug
        b.name = name
        b.email = email
        b.createdAt = Date()
        b.updatedAt = Date()
        save()
        return b
    }

    /// Vide toutes les données locales CoreData (Business, CardTemplate, ClientCard, Stamp, MemberCategory).
    /// À appeler lors du logout / suppression de compte pour éviter qu'un ancien commerce réapparaisse.
    static func clearAllLocalData(context: NSManagedObjectContext) {
        let entities = ["Stamp", "ClientCard", "MemberCategory", "CardTemplate", "Business"]
        for entityName in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDelete = NSBatchDeleteRequest(fetchRequest: request)
            batchDelete.resultType = .resultTypeObjectIDs
            if let result = try? context.execute(batchDelete) as? NSBatchDeleteResult,
               let ids = result.result as? [NSManagedObjectID] {
                let changes = [NSDeletedObjectsKey: ids]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
            }
        }
    }

    /// Juste après login / register : la 1ʳᵉ sync réseau est différée ; sans cette étape, Commerce affichait un commerce local par défaut au lieu du vrai nom API.
    @MainActor
    static func seedBusinessesFromAuth(_ dtos: [BusinessDTO], context: NSManagedObjectContext) {
        guard !dtos.isEmpty else { return }
        for dto in dtos {
            let slug = dto.slug.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !slug.isEmpty else { continue }
            let request = Business.fetchRequest()
            request.predicate = NSPredicate(format: "slug == %@", slug)
            request.fetchLimit = 1
            let business: Business
            if let existing = try? context.fetch(request).first {
                business = existing
            } else {
                business = Business(context: context)
                business.id = UUID()
                business.createdAt = Date()
            }
            let nm = dto.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let orgTrim = dto.organizationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let displayName: String
            if !orgTrim.isEmpty {
                displayName = orgTrim
            } else if !nm.isEmpty {
                displayName = nm
            } else {
                displayName = "Mon établissement"
            }
            business.slug = slug
            business.name = displayName
            business.updatedAt = Date()

            let tReq = CardTemplate.fetchRequest()
            tReq.predicate = NSPredicate(format: "business == %@", business)
            tReq.fetchLimit = 1
            let template: CardTemplate
            if let t = try? context.fetch(tReq).first {
                template = t
            } else {
                template = CardTemplate(context: context)
                template.id = UUID()
                template.business = business
                template.requiredStamps = 10
                template.primaryColorHex = AppTheme.WalletCardAppearanceDefaults.backgroundHex
                template.accentColorHex = AppTheme.WalletCardAppearanceDefaults.bodyTextHex
                template.createdAt = Date()
            }
            template.displayName = displayName
            template.updatedAt = Date()
        }
        try? context.save()
    }

    func updateBusiness(name: String?, email: String?, phone: String?, address: String?, logoURL: String?) {
        guard let b = currentBusiness() else { return }
        if let name { b.name = name }
        if let email { b.email = email }
        if let phone { b.phone = phone }
        if address != nil { b.address = address }
        if let logoURL { b.logoURL = logoURL }
        b.updatedAt = Date()
        save()
    }

    // MARK: - CardTemplate (carte wallet du commerce)

    func currentCardTemplate() -> CardTemplate? {
        guard let business = currentBusiness() else { return nil }
        let request = CardTemplate.fetchRequest()
        request.predicate = NSPredicate(format: "business == %@", business)
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CardTemplate.createdAt, ascending: true)]
        return try? viewContext.fetch(request).first
    }

    func createOrGetCurrentCardTemplate(
        displayName: String = "Ma Carte Fidélité",
        requiredStamps: Int32 = 10,
        primaryColorHex: String = AppTheme.WalletCardAppearanceDefaults.backgroundHex,
        accentColorHex: String = AppTheme.WalletCardAppearanceDefaults.bodyTextHex
    ) -> CardTemplate {
        if let existing = currentCardTemplate() { return existing }
        let business = createOrGetCurrentBusiness()
        let t = CardTemplate(context: viewContext)
        t.id = UUID()
        t.business = business
        t.displayName = displayName
        t.requiredStamps = requiredStamps
        t.primaryColorHex = primaryColorHex
        t.accentColorHex = accentColorHex
        t.createdAt = Date()
        t.updatedAt = Date()
        save()
        return t
    }

    func updateCardTemplate(
        displayName: String?,
        requiredStamps: Int32?,
        primaryColorHex: String?,
        accentColorHex: String?,
        logoURL: String? = nil,
        stampEmoji: String? = nil
    ) {
        guard let t = currentCardTemplate() else { return }
        if let displayName { t.displayName = displayName }
        if let requiredStamps { t.requiredStamps = requiredStamps }
        if let primaryColorHex { t.primaryColorHex = primaryColorHex }
        if let accentColorHex { t.accentColorHex = accentColorHex }
        t.logoURL = logoURL
        t.stampEmoji = stampEmoji
        t.updatedAt = Date()
        save()
    }

    // MARK: - ClientCard (carte d’un client)

    func clientCards(for template: CardTemplate) -> [ClientCard] {
        let request = ClientCard.fetchRequest()
        request.predicate = NSPredicate(format: "template == %@", template)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ClientCard.updatedAt, ascending: false)]
        return (try? viewContext.fetch(request)) ?? []
    }

    /// Clé stable pour regrouper les `ClientCard` en double (même membre).
    private func memberLogicalKey(for card: ClientCard) -> String {
        if let q = card.qrCodeValue?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty { return "q:\(q)" }
        if let e = card.clientEmail?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !e.isEmpty { return "e:\(e)" }
        return "o:\(card.objectID.uriRepresentation().absoluteString)"
    }

    /// Une entrée par membre logique (`qrCodeValue`, sinon e-mail, sinon objectID) — évite les doublons d’affichage après sync / réimport.
    func uniqueClientCards(for template: CardTemplate) -> [ClientCard] {
        let all = clientCards(for: template)
        var best: [String: ClientCard] = [:]
        for c in all {
            let key = memberLogicalKey(for: c)
            if let existing = best[key] {
                let cDate = c.updatedAt ?? c.createdAt ?? .distantPast
                let eDate = existing.updatedAt ?? existing.createdAt ?? .distantPast
                if cDate >= eDate { best[key] = c }
            } else {
                best[key] = c
            }
        }
        // Ordre stable : l’ordre de `Dictionary.values` n’est pas garanti — sans tri, `.first` change
        // entre exécutions et ne correspond pas au membre utilisé pour le pass Wallet.
        return Array(best.values).sorted { a, b in
            let qa = a.qrCodeValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let qb = b.qrCodeValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if qa != qb { return qa < qb }
            return a.objectID.uriRepresentation().absoluteString < b.objectID.uriRepresentation().absoluteString
        }
    }

    func clientCard(byQRCodeValue qrCodeValue: String) -> ClientCard? {
        let request = ClientCard.fetchRequest()
        request.predicate = NSPredicate(format: "qrCodeValue == %@", qrCodeValue)
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }

    func findOrCreateClientCard(qrCodeValue: String, template: CardTemplate, clientDisplayName: String?) -> ClientCard {
        let scoped = ClientCard.fetchRequest()
        scoped.predicate = NSPredicate(format: "qrCodeValue == %@ AND template == %@", qrCodeValue, template)
        scoped.fetchLimit = 1
        if let existing = try? viewContext.fetch(scoped).first { return existing }
        let c = ClientCard(context: viewContext)
        c.id = UUID()
        c.template = template
        c.qrCodeValue = qrCodeValue
        c.clientIdentifier = qrCodeValue
        c.clientDisplayName = clientDisplayName ?? "Client"
        c.stampsCount = 0
        c.createdAt = Date()
        c.updatedAt = Date()
        save()
        return c
    }

    func addStamp(to clientCard: ClientCard, note: String? = nil) {
        let s = Stamp(context: viewContext)
        s.id = UUID()
        s.clientCard = clientCard
        s.createdAt = Date()
        s.note = note
        clientCard.stampsCount += 1
        clientCard.updatedAt = Date()
        save()
    }

    // MARK: - Stats pour le dashboard

    func totalClientCardsCount() -> Int {
        guard let template = currentCardTemplate() else { return 0 }
        return uniqueClientCards(for: template).count
    }

    func stampsCountToday() -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let request = Stamp.fetchRequest()
        request.predicate = NSPredicate(format: "createdAt >= %@", startOfDay as NSDate)
        return (try? viewContext.count(for: request)) ?? 0
    }

    func recentStamps(limit: Int = 10) -> [Stamp] {
        let request = Stamp.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Stamp.createdAt, ascending: false)]
        request.fetchLimit = limit
        return (try? viewContext.fetch(request)) ?? []
    }

    /// Tampons du programme courant, du plus récent au plus ancien (évite de mélanger d’autres templates).
    private func recentStamps(for template: CardTemplate, limit: Int) -> [Stamp] {
        let request = Stamp.fetchRequest()
        request.predicate = NSPredicate(format: "clientCard.template == %@", template)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Stamp.createdAt, ascending: false)]
        request.fetchLimit = limit
        return (try? viewContext.fetch(request)) ?? []
    }

    // MARK: - Fil d’activité (tableau de bord)

    /// Lit les points crédités depuis `Stamp.note` (`txn:<id>|p:<points>`), rempli à l’import des transactions serveur.
    private static func scanPointsFromStampNote(_ note: String?) -> Int? {
        guard let raw = note?.trimmingCharacters(in: .whitespacesAndNewlines), raw.hasPrefix("txn:") else { return nil }
        guard let range = raw.range(of: "|p:") else { return nil }
        let tail = raw[range.upperBound...]
        return Int(tail)
    }

    /// Libellé pour une ligne d’historique membre (fiche détail, tampons locaux ou import sync `txn:`).
    static func memberStampEventTitle(note: String?) -> String {
        let raw = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.hasPrefix("txn:") {
            if let pts = Self.scanPointsFromStampNote(note) {
                if pts > 0 {
                    return pts == 1 ? "+1 point crédité" : "+\(pts) points crédités"
                }
                if pts < 0 {
                    let a = abs(pts)
                    return a == 1 ? "1 point retiré" : "\(a) points retirés"
                }
            }
            return "Transaction enregistrée"
        }
        if !raw.isEmpty {
            if raw.count > 60 { return String(raw.prefix(60)) + "…" }
            return raw
        }
        return "Passage / visite"
    }

    /// Clé stable pour dédoublonner un tampon importé serveur (`txn:<id>` avec ou sans `|p:` / métadonnées).
    private static func normalizedTxnDedupKey(fromStampNote note: String?) -> String? {
        let raw = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard raw.hasPrefix("txn:"), raw.count > 5 else { return nil }
        let afterPrefix = raw.dropFirst(4)
        if let pipe = afterPrefix.firstIndex(of: "|") {
            let idPart = String(afterPrefix[..<pipe]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !idPart.isEmpty else { return nil }
            return "txn:\(idPart)"
        }
        return raw
    }

    /// Événements récents : nouvelles cartes et scans, **dédupliqués** (une transaction serveur = une ligne ; tampon local = clé par `Stamp`).
    /// **Aucun filtre « depuis minuit »** : on garde les N événements les plus récents, même s’ils datent d’il y a plusieurs jours.
    /// - Parameter includeNewCardEvents: sur l’accueil « Dernières transactions », mettre `false` pour n’afficher que les **scans** (évite les doublons visuels membre + inscription).
    func dashboardActivityFeed(limit: Int = 20, includeNewCardEvents: Bool = true) -> [DashboardActivityEntry] {
        guard let template = currentCardTemplate() else { return [] }
        var items: [DashboardActivityEntry] = []

        var seenScanKeys = Set<String>()
        for s in recentStamps(for: template, limit: 400) {
            guard let card = s.clientCard, card.template == template else { continue }
            if WalletPreviewMember.shouldExcludeFromMerchantActivity(clientEmail: card.clientEmail) { continue }
            let name = card.clientDisplayName ?? "Client"
            let date = s.createdAt ?? .distantPast
            let dedupKey: String
            if let txnKey = Self.normalizedTxnDedupKey(fromStampNote: s.note) {
                dedupKey = txnKey
            } else {
                dedupKey = "local:\(s.objectID.uriRepresentation().absoluteString)"
            }
            guard !seenScanKeys.contains(dedupKey) else { continue }
            seenScanKeys.insert(dedupKey)
            items.append(DashboardActivityEntry(
                id: "scan-\(dedupKey)",
                date: date,
                clientName: name,
                kind: .scan,
                cardObjectID: card.objectID,
                scanPointsGranted: Self.scanPointsFromStampNote(s.note)
            ))
        }

        if includeNewCardEvents {
            let allCards = clientCards(for: template)
            var groups: [String: [ClientCard]] = [:]
            for c in allCards {
                let gk = memberLogicalKey(for: c)
                groups[gk, default: []].append(c)
            }
            for (gk, cards) in groups {
                guard let firstCard = cards.min(by: { a, b in
                    (a.createdAt ?? .distantFuture) < (b.createdAt ?? .distantFuture)
                }) else { continue }
                if WalletPreviewMember.shouldExcludeFromMerchantActivity(clientEmail: firstCard.clientEmail) { continue }
                let name = cards.map(\.clientDisplayName).compactMap { $0 }.first { !$0.isEmpty } ?? firstCard.clientDisplayName ?? "Client"
                let earliest = cards.compactMap(\.createdAt).min() ?? firstCard.createdAt ?? .distantPast
                items.append(DashboardActivityEntry(
                    id: "card-\(gk)",
                    date: earliest,
                    clientName: name,
                    kind: .newCard,
                    cardObjectID: firstCard.objectID,
                    scanPointsGranted: nil
                ))
            }
        }

        items.sort { $0.date > $1.date }
        return Array(items.prefix(limit))
    }

    /// Activité (scans + nouvelles cartes) regroupée par jour calendaire, pour une liste de jours (ex. semaine affichée).
    func dashboardActivityGroupedByDay(includedDays: [Date]) -> [Date: [DashboardActivityEntry]] {
        let cal = Calendar.current
        let dayStarts = Set(includedDays.map { cal.startOfDay(for: $0) })
        guard !dayStarts.isEmpty else { return [:] }
        var buckets: [Date: [DashboardActivityEntry]] = [:]
        /// Limite élevée : le regroupement par jour ne garde qu’une semaine, mais le fil global est récent d’abord.
        let feed = dashboardActivityFeed(limit: 2000)
        for e in feed {
            let sd = cal.startOfDay(for: e.date)
            guard dayStarts.contains(sd) else { continue }
            buckets[sd, default: []].append(e)
        }
        for d in dayStarts {
            buckets[d]?.sort { $0.date > $1.date }
        }
        return buckets
    }

    /// Dernière date de scan par carte (un seul fetch des tampons du template).
    func lastScanDatesByCard(for template: CardTemplate) -> [NSManagedObjectID: Date] {
        let request = Stamp.fetchRequest()
        request.predicate = NSPredicate(format: "clientCard.template == %@", template)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Stamp.createdAt, ascending: false)]
        let stamps = (try? viewContext.fetch(request)) ?? []
        var map: [NSManagedObjectID: Date] = [:]
        for s in stamps {
            guard let card = s.clientCard, let d = s.createdAt else { continue }
            let oid = card.objectID
            if map[oid] == nil { map[oid] = d }
        }
        return map
    }

    /// Dernier scan par **membre logique** (fusionne les cartes en double).
    private func lastScanDatesByMemberKey(for template: CardTemplate) -> [String: Date] {
        let request = Stamp.fetchRequest()
        request.predicate = NSPredicate(format: "clientCard.template == %@", template)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Stamp.createdAt, ascending: false)]
        let stamps = (try? viewContext.fetch(request)) ?? []
        var best: [String: Date] = [:]
        for s in stamps {
            guard let card = s.clientCard, let d = s.createdAt else { continue }
            let key = memberLogicalKey(for: card)
            if let existing = best[key] {
                if d > existing { best[key] = d }
            } else {
                best[key] = d
            }
        }
        return best
    }

    /// Tous les membres du programme, filtrés et triés pour le hub activité / membres.
    func memberActivitySummaries(filter: MemberActivityFilter) -> [MemberActivitySummary] {
        guard let template = currentCardTemplate() else { return [] }
        let lastByMemberKey = lastScanDatesByMemberKey(for: template)
        let cards = uniqueClientCards(for: template).filter {
            !WalletPreviewMember.shouldExcludeFromMerchantActivity(clientEmail: $0.clientEmail)
        }
        var summaries: [MemberActivitySummary] = cards.map { card in
            MemberActivitySummary(card: card, lastScanDate: lastByMemberKey[memberLogicalKey(for: card)])
        }
        switch filter {
        case .all:
            summaries.sort { $0.sortKey > $1.sortKey }
        case .scans:
            summaries = summaries.filter { $0.hasScanHistory }
            summaries.sort { $0.sortKey > $1.sortKey }
        case .newCards:
            summaries = summaries.filter { !$0.hasScanHistory }
            summaries.sort {
                ($0.card.createdAt ?? .distantPast) > ($1.card.createdAt ?? .distantPast)
            }
        }
        return summaries
    }

    /// Somme des points / tampons enregistrés sur toutes les cartes du programme actuel.
    func totalStampsAcrossMembers() -> Int {
        guard let template = currentCardTemplate() else { return 0 }
        return uniqueClientCards(for: template).reduce(0) { $0 + Int($1.stampsCount) }
    }

    // MARK: - Catégories de membres

    /// Toutes les catégories du template (carte fidélité du commerce), triées par sortOrder puis nom.
    func categories(for template: CardTemplate) -> [MemberCategory] {
        let request = MemberCategory.fetchRequest()
        request.predicate = NSPredicate(format: "template == %@", template)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \MemberCategory.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \MemberCategory.name, ascending: true)
        ]
        return (try? viewContext.fetch(request)) ?? []
    }

    /// Membres appartenant à une catégorie donnée.
    func clientCards(in category: MemberCategory) -> [ClientCard] {
        guard let members = category.members?.allObjects as? [ClientCard] else { return [] }
        return members.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
    }

    /// Nombre de membres dans une catégorie.
    func memberCount(for category: MemberCategory) -> Int {
        category.members?.count ?? 0
    }

    /// Catégorie par identifiant serveur (pour mise à jour locale après API).
    func category(byServerId serverId: String, template: CardTemplate) -> MemberCategory? {
        let request = MemberCategory.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@ AND template == %@", serverId, template)
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }

    /// Après suppression serveur : retire la fiche membre locale (tampons en cascade).
    func deleteClientCard(_ card: ClientCard) {
        viewContext.delete(card)
        save()
    }

    /// Après purge serveur de tous les membres : vide les cartes client du template.
    func deleteAllClientCards(for template: CardTemplate) {
        for c in clientCards(for: template) {
            viewContext.delete(c)
        }
        save()
    }

    // MARK: - Persistance

    private func save() {
        guard viewContext.hasChanges else { return }
        do {
            try viewContext.save()
            updateTrigger += 1
        } catch {
            dataServiceLog.error("DataService save error: \(String(describing: error))")
        }
    }
}
