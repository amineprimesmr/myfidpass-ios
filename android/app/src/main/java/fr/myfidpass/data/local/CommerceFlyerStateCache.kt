package fr.myfidpass.data.local

import android.content.Context
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File

/**
 * Cache disque aligné iOS `CommerceFlyerStateCache` — affichage instantané checklist Commerce / flyer.
 */
object CommerceFlyerStateCache {

    @Serializable
    data class Loaded(
        val flyerRegistered: Boolean = false,
        val shareURL: String = "",
        val bootstrapPreviewB64: String? = null,
        val customBgDataURL: String? = null,
        val engagementStepDone: Boolean = false,
        val revisionKey: String? = null,
    )

    @Serializable
    private data class Meta(
        val flyerRegistered: Boolean = false,
        val shareURL: String = "",
        val engagementStepDone: Boolean = false,
        val revisionKey: String? = null,
    )

    private val json = Json { ignoreUnknownKeys = true }

    private fun sanitizedSlug(slug: String): String =
        slug.trim().replace("/", "_").replace("\\", "_")

    private fun dir(context: Context, slug: String): File {
        val root = File(context.filesDir, "CommerceFlyerStateCache")
        val d = File(root, sanitizedSlug(slug))
        d.mkdirs()
        return d
    }

    fun load(context: Context, slug: String): Loaded? {
        if (slug.isBlank()) return null
        val d = dir(context, slug)
        val metaFile = File(d, "meta.json")
        if (!metaFile.exists()) return null
        val meta = runCatching {
            json.decodeFromString<Meta>(metaFile.readText())
        }.getOrNull() ?: return null
        val bootstrap = File(d, "bootstrap.b64").takeIf { it.exists() }?.readText()?.trim()?.takeIf { it.isNotEmpty() }
        val customBg = File(d, "custom_bg.txt").takeIf { it.exists() }?.readText()?.trim()?.takeIf { it.isNotEmpty() }
        return Loaded(
            flyerRegistered = meta.flyerRegistered,
            shareURL = meta.shareURL,
            bootstrapPreviewB64 = bootstrap,
            customBgDataURL = customBg,
            engagementStepDone = meta.engagementStepDone,
            revisionKey = meta.revisionKey,
        )
    }

    fun save(
        context: Context,
        slug: String,
        flyerRegistered: Boolean,
        shareURL: String,
        bootstrapPreviewB64: String? = null,
        customBgDataURL: String? = null,
        engagementStepDone: Boolean = false,
        revisionKey: String? = null,
    ) {
        if (slug.isBlank()) return
        val d = dir(context, slug)
        val meta = Meta(
            flyerRegistered = flyerRegistered,
            shareURL = shareURL.trim(),
            engagementStepDone = engagementStepDone,
            revisionKey = revisionKey,
        )
        File(d, "meta.json").writeText(json.encodeToString(meta))
        bootstrapPreviewB64?.trim()?.takeIf { it.isNotEmpty() }?.let {
            File(d, "bootstrap.b64").writeText(it)
        }
        customBgDataURL?.trim()?.takeIf { it.isNotEmpty() }?.let {
            File(d, "custom_bg.txt").writeText(it)
        }
    }

    fun flyerLooksCustomized(context: Context, slug: String): Boolean {
        val cached = load(context, slug) ?: return false
        val hasBootstrap = !cached.bootstrapPreviewB64.isNullOrBlank()
        val hasCustomBg = !cached.customBgDataURL.isNullOrBlank()
        return cached.flyerRegistered || hasBootstrap || hasCustomBg
    }
}
