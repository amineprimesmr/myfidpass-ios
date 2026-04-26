package fr.myfidpass.data.repo

import fr.myfidpass.data.dto.AdminBusinessesListResponse
import fr.myfidpass.data.dto.AdminEventsListResponse
import fr.myfidpass.data.dto.AdminOverviewResponse
import fr.myfidpass.data.dto.AdminUsersListResponse
import fr.myfidpass.data.dto.BusinessCategoriesResponse
import fr.myfidpass.data.dto.BusinessMembersResponse
import fr.myfidpass.data.dto.BusinessSettingsResponse
import fr.myfidpass.data.dto.BusinessStatsResponse
import fr.myfidpass.data.dto.BusinessTransactionsResponse
import fr.myfidpass.data.dto.CheckoutUrlResponse
import fr.myfidpass.data.dto.CreateCategoryRequest
import fr.myfidpass.data.dto.CreateMemberRequest
import fr.myfidpass.data.dto.CreateMemberResponse
import fr.myfidpass.data.dto.CreditMemberRequest
import fr.myfidpass.data.dto.CreditPointsResponse
import fr.myfidpass.data.dto.DashboardEvolutionResponse
import fr.myfidpass.data.dto.DashboardTrafficPatternsResponse
import fr.myfidpass.data.dto.DashboardGamesResponse
import fr.myfidpass.data.dto.GoogleWalletUrlResponse
import fr.myfidpass.data.dto.MemberPublicDetailDto
import fr.myfidpass.data.dto.MemberRewardsListResponse
import fr.myfidpass.data.dto.MemberTicketsResponse
import fr.myfidpass.data.dto.NotifyClientsRequest
import fr.myfidpass.data.dto.NotificationSendRequest
import fr.myfidpass.data.dto.PatchGameRequest
import fr.myfidpass.data.dto.PaymentCheckoutRequest
import fr.myfidpass.data.dto.PaymentReconcileResponse
import fr.myfidpass.data.dto.PortalUrlResponse
import fr.myfidpass.data.dto.ReceiptChallengeRequest
import fr.myfidpass.data.dto.ReceiptChallengeResponse
import fr.myfidpass.data.dto.RedeemRequest
import fr.myfidpass.data.dto.RedeemResponseDto
import fr.myfidpass.data.dto.RemovePointsRequest
import fr.myfidpass.data.dto.TicketsConvertRequest
import fr.myfidpass.data.dto.UpdateMemberCategoriesRequest
import fr.myfidpass.data.dto.DeviceRegisterRequest
import fr.myfidpass.data.dto.ScanLookupEnvelope
import fr.myfidpass.data.dto.ScanRequest
import fr.myfidpass.data.dto.ScanResponse
import fr.myfidpass.data.dto.UpdateCategoryRequest
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.network.MyfidpassApi
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
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

    suspend fun businessCategories(slug: String): BusinessCategoriesResponse =
        api.businessCategories(slug)

    suspend fun createCategory(slug: String, name: String, colorHex: String? = null, sortOrder: Int? = null) =
        api.createCategory(slug, CreateCategoryRequest(name = name, colorHex = colorHex, sortOrder = sortOrder))

    suspend fun updateCategory(
        slug: String,
        categoryId: String,
        name: String? = null,
        colorHex: String? = null,
        sortOrder: Int? = null,
    ) = api.updateCategory(slug, categoryId, UpdateCategoryRequest(name, colorHex, sortOrder))

    suspend fun deleteCategory(slug: String, categoryId: String) =
        api.deleteCategory(slug, categoryId)

    suspend fun patchDashboardSettings(slug: String, patch: JsonObject): JsonObject =
        api.patchDashboardSettings(slug, patch)

    suspend fun updateMemberCategories(slug: String, memberId: String, categoryIds: List<String>) =
        api.updateMemberCategories(slug, memberId, UpdateMemberCategoriesRequest(categoryIds))

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

    suspend fun socialOAuthTiktokStart(slug: String) = api.socialOAuthTiktokStart(slug)

    suspend fun receiptChallenge(slug: String, amountEur: Double): ReceiptChallengeResponse =
        api.receiptChallenge(slug, ReceiptChallengeRequest(amountEur))

    suspend fun dashboardTestPasskit(slug: String) =
        api.dashboardTestPasskit(slug, emptyPostBody())

    suspend fun dashboardRemoveTestDevice(slug: String) =
        api.dashboardRemoveTestDevice(slug, emptyPostBody())

    suspend fun notifyClients(slug: String, message: String, categoryIds: List<String>? = null) =
        api.notifyClients(slug, NotifyClientsRequest(message = message, categoryIds = categoryIds))

    suspend fun deviceRegister(fcmToken: String) =
        api.deviceRegister(DeviceRegisterRequest(fcmToken))

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

    suspend fun scan(slug: String, body: ScanRequest): ScanResponse =
        api.scan(slug, body)

    suspend fun notificationSegments(slug: String): JsonObject =
        api.notificationSegments(slug)

    suspend fun notificationStats(slug: String): JsonObject =
        api.notificationStats(slug)

    suspend fun sendNotification(
        slug: String,
        message: String,
        categoryIds: List<String>? = null,
        title: String? = null,
        segment: String? = null,
    ): JsonObject = api.notificationSend(
        slug,
        NotificationSendRequest(message = message, title = title, categoryIds = categoryIds, segment = segment),
    )

    suspend fun paymentCheckout(planId: String? = null): CheckoutUrlResponse =
        api.paymentCheckout(PaymentCheckoutRequest(planId))

    suspend fun paymentReconcile(): PaymentReconcileResponse =
        api.paymentReconcile()

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

    private fun emptyPostBody(): JsonObject = buildJsonObject { }
}
