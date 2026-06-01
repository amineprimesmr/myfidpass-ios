package fr.myfidpass.util

import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.util.jsonObjectOrNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/** Critère flyer configuré — aligné iOS `CommerceFlyerStore.isFlyerReady`. */
object MerchantFlyerReadiness {
    suspend fun isFlyerReady(slug: String, repository: DashboardRepository): Boolean {
        val key = slug.trim()
        if (key.isEmpty()) return false
        val json = runCatching { repository.dashboardFlyerGet(key) }.getOrNull() ?: return false
        return runCatching { json.looksReady() }.getOrDefault(false)
    }

    private fun JsonObject.looksReady(): Boolean {
        if (stringField("custom_bg_data_url")?.isNotBlank() == true) return true
        if (stringField("custom_logo_data_url")?.isNotBlank() == true) return true
        childObject("flyer_prefs")?.let { prefs ->
            if (prefs.stringField("custom_bg_data_url")?.isNotBlank() == true) return true
        }
        val bootstrapB64 = childObject("state")
            ?.childObject("bootstrap")
            ?.stringField("b64")
        if (bootstrapB64?.isNotBlank() == true) return true
        return false
    }

    private fun JsonObject.stringField(key: String): String? {
        val el = this[key] as? JsonPrimitive ?: return null
        return el.content.takeIf { it.isNotBlank() && it != "null" }
    }

    private fun JsonObject.childObject(key: String): JsonObject? =
        this[key].jsonObjectOrNull()
}
