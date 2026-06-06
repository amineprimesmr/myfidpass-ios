//
//  APIEndpoint.swift
//  myfidpass
//
//  Contrat HTTP unique avec le backend SaaS (`fidelity/backend`, prod https://api.myfidpass.fr).
//  Toute nouvelle route : ajouter ici + implémenter côté `fidelity/backend/src/routes/`.
//

import Foundation

/// Segments d’URL (slug, UUID, codes) — évite les 404 si espaces, accents ou caractères réservés.
fileprivate func pathSegment(_ value: String) -> String {
    var allowed = CharacterSet.urlPathAllowed
    allowed.remove(charactersIn: "/")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
}

enum APIEndpoint {
    // MARK: - Auth
    case authLogin(login: String, password: String)
    case authCheckEmail(email: String)
    /// Vérifie si un lieu Google est déjà lié à un commerce (inscription).
    case authCheckGooglePlace(googlePlaceId: String)
    /// E-mail **ou** identifiant employé (sans @) — POST /api/auth/check-identifier
    case authCheckIdentifier(identifier: String)
    case authRegister(
        email: String,
        password: String,
        name: String?,
        googlePlaceId: String?,
        establishmentName: String?,
        establishments: [AuthEstablishmentPayload]?
    )
    /// Recherche d'établissements Google (même logique que le SaaS) — sans JWT.
    case placesAutocomplete(input: String)
    /// Détails lieu (nom, adresse) — sans JWT.
    case placesPlaceDetails(placeId: String)
    case authForgotPassword(email: String)
    case authResetPassword(token: String, newPassword: String)
    case authGoogle(
        idToken: String,
        googlePlaceId: String?,
        establishmentName: String?,
        establishments: [AuthEstablishmentPayload]?,
        authIntent: String? = nil
    )
    case authApple(
        idToken: String,
        name: String?,
        email: String?,
        googlePlaceId: String?,
        establishmentName: String?,
        establishments: [AuthEstablishmentPayload]?,
        authIntent: String? = nil
    )
    case authPhoneSendCode(phone: String)
    case authPhoneVerify(
        phone: String,
        code: String,
        googlePlaceId: String?,
        establishmentName: String?,
        establishments: [AuthEstablishmentPayload]?
    )
    case authEmailSendCode(email: String)
    case authEmailVerify(
        email: String,
        code: String,
        name: String?,
        googlePlaceId: String?,
        establishmentName: String?,
        establishments: [AuthEstablishmentPayload]?
    )
    case authMe
    case authMePatch(name: String)
    case authConfig
    case authDeleteAccount
    case authRefresh(refreshToken: String)
    case authLogout(refreshToken: String)

    // MARK: - Commerce (JWT)
    case createBusiness(payload: CreateBusinessPayload)
    case createBusinessFromPlace(establishmentName: String, googlePlaceId: String)
    case paymentCheckout(plan: String)
    /// Réparation : abonnement payé sur Stripe mais pas reflété en base (webhook manquant).
    case paymentReconcileSubscription
    /// Facturation / moyen de paiement (Stripe Customer Portal).
    case paymentPortalSession
    /// Paiement Stripe dédié au commerce actif (mode carte séparée par commerce).
    case paymentBusinessCheckoutSession(businessSlug: String, interval: String?)
    /// Validation StoreKit 2 → base MyFidpass (App Store Server API côté serveur).
    case paymentAppleSyncTransaction(payload: PaymentAppleSyncTransactionPayload)
    /// Restauration / réalignement abonnement App Store.
    case paymentAppleReconcileSubscription
    case paymentAppleIntroOfferEligibility(payload: PaymentAppleIntroOfferEligibilityRequest)
    /// Active un abonnement fictif (test) — même route que le bouton « Dev » du SaaS.
    case dashboardDevSimulatePayment(slug: String)

    // MARK: - Sync (dashboard / slug)
    case businessSettings(slug: String)
    case businessStats(slug: String, period: String?)
    case businessStatsTraffic(slug: String, period: String?)
    case businessEvolution(slug: String, weeks: Int?, period: String?)
    case businessMembers(slug: String, limit: Int?, offset: Int?, search: String?, filter: String?, sort: String?)
    case businessMembersExport(slug: String, search: String?, filter: String?, sort: String?)
    /// `sort` : ex. `desc` = plus récent d’abord (requis côté serveur pour offset correct).
    case businessTransactions(slug: String, limit: Int?, offset: Int?, memberId: String?, days: Int?, type: String?, sort: String?)
    /// `format` : `csv` | `json` — `json` sert à générer le PDF dans l’app.
    case businessTransactionsExport(
        slug: String,
        format: String,
        days: Int?,
        type: String?,
        types: String?,
        dateFrom: String?,
        dateTo: String?,
        memberId: String?,
        limit: Int?
    )
    /// JSON : pack multi-CSV pour bilan / CAC (voir `MerchantAccountingPackResponse`).
    case businessAccountingPack(slug: String, days: Int?, dateFrom: String?, dateTo: String?, limit: Int?)
    /// Supprime un membre et les données associées (pass, historique).
    case deleteDashboardMember(slug: String, memberId: String)
    /// Supprime tous les membres du commerce (confirmation côté serveur).
    case deleteAllDashboardMembers(slug: String)

    // MARK: - Jeux & engagement (dashboard)
    case dashboardGames(slug: String)
    case dashboardPatchGame(slug: String, gameCode: String, body: PatchGameBody)
    case dashboardGameRewardsGet(slug: String, gameCode: String)
    case dashboardGameRewardsPut(slug: String, gameCode: String, body: PutGameRewardsBody)
    case dashboardMatchPredictions(slug: String)
    case dashboardMatchPredictionsConfig(slug: String, body: MatchPredictionsConfigPatchBody)
    case dashboardMatchPredictionsSetResult(slug: String, matchId: String, body: MatchPredictionsResultBody)

    // MARK: - Notifications dashboard
    case dashboardNotificationSend(slug: String, body: NotificationSendPayload)
    case dashboardNotificationSegments(slug: String)
    case dashboardNotificationStats(slug: String)
    case dashboardTestPasskit(slug: String)
    case dashboardRemoveTestDevice(slug: String)

    // MARK: - Scan
    case scanLookup(slug: String, barcode: String)
    case scan(slug: String, barcode: String, visit: Bool, points: Int?, amountEur: Double?, receiptValidationToken: String?)
    case integrationRewardRedeem(slug: String, barcode: String)

    case deviceRegister(token: String)

    case walletPass(slug: String, memberId: String, design: WalletPassDesign?)

    case notifyClients(slug: String, message: String)

    case patchDashboardSettings(slug: String, patch: FullDashboardSettingsPatch)
    /// Préférences flyer QR (sync avec le SaaS).
    case dashboardFlyerGet(slug: String)
    case dashboardFlyerPut(slug: String, payload: FlyerPutPayload)
    /// Génération d’image de fond flyer (OpenAI côté serveur).
    case dashboardFlyerAIGenerate(slug: String, body: FlyerAIGenerateRequestDTO)
    /// Statut d’un job de génération flyer (après 202 + `job_id`).
    case dashboardFlyerAIGenerateJobStatus(slug: String, jobId: String)
    /// Détourage logo (rembg côté serveur ; repli heuristique local si `ok: false`).
    case dashboardFlyerRemoveLogoBackground(slug: String, imageDataUrl: String)
    /// Logo sans fond (remove.bg) persisté côté serveur — réutilisable pour la carte.
    case dashboardLogoNobg(slug: String)
    /// IA: transforme du texte libre en règle d’automatisation campagne.
    case dashboardCampaignAutomationParse(slug: String, body: CampaignAutomationAIParseRequestDTO)
    /// Métriques avis & réseaux (historique, deltas).
    case dashboardSocialMetrics(slug: String)
    case dashboardSocialMetricsRefresh(slug: String)
    case dashboardSocialMetricsManual(slug: String, payload: SocialMetricsManualPayload)
    /// Missions réseaux sociaux (Instagram, TikTok, Facebook, X) — config par pseudo.
    case dashboardSocialMissions(slug: String)
    case dashboardSocialMissionsPatch(slug: String, payload: SocialMissionsPatchPayload)
    case dashboardSocialMissionsStats(slug: String)
    /// OAuth Meta (Instagram + Page Facebook).
    case dashboardSocialOAuthMetaStart(slug: String)
    case dashboardSocialOAuthGoogleYoutubeStart(slug: String)
    case dashboardSocialOAuthGoogleBusinessStart(slug: String)
    case dashboardSocialOAuthTiktokStart(slug: String)
    /// JWT à encoder en QR sur le ticket (montant € = panier).
    case dashboardReceiptChallenge(slug: String, amountEur: Double)
    case updateLocationSettings(
        slug: String,
        locationLat: Double?,
        locationLng: Double?,
        locationRadiusMeters: Int?,
        locationRelevantText: String?,
        locationAddress: String?,
        walletPassIncludeLocations: Bool?
    )

    /// Crédit membre (points directs, montant €, et/ou passage) — aligné POST .../members/:id/points.
    case creditMember(slug: String, memberId: String, points: Int?, amountEur: Double?, visit: Bool, receiptValidationToken: String?)
    /// Retrait de points (correction erreur de caisse) — POST .../members/:id/points/remove.
    case removeMemberPoints(slug: String, memberId: String, points: Int)
    case redeemReward(slug: String, memberId: String, type: RedeemType)

    // MARK: - Membres (import, détail public, tickets, récompenses)
    case membersImport(slug: String, payload: MembersImportPayload)
    case createMember(slug: String, email: String, name: String)
    case memberPublic(slug: String, memberId: String)
    case memberTickets(slug: String, memberId: String)
    case memberTicketsConvert(slug: String, memberId: String, pointsToConvert: Int, idempotencyKey: String?)
    case memberRewardsList(slug: String, memberId: String)
    case claimMemberReward(slug: String, memberId: String, grantId: String)
    case googleWalletMemberUrl(slug: String, memberId: String)

    /// Administration plateforme (JWT + `is_admin`).
    case adminOverview
    case adminUsers(q: String?, limit: Int?, offset: Int?)
    case adminBusinesses(q: String?, limit: Int?, offset: Int?)
    case adminEvents(limit: Int?, filter: String?)

    // MARK: - Équipe (accès employés, owner/manager)
    case businessTeamList(slug: String)
    case businessTeamInvite(slug: String, body: WorkspaceTeamInviteBody)
    case businessTeamStaffAccount(slug: String, body: WorkspaceTeamStaffAccountBody)
    case businessTeamMemberDetail(slug: String, memberId: String)
    case businessTeamMemberPatch(slug: String, memberId: String, body: WorkspaceTeamMemberPatchBody)
    case businessTeamMemberResendAccess(slug: String, memberId: String)
    case businessTeamRevoke(slug: String, membershipId: String)

    var path: String {
        switch self {
        case .authLogin: return "/api/auth/login"
        case .authCheckEmail: return "/api/auth/check-email"
        case .authCheckGooglePlace: return "/api/auth/check-google-place"
        case .authCheckIdentifier: return "/api/auth/check-identifier"
        case .authRegister: return "/api/auth/register"
        case .placesAutocomplete: return "/api/places/autocomplete"
        case .placesPlaceDetails: return "/api/places/details"
        case .authForgotPassword: return "/api/auth/forgot-password"
        case .authResetPassword: return "/api/auth/reset-password"
        case .authGoogle: return "/api/auth/google"
        case .authApple: return "/api/auth/apple"
        case .authPhoneSendCode: return "/api/auth/phone/send-code"
        case .authPhoneVerify: return "/api/auth/phone/verify"
        case .authEmailSendCode: return "/api/auth/email/send-code"
        case .authEmailVerify: return "/api/auth/email/verify"
        case .authMe, .authMePatch: return "/api/auth/me"
        case .authConfig: return "/api/auth/config"
        case .authDeleteAccount: return "/api/auth/account"
        case .authRefresh: return "/api/auth/refresh"
        case .authLogout: return "/api/auth/logout"
        case .createBusiness: return "/api/businesses"
        case .createBusinessFromPlace: return "/api/businesses/create-from-place"
        case .paymentCheckout: return "/api/payment/create-checkout-session"
        case .paymentReconcileSubscription: return "/api/payment/reconcile-subscription"
        case .paymentPortalSession: return "/api/payment/create-portal-session"
        case .paymentBusinessCheckoutSession: return "/api/payment/create-business-checkout-session"
        case .paymentAppleSyncTransaction: return "/api/payment/apple/sync-transaction"
        case .paymentAppleReconcileSubscription: return "/api/payment/apple/reconcile-subscription"
        case .paymentAppleIntroOfferEligibility: return "/api/payment/apple/introductory-offer-eligibility"
        case .dashboardDevSimulatePayment(let slug):
            return "/api/businesses/\(pathSegment(slug))/dashboard/dev-simulate-payment"
        case .businessSettings(let slug): return "/api/businesses/\(pathSegment(slug))/dashboard/settings"
        case .businessStats(let slug, _): return "/api/businesses/\(pathSegment(slug))/dashboard/stats"
        case .businessStatsTraffic(let slug, _): return "/api/businesses/\(pathSegment(slug))/dashboard/stats/traffic"
        case .businessEvolution(let slug, _, _): return "/api/businesses/\(pathSegment(slug))/dashboard/evolution"
        case .businessMembers(let slug, _, _, _, _, _): return "/api/businesses/\(pathSegment(slug))/dashboard/members"
        case .businessMembersExport(let slug, _, _, _): return "/api/businesses/\(pathSegment(slug))/dashboard/members/export"
        case .businessTransactions(let slug, _, _, _, _, _, _): return "/api/businesses/\(pathSegment(slug))/dashboard/transactions"
        case .businessTransactionsExport(let slug, _, _, _, _, _, _, _, _):
            return "/api/businesses/\(pathSegment(slug))/dashboard/transactions/export"
        case .businessAccountingPack(let slug, _, _, _, _):
            return "/api/businesses/\(pathSegment(slug))/dashboard/accounting-pack"
        case .deleteDashboardMember(let slug, let memberId): return "/api/businesses/\(pathSegment(slug))/dashboard/members/\(pathSegment(memberId))"
        case .deleteAllDashboardMembers(let slug): return "/api/businesses/\(pathSegment(slug))/dashboard/members/delete-all"
        case .dashboardGames(let slug): return "/api/businesses/\(pathSegment(slug))/dashboard/games"
        case .dashboardPatchGame(let slug, let gameCode, _): return "/api/businesses/\(pathSegment(slug))/dashboard/games/\(pathSegment(gameCode))"
        case .dashboardGameRewardsGet(let slug, let gameCode): return "/api/businesses/\(pathSegment(slug))/dashboard/games/\(pathSegment(gameCode))/rewards"
        case .dashboardGameRewardsPut(let slug, let gameCode, _): return "/api/businesses/\(pathSegment(slug))/dashboard/games/\(pathSegment(gameCode))/rewards"
        case .dashboardMatchPredictions(let slug): return "/api/businesses/\(pathSegment(slug))/dashboard/match-predictions"
        case .dashboardMatchPredictionsConfig(let slug, _): return "/api/businesses/\(pathSegment(slug))/dashboard/match-predictions/config"
        case .dashboardMatchPredictionsSetResult(let slug, let matchId, _): return "/api/businesses/\(pathSegment(slug))/dashboard/match-predictions/matches/\(pathSegment(matchId))/result"
        case .dashboardNotificationSend(let slug, _): return "/api/businesses/\(pathSegment(slug))/notifications/send"
        case .dashboardNotificationSegments(let slug): return "/api/businesses/\(pathSegment(slug))/notifications/campaign-segments"
        case .dashboardNotificationStats(let slug): return "/api/businesses/\(pathSegment(slug))/notifications/stats"
        case .dashboardTestPasskit(let slug): return "/api/businesses/\(pathSegment(slug))/notifications/test-passkit"
        case .dashboardRemoveTestDevice(let slug): return "/api/businesses/\(pathSegment(slug))/notifications/remove-test-device"
        case .scanLookup(let slug, _): return "/api/businesses/\(pathSegment(slug))/integration/lookup"
        case .scan(let slug, _, _, _, _, _): return "/api/businesses/\(pathSegment(slug))/integration/scan"
        case .integrationRewardRedeem(let slug, _): return "/api/businesses/\(pathSegment(slug))/integration/reward-redeem"
        case .deviceRegister: return "/api/device/register"
        case .walletPass(let slug, let memberId, _): return "/api/businesses/\(pathSegment(slug))/members/\(pathSegment(memberId))/pass"
        case .notifyClients(let slug, _): return "/api/businesses/\(pathSegment(slug))/notify"
        case .patchDashboardSettings(let slug, _): return "/api/businesses/\(pathSegment(slug))/dashboard/settings"
        case .dashboardFlyerGet(let slug): return "/api/businesses/\(pathSegment(slug))/dashboard/flyer"
        case .dashboardFlyerPut(let slug, _): return "/api/businesses/\(pathSegment(slug))/dashboard/flyer"
        case .dashboardFlyerAIGenerate(let slug, _): return "/api/businesses/\(pathSegment(slug))/dashboard/flyer/ai-generate"
        case .dashboardFlyerAIGenerateJobStatus(let slug, let jobId):
            return "/api/businesses/\(pathSegment(slug))/dashboard/flyer/ai-generate/jobs/\(pathSegment(jobId))"
        case .dashboardFlyerRemoveLogoBackground(let slug, _):
            return "/api/businesses/\(pathSegment(slug))/dashboard/flyer/remove-logo-background"
        case .dashboardLogoNobg(let slug):
            return "/api/businesses/\(pathSegment(slug))/logo-nobg"
        case .dashboardCampaignAutomationParse(let slug, _): return "/api/businesses/\(pathSegment(slug))/dashboard/campaign-automation/parse"
        case .dashboardSocialMetrics(let slug): return "/api/businesses/\(pathSegment(slug))/dashboard/social-metrics"
        case .dashboardSocialMetricsRefresh(let slug): return "/api/businesses/\(pathSegment(slug))/dashboard/social-metrics/refresh"
        case .dashboardSocialMetricsManual(let slug, _): return "/api/businesses/\(pathSegment(slug))/dashboard/social-metrics/manual"
        case .dashboardSocialMissions(let slug): return "/api/businesses/\(pathSegment(slug))/dashboard/social-missions"
        case .dashboardSocialMissionsPatch(let slug, _): return "/api/businesses/\(pathSegment(slug))/dashboard/social-missions"
        case .dashboardSocialMissionsStats(let slug): return "/api/businesses/\(pathSegment(slug))/dashboard/social-missions/stats"
        case .dashboardSocialOAuthMetaStart(let slug): return "/api/businesses/\(pathSegment(slug))/dashboard/social-oauth/meta/start"
        case .dashboardSocialOAuthGoogleYoutubeStart(let slug): return "/api/businesses/\(pathSegment(slug))/dashboard/social-oauth/google-youtube/start"
        case .dashboardSocialOAuthGoogleBusinessStart(let slug): return "/api/businesses/\(pathSegment(slug))/dashboard/social-oauth/google-business/start"
        case .dashboardSocialOAuthTiktokStart(let slug): return "/api/businesses/\(pathSegment(slug))/dashboard/social-oauth/tiktok/start"
        case .dashboardReceiptChallenge(let slug, _): return "/api/businesses/\(pathSegment(slug))/dashboard/receipt-challenge"
        case .updateLocationSettings(let slug, _, _, _, _, _, _): return "/api/businesses/\(pathSegment(slug))/dashboard/settings"
        case .creditMember(let slug, let memberId, _, _, _, _): return "/api/businesses/\(pathSegment(slug))/members/\(pathSegment(memberId))/points"
        case .removeMemberPoints(let slug, let memberId, _): return "/api/businesses/\(pathSegment(slug))/members/\(pathSegment(memberId))/points/remove"
        case .redeemReward(let slug, let memberId, _): return "/api/businesses/\(pathSegment(slug))/members/\(pathSegment(memberId))/redeem"
        case .membersImport(let slug, _): return "/api/businesses/\(pathSegment(slug))/members/import"
        case .createMember(let slug, _, _): return "/api/businesses/\(pathSegment(slug))/members"
        case .memberPublic(let slug, let memberId): return "/api/businesses/\(pathSegment(slug))/members/\(pathSegment(memberId))"
        case .memberTickets(let slug, let memberId): return "/api/businesses/\(pathSegment(slug))/members/\(pathSegment(memberId))/tickets"
        case .memberTicketsConvert(let slug, let memberId, _, _): return "/api/businesses/\(pathSegment(slug))/members/\(pathSegment(memberId))/tickets/convert"
        case .memberRewardsList(let slug, let memberId): return "/api/businesses/\(pathSegment(slug))/members/\(pathSegment(memberId))/rewards"
        case .claimMemberReward(let slug, let memberId, let grantId): return "/api/businesses/\(pathSegment(slug))/members/\(pathSegment(memberId))/rewards/\(pathSegment(grantId))/claim"
        case .googleWalletMemberUrl(let slug, let memberId): return "/api/businesses/\(pathSegment(slug))/members/\(pathSegment(memberId))/google-wallet-url"
        case .adminOverview: return "/api/admin/overview"
        case .adminUsers: return "/api/admin/users"
        case .adminBusinesses: return "/api/admin/businesses"
        case .adminEvents: return "/api/admin/events"
        case .businessTeamList(let slug):
            return "/api/businesses/\(pathSegment(slug))/dashboard/team"
        case .businessTeamInvite(let slug, _):
            return "/api/businesses/\(pathSegment(slug))/dashboard/team/invites"
        case .businessTeamStaffAccount(let slug, _):
            return "/api/businesses/\(pathSegment(slug))/dashboard/team/staff-accounts"
        case .businessTeamMemberDetail(let slug, let memberId):
            return "/api/businesses/\(pathSegment(slug))/dashboard/team/members/\(pathSegment(memberId))"
        case .businessTeamMemberPatch(let slug, let memberId, _):
            return "/api/businesses/\(pathSegment(slug))/dashboard/team/members/\(pathSegment(memberId))"
        case .businessTeamMemberResendAccess(let slug, let memberId):
            return "/api/businesses/\(pathSegment(slug))/dashboard/team/members/\(pathSegment(memberId))/resend-access"
        case .businessTeamRevoke(let slug, let membershipId):
            return "/api/businesses/\(pathSegment(slug))/dashboard/team/members/\(pathSegment(membershipId))"
        }
    }

    /// Seul `POST /api/auth/login` renvoie 404 pour « aucun compte » — pas l’inscription ni les autres routes auth.
    var is404NoAccountLogin: Bool {
        if case .authLogin = self { return true }
        return false
    }

    /// Pas de `ensureValidAccessToken` ni d’en-tête `Authorization` : évite d’envoyer d’anciens JWT (compte supprimé / reset BDD) sur `/api/auth/config` ou login, ce qui provoquait un refresh en échec et « Session expirée » au moment de Continuer avec Google.
    /// `placesAutocomplete` suit le `default` (false) : avec Bearer, le backend retire les lieux Google déjà liés au compte (comme le SaaS).
    var skipsClientSessionBootstrap: Bool {
        switch self {
        case .authConfig, .authLogin, .authCheckEmail, .authCheckGooglePlace, .authCheckIdentifier, .authRegister, .authForgotPassword, .authResetPassword,
             .authGoogle, .authApple, .authPhoneSendCode, .authPhoneVerify, .authEmailSendCode, .authEmailVerify,
             .authRefresh, .authLogout, .placesPlaceDetails:
            return true
        default:
            return false
        }
    }

    /// En-têtes additionnels (ex. idempotency).
    var supplementalHeaders: [String: String] {
        switch self {
        case .memberTicketsConvert(_, _, _, let key):
            if let key, !key.isEmpty { return ["Idempotency-Key": key] }
            return [:]
        default:
            return [:]
        }
    }

    var method: String {
        switch self {
        case .authLogin, .authCheckEmail, .authCheckGooglePlace, .authCheckIdentifier, .authRegister, .authForgotPassword, .authResetPassword, .authGoogle, .authApple,
             .authPhoneSendCode, .authPhoneVerify, .authEmailSendCode, .authEmailVerify,
             .authRefresh, .authLogout,
             .scan, .integrationRewardRedeem, .deviceRegister, .notifyClients, .creditMember,
             .dashboardReceiptChallenge,
             .removeMemberPoints, .redeemReward, .createBusiness, .createBusinessFromPlace, .paymentCheckout, .paymentReconcileSubscription, .paymentPortalSession, .dashboardNotificationSend, .dashboardRemoveTestDevice,
             .paymentBusinessCheckoutSession, .paymentAppleSyncTransaction, .paymentAppleReconcileSubscription,
             .paymentAppleIntroOfferEligibility,
             .dashboardDevSimulatePayment,
             .membersImport, .createMember, .memberTicketsConvert, .claimMemberReward, .deleteAllDashboardMembers,
             .dashboardFlyerAIGenerate, .dashboardFlyerRemoveLogoBackground, .dashboardCampaignAutomationParse,
             .dashboardSocialMetricsRefresh, .dashboardSocialMetricsManual, .dashboardMatchPredictionsSetResult,
             .businessTeamInvite, .businessTeamStaffAccount, .businessTeamMemberResendAccess:
            return "POST"
        case .patchDashboardSettings, .updateLocationSettings, .dashboardPatchGame, .dashboardSocialMissionsPatch, .dashboardMatchPredictionsConfig, .businessTeamMemberPatch, .authMePatch:
            return "PATCH"
        case .authDeleteAccount, .deleteDashboardMember, .businessTeamRevoke:
            return "DELETE"
        case .dashboardGameRewardsPut, .dashboardFlyerPut:
            return "PUT"
        default:
            return "GET"
        }
    }

    func urlRequest(base: URL, encoder: JSONEncoder) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: base) else { throw APIError.invalidURL }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        switch self {
        case .businessStats(_, let period):
            if let period, !period.isEmpty {
                components.queryItems = [URLQueryItem(name: "period", value: period)]
            }
        case .businessStatsTraffic(_, let period):
            if let period, !period.isEmpty {
                components.queryItems = [URLQueryItem(name: "period", value: period)]
            }
        case .businessEvolution(_, let weeks, let period):
            var items: [URLQueryItem] = []
            if let w = weeks { items.append(URLQueryItem(name: "weeks", value: "\(w)")) }
            if let p = period, !p.isEmpty { items.append(URLQueryItem(name: "period", value: p)) }
            components.queryItems = items.isEmpty ? nil : items
        case .businessMembers(_, let limit, let offset, let search, let filter, let sort):
            var items: [URLQueryItem] = []
            if let l = limit { items.append(URLQueryItem(name: "limit", value: "\(l)")) }
            if let o = offset { items.append(URLQueryItem(name: "offset", value: "\(o)")) }
            if let s = search, !s.isEmpty { items.append(URLQueryItem(name: "search", value: s)) }
            if let f = filter, !f.isEmpty { items.append(URLQueryItem(name: "filter", value: f)) }
            if let so = sort, !so.isEmpty { items.append(URLQueryItem(name: "sort", value: so)) }
            components.queryItems = items.isEmpty ? nil : items
        case .businessMembersExport(_, let search, let filter, let sort):
            var items: [URLQueryItem] = []
            if let s = search, !s.isEmpty { items.append(URLQueryItem(name: "search", value: s)) }
            if let f = filter, !f.isEmpty { items.append(URLQueryItem(name: "filter", value: f)) }
            if let so = sort, !so.isEmpty { items.append(URLQueryItem(name: "sort", value: so)) }
            components.queryItems = items.isEmpty ? nil : items
        case .businessTransactions(_, let limit, let offset, let memberId, let days, let type, let sort):
            var items: [URLQueryItem] = []
            if let l = limit { items.append(URLQueryItem(name: "limit", value: "\(l)")) }
            if let o = offset { items.append(URLQueryItem(name: "offset", value: "\(o)")) }
            if let m = memberId, !m.isEmpty { items.append(URLQueryItem(name: "memberId", value: m)) }
            if let d = days { items.append(URLQueryItem(name: "days", value: "\(d)")) }
            if let t = type, !t.isEmpty { items.append(URLQueryItem(name: "type", value: t)) }
            if let s = sort, !s.isEmpty { items.append(URLQueryItem(name: "sort", value: s)) }
            components.queryItems = items.isEmpty ? nil : items
        case .businessTransactionsExport(_, let format, let days, let type, let types, let dateFrom, let dateTo, let memberId, let limit):
            var items: [URLQueryItem] = [URLQueryItem(name: "format", value: format)]
            if let d = days { items.append(URLQueryItem(name: "days", value: "\(d)")) }
            if let t = type, !t.isEmpty { items.append(URLQueryItem(name: "type", value: t)) }
            if let ts = types, !ts.isEmpty { items.append(URLQueryItem(name: "types", value: ts)) }
            if let f = dateFrom, !f.isEmpty { items.append(URLQueryItem(name: "from", value: f)) }
            if let t2 = dateTo, !t2.isEmpty { items.append(URLQueryItem(name: "to", value: t2)) }
            if let m = memberId, !m.isEmpty { items.append(URLQueryItem(name: "memberId", value: m)) }
            if let l = limit { items.append(URLQueryItem(name: "limit", value: "\(l)")) }
            components.queryItems = items
        case .businessAccountingPack(_, let days, let dateFrom, let dateTo, let limit):
            var items: [URLQueryItem] = []
            if let d = days { items.append(URLQueryItem(name: "days", value: "\(d)")) }
            if let f = dateFrom, !f.isEmpty { items.append(URLQueryItem(name: "from", value: f)) }
            if let t = dateTo, !t.isEmpty { items.append(URLQueryItem(name: "to", value: t)) }
            if let l = limit { items.append(URLQueryItem(name: "limit", value: "\(l)")) }
            components.queryItems = items.isEmpty ? nil : items
        case .placesAutocomplete(let input):
            components.queryItems = [URLQueryItem(name: "input", value: input)]
        case .placesPlaceDetails(let placeId):
            components.queryItems = [URLQueryItem(name: "place_id", value: placeId)]
        case .scanLookup(_, let barcode):
            components.queryItems = [URLQueryItem(name: "barcode", value: barcode)]
        case .walletPass(_, _, let design):
            let template = design?.template.flatMap { $0.isEmpty ? nil : $0 } ?? "classic"
            var items = [URLQueryItem(name: "template", value: template)]
            if let d = design {
                if !d.organizationName.isEmpty { items.append(URLQueryItem(name: "organization_name", value: d.organizationName)) }
                if !d.backgroundColor.isEmpty { items.append(URLQueryItem(name: "background_color", value: d.backgroundColor)) }
                if !d.foregroundColor.isEmpty { items.append(URLQueryItem(name: "foreground_color", value: d.foregroundColor)) }
                if let pt = d.programType, !pt.isEmpty { items.append(URLQueryItem(name: "program_type", value: pt)) }
                if let sc = d.stripColor, !sc.isEmpty { items.append(URLQueryItem(name: "strip_color", value: sc)) }
                if let mode = d.stripDisplayMode, !mode.isEmpty { items.append(URLQueryItem(name: "strip_display_mode", value: mode)) }
                if let st = d.stripText, !st.isEmpty { items.append(URLQueryItem(name: "strip_text", value: st)) }
                if !d.stampEmoji.isEmpty { items.append(URLQueryItem(name: "stamp_emoji", value: d.stampEmoji)) }
                if d.requiredStamps > 0 { items.append(URLQueryItem(name: "required_stamps", value: "\(d.requiredStamps)")) }
                if let lab = d.labelColor?.trimmingCharacters(in: .whitespacesAndNewlines), !lab.isEmpty {
                    items.append(URLQueryItem(name: "label_color", value: lab.hasPrefix("#") ? String(lab.dropFirst()) : lab))
                }
                if let pp = d.previewPoints, pp >= 0, pp <= 9_999_999 {
                    items.append(URLQueryItem(name: "preview_points", value: "\(pp)"))
                }
                if d.catalogStampOnly {
                    items.append(URLQueryItem(name: "catalog_stamp_only", value: "1"))
                }
            }
            components.queryItems = items
        case .adminOverview:
            break
        case .adminUsers(let q, let limit, let offset):
            var items: [URLQueryItem] = []
            if let q, !q.isEmpty { items.append(URLQueryItem(name: "q", value: q)) }
            if let l = limit { items.append(URLQueryItem(name: "limit", value: "\(l)")) }
            if let o = offset { items.append(URLQueryItem(name: "offset", value: "\(o)")) }
            components.queryItems = items.isEmpty ? nil : items
        case .adminBusinesses(let q, let limit, let offset):
            var items: [URLQueryItem] = []
            if let q, !q.isEmpty { items.append(URLQueryItem(name: "q", value: q)) }
            if let l = limit { items.append(URLQueryItem(name: "limit", value: "\(l)")) }
            if let o = offset { items.append(URLQueryItem(name: "offset", value: "\(o)")) }
            components.queryItems = items.isEmpty ? nil : items
        case .adminEvents(let limit, let filter):
            var items: [URLQueryItem] = []
            if let l = limit { items.append(URLQueryItem(name: "limit", value: "\(l)")) }
            if let f = filter, !f.isEmpty { items.append(URLQueryItem(name: "filter", value: f)) }
            components.queryItems = items.isEmpty ? nil : items
        case .businessTeamList, .businessTeamInvite, .businessTeamStaffAccount, .businessTeamMemberDetail, .businessTeamMemberPatch, .businessTeamMemberResendAccess, .businessTeamRevoke:
            break
        default:
            break
        }
        guard let finalURL = components.url else { throw APIError.invalidURL }
        var bodyData: Data?
        switch self {
        case .authLogin(let login, let password):
            bodyData = try encoder.encode(LoginPayload(login: login, password: password))
        case .authCheckEmail(let email):
            bodyData = try encoder.encode(CheckEmailPayload(email: email))
        case .authCheckGooglePlace(let googlePlaceId):
            bodyData = try encoder.encode(CheckGooglePlacePayload(googlePlaceId: googlePlaceId))
        case .authCheckIdentifier(let identifier):
            bodyData = try encoder.encode(CheckIdentifierPayload(identifier: identifier))
        case .authRegister(let email, let password, let name, let googlePlaceId, let establishmentName, let establishments):
            bodyData = try encoder.encode(
                AuthRegisterPayload(
                    email: email,
                    password: password,
                    name: name,
                    googlePlaceId: googlePlaceId,
                    establishmentName: establishmentName,
                    establishments: establishments
                )
            )
        case .authForgotPassword(let email):
            bodyData = try encoder.encode(ForgotPasswordPayload(email: email))
        case .authResetPassword(let token, let newPassword):
            bodyData = try encoder.encode(ResetPasswordPayload(token: token, newPassword: newPassword))
        case .authGoogle(let idToken, let googlePlaceId, let establishmentName, let establishments, let authIntent):
            bodyData = try encoder.encode(
                GooglePayload(
                    idToken: idToken,
                    googlePlaceId: googlePlaceId,
                    establishmentName: establishmentName,
                    establishments: establishments,
                    authIntent: authIntent
                )
            )
        case .authApple(let idToken, let name, let email, let googlePlaceId, let establishmentName, let establishments, let authIntent):
            bodyData = try encoder.encode(
                ApplePayload(
                    idToken: idToken,
                    name: name,
                    email: email,
                    googlePlaceId: googlePlaceId,
                    establishmentName: establishmentName,
                    establishments: establishments,
                    authIntent: authIntent
                )
            )
        case .authPhoneSendCode(let phone):
            bodyData = try encoder.encode(PhoneSendBody(phone: phone))
        case .authPhoneVerify(let phone, let code, let googlePlaceId, let establishmentName, let establishments):
            bodyData = try encoder.encode(
                PhoneVerifyBody(
                    phone: phone,
                    code: code,
                    googlePlaceId: googlePlaceId,
                    establishmentName: establishmentName,
                    establishments: establishments
                )
            )
        case .authEmailSendCode(let email):
            bodyData = try encoder.encode(EmailSendBody(email: email))
        case .authEmailVerify(let email, let code, let name, let googlePlaceId, let establishmentName, let establishments):
            bodyData = try encoder.encode(
                EmailVerifyBody(
                    email: email,
                    code: code,
                    name: name,
                    googlePlaceId: googlePlaceId,
                    establishmentName: establishmentName,
                    establishments: establishments
                )
            )
        case .createBusiness(let payload):
            bodyData = try encoder.encode(payload)
        case .createBusinessFromPlace(let name, let placeId):
            bodyData = try encoder.encode(CreateBusinessFromPlacePayload(establishmentName: name, googlePlaceId: placeId))
        case .paymentCheckout(let plan):
            bodyData = try encoder.encode(CheckoutSessionPayload(plan: plan))
        case .paymentReconcileSubscription:
            bodyData = try encoder.encode(PaymentReconcileEmptyBody())
        case .paymentPortalSession:
            bodyData = try encoder.encode(PaymentReconcileEmptyBody())
        case .paymentBusinessCheckoutSession(let businessSlug, let interval):
            bodyData = try encoder.encode(BusinessCheckoutSessionPayload(businessSlug: businessSlug, interval: interval))
        case .paymentAppleSyncTransaction(let payload):
            bodyData = try encoder.encode(payload)
        case .paymentAppleReconcileSubscription:
            bodyData = try encoder.encode(PaymentReconcileEmptyBody())
        case .paymentAppleIntroOfferEligibility(let payload):
            bodyData = try encoder.encode(payload)
        case .scan(_, let barcode, let visit, let points, let amountEur, let receiptValidationToken):
            bodyData = try encoder.encode(ScanPayload(barcode: barcode, visit: visit, points: points, amount_eur: amountEur, receiptValidationToken: receiptValidationToken))
        case .integrationRewardRedeem(_, let barcode):
            bodyData = try encoder.encode(BarcodeOnlyPayload(barcode: barcode))
        case .dashboardReceiptChallenge(_, let amountEur):
            bodyData = try encoder.encode(ReceiptChallengeRequestBody(amountEur: amountEur))
        case .deviceRegister(let token):
            bodyData = try encoder.encode(DeviceRegisterPayload(deviceToken: token))
        case .notifyClients(_, let message):
            bodyData = try encoder.encode(NotifyClientsPayload(message: message))
        case .creditMember(_, _, let points, let amountEur, let visit, let receiptValidationToken):
            bodyData = try encoder.encode(CreditMemberBody(points: points, amountEur: amountEur, visit: visit, receiptValidationToken: receiptValidationToken))
        case .removeMemberPoints(_, _, let points):
            bodyData = try encoder.encode(RemoveMemberPointsBody(points: points))
        case .redeemReward(_, _, let type):
            bodyData = try encoder.encode(RedeemPayload(type: type))
        case .updateLocationSettings(_, let locationLat, let locationLng, let locationRadiusMeters, let locationRelevantText, let locationAddress, let walletPassIncludeLocations):
            bodyData = try encoder.encode(UpdateLocationSettingsPayload(
                locationLat: locationLat,
                locationLng: locationLng,
                locationRadiusMeters: locationRadiusMeters,
                locationRelevantText: locationRelevantText,
                locationAddress: locationAddress,
                walletPassIncludeLocations: walletPassIncludeLocations
            ))
        case .authMePatch(let name):
            bodyData = try encoder.encode(AuthMePatchBody(name: name))
        case .patchDashboardSettings(_, let patch):
            bodyData = try encoder.encode(patch)
        case .dashboardFlyerPut(_, let payload):
            bodyData = try payload.encodedJSON()
        case .dashboardFlyerAIGenerate(_, let body):
            bodyData = try encoder.encode(body)
        case .dashboardFlyerRemoveLogoBackground(_, let imageDataUrl):
            bodyData = try encoder.encode(FlyerRemoveLogoBgRequestBody(imageDataUrl: imageDataUrl))
        case .dashboardCampaignAutomationParse(_, let body):
            bodyData = try encoder.encode(body)
        case .dashboardSocialMetricsRefresh:
            bodyData = try encoder.encode(EmptyJSONBody())
        case .dashboardSocialMetricsManual(_, let payload):
            bodyData = try encoder.encode(payload)
        case .dashboardSocialMissionsPatch(_, let payload):
            bodyData = try encoder.encode(payload)
        case .dashboardPatchGame(_, _, let body):
            bodyData = try encoder.encode(body)
        case .dashboardGameRewardsPut(_, _, let body):
            bodyData = try encoder.encode(body)
        case .dashboardMatchPredictionsConfig(_, let body):
            bodyData = try encoder.encode(body)
        case .dashboardMatchPredictionsSetResult(_, _, let body):
            bodyData = try encoder.encode(body)
        case .dashboardNotificationSend(_, let body):
            bodyData = try encoder.encode(body)
        case .membersImport(_, let payload):
            bodyData = try encoder.encode(payload)
        case .createMember(_, let email, let name):
            bodyData = try encoder.encode(CreateMemberPayload(email: email, name: name))
        case .memberTicketsConvert(_, _, let pointsToConvert, _):
            bodyData = try encoder.encode(MemberTicketsConvertBody(pointsToConvert: pointsToConvert))
        case .deleteAllDashboardMembers:
            bodyData = try encoder.encode(DeleteAllMembersConfirmBody())
        case .authRefresh(let refreshToken):
            bodyData = try encoder.encode(RefreshTokenPayload(refreshToken: refreshToken))
        case .authLogout(let refreshToken):
            bodyData = try encoder.encode(RefreshTokenPayload(refreshToken: refreshToken))
        case .businessTeamInvite(_, let body):
            bodyData = try encoder.encode(body)
        case .businessTeamStaffAccount(_, let body):
            bodyData = try encoder.encode(body)
        case .businessTeamMemberPatch(_, _, let body):
            bodyData = try encoder.encode(body)
        case .businessTeamMemberResendAccess, .dashboardDevSimulatePayment:
            bodyData = try encoder.encode(EmptyJSONBody())
        default:
            break
        }
        var request = URLRequest(url: finalURL)
        request.httpMethod = method
        request.httpBody = bodyData
        // Campagnes + PATCH réglages (icône / pass) : le serveur peut attendre des salves PassKit APNs.
        switch self {
        case .dashboardNotificationSend, .patchDashboardSettings, .dashboardFlyerAIGenerate, .dashboardCampaignAutomationParse:
            request.timeoutInterval = 300
        case .dashboardFlyerRemoveLogoBackground:
            request.timeoutInterval = 120
        default:
            break
        }
        return request
    }
}

private struct DeleteAllMembersConfirmBody: Encodable {
    let confirm: String

    init() {
        self.confirm = "SUPPRIMER tous les membres"
    }
}

private struct RefreshTokenPayload: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        // Contrat API : camelCase (convertToSnakeCase enverrait refresh_token → 400 sur POST /auth/refresh).
        case refreshToken = "refreshToken"
    }
}

private struct EmptyJSONBody: Encodable {}

private struct LoginPayload: Encodable {
    let login: String
    let password: String
}

private struct CheckIdentifierPayload: Encodable {
    let identifier: String
}

private struct CheckEmailPayload: Encodable {
    let email: String
}

private struct CheckGooglePlacePayload: Encodable {
    let googlePlaceId: String

    enum CodingKeys: String, CodingKey {
        case googlePlaceId = "google_place_id"
    }
}

private struct GooglePayload: Encodable {
    let idToken: String
    let googlePlaceId: String?
    let establishmentName: String?
    let establishments: [AuthEstablishmentPayload]?
    let authIntent: String?

    enum CodingKeys: String, CodingKey {
        case idToken
        case googlePlaceId = "google_place_id"
        case establishmentName = "establishment_name"
        case establishments
        case authIntent = "auth_intent"
    }
}

private struct PhoneSendBody: Encodable {
    let phone: String
}

private struct PhoneVerifyBody: Encodable {
    let phone: String
    let code: String
    let googlePlaceId: String?
    let establishmentName: String?
    let establishments: [AuthEstablishmentPayload]?

    enum CodingKeys: String, CodingKey {
        case phone, code
        case googlePlaceId = "google_place_id"
        case establishmentName = "establishment_name"
        case establishments
    }
}

private struct EmailSendBody: Encodable {
    let email: String
}

private struct AuthMePatchBody: Encodable {
    let name: String
}

private struct EmailVerifyBody: Encodable {
    let email: String
    let code: String
    let name: String?
    let googlePlaceId: String?
    let establishmentName: String?
    let establishments: [AuthEstablishmentPayload]?

    enum CodingKeys: String, CodingKey {
        case email, code, name
        case googlePlaceId = "google_place_id"
        case establishmentName = "establishment_name"
        case establishments
    }
}

private struct ApplePayload: Encodable {
    let idToken: String
    let name: String?
    let email: String?
    let googlePlaceId: String?
    let establishmentName: String?
    let establishments: [AuthEstablishmentPayload]?
    let authIntent: String?

    enum CodingKeys: String, CodingKey {
        case idToken
        case name
        case email
        case googlePlaceId = "google_place_id"
        case establishmentName = "establishment_name"
        case establishments
        case authIntent = "auth_intent"
    }
}

private struct DeviceRegisterPayload: Encodable {
    let deviceToken: String
}

private struct NotifyClientsPayload: Encodable {
    let message: String
}

private struct CreditMemberBody: Encodable {
    let points: Int?
    let amountEur: Double?
    let visit: Bool?
    let receiptValidationToken: String?

    enum CodingKeys: String, CodingKey {
        case points
        case amountEur = "amount_eur"
        case visit
        case receiptValidationToken = "receipt_validation_token"
    }

    init(points: Int?, amountEur: Double?, visit: Bool, receiptValidationToken: String?) {
        self.points = points
        self.amountEur = amountEur
        self.visit = visit ? true : nil
        self.receiptValidationToken = receiptValidationToken
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(points, forKey: .points)
        try c.encodeIfPresent(amountEur, forKey: .amountEur)
        try c.encodeIfPresent(visit, forKey: .visit)
        if let t = receiptValidationToken, !t.isEmpty {
            try c.encode(t, forKey: .receiptValidationToken)
        }
    }
}

private struct RemoveMemberPointsBody: Encodable {
    let points: Int
}

private struct MemberTicketsConvertBody: Encodable {
    let pointsToConvert: Int

    enum CodingKeys: String, CodingKey {
        case pointsToConvert = "points_to_convert"
    }
}

enum RedeemType {
    case stamps
    case points(pointsToDeduct: Int)
}

private struct RedeemPayload: Encodable {
    let type: String
    let points: Int?

    init(type: RedeemType) {
        switch type {
        case .stamps:
            self.type = "stamps"
            self.points = nil
        case .points(let n):
            self.type = "points"
            self.points = n
        }
    }
}

struct PointsRewardTierPayload: Encodable {
    let points: Int
    let label: String
}

/// Body PATCH emplacement — clés snake_case comme le backend (`dashboard.js`).
private struct UpdateLocationSettingsPayload: Encodable {
    let locationLat: Double?
    let locationLng: Double?
    let locationRadiusMeters: Int?
    let locationRelevantText: String?
    let locationAddress: String?
    let walletPassIncludeLocations: Bool?

    enum CK: String, CodingKey {
        case locationLat = "location_lat"
        case locationLng = "location_lng"
        case locationRadiusMeters = "location_radius_meters"
        case locationRelevantText = "location_relevant_text"
        case locationAddress = "location_address"
        case walletPassIncludeLocations = "wallet_pass_include_locations"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CK.self)
        try c.encodeIfPresent(locationLat, forKey: .locationLat)
        try c.encodeIfPresent(locationLng, forKey: .locationLng)
        try c.encodeIfPresent(locationRadiusMeters, forKey: .locationRadiusMeters)
        try c.encodeIfPresent(locationRelevantText, forKey: .locationRelevantText)
        try c.encodeIfPresent(locationAddress, forKey: .locationAddress)
        if let w = walletPassIncludeLocations {
            try c.encode(w ? 1 : 0, forKey: .walletPassIncludeLocations)
        }
    }
}

struct WalletPassDesign {
    var organizationName: String
    var backgroundColor: String
    var foregroundColor: String
    var stampEmoji: String
    var requiredStamps: Int
    var programType: String?
    var stripColor: String?
    var stripDisplayMode: String?
    var stripText: String?
    var template: String?
    /// Couleur libellés Wallet (alignée `label_color` SaaS / Ma carte).
    var labelColor: String? = nil
    /// Solde affiché sur le pass comme dans l’aperçu (requête dashboard uniquement ; sinon points réels membre).
    var previewPoints: Int? = nil
    /// Si `true`, le serveur n’utilise pas l’image tampon perso stockée (`stamp_icon`) et dessine le catalogue `stamp_emoji` — aligné sur l’aperçu Ma carte.
    var catalogStampOnly: Bool = false
}

private struct ReceiptChallengeRequestBody: Encodable {
    let amount_eur: Double
    init(amountEur: Double) { amount_eur = amountEur }
}

private struct BarcodeOnlyPayload: Encodable {
    let barcode: String
}

private struct ScanPayload: Encodable {
    let barcode: String
    let visit: Bool?
    let points: Int?
    let amount_eur: Double?
    let receipt_validation_token: String?

    enum CodingKeys: String, CodingKey {
        case barcode, visit, points
        case amount_eur = "amount_eur"
        case receipt_validation_token = "receipt_validation_token"
    }

    init(barcode: String, visit: Bool, points: Int?, amount_eur: Double?, receiptValidationToken: String?) {
        self.barcode = barcode
        self.visit = visit ? true : nil
        self.points = points
        self.amount_eur = amount_eur
        self.receipt_validation_token = receiptValidationToken
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(barcode, forKey: .barcode)
        try c.encodeIfPresent(visit, forKey: .visit)
        try c.encodeIfPresent(points, forKey: .points)
        try c.encodeIfPresent(amount_eur, forKey: .amount_eur)
        if let t = receipt_validation_token, !t.isEmpty {
            try c.encode(t, forKey: .receipt_validation_token)
        }
    }
}
