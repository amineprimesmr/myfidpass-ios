package fr.myfidpass.data.dto

/** Périmètre Wallet uniquement — plus d’automatisations campagne côté produit. */

const val LOCATION_ENTRY_RULE_ID = "locationEntry"

val defaultPerimeterNotificationMessage: String =
    "Vous êtes à proximité de notre commerce. Passez nous voir, votre carte Wallet est prête."

fun mergedAutomationRules(api: CampaignAutomationConfigDto?): Map<String, CampaignAutomationRuleDto> {
    val existing = api?.rules?.get(LOCATION_ENTRY_RULE_ID)
    val message = existing?.message?.trim()?.takeIf { it.isNotEmpty() } ?: defaultPerimeterNotificationMessage
    return mapOf(
        LOCATION_ENTRY_RULE_ID to CampaignAutomationRuleDto(
            enabled = existing?.enabled == true,
            message = message,
        ),
    )
}

fun ruleDisplayTitle(ruleId: String): String =
    if (ruleId == LOCATION_ENTRY_RULE_ID) "Entrée dans le périmètre" else ruleId
