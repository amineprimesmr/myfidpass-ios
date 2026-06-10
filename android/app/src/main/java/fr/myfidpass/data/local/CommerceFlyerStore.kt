package fr.myfidpass.data.local

import android.content.Context
import fr.myfidpass.flyer.FlyerBootstrapPreviewPayloadBuilder

/** Mémoire cross-écrans — aligné iOS `CommerceFlyerStore`. */
object CommerceFlyerStore {

    data class Snapshot(
        val flyerRegistered: Boolean = false,
        val shareURL: String = "",
        val bootstrapPreviewB64: String? = null,
        val customBgDataURL: String? = null,
        val revisionKey: String? = null,
    )

    private val memory = mutableMapOf<String, Snapshot>()

    fun snapshot(slug: String): Snapshot? = memory[slug.trim()]

    fun hydrateFromDiskIfNeeded(context: Context, slug: String) {
        val key = slug.trim()
        if (key.isEmpty() || memory.containsKey(key)) return
        CommerceFlyerStateCache.load(context, key)?.let { cached ->
            memory[key] = Snapshot(
                flyerRegistered = cached.flyerRegistered,
                shareURL = cached.shareURL,
                bootstrapPreviewB64 = cached.bootstrapPreviewB64,
                customBgDataURL = cached.customBgDataURL,
                revisionKey = cached.revisionKey,
            )
        }
    }

    fun update(context: Context, slug: String, snapshot: Snapshot) {
        val key = slug.trim()
        if (key.isEmpty()) return
        memory[key] = snapshot
        CommerceFlyerStateCache.save(
            context = context,
            slug = key,
            flyerRegistered = snapshot.flyerRegistered,
            shareURL = snapshot.shareURL,
            bootstrapPreviewB64 = snapshot.bootstrapPreviewB64,
            customBgDataURL = snapshot.customBgDataURL,
            revisionKey = snapshot.revisionKey,
        )
    }

    fun isFlyerReady(context: Context, slug: String): Boolean {
        hydrateFromDiskIfNeeded(context, slug)
        val snap = snapshot(slug) ?: CommerceFlyerStateCache.load(context, slug)?.let { cached ->
            Snapshot(
                flyerRegistered = cached.flyerRegistered,
                shareURL = cached.shareURL,
                bootstrapPreviewB64 = cached.bootstrapPreviewB64,
                customBgDataURL = cached.customBgDataURL,
                revisionKey = cached.revisionKey,
            )
        }
        if (snap != null) {
            if (snap.flyerRegistered) return true
            if (!snap.bootstrapPreviewB64.isNullOrBlank()) return true
            if (!snap.customBgDataURL.isNullOrBlank()) return true
        }
        return CommerceFlyerEditorDraftStore.load(context, slug) != null
    }

    fun clearAll(context: Context) {
        memory.clear()
        CommerceFlyerStateCache.clearAll(context)
    }
}
