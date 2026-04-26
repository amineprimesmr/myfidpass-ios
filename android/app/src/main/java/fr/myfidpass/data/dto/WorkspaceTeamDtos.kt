package fr.myfidpass.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class WorkspaceTeamMemberDto(
    @SerialName("membership_id") val membershipId: String? = null,
    @SerialName("user_id") val userId: String? = null,
    val email: String? = null,
    @SerialName("staff_login") val staffLogin: String? = null,
    val name: String? = null,
    val role: String? = null,
    val status: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("points_add_count") val pointsAddCount: Int? = null,
    @SerialName("reward_redeem_count") val rewardRedeemCount: Int? = null,
    @SerialName("points_issued") val pointsIssued: Int? = null,
    @SerialName("amount_eur_sum") val amountEurSum: Double? = null,
)

@Serializable
data class WorkspaceTeamListResponse(
    val members: List<WorkspaceTeamMemberDto> = emptyList(),
    val items: List<WorkspaceTeamMemberDto>? = null,
) {
    fun resolved(): List<WorkspaceTeamMemberDto> = items?.takeIf { it.isNotEmpty() } ?: members
}

@Serializable
data class WorkspaceTeamInviteRequest(
    val email: String,
    val name: String? = null,
    val role: String? = "staff",
)

@Serializable
data class WorkspaceTeamInviteResponse(
    val ok: Boolean? = null,
    val message: String? = null,
    @SerialName("email_sent") val emailSent: Boolean? = null,
)
