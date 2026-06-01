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
    @SerialName("invited_by_label") val invitedByLabel: String? = null,
    @SerialName("scan_count") val scanCount: Int? = null,
    @SerialName("points_add_count") val pointsAddCount: Int? = null,
    @SerialName("reward_redeem_count") val rewardRedeemCount: Int? = null,
    @SerialName("points_correction_count") val pointsCorrectionCount: Int? = null,
    @SerialName("points_issued") val pointsIssued: Int? = null,
    @SerialName("amount_eur_sum") val amountEurSum: Double? = null,
    @SerialName("last_activity_at") val lastActivityAt: String? = null,
    @SerialName("scans_7d") val scans7d: Int? = null,
    @SerialName("scans_30d") val scans30d: Int? = null,
) {
    val displayName: String
        get() {
            name?.trim()?.takeIf { it.isNotEmpty() }?.let { return it }
            staffLogin?.trim()?.takeIf { it.isNotEmpty() }?.let { return it }
            email?.trim()?.takeIf { it.isNotEmpty() }?.let { return it }
            return "Membre"
        }

    val isOwner: Boolean get() = role?.lowercase() == "owner"

    val apiMemberId: String?
        get() = membershipId?.trim()?.takeIf { it.isNotEmpty() }
            ?: userId?.trim()?.takeIf { it.isNotEmpty() }
}

@Serializable
data class WorkspaceTeamTotalsDto(
    @SerialName("scan_count") val scanCount: Int? = null,
    @SerialName("scans_7d") val scans7d: Int? = null,
    @SerialName("scans_30d") val scans30d: Int? = null,
    @SerialName("member_count") val memberCount: Int? = null,
)

@Serializable
data class WorkspaceTeamListResponse(
    val members: List<WorkspaceTeamMemberDto> = emptyList(),
    val items: List<WorkspaceTeamMemberDto>? = null,
    @SerialName("team_totals") val teamTotals: WorkspaceTeamTotalsDto? = null,
) {
    fun resolved(): List<WorkspaceTeamMemberDto> = items?.takeIf { it.isNotEmpty() } ?: members
}

@Serializable
data class WorkspaceTeamMemberDetailResponse(
    val member: WorkspaceTeamMemberDto,
    @SerialName("recent_activity") val recentActivity: List<WorkspaceTeamActivityDto> = emptyList(),
)

@Serializable
data class WorkspaceTeamActivityDto(
    val id: String,
    val type: String? = null,
    val points: Int? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("member_id") val memberId: String? = null,
    @SerialName("member_name") val memberName: String? = null,
    @SerialName("amount_eur") val amountEur: Double? = null,
)

@Serializable
data class WorkspaceTeamInviteRequest(
    val email: String,
    val name: String? = null,
    val role: String? = "staff",
)

@Serializable
data class WorkspaceTeamStaffAccountRequest(
    val email: String,
    val name: String? = null,
    val role: String? = "staff",
)

@Serializable
data class WorkspaceTeamStaffAccountResponse(
    val ok: Boolean? = null,
    val message: String? = null,
    @SerialName("user_id") val userId: String? = null,
    val email: String? = null,
    @SerialName("email_sent") val emailSent: Boolean? = null,
)

@Serializable
data class WorkspaceTeamMemberPatchRequest(
    val name: String? = null,
    val role: String? = null,
)

@Serializable
data class WorkspaceTeamMemberPatchResponse(
    val ok: Boolean? = null,
    val member: WorkspaceTeamMemberDto? = null,
)

@Serializable
data class WorkspaceTeamInviteResponse(
    val ok: Boolean? = null,
    val message: String? = null,
    @SerialName("email_sent") val emailSent: Boolean? = null,
)

@Serializable
data class WorkspaceTeamResendAccessResponse(
    val ok: Boolean? = null,
    val message: String? = null,
    @SerialName("email_sent") val emailSent: Boolean? = null,
)
