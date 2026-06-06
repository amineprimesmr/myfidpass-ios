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
    /// Instance live de l’app (pas les previews) — push silencieux `dashboard_sync` et sync au premier plan.
    private static weak var liveInstance: SyncService?

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
        Self.liveInstance = self
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

    /// Push silencieux serveur (`myfidpass_action=dashboard_sync`) : pull transactions / membres sans bannière.
    static func handleSilentDashboardPush(completion: @escaping (UIBackgroundFetchResult) -> Void) {
        Task { @MainActor in
            guard AuthStorage.isLoggedIn, let service = liveInstance else {
                completion(.noData)
                return
            }
            await service.syncIfNeeded(force: true)
            completion(.newData)
        }
    }

    /// Même logique quand l’app est déjà au premier plan (APNs reçu sans alerte).
    static func requestDashboardSyncFromPush() {
        Task { @MainActor in
            guard AuthStorage.isLoggedIn, let service = liveInstance else { return }
            await service.syncIfNeeded(force: true)
        }
    }

    private static let syncThrottleInterval: TimeInterval = 45
    /// L’API dashboard plafonne à 200 membres par page (`dashboard.js`).
    private static let membersAPIPageSize = 200
    private static let transactionsAPIPageSize = 100
    /// Mode perf : limite volontairement le volume synchronisé par passe (200 × pages).
    private static let maxMemberPages = 25
    /// `sort=desc` : transactions récentes en priorité (100 × pages = 1000 lignes).
    private static let maxTransactionPages = 10
    /// Plafond aligné export SaaS (`GET …/transactions/export`, limit 25000).
    private static let maxMemberHistoryTransactions = 25_000
    private static let memberHistoryPageSize = 200

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

    /// Historique **complet** d’un membre : pagination API (`memberId`), fusion Core Data, dédoublonnage cartes/tampons, purge locale obsolète.
    func syncMemberTransactionHistory(memberId: String) async {
        let trimmed = memberId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines),
              !slug.isEmpty else { return }
        await syncSerialExecutor.enqueue { [weak self] in
            guard let self else { return }
            do {
                try await self.performMemberTransactionHistorySync(slug: slug, memberId: trimmed)
            } catch {
                syncServiceLog.error("Member history sync failed: \(String(describing: error))")
            }
        }
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
            lastError = nil
            MerchantProUnlockPresenter.shared.presentTeaser()
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
            lastError = APIError.merchantFacingMessage(from: error) ?? error.localizedDescription
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
            skipTemplateOverwrite: skipTemplateOverwrite,
            notifyUI: true
        )
    }

    /// Met à jour le snapshot d'aperçu carte depuis GET settings pour que l'accueil reflète
    /// logo, couleurs, mode, récompenses, etc. après modification sur un autre appareil.
    /// Préserve uniquement l'état brouillon local (fond photo, icône tampon en cours d'édition).
    private func updateSnapshotRemoteBackground(settings: BusinessSettingsResponse, slug: String) {
        let existing = CardPreviewDisplaySnapshotStore.load(slug: slug)
        let merged = Self.minimalDisplaySnapshotFromSettings(settings, slug: slug, preserving: existing)
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

    private func mergeOnBackground(
        slug: String,
        settings: BusinessSettingsResponse,
        stats: BusinessStatsResponse,
        members: BusinessMembersResponse,
        transactions: BusinessTransactionsResponse,
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

    // MARK: - Historique membre (phase 2)

    private func fetchAllTransactionsForMember(slug: String, memberId: String) async throws -> [TransactionDTO] {
        var collected: [TransactionDTO] = []
        var seenIds = Set<String>()
        var offset = 0
        var serverTotal: Int?
        let pageSize = Self.memberHistoryPageSize
        let maxPages = (Self.maxMemberHistoryTransactions + pageSize - 1) / pageSize
        for _ in 0..<maxPages {
            let page = try await APIClient.shared.request(
                .businessTransactions(
                    slug: slug,
                    limit: pageSize,
                    offset: offset,
                    memberId: memberId,
                    days: nil,
                    type: nil,
                    sort: "desc"
                )
            ) as BusinessTransactionsResponse
            if serverTotal == nil { serverTotal = page.total }
            if page.transactions.isEmpty { break }
            for t in page.transactions {
                if let id = t.id?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
                    guard !seenIds.contains(id) else { continue }
                    seenIds.insert(id)
                }
                collected.append(t)
            }
            if page.transactions.count < pageSize { break }
            if let total = serverTotal, collected.count >= total { break }
            offset += pageSize
            if offset >= Self.maxMemberHistoryTransactions { break }
        }
        return collected
    }

    private func performMemberTransactionHistorySync(slug: String, memberId: String) async throws {
        let transactions = try await fetchAllTransactionsForMember(slug: slug, memberId: memberId)
        let serverTxnIds = Set(
            transactions.compactMap { t -> String? in
                let id = t.id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return id.isEmpty ? nil : id
            }
        )
        let c = container
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let child = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            child.parent = c.viewContext
            child.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            child.perform {
                do {
                    guard let business = SyncCoreDataMerge.findBusiness(slug: slug, context: child),
                          let template = SyncCoreDataMerge.findCardTemplate(business: business, context: child) else {
                        cont.resume()
                        return
                    }
                    SyncCoreDataMerge.deduplicateClientCards(for: template, context: child)
                    guard let card = SyncCoreDataMerge.clientCard(memberId: memberId, template: template, context: child) else {
                        cont.resume()
                        return
                    }
                    var txnStampsByKey = SyncCoreDataMerge.existingTxnStampIndex(for: template, context: child)
                    let cardsByMemberId = [memberId: card]
                    SyncCoreDataMerge.mergeTransactions(
                        transactions,
                        cardsByMemberId: cardsByMemberId,
                        txnStampsByKey: &txnStampsByKey,
                        context: child
                    )
                    SyncCoreDataMerge.dedupeStamps(on: card, txnStampsByKey: &txnStampsByKey, context: child)
                    SyncCoreDataMerge.purgeOrphanTxnStamps(
                        for: card,
                        serverTxnIds: serverTxnIds,
                        txnStampsByKey: &txnStampsByKey,
                        context: child
                    )
                    try child.save()
                    DispatchQueue.main.async {
                        do {
                            try c.viewContext.save()
                            NotificationCenter.default.post(name: .myfidpassMerchantCoreDataDidMergeFromSync, object: nil)
                            cont.resume()
                        } catch {
                            cont.resume(throwing: error)
                        }
                    }
                } catch {
                    DispatchQueue.main.async { cont.resume(throwing: error) }
                }
            }
        }
    }
}

// MARK: - Fusion Core Data (file privée, hors MainActor)

fileprivate enum SyncCoreDataMerge {
    static func parseISO8601(_ s: String?) -> Date? {
        guard let raw = s?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFrac.date(from: raw) { return d }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) { return d }
        // SQLite `datetime('now')` renvoyé tel quel par l’API (UTC).
        let sqlite = DateFormatter()
        sqlite.locale = Locale(identifier: "en_US_POSIX")
        sqlite.timeZone = TimeZone(secondsFromGMT: 0)
        for pattern in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss"] {
            sqlite.dateFormat = pattern
            if let d = sqlite.date(from: raw) { return d }
        }
        return nil
    }

    private static func normalizedTxnDedupKey(fromStampNote note: String?) -> String? {
        MerchantTransactionEventLabels.normalizedTxnDedupKey(fromStampNote: note)
    }

    static func apply(
        slug: String,
        settings: BusinessSettingsResponse,
        stats: BusinessStatsResponse,
        members: BusinessMembersResponse,
        transactions: BusinessTransactionsResponse,
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
                created.createdAt = parseISO8601(m.createdAt)
                created.updatedAt = parseISO8601(m.lastVisitAt) ?? parseISO8601(m.createdAt) ?? Date()
                cardsByMemberId[m.id] = created
                return created
            }()
            card.stampsCount = Int32(m.points ?? 0)
            card.clientDisplayName = m.name ?? "Client"
            card.clientEmail = m.email
            if let serverCreated = parseISO8601(m.createdAt) {
                if card.createdAt == nil || serverCreated < card.createdAt! {
                    card.createdAt = serverCreated
                }
            }
            card.updatedAt = parseISO8601(m.lastVisitAt) ?? card.updatedAt
        }

        deduplicateClientCards(for: template, context: context)
        cardsByMemberId = rebuildCardsByMemberId(for: template, context: context)
        txnStampsByKey = existingTxnStampIndex(for: template, context: context)

        mergeTransactions(
            transactions.transactions,
            cardsByMemberId: cardsByMemberId,
            txnStampsByKey: &txnStampsByKey,
            context: context
        )
    }

    // MARK: - Fusion transactions

    static func mergeTransactions(
        _ transactions: [TransactionDTO],
        cardsByMemberId: [String: ClientCard],
        txnStampsByKey: inout [String: Stamp],
        context: NSManagedObjectContext
    ) {
        var txnStampKeys = Set(txnStampsByKey.keys)
        for t in transactions {
            guard let memberId = t.memberId else { continue }
            guard let card = cardsByMemberId[memberId] else { continue }

            let dedupKey: String
            if let tid = t.id?.trimmingCharacters(in: .whitespacesAndNewlines), !tid.isEmpty {
                dedupKey = "txn:\(tid)"
            } else {
                dedupKey = MerchantTransactionEventLabels.compositeDedupKey(
                    memberId: memberId,
                    type: t.type,
                    createdAt: t.createdAt,
                    points: t.points
                )
            }
            if txnStampKeys.contains(dedupKey) {
                // Réconciliation sur tampon déjà connu
                if dedupKey.hasPrefix("txn:"),
                   let stamp = txnStampsByKey[dedupKey],
                   let tid = t.id?.trimmingCharacters(in: .whitespacesAndNewlines), !tid.isEmpty {
                    if let serverDate = parseISO8601(t.createdAt) { stamp.createdAt = serverDate }
                    stamp.note = MerchantTransactionEventLabels.enrichStampNote(
                        stamp.note,
                        txnId: tid,
                        type: t.type,
                        points: t.points,
                        metadata: t.metadata
                    )
                }
                continue
            }
            txnStampKeys.insert(dedupKey)

            let stamp = Stamp(context: context)
            stamp.id = UUID()
            stamp.clientCard = card
            stamp.createdAt = parseISO8601(t.createdAt)
            if let tid = t.id?.trimmingCharacters(in: .whitespacesAndNewlines), !tid.isEmpty {
                stamp.note = MerchantTransactionEventLabels.encodeStampNote(
                    txnId: tid,
                    type: t.type,
                    points: t.points,
                    metadata: t.metadata
                )
                txnStampsByKey[dedupKey] = stamp
            } else {
                stamp.note = t.metadata?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        for t in transactions {
            guard let memberId = t.memberId else { continue }
            guard cardsByMemberId[memberId] != nil else { continue }
            guard let tid = t.id?.trimmingCharacters(in: .whitespacesAndNewlines), !tid.isEmpty else { continue }
            let key = "txn:\(tid)"
            guard let stamp = txnStampsByKey[key] else { continue }
            if let serverDate = parseISO8601(t.createdAt) { stamp.createdAt = serverDate }
            stamp.note = MerchantTransactionEventLabels.enrichStampNote(
                stamp.note,
                txnId: tid,
                type: t.type,
                points: t.points,
                metadata: t.metadata
            )
        }
    }

    // MARK: - Dédoublonnage cartes / tampons

    static func memberLogicalKey(for card: ClientCard) -> String {
        if let q = card.qrCodeValue?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty { return "q:\(q)" }
        if let e = card.clientEmail?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !e.isEmpty { return "e:\(e)" }
        return "o:\(card.objectID.uriRepresentation().absoluteString)"
    }

    static func deduplicateClientCards(for template: CardTemplate, context: NSManagedObjectContext) {
        let request = ClientCard.fetchRequest()
        request.predicate = NSPredicate(format: "template == %@", template)
        let all = (try? context.fetch(request)) ?? []
        guard all.count > 1 else { return }

        var emailToMemberId: [String: String] = [:]
        for card in all {
            let q = card.qrCodeValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let e = card.clientEmail?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            if !q.isEmpty, !e.isEmpty { emailToMemberId[e] = q }
        }

        var groups: [String: [ClientCard]] = [:]
        for card in all {
            var key = memberLogicalKey(for: card)
            if key.hasPrefix("e:") {
                let email = String(key.dropFirst(2))
                if let memberId = emailToMemberId[email] { key = "q:\(memberId)" }
            }
            groups[key, default: []].append(card)
        }

        for (_, rawCards) in groups {
            var seen = Set<NSManagedObjectID>()
            let cards = rawCards.filter { seen.insert($0.objectID).inserted }
            guard cards.count > 1 else { continue }
            let canonical = pickCanonicalCard(cards)
            for duplicate in cards where duplicate.objectID != canonical.objectID {
                mergeClientCard(from: duplicate, into: canonical, context: context)
                context.delete(duplicate)
            }
        }
    }

    private static func pickCanonicalCard(_ cards: [ClientCard]) -> ClientCard {
        cards.max(by: { cardCanonicalScore($0) < cardCanonicalScore($1) })!
    }

    private static func cardCanonicalScore(_ card: ClientCard) -> Int {
        var score = 0
        if !(card.qrCodeValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 10_000 }
        score += Int(card.stampsCount) * 10
        score += card.stamps?.count ?? 0
        if !(card.clientEmail ?? "").isEmpty { score += 50 }
        if card.createdAt != nil { score += 5 }
        if let updated = card.updatedAt { score += min(Int(updated.timeIntervalSince1970 / 86_400), 10_000) }
        return score
    }

    private static func mergeClientCard(from source: ClientCard, into target: ClientCard, context: NSManagedObjectContext) {
        let targetQR = target.qrCodeValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sourceQR = source.qrCodeValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if targetQR.isEmpty, !sourceQR.isEmpty {
            target.qrCodeValue = sourceQR
            target.clientIdentifier = sourceQR
        }
        if (target.clientEmail ?? "").isEmpty, let email = source.clientEmail { target.clientEmail = email }
        let targetName = target.clientDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if targetName.isEmpty || targetName == "Client",
           let name = source.clientDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            target.clientDisplayName = name
        }
        if let sourceCreated = source.createdAt {
            if target.createdAt == nil || sourceCreated < target.createdAt! { target.createdAt = sourceCreated }
        }
        if let sourceUpdated = source.updatedAt {
            if target.updatedAt == nil || sourceUpdated > target.updatedAt! { target.updatedAt = sourceUpdated }
        }
        target.stampsCount = max(target.stampsCount, source.stampsCount)

        if let stamps = source.stamps?.allObjects as? [Stamp] {
            for stamp in stamps { stamp.clientCard = target }
        }

        _ = context
    }

    static func dedupeStamps(
        on card: ClientCard,
        txnStampsByKey: inout [String: Stamp],
        context: NSManagedObjectContext
    ) {
        guard let stamps = card.stamps?.allObjects as? [Stamp] else { return }
        var seen = Set<String>()
        for stamp in stamps {
            guard let key = normalizedTxnDedupKey(fromStampNote: stamp.note) else { continue }
            if seen.contains(key) {
                context.delete(stamp)
                if txnStampsByKey[key]?.objectID == stamp.objectID { txnStampsByKey.removeValue(forKey: key) }
            } else {
                seen.insert(key)
                txnStampsByKey[key] = stamp
            }
        }
    }

    static func purgeOrphanTxnStamps(
        for card: ClientCard,
        serverTxnIds: Set<String>,
        txnStampsByKey: inout [String: Stamp],
        context: NSManagedObjectContext
    ) {
        guard !serverTxnIds.isEmpty else { return }
        guard let stamps = card.stamps?.allObjects as? [Stamp] else { return }
        for stamp in stamps {
            guard let key = normalizedTxnDedupKey(fromStampNote: stamp.note) else { continue }
            let txnId = String(key.dropFirst(4))
            guard !serverTxnIds.contains(txnId) else { continue }
            context.delete(stamp)
            if txnStampsByKey[key]?.objectID == stamp.objectID { txnStampsByKey.removeValue(forKey: key) }
        }
    }

    static func rebuildCardsByMemberId(for template: CardTemplate, context: NSManagedObjectContext) -> [String: ClientCard] {
        let request = ClientCard.fetchRequest()
        request.predicate = NSPredicate(format: "template == %@", template)
        let cards = (try? context.fetch(request)) ?? []
        var map: [String: ClientCard] = [:]
        for card in cards {
            guard let memberId = card.qrCodeValue?.trimmingCharacters(in: .whitespacesAndNewlines), !memberId.isEmpty else { continue }
            if let existing = map[memberId] {
                map[memberId] = pickCanonicalCard([existing, card])
            } else {
                map[memberId] = card
            }
        }
        return map
    }

    static func findBusiness(slug: String, context: NSManagedObjectContext) -> Business? {
        let request = Business.fetchRequest()
        request.predicate = NSPredicate(format: "slug == %@", slug)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    static func findCardTemplate(business: Business, context: NSManagedObjectContext) -> CardTemplate? {
        let request = CardTemplate.fetchRequest()
        request.predicate = NSPredicate(format: "business == %@", business)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    static func clientCard(memberId: String, template: CardTemplate, context: NSManagedObjectContext) -> ClientCard? {
        let request = ClientCard.fetchRequest()
        request.predicate = NSPredicate(format: "template == %@ AND qrCodeValue == %@", template, memberId)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private static func existingCardsIndex(for template: CardTemplate, context: NSManagedObjectContext) -> [String: ClientCard] {
        let request = ClientCard.fetchRequest()
        request.predicate = NSPredicate(format: "template == %@", template)
        let cards = (try? context.fetch(request)) ?? []
        var map: [String: ClientCard] = [:]
        map.reserveCapacity(cards.count)
        for card in cards {
            guard let memberId = card.qrCodeValue?.trimmingCharacters(in: .whitespacesAndNewlines), !memberId.isEmpty else { continue }
            if let existing = map[memberId] {
                map[memberId] = pickCanonicalCard([existing, card])
            } else {
                map[memberId] = card
            }
        }
        return map
    }

    static func existingTxnStampIndex(for template: CardTemplate, context: NSManagedObjectContext) -> [String: Stamp] {
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
