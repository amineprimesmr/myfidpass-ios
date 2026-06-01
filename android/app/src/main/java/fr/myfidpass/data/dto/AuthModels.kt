package fr.myfidpass.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class LoginRequest(
    /** E-mail ou identifiant employé (`staff_login`) — clé API `login`. */
    val login: String,
    val password: String,
)

@Serializable
data class RegisterRequest(
    val email: String,
    val password: String,
    val name: String? = null,
    @SerialName("google_place_id") val googlePlaceId: String? = null,
    @SerialName("establishment_name") val establishmentName: String? = null,
)

@Serializable
data class RefreshRequest(
    /** Contrat API : camelCase (`refreshToken`), aligné iOS. */
    val refreshToken: String,
)

@Serializable
data class GoogleAuthRequest(
    /** Même clé que l’iOS (`CodingKeys.idToken`, pas snake_case). */
    val idToken: String,
    @SerialName("google_place_id") val googlePlaceId: String? = null,
    @SerialName("establishment_name") val establishmentName: String? = null,
)

@Serializable
data class AppleAuthRequest(
    @SerialName("id_token") val idToken: String,
    val name: String? = null,
    val email: String? = null,
    @SerialName("google_place_id") val googlePlaceId: String? = null,
    @SerialName("establishment_name") val establishmentName: String? = null,
)

@Serializable
data class CheckIdentifierRequest(
    val identifier: String,
)

@Serializable
data class CheckIdentifierResponse(
    @SerialName("account_exists") val accountExists: Boolean? = null,
    val kind: String? = null,
)

@Serializable
data class AuthUser(
    val id: String? = null,
    val email: String? = null,
    val name: String? = null,
    @SerialName("is_admin")
    @Serializable(with = FlexibleOptionalBooleanSerializer::class)
    val isAdmin: Boolean? = null,
    /** `owner` | `manager` | `staff` — accès employé limité à l’app commerçant. */
    @SerialName("workspace_role") val workspaceRole: String? = null,
    @SerialName("staff_login") val staffLogin: String? = null,
)

@Serializable
data class BusinessDto(
    val id: String,
    val name: String,
    val slug: String,
    @SerialName("organization_name") val organizationName: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("dashboard_token") val dashboardToken: String? = null,
)

@Serializable
data class SubscriptionDto(
    val status: String? = null,
    @SerialName("plan_id") val planId: String? = null,
)

@Serializable
data class AuthLoginResponse(
    val user: AuthUser,
    val token: String,
    val refreshToken: String? = null,
    val businesses: List<BusinessDto> = emptyList(),
    val subscription: SubscriptionDto? = null,
    @SerialName("has_active_subscription")
    @Serializable(with = FlexibleOptionalBooleanSerializer::class)
    val hasActiveSubscription: Boolean? = null,
    @SerialName("has_paid_merchant_subscription")
    @Serializable(with = FlexibleOptionalBooleanSerializer::class)
    val hasPaidMerchantSubscription: Boolean? = null,
    @SerialName("merchant_trial_ends_at") val merchantTrialEndsAt: String? = null,
)

@Serializable
data class AuthRefreshResponse(
    val token: String,
    val refreshToken: String? = null,
    val subscription: SubscriptionDto? = null,
    @SerialName("has_active_subscription")
    @Serializable(with = FlexibleOptionalBooleanSerializer::class)
    val hasActiveSubscription: Boolean? = null,
    @SerialName("has_paid_merchant_subscription")
    @Serializable(with = FlexibleOptionalBooleanSerializer::class)
    val hasPaidMerchantSubscription: Boolean? = null,
    @SerialName("merchant_trial_ends_at") val merchantTrialEndsAt: String? = null,
)

@Serializable
data class AuthMeResponse(
    val user: AuthUser,
    val businesses: List<BusinessDto> = emptyList(),
    val subscription: SubscriptionDto? = null,
    @SerialName("has_active_subscription")
    @Serializable(with = FlexibleOptionalBooleanSerializer::class)
    val hasActiveSubscription: Boolean? = null,
    @SerialName("has_paid_merchant_subscription")
    @Serializable(with = FlexibleOptionalBooleanSerializer::class)
    val hasPaidMerchantSubscription: Boolean? = null,
    @SerialName("merchant_trial_ends_at") val merchantTrialEndsAt: String? = null,
)

@Serializable
data class EmailSendCodeRequest(
    val email: String,
)

@Serializable
data class EmailSendCodeResponse(
    val ok: Boolean? = null,
)

@Serializable
data class EmailVerifyRequest(
    val email: String,
    val code: String,
    val name: String? = null,
    @SerialName("google_place_id") val googlePlaceId: String? = null,
    @SerialName("establishment_name") val establishmentName: String? = null,
)

@Serializable
data class AuthConfigResponse(
    val googleClientId: String? = null,
)
