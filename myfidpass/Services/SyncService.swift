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

    /// Référence forte vers l’instance active du SyncService.
    ///
    /// POURQUOI FORTE et non faible :
    /// En cas de lancement à froid depuis une notification push silencieuse, iOS appelle
    /// `AppDelegate.didReceiveRemoteNotification` AVANT que SwiftUI ait eu le temps d’initialiser
    /// les @StateObject (qui sont créés de façon lazy, au premier rendu du View). Avec une
    /// référence `weak`, `remoteNotificationHook` est nil dans ce scénario → le push est ignoré
    /// silencieusement → le tableau de bord ne se synchronise pas.
    ///
    /// La référence forte ne crée pas de rétention cyclique : SyncService ne pointe pas vers
    /// AppDelegate, et SwiftUI reste le propriétaire principal (@StateObject). Cette variable
    /// statique est simplement un alias vers la même instance, permettant à AppDelegate d’y accéder
    /// sans passer par la hiérarchie de vues.
    ///
    /// Elle est mise à nil dans deinit pour éviter que des instances obsolètes (ex: après un
    /// logout/reinit) restent accessibles.
    /// `nonisolated(unsafe)` : `deinit` n’est pas isolé au MainActor ; seuls `init` / `deinit` et
    /// `handleSilentDashboardPush` (Task @MainActor) touchent ce pointeur.
    nonisolated(unsafe) private static var remoteNotificationHook: SyncService?

    private static let lastSyncKey = "myfidpass.sync.lastSyncDate"
    private static let templateLastSavedKey = "myfidpass.templateLastSavedAt"
    /// Dernière date d’envoi du logo depuis l’app (last-write-wins avec le SaaS).
    static let lastLogoUploadAtKey = SyncMergeUserDefaults.lastLogoUploadAt
    static let lastLogoIconUploadAtKey = SyncMergeUserDefaults.lastLogoIconUploadAt
    /// Dernier envoi de l’icône campagnes / `…/notification-icon` (cache-bust côté aperçu, comme les logos).
    static let lastNotificationIconUploadAtKey = SyncMergeUserDefaults.lastNotificationIconUploadAt

    init(container: NSPersistentContainer, authService: AuthService? = nil) {
        self.container = container
        self.authService = authService
        self.lastSyncDate = UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date
        Self.remoteNotificationHook = self
        // Traiter immédiatement tout push silencieux reçu pendant un cold launch
        // (avant que SwiftUI ait initialisé cette instance).
        processPendingSilentSyncIfNeeded()
    }

    deinit {
        // Nettoie la référence statique si c'est bien CETTE instance qui est détruite
        // (pas une instance recréée après un reinit ou un changement de compte).
        if Self.remoteNotificationHook === self {
            Self.remoteNotificationHook = nil
        }
    }

    /// Clé UserDefaults pour signaler qu'une sync est attendue au prochain démarrage complet.
    private static let pendingSilentSyncKey = "myfidpass.pendingSilentSync"

    /// Push silencieux serveur → relance une sync complète sans bannière (voir backend `sendMerchantSilentDashboardSync`).
    ///
    /// CAS DU COLD LAUNCH : si l'app est lancée depuis un push silencieux (cold start),
    /// iOS appelle cette méthode AVANT que SwiftUI ait rendu les vues et donc avant
    /// que l'instance SyncService soit assignée. Dans ce cas, `remoteNotificationHook`
    /// est nil. On sauvegarde un flag dans UserDefaults ; la sync sera déclenchée dès
    /// que SyncService sera initialisé (voir la méthode `processPendingSilentSyncIfNeeded`).
    static func handleSilentDashboardPush(completion: @escaping (UIBackgroundFetchResult) -> Void) {
        Task { @MainActor in
            guard AuthStorage.isLoggedIn else {
                completion(.noData)
                return
            }
            guard let service = remoteNotificationHook else {
                // Cold launch : l'instance n'est pas encore créée. Mémoriser pour traiter dès l'init.
                UserDefaults.standard.set(true, forKey: pendingSilentSyncKey)
                completion(.noData)
                return
            }
            service.invalidateSyncThrottle()
            await service.syncAfterServerMutation()
            completion(.newData)
        }
    }

    /// Appelé depuis init() pour traiter un push silencieux reçu pendant un cold launch.
    /// Si le flag est présent, déclenche une sync complète immédiate.
    private func processPendingSilentSyncIfNeeded() {
        guard UserDefaults.standard.bool(forKey: Self.pendingSilentSyncKey) else { return }
        UserDefaults.standard.removeObject(forKey: Self.pendingSilentSyncKey)
        Task { @MainActor in
            guard AuthStorage.isLoggedIn else { return }
            self.invalidateSyncThrottle()
            await self.syncAfterServerMutation()
        }
    }

    private static let syncThrottleInterval: TimeInterval = 45
    /// L’API dashboard plafonne à 200 membres par page (`dashboard.js`).
    private static let membersAPIPageSize = 200
    private static let transactionsAPIPageSize = 100
    /// Augmenté : gros carnets membres (les transactions sans carte importée sont ignorées côté merge).
    private static let maxMemberPages = 50
    /// `sort=desc` : pages = des blocs du plus récent au plus ancien (contrat API).
    private static let maxTransactionPages = 24

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
        guard AuthStorage.isLoggedIn, let token = APIClient.shared.authToken, !token.isEmpty else { return }
        if !force, let last = lastSyncDate, Date().timeIntervalSince(last) < Self.syncThrottleInterval, !isSyncing {
            return
        }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }
        do {
            // Séquentiel volontaire : la phase de sync est prioritaire sur la perf.
            // Des rafales de requêtes/décodages parallèles au lancement ont déjà été corrélées
            // à des crashs malloc (`freed pointer was not the last allocation`).
            let cachedSlug = AuthStorage.currentBusinessSlug.flatMap { s -> String? in
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            }
            let lastSaved = UserDefaults.standard.object(forKey: Self.templateLastSavedKey) as? Date
            let skipTemplate = (lastSaved != nil && lastSyncDate != nil && lastSaved! > lastSyncDate!)

            let me: AuthMeResponse
            if let slug = cachedSlug {
                // D'abord le profil, ensuite la sync du commerce. Plus lent, mais beaucoup plus sûr.
                me = try await APIClient.shared.request(.authMe)
                let resolvedAfterMe = resolvedSlug(from: me) ?? slug
                try await syncBusiness(slug: resolvedAfterMe, skipTemplateOverwrite: skipTemplate)
            } else {
                me = try await APIClient.shared.request(.authMe)
            }
            authService?.applyAuthMeResponse(me)
            let slug = resolvedSlug(from: me)
            if let slug, slug != cachedSlug {
                // Slug différent du cache — re-sync avec le slug correct
                try await syncBusiness(slug: slug, skipTemplateOverwrite: skipTemplate)
            } else if slug == nil && cachedSlug == nil {
                // Pas de slug disponible, rien à sync
            }
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: Self.lastSyncKey)
            if let slug = (resolvedSlug(from: me) ?? cachedSlug)?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty {
                MerchantStatisticsDiskCache.removePeriod(slug: slug, period: Self.currentStatsMonthKey())
            }
            NotificationCenter.default.post(name: .myfidpassRemoteSyncDidMerge, object: nil)
        } catch APIError.unauthorized {
            lastError = "Session expirée"
            AppState.shared.showError(lastError ?? "Session expirée")
            postSyncFailureBanner()
        } catch APIError.subscriptionRequired {
            lastError = "Abonnement inactif ou expiré. Réactivez votre offre (Stripe) pour synchroniser le tableau de bord."
            postSyncFailureBanner()
        } catch APIError.notFound {
            // Souvent slug / URL mal formée ou commerce supprimé : 2ᵉ essai après relecture du profil (slug recalculé).
            do {
                let meRetry: AuthMeResponse = try await APIClient.shared.request(.authMe)
                authService?.applyAuthMeResponse(meRetry)
                guard let slugRetry = resolvedSlug(from: meRetry) else {
                    presentSyncFailure(APIError.notFound)
                    return
                }
                let lastSaved = UserDefaults.standard.object(forKey: Self.templateLastSavedKey) as? Date
                let skipTemplate = (lastSaved != nil && lastSyncDate != nil && lastSaved! > lastSyncDate!)
                try await syncBusiness(slug: slugRetry, skipTemplateOverwrite: skipTemplate)
                lastSyncDate = Date()
                UserDefaults.standard.set(lastSyncDate, forKey: Self.lastSyncKey)
                if let slug = resolvedSlug(from: meRetry)?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty {
                    MerchantStatisticsDiskCache.removePeriod(slug: slug, period: Self.currentStatsMonthKey())
                }
                NotificationCenter.default.post(name: .myfidpassRemoteSyncDidMerge, object: nil)
            } catch {
                presentSyncFailure(error)
            }
        } catch {
            presentSyncFailure(error)
        }
    }

    /// Échec de synchro : l’app continue avec Core Data ; bandeau + `lastError` (Réglages).
    private func presentSyncFailure(_ error: Error) {
        if isCancelledNetworkError(error) {
            lastError = nil
            return
        }
        if case APIError.notFound = error {
            lastError =
                "Le serveur ne trouve pas ce commerce (ou la connexion est désynchronisée). Ouvrez l’onglet Commerce pour vérifier l’établissement, ou fermez puis rouvrez l’app."
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

    private func syncBusiness(slug: String, skipTemplateOverwrite: Bool = false) async throws {
        // Vague 1 : séquentielle, plus sûre que trois requêtes parallèles au démarrage.
        let settings: BusinessSettingsResponse = try await APIClient.shared.request(.businessSettings(slug: slug))
        ScanFlowSettingsCache.store(settings, for: slug)
        let stats: BusinessStatsResponse = try await APIClient.shared.request(.businessStats(slug: slug, period: nil))
        let categoriesResponse = await fetchCategoriesOptional(slug: slug)

        let emptyMembers = BusinessMembersResponse(members: [], total: nil)
        let emptyTransactions = BusinessTransactionsResponse(transactions: [], total: nil)
        try await mergeOnBackground(
            slug: slug,
            settings: settings,
            stats: stats,
            members: emptyMembers,
            transactions: emptyTransactions,
            categories: categoriesResponse,
            skipTemplateOverwrite: skipTemplateOverwrite
        )
        // Après la 1ère vague (settings disponibles), mettre à jour le snapshot d'aperçu avec
        // l'URL du fond distant — sans attendre que l'utilisateur ouvre « Ma carte ».
        updateSnapshotRemoteBackground(settings: settings, slug: slug)

        // Vague 2 : entièrement séquentielle pour supprimer une autre source de courses.
        let members = try await fetchAllMembers(slug: slug)
        let transactions = try await fetchAllTransactions(slug: slug)

        try await mergeOnBackground(
            slug: slug,
            settings: settings,
            stats: stats,
            members: members,
            transactions: transactions,
            categories: nil,
            skipTemplateOverwrite: true
        )
    }

    /// Met à jour le snapshot d'aperçu carte (UserDefaults) avec l'URL du fond distant issu des settings API,
    /// pour que l'accueil reflète l'état serveur sans que l'utilisateur ait à ouvrir « Ma carte ».
    /// Si aucun snapshot n’existe encore, en crée un minimal depuis `settings` (sinon l’accueil n’avait jamais `cardBackgroundRemoteURL`).
    /// Préserve `hasLocalCardBackground` (fond photo local) sauf réparation `nil` → disque.
    private func updateSnapshotRemoteBackground(settings: BusinessSettingsResponse, slug: String) {
        var snap = CardPreviewDisplaySnapshotStore.load(slug: slug)
        let createdFresh = snap == nil
        if snap == nil {
            snap = Self.minimalDisplaySnapshotFromSettings(settings, slug: slug)
        }
        guard var snap = snap else { return }
        var changed = createdFresh

        if settings.hasCardBackground == true {
            let bgURL = Self.cardBackgroundRemoteURLString(slug: slug, updatedAt: settings.cardBackgroundUpdatedAt)
            if snap.cardBackgroundRemoteURL != bgURL || !snap.hasRemoteCardBackground {
                snap.hasRemoteCardBackground = true
                snap.cardBackgroundRemoteURL = bgURL
                changed = true
            }
        } else if snap.hasRemoteCardBackground {
            snap.hasRemoteCardBackground = false
            snap.cardBackgroundRemoteURL = nil
            changed = true
        }

        // Réparer les snapshots anciens (hasLocalCardBackground = nil) : vérifier si le fichier est sur disque.
        if snap.hasLocalCardBackground == nil {
            let rel = CardLogoStorage.relativeCardBackgroundPath
            let exists = CardLogoStorage.fullPath(forRelative: rel)
                .map { FileManager.default.fileExists(atPath: $0) } ?? false
            snap.hasLocalCardBackground = exists
            if exists { changed = true }
        }

        if changed {
            CardPreviewDisplaySnapshotStore.save(snap, slug: slug)
        }
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
    private static func minimalDisplaySnapshotFromSettings(_ settings: BusinessSettingsResponse, slug: String) -> CardPreviewDisplaySnapshot {
        var programType = (settings.programType ?? "points").lowercased()
        if programType != "points" && programType != "stamps" { programType = "points" }
        let primary = (settings.backgroundColor ?? "#\(AppTheme.WalletCardAppearanceDefaults.backgroundHex)")
            .replacingOccurrences(of: "#", with: "")
        let accent = (settings.foregroundColor ?? "#\(AppTheme.WalletCardAppearanceDefaults.bodyTextHex)")
            .replacingOccurrences(of: "#", with: "")
        let label = (settings.labelColor ?? "#\(AppTheme.WalletCardAppearanceDefaults.labelTitlesHex)")
            .replacingOccurrences(of: "#", with: "")
        var stripMode = (settings.stripDisplayMode ?? "logo").lowercased()
        if stripMode != "text" { stripMode = "logo" }
        let req = max(1, settings.requiredStamps ?? 10)
        let logoStrip = settings.logoUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let logoIcon = settings.logoIconUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let logoCombined = logoStrip.isEmpty ? logoIcon : logoStrip

        var hasRemote = false
        var bgURL: String?
        if settings.hasCardBackground == true {
            hasRemote = true
            bgURL = cardBackgroundRemoteURLString(slug: slug, updatedAt: settings.cardBackgroundUpdatedAt)
        }

        var tierPoints: [String] = []
        var tierLabels: [String] = []
        if let tiers = settings.pointsRewardTiers {
            for t in tiers.filter({ $0.points > 0 }).sorted(by: { $0.points < $1.points }).prefix(3) {
                tierPoints.append(String(t.points))
                tierLabels.append(t.label.isEmpty ? "Récompense" : t.label)
            }
        }

        let rel = CardLogoStorage.relativeCardBackgroundPath
        let localExists = CardLogoStorage.fullPath(forRelative: rel).map { FileManager.default.fileExists(atPath: $0) } ?? false

        return CardPreviewDisplaySnapshot(
            programType: programType,
            displayName: settings.organizationName ?? "Ma Carte",
            primaryHex: primary,
            accentHex: accent,
            labelHex: label,
            stripHex: "",
            stripDisplayMode: stripMode,
            stripText: settings.stripText ?? "",
            logoURL: logoCombined,
            stampEmoji: settings.stampEmoji ?? "",
            requiredStamps: req,
            headerRightText: CardRewardsHeaderLink.displayText,
            labelMember: settings.labelMember ?? "",
            hasRemoteCardBackground: hasRemote,
            cardBackgroundRemoteURL: bgURL,
            hasLocalCardBackground: localExists ? true : nil,
            stampRewardLabel: settings.stampRewardLabel ?? "",
            stampMidRewardLabel: settings.stampMidRewardLabel,
            startGameRewardLabel: nil,
            labelRestants: settings.labelRestants,
            tierPoints: tierPoints.isEmpty ? nil : tierPoints,
            tierLabels: tierLabels.isEmpty ? nil : tierLabels,
            stampIconPendingBase64: nil,
            stampIconWasRemoved: nil
        )
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
        skipTemplateOverwrite: Bool
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

        if let categories = categories {
            for (index, dto) in categories.categories.enumerated() {
                let cat = findOrCreateCategory(template: template, serverId: dto.id, name: dto.name, colorHex: dto.colorHex, sortOrder: Int32(dto.sortOrder ?? index), context: context)
                cat.name = dto.name
                cat.colorHex = dto.colorHex
                cat.sortOrder = Int32(dto.sortOrder ?? index)
            }
        }

        for m in members.members {
            let card = findOrCreateClientCard(template: template, memberId: m.id, name: m.name, email: m.email, points: m.points ?? 0, context: context)
            card.stampsCount = Int32(m.points ?? 0)
            card.clientDisplayName = m.name ?? "Client"
            card.clientEmail = m.email
            card.updatedAt = parseISO8601(m.lastVisitAt) ?? card.updatedAt
            // Vague 2 de sync passe `categories: nil` : ne pas effacer les catégories déjà fusionnées en vague 1.
            if let categoryIds = m.categoryIds, categories != nil {
                let cats = categoryIds.compactMap { findCategory(byServerId: $0, template: template, context: context) }
                card.categories = NSSet(array: cats)
            }
        }

        for t in transactions.transactions {
            guard let memberId = t.memberId else { continue }
            let cardRequest = ClientCard.fetchRequest()
            cardRequest.predicate = NSPredicate(format: "qrCodeValue == %@ AND template == %@", memberId, template)
            cardRequest.fetchLimit = 1
            guard let card = try context.fetch(cardRequest).first else { continue }
            if let tid = t.id, findStamp(serverId: tid, context: context) != nil { continue }
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
            } else {
                stamp.note = t.metadata
            }
        }

        // Rétrocompat : tampons déjà importés en `txn:<id>` seuls → ajout `|p:` quand l’API expose `points`.
        for t in transactions.transactions {
            guard let tid = t.id, let p = t.points else { continue }
            guard let stamp = findStamp(serverId: tid, context: context) else { continue }
            let trimmed = stamp.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard trimmed.hasPrefix("txn:\(tid)") else { continue }
            if trimmed.contains("|p:") { continue }
            stamp.note = "txn:\(tid)|p:\(p)"
        }
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

    private static func findOrCreateClientCard(template: CardTemplate, memberId: String, name: String?, email: String?, points: Int, context: NSManagedObjectContext) -> ClientCard {
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

    private static func findStamp(serverId: String, context: NSManagedObjectContext) -> Stamp? {
        let prefix = "txn:\(serverId)"
        let request = Stamp.fetchRequest()
        request.predicate = NSPredicate(format: "note == %@ OR note BEGINSWITH %@", prefix, "\(prefix)|")
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private static func findOrCreateCategory(template: CardTemplate, serverId: String, name: String, colorHex: String?, sortOrder: Int32, context: NSManagedObjectContext) -> MemberCategory {
        if let existing = findCategory(byServerId: serverId, template: template, context: context) { return existing }
        let cat = MemberCategory(context: context)
        cat.serverId = serverId
        cat.name = name
        cat.colorHex = colorHex
        cat.sortOrder = sortOrder
        cat.template = template
        return cat
    }

    private static func findCategory(byServerId serverId: String, template: CardTemplate, context: NSManagedObjectContext) -> MemberCategory? {
        let request = MemberCategory.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@ AND template == %@", serverId, template)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
