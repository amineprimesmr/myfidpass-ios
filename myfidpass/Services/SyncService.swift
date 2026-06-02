//
//  SyncService.swift
//  myfidpass
//
//  Sync avec l’API MyFidpass : auth/me puis settings, stats, members, transactions par slug.
//  La fusion Core Data s’exécute dans un contexte enfant (file privée) puis save du viewContext sur le main.
//

import Foundation
import CoreData
import Combine
import UIKit
import os.log

private let syncServiceLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "myfidpass", category: "Sync")

/// Sync abandonnée (déconnexion / suppression de compte pendant un pull réseau).
private enum SyncSessionEnded: Error { case sessionEnded }

fileprivate enum SyncMergeUserDefaults {
    static let lastLogoUploadAt = "myfidpass.lastLogoUploadAt"
    static let lastLogoIconUploadAt = "myfidpass.lastLogoIconUploadAt"
    static let lastNotificationIconUploadAt = "myfidpass.lastNotificationIconUploadAt"
}

/// Une seule synchronisation à la fois. Plusieurs `syncIfNeeded` / `syncAfterServerMutation` lancés en parallèle
/// (ContentView `.onAppear`, retour premier plan, `refreshable`, notifications) enclenchaient plusieurs
/// Plusieurs syncs concurrentes + `mergeChanges` depuis des notifications → crash Core Data fréquent après connexion.
@MainActor
private final class SyncSerialExecutor {
    private var tail: Task<Void, Never>?

    func enqueue(_ work: @escaping @MainActor () async -> Void) async {
        let previous = tail
        let job = Task { @MainActor in
            await previous?.value
            await work()
        }
        tail = job
        await job.value
    }
}

@MainActor
final class SyncService: ObservableObject {
    private let container: NSPersistentContainer
    /// Mise à jour profil / abonnement après chaque `GET /api/auth/me` (ex. paiement Stripe : la sync voit l’état actif avant que l’utilisateur rouvre la feuille d’abonnement).
    private weak var authService: AuthService?

    func attachAuthService(_ service: AuthService) {
        authService = service
    }

    @Published var lastSyncDate: Date?
    @Published private(set) var isSyncing = false
    @Published private(set) var lastError: String?
    /// Incrémenté à chaque échec de synchro (hors annulation) : l’UI peut réafficher le bandeau d’erreur.
    @Published private(set) var syncErrorRevision: Int = 0

    private static let lastSyncKey = "myfidpass.sync.lastSyncDate"
    private static let templateLastSavedKey = "myfidpass.templateLastSavedAt"
    /// Dernière date d’envoi du logo depuis l’app (last-write-wins avec le SaaS).
    static let lastLogoUploadAtKey = SyncMergeUserDefaults.lastLogoUploadAt
    static let lastLogoIconUploadAtKey = SyncMergeUserDefaults.lastLogoIconUploadAt
    /// Dernier envoi de l’icône campagnes / `…/notification-icon` (cache-bust côté aperçu, comme les logos).
    private static let lastNotificationIconUploadAtKey = SyncMergeUserDefaults.lastNotificationIconUploadAt

    /// Incrémenté à chaque fin de session : les syncs encore en file n’écrivent plus d’erreur ni de bandeau.
    private var sessionGeneration = 0
    private var sessionEndObserver: AnyCancellable?

    init(container: NSPersistentContainer, authService: AuthService? = nil) {
        self.container = container
        self.authService = authService
        self.lastSyncDate = UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date
        sessionEndObserver = NotificationCenter.default
            .publisher(for: .myfidpassLocalSessionDidEnd)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.resetForSessionEnd()
            }
    }

    /// Déconnexion / suppression de compte : oublie les syncs en cours et efface les erreurs affichées.
    func resetForSessionEnd() {
        sessionGeneration += 1
        lastError = nil
        invalidateSyncThrottle()
    }

    private func syncStillOwnedByCurrentSession(_ capturedGeneration: Int) -> Bool {
        capturedGeneration == sessionGeneration && AuthStorage.isLoggedIn
    }

    /// Push silencieux serveur : désactivé volontairement en mode perf agressif.
    static func handleSilentDashboardPush(completion: @escaping (UIBackgroundFetchResult) -> Void) {
        completion(.noData)
    }

    private static let syncThrottleInterval: TimeInterval = 45
    /// L’API dashboard plafonne à 200 membres par page (`dashboard.js`).
    private static let membersAPIPageSize = 200
    private static let transactionsAPIPageSize = 100
    /// Mode perf agressif : limite volontairement le volume synchronisé par passe.
    private static let maxMemberPages = 4
    /// `sort=desc` : on garde les transactions récentes en priorité.
    private static let maxTransactionPages = 4

    private let syncSerialExecutor = SyncSerialExecutor()

    /// Invalide le délai minimal entre syncs (ex. après un `PATCH` réussi) pour autoriser un pull immédiat sans `force`.
    func invalidateSyncThrottle() {
        lastSyncDate = nil
        UserDefaults.standard.removeObject(forKey: Self.lastSyncKey)
    }

    /// `YYYY-MM` (aligné `CommerceStatsMonthNavigator`) : invalide le cache stats du mois après sync.
    private static func currentStatsMonthKey(_ date: Date = Date()) -> String {
        let cal = Calendar(identifier: .gregorian)
        let d = cal.startOfDay(for: date)
        let y = cal.component(.year, from: d)
        let m = cal.component(.month, from: d)
        return String(format: "%04d-%02d", y, m)
    }

    private func postSyncFailureBanner() {
        guard let msg = lastError, !msg.isEmpty else { return }
        syncErrorRevision += 1
        NotificationCenter.default.post(
            name: .myfidpassRemoteSyncDidFail,
            object: nil,
            userInfo: ["message": msg as Any]
        )
    }

    /// Recharge serveur → Core Data après une mutation locale enregistrée côté API.
    /// **Toujours en `force: true`** : sinon le throttle 45 s (`syncThrottleInterval`) annule le pull — les **transactions**
    /// (fil « Dernières transactions ») ne sont jamais fusionnées et l’accueil reste vide ou obsolète après scan.
    func syncAfterServerMutation() async {
        await syncIfNeeded(force: true)
    }

    /// Récupère user + businesses, puis pour le commerce courant (slug) : settings, stats, membres, transactions.
    func syncIfNeeded(force: Bool = false) async {
        await syncSerialExecutor.enqueue { [self] in
            await self.performSyncIfNeeded(force: force)
        }
    }

    private func performSyncIfNeeded(force: Bool) async {
        let syncGeneration = sessionGeneration
        guard syncStillOwnedByCurrentSession(syncGeneration),
              let token = APIClient.shared.authToken, !token.isEmpty else { return }
        if authService?.isPlatformAdmin == true, authService?.adminShowsMerchantWorkspace != true {
            return
        }
        if !force, let last = lastSyncDate, Date().timeIntervalSince(last) < Self.syncThrottleInterval, !isSyncing {
            return
        }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }
        do {
            await APIClient.shared.ensureValidAccessTokenWithRetry(maxAttempts: 3)

            let cachedSlug = AuthStorage.currentBusinessSlug.flatMap { s -> String? in
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            }
            let lastSaved = UserDefaults.standard.object(forKey: Self.templateLastSavedKey) as? Date
            let skipTemplate = (lastSaved != nil && lastSyncDate != nil && lastSaved! > lastSyncDate!)

            let me: AuthMeResponse = try await APIClient.shared.request(.authMe)
            guard syncStillOwnedByCurrentSession(syncGeneration) else { return }
            authService?.applyAuthMeResponse(me)

            let slug = resolvedSlug(from: me) ?? cachedSlug
            if let slug {
                try await syncBusiness(slug: slug, skipTemplateOverwrite: skipTemplate, syncGeneration: syncGeneration)
            }

            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: Self.lastSyncKey)
            if let slug = slug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty {
                MerchantStatisticsDiskCache.removePeriod(slug: slug, period: Self.currentStatsMonthKey())
            }
            guard syncStillOwnedByCurrentSession(syncGeneration) else { return }
        } catch APIError.unauthorized {
            guard syncStillOwnedByCurrentSession(syncGeneration) else { return }
            await APIClient.shared.ensureValidAccessTokenWithRetry(maxAttempts: 3)
            let refresh = await APIClient.shared.tryRefreshToken()
            if case .success = refresh {
                await performSyncIfNeeded(force: true)
                return
            }
            guard syncStillOwnedByCurrentSession(syncGeneration) else { return }
            if refresh == .transientFailure || APIClient.accessTokenStillWithinValidityWindow() {
                lastError = "Synchronisation interrompue. Tirez pour rafraîchir ou réessayez dans un instant."
                postSyncFailureBanner()
                return
            }
            lastError = "Session expirée"
            AppState.shared.showError(lastError ?? "Session expirée")
            postSyncFailureBanner()
        } catch APIError.subscriptionRequired {
            guard syncStillOwnedByCurrentSession(syncGeneration) else { return }
            lastError = "Abonnement inactif ou expiré. Réactivez votre offre (Stripe) pour synchroniser le tableau de bord."
            postSyncFailureBanner()
        } catch let err as APIError where err.isHTTPResourceMissing {
            guard syncStillOwnedByCurrentSession(syncGeneration) else { return }
            // Souvent slug / URL mal formée ou commerce supprimé : 2ᵉ essai après relecture du profil (slug recalculé).
            do {
                let meRetry: AuthMeResponse = try await APIClient.shared.request(.authMe)
                authService?.applyAuthMeResponse(meRetry)
                guard let slugRetry = resolvedSlug(from: meRetry) else {
                    presentSyncFailure(err, syncGeneration: syncGeneration)
                    return
                }
                let lastSaved = UserDefaults.standard.object(forKey: Self.templateLastSavedKey) as? Date
                let skipTemplate = (lastSaved != nil && lastSyncDate != nil && lastSaved! > lastSyncDate!)
                try await syncBusiness(slug: slugRetry, skipTemplateOverwrite: skipTemplate, syncGeneration: syncGeneration)
                lastSyncDate = Date()
                UserDefaults.standard.set(lastSyncDate, forKey: Self.lastSyncKey)
                if let slug = resolvedSlug(from: meRetry)?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty {
                    MerchantStatisticsDiskCache.removePeriod(slug: slug, period: Self.currentStatsMonthKey())
                }
            } catch SyncSessionEnded.sessionEnded {
                return
            } catch {
                presentSyncFailure(error, syncGeneration: syncGeneration)
            }
        } catch SyncSessionEnded.sessionEnded {
            return
        } catch {
            presentSyncFailure(error, syncGeneration: syncGeneration)
        }
    }

    /// Échec de synchro : l’app continue avec Core Data ; bandeau + `lastError` (Réglages).
    private func presentSyncFailure(_ error: Error, syncGeneration: Int) {
        guard syncStillOwnedByCurrentSession(syncGeneration) else { return }
        if isCancelledNetworkError(error) {
            lastError = nil
            return
        }
        if let api = error as? APIError, api.isHTTPResourceMissing {
            lastError =
                "Le serveur ne trouve pas ce commerce (ou la connexion est désynchronisée). Ouvrez l’onglet Commerce pour vérifier l’établissement, ou fermez puis rouvrez l’app."
        } else if let api = error as? APIError, case .sessionRefreshTransient = api {
            let hasProfile = !(authService?.businesses.isEmpty ?? true)
            lastError = hasProfile
                ? "Synchronisation du commerce incomplète. Réessayez dans un instant."
                : (api.errorDescription ?? "Connexion instable. Réessayez.")
        } else {
            lastError = (error as? APIError)?.errorDescription ?? error.localizedDescription
            if let api = error as? APIError, case let .decoding(underlying) = api {
                syncServiceLog.error("Decoding sync: \(String(reflecting: underlying))")
            } else {
                syncServiceLog.error("Synchro: \(String(describing: error))")
            }
        }
        postSyncFailureBanner()
    }

    /// Ne pas afficher « Réseau: cancelled » : requête annulée (changement d’écran, refresh rapide, etc.).
    private func isCancelledNetworkError(_ error: Error) -> Bool {
        if case .network(let underlying) = error as? APIError {
            return (underlying as? URLError)?.code == .cancelled
        }
        return (error as? URLError)?.code == .cancelled
    }

    private func syncBusiness(slug: String, skipTemplateOverwrite: Bool = false, syncGeneration: Int) async throws {
        guard syncStillOwnedByCurrentSession(syncGeneration) else { throw SyncSessionEnded.sessionEnded }
        // Vague 1 : séquentielle, plus sûre que trois requêtes parallèles au démarrage.
        let settings: BusinessSettingsResponse = try await APIClient.shared.request(.businessSettings(slug: slug))
        guard syncStillOwnedByCurrentSession(syncGeneration) else { throw SyncSessionEnded.sessionEnded }
        ScanFlowSettingsCache.store(settings, for: slug)
        let stats: BusinessStatsResponse = try await APIClient.shared.request(.businessStats(slug: slug, period: nil))
        let categoriesResponse = await fetchCategoriesOptional(slug: slug)
        guard syncStillOwnedByCurrentSession(syncGeneration) else { throw SyncSessionEnded.sessionEnded }
        updateSnapshotRemoteBackground(settings: settings, slug: slug)

        // Vague 2 : membres + transactions en parallèle, puis un seul merge Core Data (UI notifiée).
        async let membersTask = fetchAllMembers(slug: slug)
        async let transactionsTask = fetchAllTransactions(slug: slug)
        let members = try await membersTask
        let transactions = try await transactionsTask
        guard syncStillOwnedByCurrentSession(syncGeneration) else { throw SyncSessionEnded.sessionEnded }

        try await mergeOnBackground(
            slug: slug,
            settings: settings,
            stats: stats,
            members: members,
            transactions: transactions,
            categories: categoriesResponse,
            skipTemplateOverwrite: skipTemplateOverwrite,
            notifyUI: true
        )
    }

    /// Met à jour le snapshot d'aperçu carte depuis GET settings pour que l'accueil reflète
    /// logo, couleurs, mode, récompenses, etc. après modification sur un autre appareil.
    /// Préserve uniquement l'état brouillon local (fond photo, icône tampon en cours d'édition).
    private func updateSnapshotRemoteBackground(settings: BusinessSettingsResponse, slug: String) {
        let existing = CardPreviewDisplaySnapshotStore.load(slug: slug)
        var merged = Self.minimalDisplaySnapshotFromSettings(settings, slug: slug, preserving: existing)
        guard existing != merged else { return }
        CardPreviewDisplaySnapshotStore.save(merged, slug: slug)
    }

    /// URL absolue du fond carte (API authentifiée), alignée sur `MyCardView` / `DashboardHomeCardModel`.
    private static func cardBackgroundRemoteURLString(slug: String, updatedAt: String?) -> String {
        let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let enc = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        var bgURL = "\(base)/api/businesses/\(enc)/card-background"
        if let v = updatedAt?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty {
            let q = v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v
            bgURL += "?v=\(q)"
        }
        return bgURL
    }

    /// Snapshot minimal depuis GET settings quand UserDefaults n’a encore rien (pas encore ouvert « Ma carte »).
    private static func minimalDisplaySnapshotFromSettings(
        _ settings: BusinessSettingsResponse,
        slug: String,
        preserving existing: CardPreviewDisplaySnapshot? = nil
    ) -> CardPreviewDisplaySnapshot {
        CardPreviewSnapshotBuilder.fromSettings(settings, slug: slug, preserving: existing)
    }

    private func fetchAllMembers(slug: String) async throws -> BusinessMembersResponse {
        var collected: [MemberDTO] = []
        var offset = 0
        var serverTotal: Int?
        for _ in 0..<Self.maxMemberPages {
            let page = try await APIClient.shared.request(
                .businessMembers(
                    slug: slug,
                    limit: Self.membersAPIPageSize,
                    offset: offset,
                    search: nil,
                    filter: nil,
                    sort: nil
                )
            ) as BusinessMembersResponse
            if serverTotal == nil { serverTotal = page.total }
            if page.members.isEmpty { break }
            collected.append(contentsOf: page.members)
            if page.members.count < Self.membersAPIPageSize { break }
            offset += Self.membersAPIPageSize
        }
        return BusinessMembersResponse(members: collected, total: serverTotal ?? collected.count)
    }

    private func fetchAllTransactions(slug: String) async throws -> BusinessTransactionsResponse {
        var collected: [TransactionDTO] = []
        var seenIds = Set<String>()
        var offset = 0
        var serverTotal: Int?
        for _ in 0..<Self.maxTransactionPages {
            let page = try await APIClient.shared.request(
                .businessTransactions(
                    slug: slug,
                    limit: Self.transactionsAPIPageSize,
                    offset: offset,
                    memberId: nil,
                    days: nil,
                    type: nil,
                    sort: "desc"
                )
            ) as BusinessTransactionsResponse
            if serverTotal == nil { serverTotal = page.total }
            if page.transactions.isEmpty { break }
            for t in page.transactions {
                if let id = t.id, !id.isEmpty {
                    guard !seenIds.contains(id) else { continue }
                    seenIds.insert(id)
                }
                collected.append(t)
            }
            if page.transactions.count < Self.transactionsAPIPageSize { break }
            offset += Self.transactionsAPIPageSize
        }
        return BusinessTransactionsResponse(transactions: collected, total: serverTotal ?? collected.count)
    }

    private func fetchCategoriesOptional(slug: String) async -> BusinessCategoriesResponse? {
        do {
            return try await APIClient.shared.request(.businessCategories(slug: slug)) as BusinessCategoriesResponse
        } catch {
            return nil
        }
    }

    private func mergeOnBackground(
        slug: String,
        settings: BusinessSettingsResponse,
        stats: BusinessStatsResponse,
        members: BusinessMembersResponse,
        transactions: BusinessTransactionsResponse,
        categories: BusinessCategoriesResponse?,
        skipTemplateOverwrite: Bool,
        notifyUI: Bool = true
    ) async throws {
        let c = container
        let logoKey = SyncMergeUserDefaults.lastLogoUploadAt
        let logoIconKey = SyncMergeUserDefaults.lastLogoIconUploadAt
        // Contexte enfant → parent : aucun `mergeChanges` global (observateur supprimé dans Persistence).
        // Sauvegarde du parent sur la file principale, sans `perform` + `Task` imbriqués (réentrance / malloc).
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let child = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            child.parent = c.viewContext
            child.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            child.automaticallyMergesChangesFromParent = false
            child.shouldDeleteInaccessibleFaults = true

            child.perform {
                do {
                    try SyncCoreDataMerge.apply(
                        slug: slug,
                        settings: settings,
                        stats: stats,
                        members: members,
                        transactions: transactions,
                        categories: categories,
                        skipTemplateOverwrite: skipTemplateOverwrite,
                        lastLogoUploadKey: logoKey,
                        lastLogoIconUploadKey: logoIconKey,
                        context: child
                    )
                    if child.hasChanges {
                        try child.save()
                    }
                    DispatchQueue.main.async {
                        do {
                            if c.viewContext.hasChanges {
                                try c.viewContext.save()
                            }
                            if notifyUI {
                                NotificationCenter.default.post(name: .myfidpassMerchantCoreDataDidMergeFromSync, object: nil)
                            }
                            cont.resume()
                        } catch {
                            cont.resume(throwing: error)
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        cont.resume(throwing: error)
                    }
                }
            }
        }
    }

    /// Slug effectif : préférence locale si encore dans la liste /me, sinon premier commerce. Admin : conserve un slug hors liste.
    private func resolvedSlug(from me: AuthMeResponse) -> String? {
        let list = me.businesses
        let isAdmin = me.user.isAdmin == true
        if let saved = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines),
           !saved.isEmpty {
            if isAdmin { return saved }
            if list.contains(where: { $0.slug == saved }) { return saved }
        }
        guard !list.isEmpty else {
            if !isAdmin { AuthStorage.currentBusinessSlug = nil }
            return nil
        }
        let first = list[0].slug
        AuthStorage.currentBusinessSlug = first
        return first
    }

    /// Plus utilisé : le scan envoie directement à l’API. Gardé pour compatibilité.
    func pushLocalChanges() async { }
}

// MARK: - Fusion Core Data (file privée, hors MainActor)

fileprivate enum SyncCoreDataMerge {
    static func parseISO8601(_ s: String?) -> Date? {
        guard let s = s else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }

    private static func normalizedTxnDedupKey(fromStampNote note: String?) -> String? {
        let raw = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard raw.hasPrefix("txn:"), raw.count > 4 else { return nil }
        let payload = raw.dropFirst(4)
        if let pipe = payload.firstIndex(of: "|") {
            let tid = String(payload[..<pipe]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tid.isEmpty else { return nil }
            return "txn:\(tid)"
        }
        return raw
    }

    static func apply(
        slug: String,
        settings: BusinessSettingsResponse,
        stats: BusinessStatsResponse,
        members: BusinessMembersResponse,
        transactions: BusinessTransactionsResponse,
        categories: BusinessCategoriesResponse?,
        skipTemplateOverwrite: Bool,
        lastLogoUploadKey: String,
        lastLogoIconUploadKey: String,
        context: NSManagedObjectContext
    ) throws {
        let business = findOrCreateBusiness(slug: slug, context: context)
        business.slug = slug
        business.name = stats.businessName ?? settings.organizationName ?? "Mon Commerce"
        business.address = settings.locationAddress
        business.updatedAt = Date()

        let template = findOrCreateCardTemplate(business: business, context: context)
        let existingCardsByMemberId = existingCardsIndex(for: template, context: context)
        let existingCategoriesByServerId = existingCategoriesIndex(for: template, context: context)
        var txnStampsByKey = existingTxnStampIndex(for: template, context: context)
        MerchantLogoAssetCache.applyMerchantLogoTimestamps(from: settings)
        if !skipTemplateOverwrite {
            template.displayName = settings.organizationName ?? "Ma Carte"
            template.primaryColorHex = settings.backgroundColor?.replacingOccurrences(of: "#", with: "")
                ?? AppTheme.WalletCardAppearanceDefaults.backgroundHex
            template.accentColorHex = settings.foregroundColor?.replacingOccurrences(of: "#", with: "")
                ?? AppTheme.WalletCardAppearanceDefaults.bodyTextHex
            if let s = settings.requiredStamps, s > 0 { template.requiredStamps = Int32(s) }
            if let url = settings.logoUrl, !url.isEmpty {
                let current = template.logoURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let pendingLocal = CardLogoStorage.isLocalPendingLogoReference(current)
                if !pendingLocal {
                    let serverLogoAt = settings.logoUpdatedAt.flatMap { parseISO8601($0) }
                    let localUploadAt = UserDefaults.standard.object(forKey: lastLogoUploadKey) as? Date
                    let useServerLogo = localUploadAt == nil || (serverLogoAt != nil && serverLogoAt! > localUploadAt!)
                    if useServerLogo { template.logoURL = url }
                }
            }
            if let url = settings.logoIconUrl, !url.isEmpty {
                let current = template.logoIconURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let pendingLocal = CardLogoStorage.isLocalPendingLogoIconReference(current)
                if !pendingLocal {
                    let serverAt = settings.logoIconUpdatedAt.flatMap { parseISO8601($0) }
                    let localUploadAt = UserDefaults.standard.object(forKey: lastLogoIconUploadKey) as? Date
                    let useServer = localUploadAt == nil || (serverAt != nil && serverAt! > localUploadAt!)
                    if useServer { template.logoIconURL = url }
                }
            }
            if let emoji = settings.stampEmoji { template.stampEmoji = emoji }
            template.updatedAt = Date()
        }

        var categoryByServerId = existingCategoriesByServerId
        if let categories = categories {
            for (index, dto) in categories.categories.enumerated() {
                let cat = categoryByServerId[dto.id] ?? {
                    let created = MemberCategory(context: context)
                    created.serverId = dto.id
                    created.template = template
                    categoryByServerId[dto.id] = created
                    return created
                }()
                cat.name = dto.name
                cat.colorHex = dto.colorHex
                cat.sortOrder = Int32(dto.sortOrder ?? index)
            }
        }

        var cardsByMemberId = existingCardsByMemberId
        for m in members.members {
            let card = cardsByMemberId[m.id] ?? {
                let created = ClientCard(context: context)
                created.id = UUID()
                created.template = template
                created.qrCodeValue = m.id
                created.clientIdentifier = m.id
                created.clientDisplayName = m.name ?? "Client"
                created.clientEmail = m.email
                created.stampsCount = Int32(m.points ?? 0)
                created.createdAt = Date()
                created.updatedAt = Date()
                cardsByMemberId[m.id] = created
                return created
            }()
            card.stampsCount = Int32(m.points ?? 0)
            card.clientDisplayName = m.name ?? "Client"
            card.clientEmail = m.email
            card.updatedAt = parseISO8601(m.lastVisitAt) ?? card.updatedAt
            // Vague 2 de sync passe `categories: nil` : ne pas effacer les catégories déjà fusionnées en vague 1.
            if let categoryIds = m.categoryIds, categories != nil {
                let cats = categoryIds.compactMap { categoryByServerId[$0] }
                card.categories = NSSet(array: cats)
            }
        }

        var txnStampKeys = Set(txnStampsByKey.keys)
        for t in transactions.transactions {
            guard let memberId = t.memberId else { continue }
            guard let card = cardsByMemberId[memberId] else { continue }
            if let tid = t.id {
                let key = "txn:\(tid)"
                if txnStampKeys.contains(key) { continue }
                txnStampKeys.insert(key)
            }
            let stamp = Stamp(context: context)
            stamp.id = UUID()
            stamp.clientCard = card
            stamp.createdAt = parseISO8601(t.createdAt) ?? Date()
            if let tid = t.id {
                var noteBody = "txn:\(tid)"
                if let p = t.points {
                    noteBody += "|p:\(p)"
                }
                stamp.note = noteBody
                txnStampsByKey["txn:\(tid)"] = stamp
            } else {
                stamp.note = t.metadata
            }
        }

        // Rétrocompat : tampons déjà importés en `txn:<id>` seuls → ajout `|p:` quand l’API expose `points`.
        for t in transactions.transactions {
            guard let tid = t.id, let p = t.points else { continue }
            guard let stamp = txnStampsByKey["txn:\(tid)"] else { continue }
            let trimmed = stamp.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard trimmed.hasPrefix("txn:\(tid)") else { continue }
            if trimmed.contains("|p:") { continue }
            stamp.note = "txn:\(tid)|p:\(p)"
        }
    }

    private static func existingCardsIndex(for template: CardTemplate, context: NSManagedObjectContext) -> [String: ClientCard] {
        let request = ClientCard.fetchRequest()
        request.predicate = NSPredicate(format: "template == %@", template)
        let cards = (try? context.fetch(request)) ?? []
        var map: [String: ClientCard] = [:]
        map.reserveCapacity(cards.count)
        for card in cards {
            guard let memberId = card.qrCodeValue?.trimmingCharacters(in: .whitespacesAndNewlines), !memberId.isEmpty else { continue }
            map[memberId] = card
        }
        return map
    }

    private static func existingCategoriesIndex(for template: CardTemplate, context: NSManagedObjectContext) -> [String: MemberCategory] {
        let request = MemberCategory.fetchRequest()
        request.predicate = NSPredicate(format: "template == %@", template)
        let categories = (try? context.fetch(request)) ?? []
        var map: [String: MemberCategory] = [:]
        map.reserveCapacity(categories.count)
        for category in categories {
            guard let sid = category.serverId?.trimmingCharacters(in: .whitespacesAndNewlines), !sid.isEmpty else { continue }
            map[sid] = category
        }
        return map
    }

    private static func existingTxnStampIndex(for template: CardTemplate, context: NSManagedObjectContext) -> [String: Stamp] {
        let request = Stamp.fetchRequest()
        request.predicate = NSPredicate(format: "clientCard.template == %@ AND note BEGINSWITH %@", template, "txn:")
        let stamps = (try? context.fetch(request)) ?? []
        var map: [String: Stamp] = [:]
        map.reserveCapacity(stamps.count)
        for stamp in stamps {
            if let key = normalizedTxnDedupKey(fromStampNote: stamp.note) {
                map[key] = stamp
            }
        }
        return map
    }

    private static func findOrCreateBusiness(slug: String, context: NSManagedObjectContext) -> Business {
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

    private static func findOrCreateCardTemplate(business: Business, context: NSManagedObjectContext) -> CardTemplate {
        let request = CardTemplate.fetchRequest()
        request.predicate = NSPredicate(format: "business == %@", business)
        request.fetchLimit = 1
        if let t = try? context.fetch(request).first { return t }
        let t = CardTemplate(context: context)
        t.id = UUID()
        t.business = business
        t.displayName = "Ma Carte"
        t.requiredStamps = 10
        t.primaryColorHex = AppTheme.WalletCardAppearanceDefaults.backgroundHex
        t.accentColorHex = AppTheme.WalletCardAppearanceDefaults.bodyTextHex
        t.createdAt = Date()
        t.updatedAt = Date()
        return t
    }

}
