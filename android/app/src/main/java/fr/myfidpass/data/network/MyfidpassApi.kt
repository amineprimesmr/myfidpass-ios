package fr.myfidpass.data.network

import fr.myfidpass.data.dto.AuthConfigResponse
import fr.myfidpass.data.dto.AuthLoginResponse
import fr.myfidpass.data.dto.AuthMeResponse
import fr.myfidpass.data.dto.AdminBusinessesListResponse
import fr.myfidpass.data.dto.AdminEventsListResponse
import fr.myfidpass.data.dto.AdminOverviewResponse
import fr.myfidpass.data.dto.AdminUsersListResponse
import fr.myfidpass.data.dto.AppleAuthRequest
import fr.myfidpass.data.dto.BusinessCategoriesResponse
import fr.myfidpass.data.dto.BusinessMembersResponse
import fr.myfidpass.data.dto.BusinessSettingsResponse
import fr.myfidpass.data.dto.BusinessStatsResponse
import fr.myfidpass.data.dto.BusinessTransactionsResponse
import fr.myfidpass.data.dto.ClaimRewardResponseDto
import fr.myfidpass.data.dto.CreateBusinessRequest
import fr.myfidpass.data.dto.CreateBusinessResponse
import fr.myfidpass.data.dto.CheckoutUrlResponse
import fr.myfidpass.data.dto.DashboardGamesResponse
import fr.myfidpass.data.dto.CreateCategoryRequest
import fr.myfidpass.data.dto.CreateMemberRequest
import fr.myfidpass.data.dto.CreateMemberResponse
import fr.myfidpass.data.dto.CreditMemberRequest
import fr.myfidpass.data.dto.CreditPointsResponse
import fr.myfidpass.data.dto.DashboardEvolutionResponse
import fr.myfidpass.data.dto.DashboardTrafficPatternsResponse
import fr.myfidpass.data.dto.ForgotPasswordRequest
import fr.myfidpass.data.dto.GoogleAuthRequest
import fr.myfidpass.data.dto.DeviceRegisterRequest
import fr.myfidpass.data.dto.GoogleWalletUrlResponse
import fr.myfidpass.data.dto.LoginRequest
import fr.myfidpass.data.dto.LogoutRequest
import fr.myfidpass.data.dto.MemberPublicDetailDto
import fr.myfidpass.data.dto.MemberRewardsListResponse
import fr.myfidpass.data.dto.MemberTicketsResponse
import fr.myfidpass.data.dto.NotifyClientsRequest
import fr.myfidpass.data.dto.NotificationSendRequest
import fr.myfidpass.data.dto.PaymentCheckoutRequest
import fr.myfidpass.data.dto.PatchGameRequest
import fr.myfidpass.data.dto.PaymentReconcileResponse
import fr.myfidpass.data.dto.PlacesAutocompleteResponse
import fr.myfidpass.data.dto.PlacesPlaceDetailsResponse
import fr.myfidpass.data.dto.WorkspaceTeamInviteRequest
import fr.myfidpass.data.dto.WorkspaceTeamInviteResponse
import fr.myfidpass.data.dto.WorkspaceTeamListResponse
import fr.myfidpass.data.dto.PortalUrlResponse
import fr.myfidpass.data.dto.RegisterRequest
import fr.myfidpass.data.dto.ReceiptChallengeRequest
import fr.myfidpass.data.dto.ReceiptChallengeResponse
import fr.myfidpass.data.dto.RedeemRequest
import fr.myfidpass.data.dto.RedeemResponseDto
import fr.myfidpass.data.dto.RemovePointsRequest
import fr.myfidpass.data.dto.TicketsConvertRequest
import fr.myfidpass.data.dto.ResetPasswordRequest
import fr.myfidpass.data.dto.ScanLookupEnvelope
import fr.myfidpass.data.dto.ScanRequest
import fr.myfidpass.data.dto.ScanResponse
import fr.myfidpass.data.dto.UpdateCategoryRequest
import fr.myfidpass.data.dto.UpdateMemberCategoriesRequest
import kotlinx.serialization.json.JsonObject
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.PUT
import retrofit2.http.Path
import retrofit2.http.Query

interface MyfidpassApi {

    @POST("/api/auth/login")
    suspend fun login(@Body body: LoginRequest): AuthLoginResponse

    @POST("/api/auth/register")
    suspend fun register(@Body body: RegisterRequest): AuthLoginResponse

    @GET("/api/places/autocomplete")
    suspend fun placesAutocomplete(@Query("input") input: String): PlacesAutocompleteResponse

    @GET("/api/places/details")
    suspend fun placesPlaceDetails(@Query("place_id") placeId: String): PlacesPlaceDetailsResponse

    @POST("/api/auth/google")
    suspend fun authGoogle(@Body body: GoogleAuthRequest): AuthLoginResponse

    @POST("/api/auth/apple")
    suspend fun authApple(@Body body: AppleAuthRequest): AuthLoginResponse

    @GET("/api/auth/me")
    suspend fun me(): AuthMeResponse

    @GET("/api/auth/config")
    suspend fun authConfig(): AuthConfigResponse

    @POST("/api/auth/forgot-password")
    suspend fun forgotPassword(@Body body: ForgotPasswordRequest): JsonObject

    @POST("/api/auth/reset-password")
    suspend fun resetPassword(@Body body: ResetPasswordRequest): JsonObject

    @POST("/api/auth/logout")
    suspend fun logout(@Body body: LogoutRequest): JsonObject

    @DELETE("/api/auth/account")
    suspend fun deleteAccount()

    @POST("/api/businesses")
    suspend fun createBusiness(@Body body: CreateBusinessRequest): CreateBusinessResponse

    @PATCH("/api/businesses/{slug}/dashboard/settings")
    suspend fun patchDashboardSettings(
        @Path("slug") slug: String,
        @Body body: JsonObject,
    ): JsonObject

    @GET("/api/businesses/{slug}/dashboard/stats")
    suspend fun businessStats(
        @Path("slug") slug: String,
        @Query("period") period: String? = null,
    ): BusinessStatsResponse

    @GET("/api/businesses/{slug}/dashboard/stats/traffic")
    suspend fun businessStatsTraffic(
        @Path("slug") slug: String,
        @Query("period") period: String? = null,
    ): DashboardTrafficPatternsResponse

    @GET("/api/businesses/{slug}/dashboard/evolution")
    suspend fun businessEvolution(
        @Path("slug") slug: String,
        @Query("weeks") weeks: Int? = null,
        @Query("period") period: String? = null,
    ): DashboardEvolutionResponse

    @GET("/api/businesses/{slug}/dashboard/members")
    suspend fun businessMembers(
        @Path("slug") slug: String,
        @Query("limit") limit: Int? = 50,
        @Query("offset") offset: Int? = 0,
        @Query("search") search: String? = null,
        @Query("filter") filter: String? = null,
        @Query("sort") sort: String? = null,
    ): BusinessMembersResponse

    @GET("/api/businesses/{slug}/dashboard/transactions")
    suspend fun businessTransactions(
        @Path("slug") slug: String,
        @Query("limit") limit: Int? = 50,
        @Query("offset") offset: Int? = 0,
        @Query("memberId") memberId: String? = null,
        @Query("days") days: Int? = null,
        @Query("type") type: String? = null,
        @Query("sort") sort: String? = null,
    ): BusinessTransactionsResponse

    @GET("/api/businesses/{slug}/dashboard/settings")
    suspend fun businessSettings(@Path("slug") slug: String): BusinessSettingsResponse

    @GET("/api/businesses/{slug}/dashboard/categories")
    suspend fun businessCategories(@Path("slug") slug: String): BusinessCategoriesResponse

    @POST("/api/businesses/{slug}/dashboard/categories")
    suspend fun createCategory(
        @Path("slug") slug: String,
        @Body body: CreateCategoryRequest,
    ): JsonObject

    @PATCH("/api/businesses/{slug}/dashboard/categories/{categoryId}")
    suspend fun updateCategory(
        @Path("slug") slug: String,
        @Path("categoryId") categoryId: String,
        @Body body: UpdateCategoryRequest,
    ): JsonObject

    @DELETE("/api/businesses/{slug}/dashboard/categories/{categoryId}")
    suspend fun deleteCategory(
        @Path("slug") slug: String,
        @Path("categoryId") categoryId: String,
    )

    @PATCH("/api/businesses/{slug}/dashboard/members/{memberId}/categories")
    suspend fun updateMemberCategories(
        @Path("slug") slug: String,
        @Path("memberId") memberId: String,
        @Body body: UpdateMemberCategoriesRequest,
    ): JsonObject

    @POST("/api/businesses/{slug}/dashboard/members/delete-all")
    suspend fun deleteAllDashboardMembers(
        @Path("slug") slug: String,
        @Body body: JsonObject,
    ): JsonObject

    @GET("/api/businesses/{slug}/dashboard/games")
    suspend fun dashboardGames(@Path("slug") slug: String): DashboardGamesResponse

    @PATCH("/api/businesses/{slug}/dashboard/games/{gameCode}")
    suspend fun dashboardPatchGame(
        @Path("slug") slug: String,
        @Path("gameCode") gameCode: String,
        @Body body: PatchGameRequest,
    ): JsonObject

    @GET("/api/businesses/{slug}/dashboard/games/{gameCode}/rewards")
    suspend fun dashboardGameRewardsGet(
        @Path("slug") slug: String,
        @Path("gameCode") gameCode: String,
    ): JsonObject

    @PUT("/api/businesses/{slug}/dashboard/games/{gameCode}/rewards")
    suspend fun dashboardGameRewardsPut(
        @Path("slug") slug: String,
        @Path("gameCode") gameCode: String,
        @Body body: JsonObject,
    ): JsonObject

    @GET("/api/businesses/{slug}/dashboard/flyer")
    suspend fun dashboardFlyerGet(@Path("slug") slug: String): JsonObject

    @PUT("/api/businesses/{slug}/dashboard/flyer")
    suspend fun dashboardFlyerPut(
        @Path("slug") slug: String,
        @Body body: JsonObject,
    ): JsonObject

    @POST("/api/businesses/{slug}/dashboard/flyer/ai-generate")
    suspend fun dashboardFlyerAiGenerate(
        @Path("slug") slug: String,
        @Body body: JsonObject,
    ): JsonObject

    @GET("/api/businesses/{slug}/dashboard/flyer/ai-generate/jobs/{jobId}")
    suspend fun dashboardFlyerAiJob(
        @Path("slug") slug: String,
        @Path("jobId") jobId: String,
    ): JsonObject

    @POST("/api/businesses/{slug}/dashboard/campaign-automation/parse")
    suspend fun dashboardCampaignAutomationParse(
        @Path("slug") slug: String,
        @Body body: JsonObject,
    ): JsonObject

    @GET("/api/businesses/{slug}/dashboard/social-metrics")
    suspend fun dashboardSocialMetrics(@Path("slug") slug: String): JsonObject

    @POST("/api/businesses/{slug}/dashboard/social-metrics/refresh")
    suspend fun dashboardSocialMetricsRefresh(
        @Path("slug") slug: String,
        @Body body: JsonObject,
    ): JsonObject

    @POST("/api/businesses/{slug}/dashboard/social-metrics/manual")
    suspend fun dashboardSocialMetricsManual(
        @Path("slug") slug: String,
        @Body body: JsonObject,
    ): JsonObject

    @GET("/api/businesses/{slug}/dashboard/social-oauth/meta/start")
    suspend fun socialOAuthMetaStart(@Path("slug") slug: String): JsonObject

    @GET("/api/businesses/{slug}/dashboard/social-oauth/google-youtube/start")
    suspend fun socialOAuthGoogleYoutubeStart(@Path("slug") slug: String): JsonObject

    @GET("/api/businesses/{slug}/dashboard/social-oauth/google-business/start")
    suspend fun socialOAuthGoogleBusinessStart(@Path("slug") slug: String): JsonObject

    @GET("/api/businesses/{slug}/dashboard/social-oauth/tiktok/start")
    suspend fun socialOAuthTiktokStart(@Path("slug") slug: String): JsonObject

    @POST("/api/businesses/{slug}/dashboard/receipt-challenge")
    suspend fun receiptChallenge(
        @Path("slug") slug: String,
        @Body body: ReceiptChallengeRequest,
    ): ReceiptChallengeResponse

    @GET("/api/businesses/{slug}/integration/lookup")
    suspend fun scanLookup(
        @Path("slug") slug: String,
        @Query("barcode") barcode: String,
    ): ScanLookupEnvelope

    @POST("/api/businesses/{slug}/integration/scan")
    suspend fun scan(
        @Path("slug") slug: String,
        @Body body: ScanRequest,
    ): ScanResponse

    @GET("/api/businesses/{slug}/notifications/campaign-segments")
    suspend fun notificationSegments(@Path("slug") slug: String): JsonObject

    @GET("/api/businesses/{slug}/notifications/stats")
    suspend fun notificationStats(@Path("slug") slug: String): JsonObject

    @POST("/api/businesses/{slug}/notifications/send")
    suspend fun notificationSend(
        @Path("slug") slug: String,
        @Body body: NotificationSendRequest,
    ): JsonObject

    @POST("/api/businesses/{slug}/notifications/test-passkit")
    suspend fun dashboardTestPasskit(
        @Path("slug") slug: String,
        @Body body: JsonObject,
    ): JsonObject

    @POST("/api/businesses/{slug}/notifications/remove-test-device")
    suspend fun dashboardRemoveTestDevice(
        @Path("slug") slug: String,
        @Body body: JsonObject,
    ): JsonObject

    @POST("/api/businesses/{slug}/notify")
    suspend fun notifyClients(
        @Path("slug") slug: String,
        @Body body: NotifyClientsRequest,
    ): JsonObject

    @POST("/api/device/register")
    suspend fun deviceRegister(@Body body: DeviceRegisterRequest): JsonObject

    @POST("/api/payment/create-checkout-session")
    suspend fun paymentCheckout(@Body body: PaymentCheckoutRequest): CheckoutUrlResponse

    @POST("/api/payment/reconcile-subscription")
    suspend fun paymentReconcile(): PaymentReconcileResponse

    @POST("/api/payment/create-portal-session")
    suspend fun paymentPortal(): PortalUrlResponse

    @GET("/api/businesses/{slug}/members/{memberId}")
    suspend fun memberPublic(
        @Path("slug") slug: String,
        @Path("memberId") memberId: String,
    ): MemberPublicDetailDto

    @GET("/api/businesses/{slug}/members/{memberId}/google-wallet-url")
    suspend fun googleWalletMemberUrl(
        @Path("slug") slug: String,
        @Path("memberId") memberId: String,
    ): GoogleWalletUrlResponse

    @POST("/api/businesses/{slug}/members/{memberId}/points")
    suspend fun creditMemberPoints(
        @Path("slug") slug: String,
        @Path("memberId") memberId: String,
        @Body body: CreditMemberRequest,
    ): CreditPointsResponse

    @POST("/api/businesses/{slug}/members/{memberId}/points/remove")
    suspend fun removeMemberPoints(
        @Path("slug") slug: String,
        @Path("memberId") memberId: String,
        @Body body: RemovePointsRequest,
    ): CreditPointsResponse

    @POST("/api/businesses/{slug}/members/{memberId}/redeem")
    suspend fun redeemReward(
        @Path("slug") slug: String,
        @Path("memberId") memberId: String,
        @Body body: RedeemRequest,
    ): RedeemResponseDto

    @POST("/api/businesses/{slug}/members")
    suspend fun createMember(
        @Path("slug") slug: String,
        @Body body: CreateMemberRequest,
    ): CreateMemberResponse

    @DELETE("/api/businesses/{slug}/dashboard/members/{memberId}")
    suspend fun deleteDashboardMember(
        @Path("slug") slug: String,
        @Path("memberId") memberId: String,
    )

    @GET("/api/businesses/{slug}/members/{memberId}/tickets")
    suspend fun memberTickets(
        @Path("slug") slug: String,
        @Path("memberId") memberId: String,
    ): MemberTicketsResponse

    @POST("/api/businesses/{slug}/members/{memberId}/tickets/convert")
    suspend fun memberTicketsConvert(
        @Path("slug") slug: String,
        @Path("memberId") memberId: String,
        @Header("Idempotency-Key") idempotencyKey: String? = null,
        @Body body: TicketsConvertRequest,
    ): JsonObject

    @GET("/api/businesses/{slug}/members/{memberId}/rewards")
    suspend fun memberRewardsList(
        @Path("slug") slug: String,
        @Path("memberId") memberId: String,
    ): MemberRewardsListResponse

    @POST("/api/businesses/{slug}/members/{memberId}/rewards/{grantId}/claim")
    suspend fun claimMemberReward(
        @Path("slug") slug: String,
        @Path("memberId") memberId: String,
        @Path("grantId") grantId: String,
        @Body body: JsonObject,
    ): ClaimRewardResponseDto

    @GET("/api/admin/overview")
    suspend fun adminOverview(): AdminOverviewResponse

    @GET("/api/admin/users")
    suspend fun adminUsers(
        @Query("q") q: String? = null,
        @Query("limit") limit: Int? = 50,
        @Query("offset") offset: Int? = 0,
    ): AdminUsersListResponse

    @GET("/api/admin/businesses")
    suspend fun adminBusinesses(
        @Query("q") q: String? = null,
        @Query("limit") limit: Int? = 50,
        @Query("offset") offset: Int? = 0,
    ): AdminBusinessesListResponse

    @GET("/api/admin/events")
    suspend fun adminEvents(
        @Query("limit") limit: Int? = 50,
        @Query("filter") filter: String? = null,
    ): AdminEventsListResponse

    @GET("/api/businesses/{slug}/dashboard/team")
    suspend fun workspaceTeamList(
        @Path("slug") slug: String,
    ): WorkspaceTeamListResponse

    @POST("/api/businesses/{slug}/dashboard/team/invites")
    suspend fun workspaceTeamInvite(
        @Path("slug") slug: String,
        @Body body: WorkspaceTeamInviteRequest,
    ): WorkspaceTeamInviteResponse

    @DELETE("/api/businesses/{slug}/dashboard/team/members/{memberId}")
    suspend fun workspaceTeamRevoke(
        @Path("slug") slug: String,
        @Path("memberId") memberId: String,
    )
}
