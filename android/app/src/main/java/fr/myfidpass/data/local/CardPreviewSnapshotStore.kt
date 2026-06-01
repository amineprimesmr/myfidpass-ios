package fr.myfidpass.data.local

import android.content.Context
import android.content.SharedPreferences
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
data class CardPreviewSnapshot(
    val programType: String = "points",
    val displayName: String = "",
    val primaryHex: String = "",
    val accentHex: String = "",
    val labelHex: String = "",
    val stripDisplayMode: String = "logo",
    val stripText: String = "",
    val logoUrl: String? = null,
    val stampEmoji: String? = null,
    val requiredStamps: Int = 10,
    val hasLocalBackground: Boolean = false,
    val hasRemoteBackground: Boolean = false,
    val stampRewardLabel: String = "",
    val stampMidRewardLabel: String = "",
    val startGameRewardLabel: String = "",
    val tierPoints: List<String> = emptyList(),
    val tierLabels: List<String> = emptyList(),
    val hasServerStampIcon: Boolean = false,
)

object CardPreviewSnapshotStore {
    private val json = Json { ignoreUnknownKeys = true }

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences("myfidpass_card_snapshot", Context.MODE_PRIVATE)

    fun load(context: Context, slug: String): CardPreviewSnapshot? {
        val raw = prefs(context).getString(key(slug), null) ?: return null
        return runCatching { json.decodeFromString<CardPreviewSnapshot>(raw) }.getOrNull()
    }

    fun save(context: Context, slug: String, snapshot: CardPreviewSnapshot) {
        prefs(context).edit().putString(key(slug), json.encodeToString(snapshot)).apply()
    }

    fun isMerchantCardConfigured(context: Context, slug: String): Boolean {
        val snap = load(context, slug) ?: return false
        return snap.displayName.isNotBlank() &&
            snap.primaryHex.isNotBlank() &&
            snap.accentHex.isNotBlank() &&
            snap.labelHex.isNotBlank()
    }

    private fun key(slug: String) = "myfidpass.cardDisplaySnapshot.v1.${slug.trim().lowercase()}"
}
