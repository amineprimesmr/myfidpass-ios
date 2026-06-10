package fr.myfidpass.data.local

import android.content.Context
import fr.myfidpass.data.dto.NotificationCampaignInsightDto
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
data class NotificationSendLocalEntry(
    val id: String,
    val createdAtISO: String,
    val title: String? = null,
    val message: String,
    val recipientOrSentCount: Int = 0,
    val expectedDevices: Int? = null,
    val deliveryStatus: String? = null,
    val jobId: String? = null,
)

object NotificationSendLocalHistoryStore {
    private const val PREFS = "myfidpass.notificationSendLocalHistory.v3"
    private const val KEY = "by_scope"
    private const val PER_SLUG_MAX = 40
    private val json = Json { ignoreUnknownKeys = true }
    private val pendingStatuses = setOf("queued", "sending", "pending")

    fun isPendingDeliveryStatus(raw: String?): Boolean =
        pendingStatuses.contains(raw?.trim()?.lowercase().orEmpty().ifEmpty { "queued" })

    /** Enregistre une campagne livrée (état terminal) — jamais « Envoi en cours » dans l'historique. */
    fun recordDelivered(
        context: Context,
        slug: String,
        batchId: String,
        jobId: String?,
        title: String?,
        message: String,
        expectedDevices: Int,
        deliveryStatus: String,
        recipientsDistinct: Int,
    ) {
        val scopeKey = scopedStorageKey(context, slug)
        if (scopeKey.isEmpty() || message.isBlank()) return
        if (isPendingDeliveryStatus(deliveryStatus)) return
        val map = readMap(context).toMutableMap()
        val list = map[scopeKey]?.toMutableList() ?: mutableListOf()
        val iso = java.time.Instant.now().toString()
        val entry = NotificationSendLocalEntry(
            id = batchId,
            createdAtISO = iso,
            title = title?.trim()?.takeIf { it.isNotEmpty() },
            message = message.trim(),
            recipientOrSentCount = recipientsDistinct.coerceAtLeast(0),
            expectedDevices = expectedDevices.coerceAtLeast(0),
            deliveryStatus = deliveryStatus,
            jobId = jobId,
        )
        val idx = list.indexOfFirst { it.id == batchId || (jobId != null && it.jobId == jobId) }
        if (idx >= 0) {
            list[idx] = entry
        } else {
            val last = list.lastOrNull()
            if (last != null &&
                last.message == entry.message &&
                last.title == entry.title &&
                isoDistanceSeconds(last.createdAtISO, iso) < 4
            ) {
                return
            }
            list.add(entry)
        }
        map[scopeKey] = if (list.size > PER_SLUG_MAX) list.takeLast(PER_SLUG_MAX) else list
        writeMap(context, map)
    }

    fun entries(context: Context, slug: String): List<NotificationSendLocalEntry> =
        readMap(context)[scopedStorageKey(context, slug)].orEmpty()

    fun clearAll(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    fun asCampaignInsights(entries: List<NotificationSendLocalEntry>): List<NotificationCampaignInsightDto> =
        entries
            .filter { !isPendingDeliveryStatus(it.deliveryStatus) }
            .sortedByDescending { it.createdAtISO }
            .map { e ->
                val confirmed = e.recipientOrSentCount.coerceAtLeast(0)
                NotificationCampaignInsightDto(
                    batchId = e.id,
                    triggerName = "manual",
                    createdAt = e.createdAtISO,
                    sentTotal = if (confirmed > 0) confirmed else null,
                    recipientsDistinct = confirmed,
                    returnedWithin48h = null,
                    notificationTitle = e.title,
                    message = e.message,
                    deliveryStatus = e.deliveryStatus,
                    expectedDevices = e.expectedDevices,
                )
            }

    private fun scopedStorageKey(context: Context, slug: String): String {
        val slugKey = slug.trim().lowercase()
        if (slugKey.isEmpty()) return ""
        val account = SessionStore(context).userEmail?.trim()?.lowercase().orEmpty()
        return if (account.isEmpty()) slugKey else "$account|$slugKey"
    }

    private fun isoDistanceSeconds(a: String, b: String): Long =
        runCatching {
            val da = java.time.Instant.parse(a)
            val db = java.time.Instant.parse(b)
            kotlin.math.abs(da.epochSecond - db.epochSecond)
        }.getOrDefault(999L)

    private fun readMap(context: Context): Map<String, List<NotificationSendLocalEntry>> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
            ?: return emptyMap()
        return runCatching {
            json.decodeFromString<Map<String, List<NotificationSendLocalEntry>>>(raw)
        }.getOrDefault(emptyMap())
    }

    private fun writeMap(context: Context, map: Map<String, List<NotificationSendLocalEntry>>) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY, json.encodeToString(map))
            .apply()
    }
}
