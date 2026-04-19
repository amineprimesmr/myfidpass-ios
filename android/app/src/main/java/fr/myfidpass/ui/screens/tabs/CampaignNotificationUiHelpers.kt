package fr.myfidpass.ui.screens.tabs

import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull

internal fun JsonElement.displayValue(): String = when (this) {
    is JsonNull -> "—"
    is JsonPrimitive -> when {
        booleanOrNull != null -> if (booleanOrNull == true) "Oui" else "Non"
        else -> content
    }
    else -> toString()
}

/** Libellés FR pour les clés de segments (API dashboard). */
internal val segmentKeyLabels: Map<String, String> = mapOf(
    "inactive14" to "Inactifs depuis 14 j",
    "inactive30" to "Inactifs depuis 30 j",
    "inactive60" to "Inactifs depuis 60 j",
    "inactive90" to "Inactifs depuis 90 j",
    "new7" to "Nouveaux (7 j)",
    "new30" to "Nouveaux (30 j)",
    "welcomeNew" to "Accueil nouveaux",
    "pointsNear50" to "Proche de 50 pts",
    "points50" to "50 pts",
    "recurrent" to "Réguliers",
    "birthdayToday" to "Anniversaire aujourd’hui",
)

/** Libellés FR pour les champs « stats » (hors textes d’aide longs). */
internal val statsKeyLabels: Map<String, String> = mapOf(
    "subscriptionsCount" to "Abonnements notif (total)",
    "membersCount" to "Membres en base",
    "webPushCount" to "Web push (navigateur)",
    "passKitCount" to "Passes Apple Wallet enregistrés",
    "passKitWithTokenCount" to "Passes avec jeton push",
    "membersWithNotifications" to "Membres avec au moins un canal notif",
    "passKitUrlConfigured" to "URL PassKit configurée (serveur)",
    "merchant_app_push_configured" to "Push app commerçant (APNs)",
    "merchant_app_push_detail" to "Détail config push commerçant",
    "passkit_wave_gap_ms" to "Intervalle vague PassKit (ms)",
)

/** Clés dont la valeur est un long texte d’aide / diagnostic — affichées dans des blocs repliables. */
internal val statsLongHelpKeys: Set<String> = setOf(
    "helpWhenNoDevice",
    "paradoxExplanation",
    "diagnostic",
    "dataDirHint",
    "membersVsDevicesExplanation",
)

internal fun JsonObject.pickLongHelp(): List<Pair<String, String>> =
    statsLongHelpKeys.mapNotNull { key ->
        val el = this[key] ?: return@mapNotNull null
        if (el is JsonNull) return@mapNotNull null
        val s = el.displayValue().trim()
        if (s.isEmpty() || s == "—") null else {
            val title = when (key) {
                "helpWhenNoDevice" -> "Aide : aucun appareil détecté"
                "paradoxExplanation" -> "Explication « paradoxe » Wallet"
                "diagnostic" -> "Diagnostic configuration"
                "dataDirHint" -> "Données serveur (volume / DATA_DIR)"
                "membersVsDevicesExplanation" -> "Membres vs appareils"
                else -> key
            }
            title to s
        }
    }

internal fun JsonObject.lastBatchSummary(): String? {
    val batch = this["last_batch"] ?: return null
    if (batch is JsonNull) return null
    val obj = batch as? JsonObject ?: return null
    val trigger = obj["trigger_name"]?.displayValue()?.takeIf { it != "—" }.orEmpty()
    val created = obj["created_at"]?.displayValue()?.takeIf { it != "—" }.orEmpty()
    if (trigger.isEmpty() && created.isEmpty()) return null
    return buildString {
        append("Dernier lot d’envoi")
        if (trigger.isNotEmpty()) append(" : ").append(trigger)
        if (created.isNotEmpty()) append(" · ").append(created)
    }
}

internal fun JsonObject.statsKpiEntries(): List<Pair<String, String>> {
    val skip = statsLongHelpKeys + "last_batch"
    return entries
        .filter { it.key !in skip }
        .sortedBy { it.key }
        .map { e ->
            val label = statsKeyLabels[e.key] ?: e.key
            label to e.value.displayValue()
        }
}
