package fr.myfidpass.flyer

import android.util.Base64
import fr.myfidpass.data.dto.FlyerStateDto
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import fr.myfidpass.util.jsonObjectOrNull
import kotlinx.serialization.json.jsonPrimitive

object FlyerBootstrapPreviewPayloadBuilder {

    private val json = Json {
        ignoreUnknownKeys = true
        explicitNulls = false
        encodeDefaults = true
    }

    @Serializable
    private data class BootstrapPayload(
        @SerialName("flyer_prefs") val flyerPrefs: FlyerPrefsInner,
        @SerialName("share_url") val shareUrl: String = "",
        @SerialName("match_predictions_enabled") val matchPredictionsEnabled: Boolean? = null,
        @SerialName("_nbg") val nativeBgActive: Boolean? = null,
    )

    @Serializable
    private data class FlyerPrefsInner(
        val state: FlyerStateDto,
        @SerialName("custom_logo_data_url") val customLogoDataUrl: String? = null,
        @SerialName("custom_bg_data_url") val customBgDataUrl: String? = null,
        @SerialName("business_slug") val businessSlug: String,
    )

    fun flyerStateFromBootstrapBase64(b64: String): FlyerStateDto? {
        val trimmed = b64.trim()
        if (trimmed.isEmpty()) return null
        val root = decodeRoot(trimmed) ?: return null
        val stateEl = root["flyer_prefs"].jsonObjectOrNull()?.get("state") ?: return null
        return FlyerStateDto.decodeFromJsonElement(stateEl)
    }

    fun customBgDataUrlFromBootstrapBase64(b64: String): String? {
        val root = decodeRoot(b64.trim()) ?: return null
        return root["flyer_prefs"].jsonObjectOrNull()
            ?.get("custom_bg_data_url")?.jsonPrimitive?.content?.trim()?.takeIf { it.isNotEmpty() }
    }

    fun base64FromParts(
        state: FlyerStateDto,
        businessSlug: String,
        shareUrl: String,
        customLogoDataUrl: String?,
        customBgDataUrl: String?,
        stripCustomBgForNativeUnderlay: Boolean = false,
        nativeBgActive: Boolean = false,
        matchPredictionsEnabled: Boolean = false,
    ): String {
        val st = state.normalizeClamps()
        val payload = BootstrapPayload(
            flyerPrefs = FlyerPrefsInner(
                state = st,
                customLogoDataUrl = customLogoDataUrl?.trim()?.takeIf { it.isNotEmpty() },
                customBgDataUrl = if (stripCustomBgForNativeUnderlay) null
                else customBgDataUrl?.trim()?.takeIf { it.isNotEmpty() },
                businessSlug = businessSlug.trim(),
            ),
            shareUrl = shareUrl.trim(),
            matchPredictionsEnabled = if (matchPredictionsEnabled) true else null,
            nativeBgActive = if (nativeBgActive) true else null,
        )
        val bytes = json.encodeToString(payload).toByteArray(Charsets.UTF_8)
        return Base64.encodeToString(bytes, Base64.NO_WRAP)
    }

    fun matchPredictionsEnabledFromDashboard(response: JsonObject): Boolean {
        val v = response["match_predictions_enabled"]?.jsonPrimitive?.content?.trim()?.lowercase().orEmpty()
        return v == "true" || v == "1"
    }

    fun base64FromDashboardResponse(
        response: JsonObject,
        businessSlug: String,
        fallbackState: FlyerStateDto? = null,
    ): String? {
        val slug = businessSlug.trim()
        if (slug.isEmpty()) return null
        val prefs = response["flyer_prefs"].jsonObjectOrNull() ?: return null
        val serverState = FlyerStateDto.decodeFromJsonElement(prefs["state"])
        val state = resolvedState(serverState, fallbackState)
        val share = response["share_url"]?.jsonPrimitive?.content?.trim().orEmpty()
        val logo = prefs["custom_logo_data_url"]?.jsonPrimitive?.content
        val bg = prefs["custom_bg_data_url"]?.jsonPrimitive?.content
        val hasNativeBg = !bg.isNullOrBlank()
        return base64FromParts(
            state = state,
            businessSlug = slug,
            shareUrl = share,
            customLogoDataUrl = logo,
            customBgDataUrl = bg,
            stripCustomBgForNativeUnderlay = hasNativeBg,
            nativeBgActive = hasNativeBg,
            matchPredictionsEnabled = matchPredictionsEnabledFromDashboard(response),
        )
    }

    fun resolvedState(serverState: FlyerStateDto, fallback: FlyerStateDto?): FlyerStateDto {
        if (serverState.isCustomizedComparedToAppDefault) return serverState.normalizeClamps()
        if (fallback?.isCustomizedComparedToAppDefault == true) return fallback.normalizeClamps()
        return serverState.normalizeClamps()
    }

    fun commerceIndicatesFlyerRegistered(response: JsonObject): Boolean {
        val prefs = response["flyer_prefs"].jsonObjectOrNull() ?: return false
        val hasBg = prefs["custom_bg_data_url"]?.jsonPrimitive?.content?.isNotBlank() == true
        val hasLogo = prefs["custom_logo_data_url"]?.jsonPrimitive?.content?.isNotBlank() == true
        val state = FlyerStateDto.decodeFromJsonElement(prefs["state"])
        return hasBg || hasLogo || state.isCustomizedComparedToAppDefault
    }

    private fun decodeRoot(b64: String): JsonObject? = runCatching {
        val bytes = Base64.decode(b64, Base64.DEFAULT)
        json.decodeFromString<JsonObject>(String(bytes, Charsets.UTF_8))
    }.getOrNull()
}
