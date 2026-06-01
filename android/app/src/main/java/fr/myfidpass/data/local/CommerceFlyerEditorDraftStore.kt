package fr.myfidpass.data.local

import android.content.Context
import fr.myfidpass.data.dto.FlyerRemoteImagePayload
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File

/** Brouillon session éditeur — aligné iOS `CommerceFlyerEditorDraftStore`. */
object CommerceFlyerEditorDraftStore {

    @Serializable
    data class DraftMeta(
        val shareURL: String = "",
        val customBgDataURL: String? = null,
        val serverLogoDataUrl: String? = null,
        val serverBgDataUrl: String? = null,
        val logoPayloadKind: String = "leave",
        val logoPayloadValue: String? = null,
        val bgPayloadKind: String = "leave",
        val bgPayloadValue: String? = null,
        val suppressDashboardCustomLogoForPreview: Boolean = false,
        val savedAtEpochMs: Long = System.currentTimeMillis(),
    )

    @Serializable
    private data class DraftFile(
        val meta: DraftMeta,
        val bootstrapB64: String,
    )

    private val json = Json { ignoreUnknownKeys = true }
    private const val MAX_AGE_MS = 30L * 24 * 60 * 60 * 1000

    private fun file(context: Context, slug: String): File {
        val root = File(context.filesDir, "CommerceFlyerEditorDraft")
        root.mkdirs()
        return File(root, "${slug.trim().replace('/', '_')}.json")
    }

    fun load(context: Context, slug: String): Pair<DraftMeta, String>? {
        val f = file(context, slug)
        if (!f.exists()) return null
        val draft = runCatching { json.decodeFromString<DraftFile>(f.readText()) }.getOrNull() ?: return null
        if (System.currentTimeMillis() - draft.meta.savedAtEpochMs > MAX_AGE_MS) {
            f.delete()
            return null
        }
        val b64 = draft.bootstrapB64.trim()
        if (b64.isEmpty()) return null
        return draft.meta to b64
    }

    fun save(context: Context, slug: String, bootstrapB64: String, meta: DraftMeta) {
        val b64 = bootstrapB64.trim()
        if (b64.isEmpty()) return
        val payload = DraftFile(meta = meta.copy(savedAtEpochMs = System.currentTimeMillis()), bootstrapB64 = b64)
        file(context, slug).writeText(json.encodeToString(payload))
    }

    fun clear(context: Context, slug: String) {
        file(context, slug).delete()
    }

    fun logoPayloadFromMeta(meta: DraftMeta): FlyerRemoteImagePayload = when (meta.logoPayloadKind) {
        "clear" -> FlyerRemoteImagePayload.Clear
        "data" -> FlyerRemoteImagePayload.DataUrl(meta.logoPayloadValue.orEmpty())
        else -> FlyerRemoteImagePayload.LeaveUnchanged
    }

    fun bgPayloadFromMeta(meta: DraftMeta): FlyerRemoteImagePayload = when (meta.bgPayloadKind) {
        "clear" -> FlyerRemoteImagePayload.Clear
        "data" -> FlyerRemoteImagePayload.DataUrl(meta.bgPayloadValue.orEmpty())
        else -> FlyerRemoteImagePayload.LeaveUnchanged
    }

    fun metaFromPayloads(
        shareURL: String,
        customBgDataURL: String?,
        serverLogoDataUrl: String?,
        serverBgDataUrl: String?,
        logo: FlyerRemoteImagePayload,
        bg: FlyerRemoteImagePayload,
        suppressDashboardCustomLogoForPreview: Boolean,
    ): DraftMeta = DraftMeta(
        shareURL = shareURL,
        customBgDataURL = customBgDataURL,
        serverLogoDataUrl = serverLogoDataUrl,
        serverBgDataUrl = serverBgDataUrl,
        logoPayloadKind = payloadKind(logo),
        logoPayloadValue = payloadValue(logo),
        bgPayloadKind = payloadKind(bg),
        bgPayloadValue = payloadValue(bg),
        suppressDashboardCustomLogoForPreview = suppressDashboardCustomLogoForPreview,
    )

    private fun payloadKind(p: FlyerRemoteImagePayload): String = when (p) {
        FlyerRemoteImagePayload.Clear -> "clear"
        is FlyerRemoteImagePayload.DataUrl -> "data"
        FlyerRemoteImagePayload.LeaveUnchanged -> "leave"
    }

    private fun payloadValue(p: FlyerRemoteImagePayload): String? = when (p) {
        is FlyerRemoteImagePayload.DataUrl -> p.value
        else -> null
    }
}
