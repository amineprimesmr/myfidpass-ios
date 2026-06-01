package fr.myfidpass.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class CreateBusinessRequest(
    val name: String,
    val slug: String? = null,
    @SerialName("organizationName") val organizationName: String? = null,
)

@Serializable
data class CreateBusinessFromPlaceRequest(
    @SerialName("establishment_name") val establishmentName: String,
    @SerialName("google_place_id") val googlePlaceId: String,
)

@Serializable
data class CreateBusinessFromPlaceResponse(
    val slug: String,
    val name: String? = null,
    @SerialName("organization_name") val organizationName: String? = null,
    @SerialName("dashboard_token") val dashboardToken: String? = null,
    val businesses: List<BusinessDto>? = null,
)

@Serializable
data class CreateBusinessResponse(
    val id: String? = null,
    val name: String? = null,
    val slug: String? = null,
    @SerialName("organization_name") val organizationName: String? = null,
    @SerialName("dashboard_token") val dashboardToken: String? = null,
)

@Serializable
data class UpdateMemberCategoriesRequest(
    @SerialName("category_ids") val categoryIds: List<String>,
)

@Serializable
data class DeviceRegisterRequest(
    @SerialName("device_token") val deviceToken: String,
    val platform: String = "android",
)

@Serializable
data class NotifyClientsRequest(
    val message: String,
    @SerialName("category_ids") val categoryIds: List<String>? = null,
)

@Serializable
data class ReceiptChallengeRequest(
    @SerialName("amount_eur") val amountEur: Double,
)

@Serializable
data class ReceiptChallengeResponse(
    @SerialName("qr_payload") val qrPayload: String,
    @SerialName("expires_at") val expiresAt: String? = null,
    @SerialName("amount_eur") val amountEur: Double? = null,
)

@Serializable
data class TicketsConvertRequest(
    @SerialName("points_to_convert") val pointsToConvert: Int,
)

@Serializable
data class MemberRewardsListResponse(
    val rewards: List<MemberGameRewardDto> = emptyList(),
)

@Serializable
data class MemberGameRewardDto(
    val id: String? = null,
    val status: String? = null,
    val reward: MemberRewardNestedDto? = null,
)

@Serializable
data class MemberRewardNestedDto(
    val code: String? = null,
    val label: String? = null,
    val kind: String? = null,
)

@Serializable
data class ClaimRewardResponseDto(val ok: Boolean? = null)

@Serializable
data class DashboardGamesResponse(
    val games: List<BusinessGameDto> = emptyList(),
)

@Serializable
data class BusinessGameDto(
    val id: String? = null,
    @SerialName("game_code") val gameCode: String? = null,
    @SerialName("game_name") val gameName: String? = null,
    val enabled: Boolean? = null,
    @SerialName("ticket_cost") val ticketCost: Int? = null,
    @SerialName("daily_spin_limit") val dailySpinLimit: Int? = null,
    @SerialName("cooldown_seconds") val cooldownSeconds: Int? = null,
)

@Serializable
data class PatchGameRequest(
    val enabled: Boolean? = null,
    @SerialName("ticket_cost") val ticketCost: Int? = null,
    @SerialName("daily_spin_limit") val dailySpinLimit: Int? = null,
    @SerialName("cooldown_seconds") val cooldownSeconds: Int? = null,
)

@Serializable
data class AdminEventsListResponse(
    val events: List<AdminEventRowDto> = emptyList(),
)

@Serializable
data class AdminEventRowDto(
    val id: String,
    @SerialName("event_type") val eventType: String? = null,
    @SerialName("payload_json") val payloadJson: String? = null,
    @SerialName("stripe_event_id") val stripeEventId: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
)
