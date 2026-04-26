package fr.myfidpass.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class RewardsRedeemedBreakdownRow(
    val label: String,
    val count: Int = 0,
)

@Serializable
data class BusinessStatsResponse(
    val period: String? = null,
    @SerialName("period_key") val periodKey: String? = null,
    @SerialName("members_count") val membersCount: Int? = null,
    @SerialName("points_this_month") val pointsThisMonth: Int? = null,
    @SerialName("transactions_this_month") val transactionsThisMonth: Int? = null,
    @SerialName("new_members_last_7_days") val newMembersLast7Days: Int? = null,
    @SerialName("new_members_last_30_days") val newMembersLast30Days: Int? = null,
    @SerialName("avg_basket_eur") val avgBasketEur: Double? = null,
    @SerialName("baseline_avg_basket_eur") val baselineAvgBasketEur: Double? = null,
    @SerialName("rewards_redeemed_breakdown")
    val rewardsRedeemedBreakdown: List<RewardsRedeemedBreakdownRow>? = null,
    @SerialName("business_name") val businessName: String? = null,
)

@Serializable
data class DashboardTrafficHourBucket(
    val hour: Int = 0,
    val count: Int = 0,
)

@Serializable
data class DashboardTrafficWeekdayBucket(
    val weekday: Int = 0,
    val label: String? = null,
    val count: Int = 0,
)

@Serializable
data class DashboardTrafficPeakHour(
    val hour: Int = 0,
    val count: Int = 0,
    @SerialName("pct_of_total") val pctOfTotal: Double? = null,
)

@Serializable
data class DashboardTrafficPeakWeekday(
    val weekday: Int = 0,
    val label: String? = null,
    val count: Int = 0,
    @SerialName("pct_of_total") val pctOfTotal: Double? = null,
)

@Serializable
data class DashboardTrafficPatternsResponse(
    val period: String? = null,
    @SerialName("period_key") val periodKey: String? = null,
    @SerialName("timezone_note") val timezoneNote: String? = null,
    val basis: String? = null,
    @SerialName("total_events") val totalEvents: Int? = null,
    @SerialName("by_hour") val byHour: List<DashboardTrafficHourBucket> = emptyList(),
    @SerialName("by_weekday") val byWeekday: List<DashboardTrafficWeekdayBucket> = emptyList(),
    @SerialName("peak_hour") val peakHour: DashboardTrafficPeakHour? = null,
    @SerialName("peak_weekday") val peakWeekday: DashboardTrafficPeakWeekday? = null,
)

@Serializable
data class BusinessMembersResponse(
    val members: List<MemberDto> = emptyList(),
    val total: Int? = null,
)

@Serializable
data class MemberDto(
    val id: String,
    val name: String? = null,
    val email: String? = null,
    val points: Int? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("last_visit_at") val lastVisitAt: String? = null,
    @SerialName("category_ids") val categoryIds: List<String>? = null,
)

/** Membre renvoyé par scan / lookup (champs souples, `id` parfois optionnel selon erreurs partielles). */
@Serializable
data class ScanMemberDto(
    val id: String? = null,
    val name: String? = null,
    val email: String? = null,
    val points: Int? = null,
    @SerialName("last_visit_at") val lastVisitAt: String? = null,
)

@Serializable
data class BusinessSettingsResponse(
    @SerialName("organization_name") val organizationName: String? = null,
    @SerialName("background_color") val backgroundColor: String? = null,
    @SerialName("foreground_color") val foregroundColor: String? = null,
    @SerialName("label_color") val labelColor: String? = null,
    @SerialName("logo_url") val logoUrl: String? = null,
    @SerialName("program_type") val programType: String? = null,
    @SerialName("loyalty_mode") val loyaltyMode: String? = null,
)

@Serializable
data class ScanLookupEnvelope(
    val member: ScanMemberDto? = null,
    val found: Boolean? = null,
)

@Serializable
data class ScanRequest(
    val barcode: String,
    val visit: Boolean = false,
    val points: Int? = null,
    @SerialName("amount_eur") val amountEur: Double? = null,
    @SerialName("receipt_validation_token") val receiptValidationToken: String? = null,
)

@Serializable
data class ScanResponse(
    val ok: Boolean? = null,
    val message: String? = null,
    val member: ScanMemberDto? = null,
    @SerialName("points_added") val pointsAdded: Int? = null,
    @SerialName("new_balance") val newBalance: Int? = null,
)

@Serializable
data class MemberPublicDetailDto(
    val id: String? = null,
    val email: String? = null,
    val name: String? = null,
    val points: Int? = null,
    @SerialName("last_visit_at") val lastVisitAt: String? = null,
    val phone: String? = null,
    val city: String? = null,
    @SerialName("birth_date") val birthDate: String? = null,
    @SerialName("category_ids") val categoryIds: List<String>? = null,
)

@Serializable
data class GoogleWalletUrlResponse(
    val url: String? = null,
)

@Serializable
data class CreditMemberRequest(
    val points: Int? = null,
    @SerialName("amount_eur") val amountEur: Double? = null,
    val visit: Boolean? = null,
    @SerialName("receipt_validation_token") val receiptValidationToken: String? = null,
)

@Serializable
data class CreditPointsResponse(
    val ok: Boolean? = null,
    val message: String? = null,
    @SerialName("new_balance") val newBalance: Int? = null,
    val member: ScanMemberDto? = null,
)

@Serializable
data class NotificationSendRequest(
    val message: String,
    val title: String? = null,
    @SerialName("category_ids") val categoryIds: List<String>? = null,
    val segment: String? = null,
)
