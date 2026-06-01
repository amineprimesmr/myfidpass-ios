package fr.myfidpass.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class CampaignAutomationRuleDto(
    @Serializable(with = FlexibleOptionalBooleanSerializer::class)
    val enabled: Boolean? = null,
    val message: String? = null,
    val segment: String? = null,
    val title: String? = null,
    @SerialName("event_type") val eventType: String? = null,
    @SerialName("delay_minutes") val delayMinutes: Int? = null,
)

@Serializable
data class CampaignAutomationConfigDto(
    val version: Int? = null,
    @SerialName("global_cooldown_days") val globalCooldownDays: Int? = null,
    val rules: Map<String, CampaignAutomationRuleDto>? = null,
)

val defaultAutomationRuleLabels = mapOf(
    "inactive14" to "Clients inactifs (14 j)",
    "inactive30" to "Clients inactifs (30 j)",
    "new7" to "Nouveaux (7 j)",
    "birthday" to "Anniversaires",
    "locationEntry" to "Entrée périmètre",
)
