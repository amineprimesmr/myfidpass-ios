//
//  SyncService.swift
//  myfidpass
//
//  Sync avec l’API MyFidpass : auth/me puis settings, stats, members, transactions par slug.
//

import Foundation
import CoreData
import Combine

@MainActor
final class SyncService: ObservableObject {
    private let context: NSManagedObjectContext
    @Published var lastSyncDate: Date?
    @Published private(set) var isSyncing = false
    @Published private(set) var lastError: String?

    private static let lastSyncKey = "myfidpass.sync.lastSyncDate"
    private static let templateLastSavedKey = "myfidpass.templateLastSavedAt"
    /// Dernière date d’envoi du logo depuis l’app (last-write-wins avec le SaaS).
    static let lastLogoUploadAtKey = "myfidpass.lastLogoUploadAt"

    init(context: NSManagedObjectContext) {
        self.context = context
        self.lastSyncDate = UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date
    }

    private static let syncThrottleInterval: TimeInterval = 15

    /// Récupère user + businesses, puis pour le commerce courant (slug) : settings, stats, members, transactions.
    func syncIfNeeded(force: Bool = false) async {
        guard AuthStorage.isLoggedIn, let token = APIClient.shared.authToken, !token.isEmpty else { return }
        if !force, let last = lastSyncDate, Date().timeIntervalSince(last) < Self.syncThrottleInterval, !isSyncing {
            return
        }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }
        do {
            let me: AuthMeResponse = try await APIClient.shared.request(.authMe)
            let slug = resolvedSlug(from: me)
            if let slug {
                let lastSaved = UserDefaults.standard.object(forKey: Self.templateLastSavedKey) as? Date
                let skipTemplate = (lastSaved != nil && lastSyncDate != nil && lastSaved! > lastSyncDate!)
                try await syncBusiness(slug: slug, skipTemplateOverwrite: skipTemplate)
            }
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: Self.lastSyncKey)
        } catch APIError.unauthorized {
            lastError = "Session expirée"
            AppState.shared.showError(lastError ?? "Session expirée")
        } catch {
            if isCancelledNetworkError(error) {
                lastError = nil
                return
            }
            lastError = (error as? APIError)?.errorDescription ?? error.localizedDescription
            AppState.shared.showError(lastError ?? "Erreur de synchronisation")
        }
    }

    /// Ne pas afficher « Réseau: cancelled » : requête annulée (changement d’écran, refresh rapide, etc.).
    private func isCancelledNetworkError(_ error: Error) -> Bool {
        if case .network(let underlying) = error as? APIError {
            return (underlying as? URLError)?.code == .cancelled
        }
        return (error as? URLError)?.code == .cancelled
    }

    private func syncBusiness(slug: String, skipTemplateOverwrite: Bool = false) async throws {
        // Un tuple `try await (a, b, …)` exécute chaque requête l’une après l’autre. `async let` les lance en parallèle.
        async let settingsTask = APIClient.shared.request(.businessSettings(slug: slug)) as BusinessSettingsResponse
        async let statsTask = APIClient.shared.request(.businessStats(slug: slug, period: nil)) as BusinessStatsResponse
        async let membersTask = APIClient.shared.request(.businessMembers(slug: slug, limit: 500, offset: 0, search: nil, filter: nil, sort: nil)) as BusinessMembersResponse
        async let transactionsTask = APIClient.shared.request(.businessTransactions(slug: slug, limit: 100, offset: 0, memberId: nil, days: nil, type: nil)) as BusinessTransactionsResponse
        async let categoriesTask = fetchCategoriesOptional(slug: slug)

        let settings = try await settingsTask
        let stats = try await statsTask
        let members = try await membersTask
        let transactions = try await transactionsTask
        let categoriesResponse = await categoriesTask

        try mergeIntoCoreData(slug: slug, settings: settings, stats: stats, members: members, transactions: transactions, categories: categoriesResponse, skipTemplateOverwrite: skipTemplateOverwrite)
    }

    private func fetchCategoriesOptional(slug: String) async -> BusinessCategoriesResponse? {
        do {
            return try await APIClient.shared.request(.businessCategories(slug: slug)) as BusinessCategoriesResponse
        } catch {
            return nil
        }
    }

    private func mergeIntoCoreData(slug: String, settings: BusinessSettingsResponse, stats: BusinessStatsResponse, members: BusinessMembersResponse, transactions: BusinessTransactionsResponse, categories: BusinessCategoriesResponse?, skipTemplateOverwrite: Bool = false) throws {
        let business = findOrCreateBusiness(slug: slug)
        business.slug = slug
        business.name = stats.businessName ?? settings.organizationName ?? "Mon Commerce"
        business.address = settings.locationAddress
        business.updatedAt = Date()

        let template = findOrCreateCardTemplate(business: business)
        if !skipTemplateOverwrite {
            template.displayName = settings.organizationName ?? "Ma Carte"
            template.primaryColorHex = settings.backgroundColor?.replacingOccurrences(of: "#", with: "") ?? "2563EB"
            template.accentColorHex = settings.foregroundColor?.replacingOccurrences(of: "#", with: "") ?? "F59E0B"
            if let s = settings.requiredStamps, s > 0 { template.requiredStamps = Int32(s) }
            // Logo : dernière modification gagne (app vs SaaS). On prend le serveur seulement si logo_updated_at > lastLogoUploadAt.
            if let url = settings.logoUrl, !url.isEmpty {
                let serverLogoAt = settings.logoUpdatedAt.flatMap { parseISO8601($0) }
                let localUploadAt = UserDefaults.standard.object(forKey: Self.lastLogoUploadAtKey) as? Date
                let useServerLogo = localUploadAt == nil || (serverLogoAt != nil && serverLogoAt! > localUploadAt!)
                if useServerLogo { template.logoURL = url }
            }
            if let emoji = settings.stampEmoji { template.stampEmoji = emoji }
            template.updatedAt = Date()
        }

        if let categories = categories {
            for (index, dto) in categories.categories.enumerated() {
                let cat = findOrCreateCategory(template: template, serverId: dto.id, name: dto.name, colorHex: dto.colorHex, sortOrder: Int32(dto.sortOrder ?? index))
                cat.name = dto.name
                cat.colorHex = dto.colorHex
                cat.sortOrder = Int32(dto.sortOrder ?? index)
            }
        }

        for m in members.members {
            let card = findOrCreateClientCard(template: template, memberId: m.id, name: m.name, email: m.email, points: m.points ?? 0)
            card.stampsCount = Int32(m.points ?? 0)
            card.clientDisplayName = m.name ?? "Client"
            card.clientEmail = m.email
            card.updatedAt = parseISO8601(m.lastVisitAt) ?? card.updatedAt
            if let categoryIds = m.categoryIds, categories != nil {
                let cats = categoryIds.compactMap { findCategory(byServerId: $0, template: template) }
                card.categories = NSSet(array: cats)
            } else {
                card.categories = nil
            }
        }

        for t in transactions.transactions {
            guard let memberId = t.memberId else { continue }
            let cardRequest = ClientCard.fetchRequest()
            cardRequest.predicate = NSPredicate(format: "qrCodeValue == %@ AND template == %@", memberId, template)
            cardRequest.fetchLimit = 1
            guard let card = try context.fetch(cardRequest).first else { continue }
            if let tid = t.id, findStamp(serverId: tid) != nil { continue }
            let stamp = Stamp(context: context)
            stamp.id = UUID()
            stamp.clientCard = card
            stamp.createdAt = parseISO8601(t.createdAt) ?? Date()
            stamp.note = t.id.map { "txn:\($0)" } ?? t.metadata
        }
        try context.save()
    }

    private func parseISO8601(_ s: String?) -> Date? {
        guard let s = s else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }

    /// Slug effectif : préférence locale si encore dans la liste /me, sinon premier commerce.
    private func resolvedSlug(from me: AuthMeResponse) -> String? {
        let list = me.businesses
        guard !list.isEmpty else {
            AuthStorage.currentBusinessSlug = nil
            return nil
        }
        if let saved = AuthStorage.currentBusinessSlug,
           list.contains(where: { $0.slug == saved }) {
            return saved
        }
        let first = list[0].slug
        AuthStorage.currentBusinessSlug = first
        return first
    }

    private func findOrCreateBusiness(slug: String) -> Business {
        let request = Business.fetchRequest()
        request.predicate = NSPredicate(format: "slug == %@", slug)
        request.fetchLimit = 1
        if let b = try? context.fetch(request).first { return b }
        let b = Business(context: context)
        b.id = UUID()
        b.slug = slug
        b.name = "Mon Commerce"
        b.createdAt = Date()
        b.updatedAt = Date()
        return b
    }

    private func findOrCreateCardTemplate(business: Business) -> CardTemplate {
        let request = CardTemplate.fetchRequest()
        request.predicate = NSPredicate(format: "business == %@", business)
        request.fetchLimit = 1
        if let t = try? context.fetch(request).first { return t }
        let t = CardTemplate(context: context)
        t.id = UUID()
        t.business = business
        t.displayName = "Ma Carte"
        t.requiredStamps = 10
        t.primaryColorHex = "2563EB"
        t.accentColorHex = "F59E0B"
        t.createdAt = Date()
        t.updatedAt = Date()
        return t
    }

    private func findOrCreateClientCard(template: CardTemplate, memberId: String, name: String?, email: String?, points: Int) -> ClientCard {
        let request = ClientCard.fetchRequest()
        request.predicate = NSPredicate(format: "qrCodeValue == %@ AND template == %@", memberId, template)
        request.fetchLimit = 1
        if let c = try? context.fetch(request).first { return c }
        let c = ClientCard(context: context)
        c.id = UUID()
        c.template = template
        c.qrCodeValue = memberId
        c.clientIdentifier = memberId
        c.clientDisplayName = name ?? "Client"
        c.clientEmail = email
        c.stampsCount = Int32(points)
        c.createdAt = Date()
        c.updatedAt = Date()
        return c
    }

    private func findStamp(serverId: String) -> Stamp? {
        let request = Stamp.fetchRequest()
        request.predicate = NSPredicate(format: "note == %@", "txn:\(serverId)")
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func findOrCreateCategory(template: CardTemplate, serverId: String, name: String, colorHex: String?, sortOrder: Int32) -> MemberCategory {
        if let existing = findCategory(byServerId: serverId, template: template) { return existing }
        let cat = MemberCategory(context: context)
        cat.serverId = serverId
        cat.name = name
        cat.colorHex = colorHex
        cat.sortOrder = sortOrder
        cat.template = template
        return cat
    }

    private func findCategory(byServerId serverId: String, template: CardTemplate) -> MemberCategory? {
        let request = MemberCategory.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@ AND template == %@", serverId, template)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    /// Plus utilisé : le scan envoie directement à l’API. Gardé pour compatibilité.
    func pushLocalChanges() async { }
}
