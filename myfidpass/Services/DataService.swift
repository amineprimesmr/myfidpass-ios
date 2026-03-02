//
//  DataService.swift
//  myfidpass
//
//  Service d’accès et de mise à jour des données (Business, CardTemplate, ClientCard, Stamp).
//  Prêt pour branchement API / CloudKit plus tard.
//

import CoreData
import Foundation
import Combine

@MainActor
final class DataService: ObservableObject {
    private let viewContext: NSManagedObjectContext
    /// Déclenche les mises à jour des vues qui utilisent ce service.
    @Published private(set) var updateTrigger: Int = 0

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }

    // MARK: - Business

    func currentBusiness() -> Business? {
        let request = Business.fetchRequest()
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Business.createdAt, ascending: true)]
        return try? viewContext.fetch(request).first
    }

    func createOrGetCurrentBusiness(name: String = "Mon Commerce", email: String? = nil) -> Business {
        if let existing = currentBusiness() { return existing }
        let b = Business(context: viewContext)
        b.id = UUID()
        b.name = name
        b.email = email
        b.createdAt = Date()
        b.updatedAt = Date()
        save()
        return b
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
        primaryColorHex: String = "2563EB",
        accentColorHex: String = "F59E0B"
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

    func clientCard(byQRCodeValue qrCodeValue: String) -> ClientCard? {
        let request = ClientCard.fetchRequest()
        request.predicate = NSPredicate(format: "qrCodeValue == %@", qrCodeValue)
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }

    func findOrCreateClientCard(qrCodeValue: String, template: CardTemplate, clientDisplayName: String?) -> ClientCard {
        if let existing = clientCard(byQRCodeValue: qrCodeValue) { return existing }
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
        let request = ClientCard.fetchRequest()
        request.predicate = NSPredicate(format: "template == %@", template)
        return (try? viewContext.count(for: request)) ?? 0
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

    // MARK: - Persistance

    private func save() {
        guard viewContext.hasChanges else { return }
        do {
            try viewContext.save()
            updateTrigger += 1
        } catch {
            print("DataService save error: \(error)")
        }
    }
}
