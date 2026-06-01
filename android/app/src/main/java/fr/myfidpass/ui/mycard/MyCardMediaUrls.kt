package fr.myfidpass.ui.mycard

import fr.myfidpass.data.dto.BusinessSettingsResponse
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

object MyCardMediaUrls {
    fun versionedApiUrl(raw: String, version: String?): String {
        val trimmed = raw.trim()
        if (trimmed.isEmpty()) return trimmed
        val v = version?.trim().orEmpty()
        if (v.isEmpty() || !trimmed.contains("/api/") || trimmed.contains("?v=")) return trimmed
        return "${trimmed.trimEnd('/')}?v=${URLEncoder.encode(v, StandardCharsets.UTF_8.name())}"
    }

    fun cardBackgroundUrl(apiBase: String, slug: String, version: String?): String? {
        if (slug.isBlank()) return null
        val base = "${apiBase.trimEnd('/')}/api/businesses/${slug.lowercase()}/card-background"
        return versionedApiUrl(base, version)
    }

    fun resolvedLogoModel(draft: MyCardDraftState, settings: BusinessSettingsResponse?): String? {
        draft.pendingLogoDataUrl?.takeIf { it.isNotBlank() }?.let { return it }
        val url = draft.logoUrl.takeIf { it.isNotBlank() } ?: settings?.logoUrl.orEmpty()
        if (url.isBlank()) return null
        return versionedApiUrl(url, settings?.logoUpdatedAt)
    }

    fun resolvedBackgroundModel(
        draft: MyCardDraftState,
        settings: BusinessSettingsResponse?,
        apiBase: String,
        slug: String,
    ): String? {
        if (draft.isStampsMode) return null
        draft.pendingBackgroundDataUrl?.takeIf { it.isNotBlank() }?.let { return it }
        if (draft.cardBackgroundWasRemoved || draft.cardBackgroundRemoteUrl.isBlank()) return null
        return cardBackgroundUrl(apiBase, slug, settings?.cardBackgroundUpdatedAt)
    }
}
