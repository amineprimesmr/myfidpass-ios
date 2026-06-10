package fr.myfidpass.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ForgotPasswordRequest(val email: String)

@Serializable
data class ResetPasswordRequest(
    val token: String,
    /** Aligné iOS `ResetPasswordPayload` (clé `newPassword`, pas snake_case). */
    @SerialName("newPassword") val newPassword: String,
)

@Serializable
data class LogoutRequest(
    val refreshToken: String? = null,
)

@Serializable
data class DashboardEvolutionResponse(
    val evolution: List<EvolutionWeekDto> = emptyList(),
)

@Serializable
data class EvolutionWeekDto(
    @SerialName("week_index") val weekIndex: Int? = null,
    @SerialName("day_of_month") val dayOfMonth: Int? = null,
    @SerialName("operations_count") val operationsCount: Int? = null,
    @SerialName("members_count") val membersCount: Int? = null,
    @SerialName("new_members_in_month") val newMembersInMonth: Int? = null,
    @SerialName("avg_basket_eur_in_month") val avgBasketEurInMonth: Double? = null,
    @SerialName("avg_basket_eur_in_interval") val avgBasketEurInInterval: Double? = null,
    @SerialName("basket_total_eur_in_month") val basketTotalEurInMonth: Double? = null,
)

@Serializable
data class BusinessTransactionsResponse(
    val transactions: List<TransactionDto> = emptyList(),
    val total: Int? = null,
)

@Serializable
data class TransactionDto(
    val id: String? = null,
    @SerialName("member_id") val memberId: String? = null,
    @SerialName("member_name") val memberName: String? = null,
    @SerialName("member_email") val memberEmail: String? = null,
    val type: String? = null,
    val points: Int? = null,
    val metadata: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
)

@Serializable
data class BusinessCheckoutSessionRequest(
    @SerialName("business_slug") val businessSlug: String? = null,
    val interval: String? = null,
)

@Serializable
data class PaymentCheckoutRequest(
    @SerialName("plan_id") val planId: String? = null,
)

@Serializable
data class CheckoutUrlResponse(val url: String? = null)

@Serializable
data class PortalUrlResponse(val url: String? = null)

@Serializable
data class PaymentReconcileResponse(
    val ok: Boolean? = null,
    @SerialName("has_active_subscription") val hasActiveSubscription: Boolean? = null,
    val message: String? = null,
)

@Serializable
data class CreateMemberRequest(val email: String, val name: String)

@Serializable
data class CreateMemberResponse(
    @SerialName("member_id") val memberId: String? = null,
    val member: ScanMemberDto? = null,
)

@Serializable
data class RemovePointsRequest(val points: Int)

@Serializable
data class RedeemRequest(
    val type: String,
    val points: Int? = null,
)

@Serializable
data class RedeemResponseDto(
    val ok: Boolean? = null,
    val type: String? = null,
    @SerialName("new_points") val newPoints: Int? = null,
    @SerialName("previous_points") val previousPoints: Int? = null,
    @SerialName("points_deducted") val pointsDeducted: Int? = null,
    val message: String? = null,
)

@Serializable
data class MemberTicketsResponse(
    @SerialName("ticket_balance") val ticketBalance: Int? = null,
    val points: Int? = null,
    @SerialName("loyalty_mode") val loyaltyMode: String? = null,
    @SerialName("points_per_ticket") val pointsPerTicket: Int? = null,
)

@Serializable
data class AdminOverviewResponse(
    @SerialName("users_count") val usersCount: Int? = null,
    @SerialName("businesses_count") val businessesCount: Int? = null,
    @SerialName("merchant_owners_count") val merchantOwnersCount: Int? = null,
    @SerialName("team_member_accounts_count") val teamMemberAccountsCount: Int? = null,
    @SerialName("platform_admin_accounts_count") val platformAdminAccountsCount: Int? = null,
    @SerialName("orphan_accounts_count") val orphanAccountsCount: Int? = null,
    @SerialName("active_subscriptions_count") val activeSubscriptionsCount: Int? = null,
)

@Serializable
data class AdminUsersListResponse(val users: List<AdminUserRowDto> = emptyList())

@Serializable
data class AdminUserRowDto(
    val id: String,
    val email: String? = null,
    val name: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("is_admin") val isAdmin: Int? = null,
)

@Serializable
data class AdminBusinessesListResponse(val businesses: List<AdminBusinessRowDto> = emptyList())

@Serializable
data class AdminBusinessRowDto(
    val id: String,
    val slug: String,
    val name: String? = null,
    @SerialName("organization_name") val organizationName: String? = null,
    @SerialName("user_id") val userId: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("owner_email") val ownerEmail: String? = null,
    @SerialName("member_count") val memberCount: Int? = null,
    @SerialName("owner_subscription_status") val ownerSubscriptionStatus: String? = null,
    @SerialName("owner_plan_id") val ownerPlanId: String? = null,
)
