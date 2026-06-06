package fr.myfidpass.data.repo

import fr.myfidpass.data.dto.AdminBusinessesListResponse
import fr.myfidpass.data.dto.AdminEventsListResponse
import fr.myfidpass.data.dto.AdminOverviewResponse
import fr.myfidpass.data.dto.AdminUsersListResponse
import fr.myfidpass.data.dto.BusinessMembersResponse
import fr.myfidpass.data.dto.BusinessSettingsResponse
import fr.myfidpass.data.dto.BusinessStatsResponse
import fr.myfidpass.data.dto.BusinessTransactionsResponse
import fr.myfidpass.data.dto.CheckoutUrlResponse
import fr.myfidpass.data.dto.CreateMemberRequest
import fr.myfidpass.data.dto.CreateMemberResponse
import fr.myfidpass.data.dto.CreditMemberRequest
import fr.myfidpass.data.dto.CreditPointsResponse
import fr.myfidpass.data.dto.DashboardEvolutionResponse
import fr.myfidpass.data.dto.DashboardTrafficPatternsResponse
import fr.myfidpass.data.dto.DashboardGamesResponse
import fr.myfidpass.data.dto.FlyerAiGenerateRequest
import fr.myfidpass.data.dto.FlyerAiJobStatusResponse
import fr.myfidpass.data.dto.GoogleBusinessCreatePostRequest
import fr.myfidpass.data.dto.GoogleBusinessPostsResponse
import fr.myfidpass.data.dto.GoogleBusinessReviewReplyRequest
import fr.myfidpass.data.dto.GoogleBusinessReviewsResponse
import fr.myfidpass.data.dto.GoogleBusinessStatusResponse
import fr.myfidpass.data.dto.GoogleWalletUrlResponse
import fr.myfidpass.data.dto.MemberPublicDetailDto
import fr.myfidpass.data.dto.MemberRewardsListResponse
import fr.myfidpass.data.dto.MemberTicketsResponse
import fr.myfidpass.data.dto.MerchantAccountingPackResponse
import fr.myfidpass.data.dto.TransactionExportJsonResponse
import fr.myfidpass.data.dto.NotifyClientsRequest
import fr.myfidpass.data.dto.NotificationSendRequest
import fr.myfidpass.data.dto.PatchGameRequest
import fr.myfidpass.data.dto.BusinessCheckoutSessionRequest
import fr.myfidpass.data.dto.PaymentCheckoutRequest
import fr.myfidpass.data.dto.PaymentReconcileResponse
import fr.myfidpass.data.dto.PortalUrlResponse
import fr.myfidpass.data.dto.ReceiptChallengeRequest
import fr.myfidpass.data.dto.ReceiptChallengeResponse
import fr.myfidpass.data.dto.RedeemRequest
import fr.myfidpass.data.dto.RedeemResponseDto
import fr.myfidpass.data.dto.RemovePointsRequest
import fr.myfidpass.data.dto.TicketsConvertRequest
import fr.myfidpass.data.dto.DeviceRegisterRequest
import fr.myfidpass.data.dto.RewardRedeemScanRequest
import fr.myfidpass.data.dto.RewardRedeemScanResponse
import fr.myfidpass.data.dto.ScanLookupEnvelope
import fr.myfidpass.data.dto.ScanRequest
import fr.myfidpass.data.dto.ScanResponse
import fr.myfidpass.data.dto.WorkspaceTeamInviteRequest
import fr.myfidpass.data.dto.WorkspaceTeamMemberPatchRequest
import fr.myfidpass.data.dto.WorkspaceTeamStaffAccountRequest
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.network.MyfidpassApi
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.util.UUID

class DashboardRepository(
    private val api: MyfidpassApi,
    private val sessionStore: SessionStore,
) {

    fun currentSlug(): String? = sessionStore.currentBusinessSlug

    fun requireSlug(): String = sessionStore.currentBusinessSlug?.trim().orEmpty().ifEmpty {
        error("Aucun commerce sélectionné")
    }

    suspend fun refreshAll(slug: String) = coroutineScope {
        val a = async { runCatching { api.businessSettings(slug) } }
        val b = async { runCatching { api.businessStats(slug) } }
        a.await()
        b.await()
    }

    suspend fun businessStats(slug: String, period: String? = null): BusinessStatsResponse =
        api.businessStats(slug, period)

    suspend fun businessEvolution(slug: String, weeks: Int? = 12, period: String? = null): DashboardEvolutionResponse =
        api.businessEvolution(slug, weeks, period)

    suspend fun businessStatsTraffic(slug: String, period: String? = null): DashboardTrafficPatternsResponse =
        api.businessStatsTraffic(slug, period)

    suspend fun businessTransactions(
        slug: String,
        limit: Int? = 50,
        offset: Int? = 0,
        memberId: String? = null,
        days: Int? = null,
        type: String? = null,
        sort: String? = null,
    ): BusinessTransactionsResponse = api.businessTransactions(slug, limit, offset, memberId, days, type, sort)

    suspend fun businessTransactionsExportCsv(
        slug: String,
        days: Int? = null,
        from: String? = null,
        to: String? = null,
        types: String? = null,
        memberId: String? = null,
        limit: Int? = null,
    ): ByteArray = api.businessTransactionsExportCsv(slug, "csv", days, from, to, types, memberId, limit)
        .byteStream().use { it.readBytes() }

    suspend fun businessTransactionsExportJson(
        slug: String,
        days: Int? = null,
        from: String? = null,
        to: String? = null,
        types: String? = null,
        memberId: String? = null,
        limit: Int? = null,
    ): TransactionExportJsonResponse =
        api.businessTransactionsExportJson(slug, "json", days, from, to, types, memberId, limit)

    suspend fun businessAccountingPack(
        slug: String,
        days: Int? = null,
        from: String? = null,
        to: String? = null,
        limit: Int? = null,
    ): MerchantAccountingPackResponse = api.businessAccountingPack(slug, days, from, to, limit)

    suspend fun businessMembers(
        slug: String,
        limit: Int? = 50,
        offset: Int? = 0,
        search: String? = null,
        filter: String? = null,
        sort: String? = null,
    ): BusinessMembersResponse = api.businessMembers(slug, limit, offset, search, filter, sort)

    suspend fun businessSettings(slug: String): BusinessSettingsResponse =
        api.businessSettings(slug)

    suspend fun patchDashboardSettings(slug: String, patch: JsonObject) {
        api.patchDashboardSettings(slug, patch)
    }

    suspend fun deleteAllDashboardMembers(slug: String) =
        api.deleteAllDashboardMembers(slug, emptyPostBody())

    suspend fun dashboardGames(slug: String): DashboardGamesResponse =
        api.dashboardGames(slug)

    suspend fun dashboardPatchGame(slug: String, gameCode: String, body: PatchGameRequest) =
        api.dashboardPatchGame(slug, gameCode, body)

    suspend fun dashboardGameRewardsGet(slug: String, gameCode: String) =
        api.dashboardGameRewardsGet(slug, gameCode)

    suspend fun dashboardGameRewardsPut(slug: String, gameCode: String, body: JsonObject) =
        api.dashboardGameRewardsPut(slug, gameCode, body)

    suspend fun dashboardFlyerGet(slug: String) = api.dashboardFlyerGet(slug)

    suspend fun dashboardFlyerPut(slug: String, body: JsonObject) = api.dashboardFlyerPut(slug, body)

    suspend fun dashboardFlyerAiGenerate(slug: String, body: JsonObject) =
        api.dashboardFlyerAiGenerate(slug, body)

    suspend fun dashboardFlyerAiJob(slug: String, jobId: String) =
        api.dashboardFlyerAiJob(slug, jobId)

    suspend fun dashboardCampaignAutomationParse(slug: String, body: JsonObject) =
        api.dashboardCampaignAutomationParse(slug, body)

    suspend fun dashboardSocialMetrics(slug: String) = api.dashboardSocialMetrics(slug)

    suspend fun dashboardSocialMetricsRefresh(slug: String) =
        api.dashboardSocialMetricsRefresh(slug, emptyPostBody())

    suspend fun dashboardSocialMetricsManual(slug: String, body: JsonObject) =
        api.dashboardSocialMetricsManual(slug, body)

    suspend fun socialOAuthMetaStart(slug: String) = api.socialOAuthMetaStart(slug)

    suspend fun socialOAuthGoogleYoutubeStart(slug: String) = api.socialOAuthGoogleYoutubeStart(slug)

    suspend fun socialOAuthGoogleBusinessStart(slug: String) = api.socialOAuthGoogleBusinessStart(slug)

    suspend fun googleBusinessStatus(slug: String): GoogleBusinessStatusResponse =
        api.googleBusinessStatus(slug)

    suspend fun googleBusinessReviews(slug: String, limit: Int? = 20): GoogleBusinessReviewsResponse =
        api.googleBusinessReviews(slug, limit)

    suspend fun googleBusinessReviewsSync(slug: String) =
        api.googleBusinessReviewsSync(slug, emptyPostBody())

    suspend fun googleBusinessReviewReply(slug: String, reviewId: String, reply: String) =
        api.googleBusinessReviewReply(slug, reviewId, GoogleBusinessReviewReplyRequest(reply))

    suspend fun googleBusinessPosts(slug: String, limit: Int? = 20): GoogleBusinessPostsResponse =
        api.googleBusinessPosts(slug, limit)

    suspend fun googleBusinessPostCreate(slug: String, summary: String, topicType: String = "STANDARD") =
        api.googleBusinessPostCreate(
            slug,
            GoogleBusinessCreatePostRequest(summary = summary, topicType = topicType),
        )

    suspend fun googleBusinessReviewReplyAi(slug: String, reviewId: String, tone: String = "professional") =
        api.googleBusinessReviewReplyAi(
            slug,
            reviewId,
            buildJsonObject {
                put("tone", tone)
            },
        )

    suspend fun googleBusinessReviewDeleteReply(slug: String, reviewId: String) =
        api.googleBusinessReviewDeleteReply(slug, reviewId)

    suspend fun googleBusinessReviewsMarkAllSeen(slug: String) =
        api.googleBusinessReviewsMarkAllSeen(slug, emptyPostBody())

    suspend fun googleBusinessQuestions(slug: String) = api.googleBusinessQuestions(slug)

    suspend fun googleBusinessQuestionAnswer(slug: String, questionId: String, text: String) =
        api.googleBusinessQuestionAnswer(slug, questionId, buildJsonObject { put("text", text) })

    suspend fun googleBusinessInsights(slug: String, days: Int = 30) =
        api.googleBusinessInsights(slug, days)

    suspend fun googleBusinessRetryPendingLocation(slug: String) =
        api.googleBusinessRetryPendingLocation(slug, emptyPostBody())

    suspend fun membersImport(slug: String, csvContent: String) =
        api.membersImport(slug, buildJsonObject { put("csv", csvContent) })

    suspend fun walletPassUrl(slug: String, memberId: String): String? {
        val r = api.walletPass(slug, memberId)
        return r["url"]?.jsonPrimitive?.content
            ?: r["pass_url"]?.jsonPrimitive?.content
    }

    suspend fun dashboardLogoNobg(slug: String) = api.dashboardLogoNobg(slug)

    suspend fun flyerRemoveLogoBackground(slug: String, imageDataUrl: String) =
        api.dashboardFlyerRemoveLogoBackground(slug, buildJsonObject { put("image_data_url", imageDataUrl) })

    suspend fun flyerAiGenerateAndWait(slug: String, request: FlyerAiGenerateRequest): FlyerAiJobStatusResponse =
        generateFlyerAiAndWait(api, slug, request)

    suspend fun dashboardSocialMissions(slug: String) = api.dashboardSocialMissions(slug)

    suspend fun dashboardSocialMissionsPatch(slug: String, body: JsonObject) =
        api.dashboardSocialMissionsPatch(slug, body)

    suspend fun dashboardMatchPredictions(slug: String) = api.dashboardMatchPredictions(slug)

    suspend fun dashboardMatchPredictionsConfig(slug: String, body: JsonObject) =
        api.dashboardMatchPredictionsConfig(slug, body)

    suspend fun dashboardMatchPredictionsSetResult(slug: String, matchId: String, body: JsonObject) =
        api.dashboardMatchPredictionsSetResult(slug, matchId, body)

    suspend fun businessMembersExportCsv(slug: String, search: String? = null): ByteArray =
        api.businessMembersExportCsv(slug, search).byteStream().use { it.readBytes() }

    suspend fun socialOAuthTiktokStart(slug: String) = api.socialOAuthTiktokStart(slug)

    suspend fun receiptChallenge(slug: String, amountEur: Double): ReceiptChallengeResponse =
        api.receiptChallenge(slug, ReceiptChallengeRequest(amountEur))

    suspend fun dashboardTestPasskit(slug: String) =
        api.dashboardTestPasskit(slug, emptyPostBody())

    suspend fun dashboardRemoveTestDevice(slug: String) =
        api.dashboardRemoveTestDevice(slug, emptyPostBody())

    suspend fun notifyClients(slug: String, message: String) =
        api.notifyClients(slug, NotifyClientsRequest(message = message))

    suspend fun deviceRegister(fcmToken: String) =
        api.deviceRegister(DeviceRegisterRequest(deviceToken = fcmToken))

    suspend fun memberTicketsConvert(slug: String, memberId: String, pointsToConvert: Int) =
        api.memberTicketsConvert(
            slug,
            memberId,
            UUID.randomUUID().toString(),
            TicketsConvertRequest(pointsToConvert = pointsToConvert),
        )

    suspend fun memberRewardsList(slug: String, memberId: String): MemberRewardsListResponse =
        api.memberRewardsList(slug, memberId)

    suspend fun claimMemberReward(slug: String, memberId: String, grantId: String) =
        api.claimMemberReward(slug, memberId, grantId, emptyPostBody())

    suspend fun scanLookup(slug: String, barcode: String): ScanLookupEnvelope =
        api.scanLookup(slug, barcode)

    suspend fun integrationRewardRedeem(slug: String, barcode: String): RewardRedeemScanResponse =
        api.integrationRewardRedeem(slug, RewardRedeemScanRequest(barcode = barcode))

    suspend fun scan(slug: String, body: ScanRequest): ScanResponse =
        api.scan(slug, body)

    suspend fun notificationSegments(slug: String): JsonObject =
        api.notificationSegments(slug)

    suspend fun notificationStats(slug: String): JsonObject =
        api.notificationStats(slug)

    suspend fun sendNotification(
        slug: String,
        message: String,
        title: String? = null,
        segment: String? = null,
    ): JsonObject = api.notificationSend(
        slug,
        NotificationSendRequest(message = message, title = title, segment = segment),
    )

    suspend fun paymentCheckout(planId: String? = null): CheckoutUrlResponse =
        api.paymentCheckout(PaymentCheckoutRequest(planId))

    suspend fun paymentBusinessCheckout(businessSlug: String, interval: String = "month"): CheckoutUrlResponse =
        api.paymentBusinessCheckout(
            BusinessCheckoutSessionRequest(businessSlug = businessSlug, interval = interval),
        )

    suspend fun paymentReconcile(): PaymentReconcileResponse =
        api.paymentReconcile()

    suspend fun devSimulatePayment(slug: String) = api.devSimulatePayment(slug)

    suspend fun paymentPortal(): PortalUrlResponse =
        api.paymentPortal()

    suspend fun memberPublic(slug: String, memberId: String): MemberPublicDetailDto =
        api.memberPublic(slug, memberId)

    suspend fun googleWalletMemberUrl(slug: String, memberId: String): GoogleWalletUrlResponse =
        api.googleWalletMemberUrl(slug, memberId)

    suspend fun creditMemberPoints(
        slug: String,
        memberId: String,
        points: Int? = null,
        amountEur: Double? = null,
        visit: Boolean = false,
        receiptValidationToken: String? = null,
    ): CreditPointsResponse = api.creditMemberPoints(
        slug,
        memberId,
        CreditMemberRequest(
            points = points,
            amountEur = amountEur,
            visit = if (visit) true else null,
            receiptValidationToken = receiptValidationToken,
        ),
    )

    suspend fun removeMemberPoints(slug: String, memberId: String, points: Int): CreditPointsResponse =
        api.removeMemberPoints(slug, memberId, RemovePointsRequest(points))

    suspend fun redeemStamps(slug: String, memberId: String): RedeemResponseDto =
        api.redeemReward(slug, memberId, RedeemRequest(type = "stamps"))

    suspend fun redeemPoints(slug: String, memberId: String, pointsToDeduct: Int): RedeemResponseDto =
        api.redeemReward(slug, memberId, RedeemRequest(type = "points", points = pointsToDeduct))

    suspend fun createMember(slug: String, email: String, name: String): CreateMemberResponse =
        api.createMember(slug, CreateMemberRequest(email = email.trim(), name = name.trim()))

    /** Membre technique « Aperçu Wallet » — idempotent côté API (e-mail fixe par commerce). */
    suspend fun ensurePreviewMemberIdForWallet(slug: String): String {
        val safeSlug = sanitizeSlugForPreviewEmail(slug)
        val email = "wallet-apercu.$safeSlug@example.com"
        val resp = createMember(slug, email, "Aperçu Wallet")
        val id = resp.memberId?.trim()?.takeIf { it.isNotEmpty() }
            ?: resp.member?.id?.trim()?.takeIf { it.isNotEmpty() }
        require(!id.isNullOrEmpty()) { "Impossible de préparer un aperçu Wallet." }
        return id
    }

    private fun sanitizeSlugForPreviewEmail(slug: String): String {
        val allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-".toSet()
        val folded = slug.map { if (it in allowed) it else '-' }.joinToString("")
        val compact = folded.split("-").filter { it.isNotEmpty() }.joinToString("-")
        return (compact.ifEmpty { "carte" }).take(80)
    }

    suspend fun deleteDashboardMember(slug: String, memberId: String) =
        api.deleteDashboardMember(slug, memberId)

    suspend fun memberTickets(slug: String, memberId: String): MemberTicketsResponse =
        api.memberTickets(slug, memberId)

    suspend fun adminOverview(): AdminOverviewResponse = api.adminOverview()

    suspend fun adminUsers(q: String? = null, limit: Int? = 50, offset: Int? = 0): AdminUsersListResponse =
        api.adminUsers(q, limit, offset)

    suspend fun adminBusinesses(q: String? = null, limit: Int? = 50, offset: Int? = 0): AdminBusinessesListResponse =
        api.adminBusinesses(q, limit, offset)

    suspend fun adminEvents(limit: Int? = 50, filter: String? = null): AdminEventsListResponse =
        api.adminEvents(limit, filter)

    suspend fun workspaceTeamList(slug: String) = api.workspaceTeamList(slug)

    suspend fun workspaceTeamMemberDetail(slug: String, memberId: String) =
        api.workspaceTeamMemberDetail(slug, memberId)

    suspend fun workspaceTeamMemberPatch(slug: String, memberId: String, name: String? = null, role: String? = null) =
        api.workspaceTeamMemberPatch(slug, memberId, WorkspaceTeamMemberPatchRequest(name = name, role = role))

    suspend fun workspaceTeamMemberResendAccess(slug: String, memberId: String) =
        api.workspaceTeamMemberResendAccess(slug, memberId, emptyPostBody())

    suspend fun workspaceTeamInvite(slug: String, email: String, name: String? = null, role: String = "staff") =
        api.workspaceTeamInvite(slug, WorkspaceTeamInviteRequest(email = email.trim(), name = name?.trim(), role = role))

    suspend fun businessTeamStaffAccount(slug: String, email: String, name: String? = null, role: String = "staff") =
        api.businessTeamStaffAccount(
            slug,
            WorkspaceTeamStaffAccountRequest(email = email.trim(), name = name?.trim(), role = role),
        )

    suspend fun workspaceTeamRevoke(slug: String, memberId: String) =
        api.workspaceTeamRevoke(slug, memberId)

    private fun emptyPostBody(): JsonObject = buildJsonObject { }
}
