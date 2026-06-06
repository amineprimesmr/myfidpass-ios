package fr.myfidpass.data.dto

/** Aligné iOS `CampaignNotificationsView` — familles, hub et messages par défaut. */

data class CampaignRuleSpec(
    val id: String,
    val title: String,
    val subtitle: String,
    val segmentKey: String? = null,
    val notificationPreviewTitle: String? = null,
    val timingCaption: String? = null,
)

data class CampaignFamilySpec(
    val id: String,
    val title: String,
    val icon: String,
    val rules: List<CampaignRuleSpec>,
)

val campaignFamilies: List<CampaignFamilySpec> = listOf(
    CampaignFamilySpec(
        id = "reactivation",
        title = "Client inactif +14 jours",
        icon = "reactivation",
        rules = listOf(
            CampaignRuleSpec(
                id = "inactive_14",
                title = "Client inactif +14 jours",
                subtitle = "Aucune visite depuis 2 semaines",
                segmentKey = "inactive14",
            ),
        ),
    ),
    CampaignFamilySpec(
        id = "birthday",
        title = "Anniversaires",
        icon = "birthday",
        rules = listOf(
            CampaignRuleSpec(
                id = "birthday_today",
                title = "Anniversaire du jour",
                subtitle = "Profil complété avec date de naissance",
                segmentKey = "birthdayToday",
            ),
        ),
    ),
    CampaignFamilySpec(
        id = "local",
        title = "Local & Wallet",
        icon = "local",
        rules = listOf(
            CampaignRuleSpec(
                id = "locationEntry",
                title = "Entrée dans le périmètre",
                subtitle = "Notification quand le client entre dans la zone Wallet",
            ),
        ),
    ),
)

val automationHubRules: List<CampaignRuleSpec> = listOf(
    CampaignRuleSpec(
        id = "locationEntry",
        title = "Entrée dans le périmètre",
        subtitle = "Message lié à la géolocalisation Wallet.",
        timingCaption = "Le client voit ce message en passant près du magasin avec sa carte Wallet.",
    ),
    CampaignRuleSpec(
        id = "points_near",
        title = "Presque la récompense",
        subtitle = "Clients proches du palier de points.",
        segmentKey = "pointsNear50",
        notificationPreviewTitle = "Encore quelques points",
    ),
    CampaignRuleSpec(
        id = "reward_ready",
        title = "Récompense prête",
        subtitle = "Clients à récompense disponible.",
        segmentKey = "points50",
        notificationPreviewTitle = "Votre récompense est prête",
    ),
    CampaignRuleSpec(
        id = "inactive_14",
        title = "Client inactif +14 jours",
        subtitle = "Sans visite depuis 2 semaines.",
        segmentKey = "inactive14",
        notificationPreviewTitle = "Ça fait un moment…",
    ),
    CampaignRuleSpec(
        id = "birthday_today",
        title = "Anniversaire du jour",
        subtitle = "Date de naissance renseignée sur le profil.",
        segmentKey = "birthdayToday",
        notificationPreviewTitle = "Joyeux anniversaire",
    ),
)

val defaultAutomationRuleMessages: Map<String, String> = mapOf(
    "inactive_14" to "Ça fait un moment... Revenez nous voir aujourd'hui et profitez de -10 %.",
    "reward_ready" to "Votre récompense est prête — passez en magasin pour en profiter.",
    "points_near" to "Plus que quelques points pour débloquer votre récompense !",
    "birthday_today" to "Joyeux anniversaire ! Profitez de -20 % en commandant aujourd'hui.",
    "locationEntry" to "Vous êtes à proximité de notre commerce. Passez nous voir, votre carte Wallet est prête.",
)

private fun purgeRetiredWelcomeAutomationRules(rules: MutableMap<String, CampaignAutomationRuleDto>) {
    rules.remove("welcome_pass")
    rules.keys.filter { it.startsWith("event_") }.toList().forEach { key ->
        val et = rules[key]?.eventType?.trim()?.lowercase().orEmpty()
        if (et == "member_created") rules.remove(key)
    }
}

fun mergedAutomationRules(api: CampaignAutomationConfigDto?): Map<String, CampaignAutomationRuleDto> {
    val rules = mutableMapOf<String, CampaignAutomationRuleDto>()
    for (spec in automationHubRules) {
        val defMsg = defaultAutomationRuleMessages[spec.id].orEmpty()
        val existing = api?.rules?.get(spec.id)
            ?: when (spec.id) {
                "inactive_14" -> api?.rules?.get("inactive14")
                "birthday_today" -> api?.rules?.get("birthdayToday")
                else -> null
            }
        rules[spec.id] = CampaignAutomationRuleDto(
            enabled = existing?.enabled ?: true,
            message = existing?.message?.takeIf { it.isNotBlank() } ?: defMsg,
            segment = existing?.segment,
            title = existing?.title,
        )
    }
    api?.rules?.forEach { (k, v) ->
        if (k.startsWith("custom_") || k.startsWith("event_")) {
            rules[k] = v
        } else if (rules[k] == null && k !in setOf("inactive14", "birthdayToday", "new_week", "welcome_pass")) {
            rules[k] = v
        }
    }
    purgeRetiredWelcomeAutomationRules(rules)
    upgradeFactoryDisabledHubRules(rules)
    return rules
}

/** Hub entier encore à l’état usine (tout désactivé + libellés par défaut) → activer le carrousel. */
private fun upgradeFactoryDisabledHubRules(rules: MutableMap<String, CampaignAutomationRuleDto>) {
    val hubIds = automationHubRules.map { it.id }
    if (!hubIds.all { rules[it]?.enabled != true }) return
    if (!hubIds.all { id ->
            val msg = rules[id]?.message?.trim().orEmpty()
            val def = defaultAutomationRuleMessages[id].orEmpty()
            msg.isEmpty() || msg == def
        }
    ) {
        return
    }
    for (id in hubIds) {
        val def = defaultAutomationRuleMessages[id].orEmpty()
        val row = rules[id] ?: CampaignAutomationRuleDto(enabled = true, message = def)
        rules[id] = row.copy(
            enabled = true,
            message = row.message?.trim()?.takeIf { it.isNotEmpty() } ?: def,
        )
    }
}

fun ruleDisplayTitle(ruleId: String): String {
    automationHubRules.firstOrNull { it.id == ruleId }?.title?.let { return it }
    campaignFamilies.flatMap { it.rules }.firstOrNull { it.id == ruleId }?.title?.let { return it }
    return defaultAutomationRuleLabels[ruleId] ?: ruleId
}
