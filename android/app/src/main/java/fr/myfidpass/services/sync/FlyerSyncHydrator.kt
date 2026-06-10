package fr.myfidpass.services.sync

import android.content.Context
import fr.myfidpass.data.dto.BusinessSettingsResponse
import fr.myfidpass.data.local.CommerceFlyerStateCache
import fr.myfidpass.data.local.CommerceFlyerStore
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.flyer.FlyerBootstrapPreviewPayloadBuilder
import fr.myfidpass.util.LegalURLs
import fr.myfidpass.util.jsonObjectOrNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Réhydrate le cache flyer depuis GET …/dashboard/flyer après sync (aligné iOS `SyncService.hydrateFlyerFromServer`).
 */
object FlyerSyncHydrator {

    suspend fun hydrate(
        context: Context,
        repository: DashboardRepository,
        slug: String,
        settingsHint: BusinessSettingsResponse? = null,
    ) {
        val key = slug.trim()
        if (key.isEmpty()) return
        runCatching {
            val response = repository.dashboardFlyerGet(key)
            persistFromDashboardResponse(context, key, response, settingsHint)
        }.onFailure {
            applySettingsHintFallback(context, key, settingsHint)
        }
    }

    private fun persistFromDashboardResponse(
        context: Context,
        slug: String,
        response: JsonObject,
        settingsHint: BusinessSettingsResponse?,
    ) {
        CommerceFlyerStore.hydrateFromDiskIfNeeded(context, slug)
        val cacheRegistered = CommerceFlyerStore.snapshot(slug)?.flyerRegistered == true
        val settingsRegistered = settingsHint?.hasFlyerPrefs == true
        val registered = FlyerBootstrapPreviewPayloadBuilder.commerceIndicatesFlyerRegistered(response)
            || cacheRegistered
            || settingsRegistered
        val shareRaw = response["share_url"]?.jsonPrimitive?.content?.trim().orEmpty()
        val shareURL = shareRaw.ifEmpty { LegalURLs.fidelityCardPage(slug) }
        val prefs = response["flyer_prefs"].jsonObjectOrNull()
        val customBg = prefs?.get("custom_bg_data_url")?.jsonPrimitive?.content?.trim()?.takeIf { it.isNotEmpty() }
        val priorBootstrap = CommerceFlyerStore.snapshot(slug)?.bootstrapPreviewB64
            ?: CommerceFlyerStateCache.load(context, slug)?.bootstrapPreviewB64
        val fallbackState = priorBootstrap?.let { FlyerBootstrapPreviewPayloadBuilder.flyerStateFromBootstrapBase64(it) }
        var bootstrapB64 = FlyerBootstrapPreviewPayloadBuilder.base64FromDashboardResponse(
            response = response,
            businessSlug = slug,
            fallbackState = fallbackState,
        )
        if (bootstrapB64.isNullOrBlank() && !priorBootstrap.isNullOrBlank()) {
            bootstrapB64 = priorBootstrap
        }
        val revision = response["updated_at"]?.jsonPrimitive?.content?.trim()?.takeIf { it.isNotEmpty() }
            ?: settingsHint?.flyerPrefsUpdatedAt
        CommerceFlyerStore.update(
            context = context,
            slug = slug,
            snapshot = CommerceFlyerStore.Snapshot(
                flyerRegistered = registered,
                shareURL = shareURL,
                bootstrapPreviewB64 = bootstrapB64,
                customBgDataURL = customBg,
                revisionKey = revision,
            ),
        )
    }

    private fun applySettingsHintFallback(
        context: Context,
        slug: String,
        settingsHint: BusinessSettingsResponse?,
    ) {
        if (settingsHint?.hasFlyerPrefs != true) return
        val cached = CommerceFlyerStateCache.load(context, slug)
        CommerceFlyerStore.update(
            context = context,
            slug = slug,
            snapshot = CommerceFlyerStore.Snapshot(
                flyerRegistered = true,
                shareURL = cached?.shareURL?.takeIf { it.isNotBlank() } ?: LegalURLs.fidelityCardPage(slug),
                bootstrapPreviewB64 = cached?.bootstrapPreviewB64,
                customBgDataURL = cached?.customBgDataURL,
                revisionKey = settingsHint.flyerPrefsUpdatedAt,
            ),
        )
    }
}
