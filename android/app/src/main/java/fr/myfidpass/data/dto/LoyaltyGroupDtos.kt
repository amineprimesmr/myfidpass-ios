package fr.myfidpass.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class LoyaltyGroupSummaryDto(
    val id: String,
    val name: String,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
    @SerialName("business_count") val businessCount: Int? = null,
)

@Serializable
data class LoyaltyGroupsListResponse(
    @SerialName("loyalty_groups") val loyaltyGroups: List<LoyaltyGroupSummaryDto> = emptyList(),
)

@Serializable
data class LoyaltyGroupDto(
    val id: String,
    val name: String,
    @SerialName("owner_user_id") val ownerUserId: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
)

@Serializable
data class LoyaltyGroupBusinessLinkDto(
    val id: String,
    val name: String,
    val slug: String,
    @SerialName("organization_name") val organizationName: String? = null,
    @SerialName("loyalty_group_id") val loyaltyGroupId: String? = null,
    @SerialName("program_type") val programType: String? = null,
    @SerialName("required_stamps") val requiredStamps: Int? = null,
)

@Serializable
data class LoyaltyGroupDetailResponse(
    @SerialName("loyalty_group") val loyaltyGroup: LoyaltyGroupDto,
    val businesses: List<LoyaltyGroupBusinessLinkDto> = emptyList(),
)

@Serializable
data class LoyaltyGroupCreateRequest(
    val name: String,
    @SerialName("business_ids") val businessIds: List<String>? = null,
)

@Serializable
data class LoyaltyGroupCreateResponse(
    @SerialName("loyalty_group") val loyaltyGroup: LoyaltyGroupDto,
    val businesses: List<LoyaltyGroupBusinessLinkDto> = emptyList(),
)

@Serializable
data class LoyaltyGroupPatchRequest(
    val name: String,
)

@Serializable
data class LoyaltyGroupLinkBusinessRequest(
    @SerialName("business_id") val businessId: String? = null,
    val slug: String? = null,
)

@Serializable
data class LoyaltyGroupLinkBusinessResponse(
    @SerialName("loyalty_group") val loyaltyGroup: LoyaltyGroupDto,
    val business: LoyaltyGroupBusinessLinkDto,
)

@Serializable
data class LoyaltyGroupOkResponse(
    val ok: Boolean? = null,
)
