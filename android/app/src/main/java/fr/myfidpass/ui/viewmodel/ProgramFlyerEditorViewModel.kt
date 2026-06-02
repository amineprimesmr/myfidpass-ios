package fr.myfidpass.ui.viewmodel

import android.content.Context
import android.util.Base64
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import fr.myfidpass.data.dto.FlyerAiGenerateRequest
import fr.myfidpass.data.dto.FlyerRemoteImagePayload
import fr.myfidpass.data.dto.FlyerStateDto
import fr.myfidpass.data.local.CommerceFlyerEditorDraftStore
import fr.myfidpass.data.local.CommerceFlyerStateCache
import fr.myfidpass.data.local.CommerceFlyerStore
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.data.repo.FlyerAiGenerateException
import fr.myfidpass.di.AppContainer
import fr.myfidpass.flyer.AppVibrantColorPalette
import fr.myfidpass.flyer.FlyerBackgroundTemplates
import fr.myfidpass.flyer.FlyerBootstrapPreviewPayloadBuilder
import fr.myfidpass.flyer.FlyerWheelPairColor
import fr.myfidpass.flyer.bitmapToPngDataUrl
import fr.myfidpass.util.jsonObjectOrNull
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

private data class FlyerEditSnapshot(
    val state: FlyerStateDto,
    val logo: FlyerRemoteImagePayload,
    val bg: FlyerRemoteImagePayload,
)

class ProgramFlyerEditorViewModel(
    private val repository: DashboardRepository,
    private val appContext: Context,
    val slug: String,
    val startCreateAssistant: Boolean,
    val openForEdit: Boolean,
) : ViewModel() {

    var state by mutableStateOf(FlyerStateDto.DEFAULT)
        private set
    var shareUrl by mutableStateOf("")
        private set
    var bootstrapPreviewBase64 by mutableStateOf<String?>(null)
        private set
    var logoPayload by mutableStateOf<FlyerRemoteImagePayload>(FlyerRemoteImagePayload.LeaveUnchanged)
        private set
    var bgPayload by mutableStateOf<FlyerRemoteImagePayload>(FlyerRemoteImagePayload.LeaveUnchanged)
        private set
    var serverLogoDataUrl by mutableStateOf<String?>(null)
        private set
    var serverBgDataUrl by mutableStateOf<String?>(null)
        private set
    var nativeBgDataUrl by mutableStateOf<String?>(null)
        private set

    var brandName by mutableStateOf("")
    var concept by mutableStateOf("")
    var accentHex by mutableStateOf("#651FFF")
    var logoPreviewDataUrl by mutableStateOf<String?>(null)
    var palettePriorityHexes by mutableStateOf(listOf("651FFF"))
    var selectedBackgroundTemplateKey by mutableStateOf<String?>(null)

    var flyerHeroRevealed by mutableStateOf(false)
    var isViewMode by mutableStateOf(false)
    var isEditMode by mutableStateOf(false)
    var expandedEditSection by mutableStateOf<String?>(null)

    var isLoading by mutableStateOf(false)
        private set
    var isSaving by mutableStateOf(false)
        private set
    var isGenerating by mutableStateOf(false)
        private set
    var aiProgress by mutableFloatStateOf(0f)
    var loadError by mutableStateOf<String?>(null)
        private set
    var saveError by mutableStateOf<String?>(null)
    var pendingAiImageB64 by mutableStateOf<String?>(null)

    var flyerAiGenerationsRemaining by mutableStateOf(3)
    var flyerAiUnlimited by mutableStateOf(false)
    var matchPredictionsEnabled by mutableStateOf(false)
        private set
    var serverSnapshotWasNonDefault by mutableStateOf(false)
        private set
    var hasCompletedLoad by mutableStateOf(false)
        private set

    var canUndo by mutableStateOf(false)
        private set
    var canRedo by mutableStateOf(false)
        private set

    private val undoStack = ArrayDeque<FlyerEditSnapshot>()
    private val redoStack = ArrayDeque<FlyerEditSnapshot>()
    private var suppressUndo = false
    private var suppressDashboardCustomLogoForPreview = false

    init {
        hydrateInstant()
        viewModelScope.launch {
            runCatching {
                val settings = repository.businessSettings(slug)
                brandName = settings.organizationName?.trim().orEmpty().ifEmpty { "Mon commerce" }
            }
            load(forceFullMerge = false)
        }
    }

    private fun hydrateInstant() {
        runCatching {
            CommerceFlyerStore.hydrateFromDiskIfNeeded(appContext, slug)
            CommerceFlyerEditorDraftStore.load(appContext, slug)?.let { (meta, b64) ->
                applyBootstrapHydration(b64, meta.shareURL, meta.serverLogoDataUrl, meta.serverBgDataUrl)
                logoPayload = CommerceFlyerEditorDraftStore.logoPayloadFromMeta(meta)
                bgPayload = CommerceFlyerEditorDraftStore.bgPayloadFromMeta(meta)
                suppressDashboardCustomLogoForPreview = meta.suppressDashboardCustomLogoForPreview
                if (openForEdit || !startCreateAssistant) {
                    revealHeroViewMode()
                }
                return
            }
            CommerceFlyerStore.snapshot(slug)?.let { snap ->
                snap.bootstrapPreviewB64?.let { b64 ->
                    applyBootstrapHydration(b64, snap.shareURL, null, snap.customBgDataURL)
                    if (snap.flyerRegistered && (openForEdit || !startCreateAssistant)) {
                        revealHeroViewMode()
                    }
                }
            }
        }.onFailure {
            loadError = it.message ?: "Impossible de charger le brouillon flyer"
        }
    }

    private fun applyBootstrapHydration(
        b64: String,
        share: String,
        logo: String?,
        bg: String?,
    ) {
        FlyerBootstrapPreviewPayloadBuilder.flyerStateFromBootstrapBase64(b64)?.let { st ->
            state = st
            serverSnapshotWasNonDefault = st.isCustomizedComparedToAppDefault
        }
        shareUrl = share
        bootstrapPreviewBase64 = b64
        serverLogoDataUrl = logo?.trim()?.takeIf { it.isNotEmpty() }
        serverBgDataUrl = bg?.trim()?.takeIf { it.isNotEmpty() }
        refreshNativeBg()
        refreshPreviewBootstrap()
    }

    fun load(forceFullMerge: Boolean) {
        viewModelScope.launch {
            isLoading = true
            loadError = null
            runCatching {
                val response = repository.dashboardFlyerGet(slug)
                val fallback = state.takeIf { it.isCustomizedComparedToAppDefault }
                val b64 = FlyerBootstrapPreviewPayloadBuilder.base64FromDashboardResponse(
                    response, slug, fallback,
                ) ?: FlyerBootstrapPreviewPayloadBuilder.base64FromParts(
                    state = fallback ?: state,
                    businessSlug = slug,
                    shareUrl = response["share_url"]?.jsonPrimitive?.content?.trim().orEmpty(),
                    customLogoDataUrl = null,
                    customBgDataUrl = null,
                )
                val prefs = response["flyer_prefs"].jsonObjectOrNull()
                val decoded = FlyerStateDto.decodeFromJsonElement(prefs?.get("state"))
                if (forceFullMerge || !hasCompletedLoad) {
                    state = FlyerBootstrapPreviewPayloadBuilder.resolvedState(decoded, fallback)
                }
                shareUrl = response["share_url"]?.jsonPrimitive?.content?.trim().orEmpty()
                serverLogoDataUrl = prefs?.get("custom_logo_data_url")?.jsonPrimitive?.content?.trim()?.takeIf { it.isNotEmpty() }
                serverBgDataUrl = prefs?.get("custom_bg_data_url")?.jsonPrimitive?.content?.trim()?.takeIf { it.isNotEmpty() }
                response["flyer_ai_generations_remaining"]?.jsonPrimitive?.content?.toIntOrNull()?.let {
                    flyerAiGenerationsRemaining = it
                }
                response["flyer_ai_unlimited"]?.jsonPrimitive?.content?.toBooleanStrictOrNull()?.let {
                    flyerAiUnlimited = it
                }
                matchPredictionsEnabled = FlyerBootstrapPreviewPayloadBuilder.matchPredictionsEnabledFromDashboard(response)
                serverSnapshotWasNonDefault = FlyerBootstrapPreviewPayloadBuilder.commerceIndicatesFlyerRegistered(response) ||
                    state.isCustomizedComparedToAppDefault
                bootstrapPreviewBase64 = b64
                refreshNativeBg()
                refreshPreviewBootstrap()
                persistCache(response, b64)
                hasCompletedLoad = true
                when {
                    openForEdit && serverSnapshotWasNonDefault -> revealHeroViewMode()
                    startCreateAssistant && !serverSnapshotWasNonDefault -> {
                        flyerHeroRevealed = false
                        isViewMode = false
                        isEditMode = false
                    }
                    serverSnapshotWasNonDefault -> revealHeroViewMode()
                }
            }.onFailure { loadError = it.message ?: "Chargement impossible" }
            isLoading = false
        }
    }

    private fun persistCache(response: JsonObject, b64: String?) {
        val registered = FlyerBootstrapPreviewPayloadBuilder.commerceIndicatesFlyerRegistered(response)
        CommerceFlyerStore.update(
            appContext,
            slug,
            CommerceFlyerStore.Snapshot(
                flyerRegistered = registered,
                shareURL = shareUrl,
                bootstrapPreviewB64 = b64,
                customBgDataURL = effectiveBgPreview(),
            ),
        )
    }

    fun applyState(newState: FlyerStateDto) {
        if (!suppressUndo) pushUndo()
        state = newState.normalizeClamps()
        refreshPreviewBootstrap()
    }

    fun updateStringField(update: (FlyerStateDto) -> FlyerStateDto) {
        applyState(update(state))
    }

    private fun pushUndo() {
        undoStack.addLast(FlyerEditSnapshot(state, logoPayload, bgPayload))
        if (undoStack.size > 40) undoStack.removeFirst()
        redoStack.clear()
        canUndo = undoStack.isNotEmpty()
        canRedo = false
    }

    fun undo() {
        val snap = undoStack.removeLastOrNull() ?: return
        redoStack.addLast(FlyerEditSnapshot(state, logoPayload, bgPayload))
        suppressUndo = true
        state = snap.state
        logoPayload = snap.logo
        bgPayload = snap.bg
        suppressUndo = false
        refreshNativeBg()
        refreshPreviewBootstrap()
        canUndo = undoStack.isNotEmpty()
        canRedo = redoStack.isNotEmpty()
    }

    fun redo() {
        val snap = redoStack.removeLastOrNull() ?: return
        undoStack.addLast(FlyerEditSnapshot(state, logoPayload, bgPayload))
        suppressUndo = true
        state = snap.state
        logoPayload = snap.logo
        bgPayload = snap.bg
        suppressUndo = false
        refreshNativeBg()
        refreshPreviewBootstrap()
        canUndo = undoStack.isNotEmpty()
        canRedo = redoStack.isNotEmpty()
    }

    fun setLogoDataUrl(dataUrl: String) {
        if (!suppressUndo) pushUndo()
        logoPreviewDataUrl = dataUrl
        logoPayload = FlyerRemoteImagePayload.DataUrl(dataUrl)
        suppressDashboardCustomLogoForPreview = false
        refreshPreviewBootstrap()
    }

    fun setBackgroundDataUrl(dataUrl: String) {
        if (!suppressUndo) pushUndo()
        bgPayload = FlyerRemoteImagePayload.DataUrl(dataUrl)
        serverBgDataUrl = dataUrl
        refreshNativeBg()
        refreshPreviewBootstrap()
    }

    fun clearBackground() {
        if (!suppressUndo) pushUndo()
        bgPayload = FlyerRemoteImagePayload.Clear
        serverBgDataUrl = null
        nativeBgDataUrl = null
        refreshPreviewBootstrap()
    }

    fun useGradientBackground() {
        if (!suppressUndo) pushUndo()
        bgPayload = FlyerRemoteImagePayload.Clear
        serverBgDataUrl = null
        nativeBgDataUrl = null
        refreshPreviewBootstrap()
    }

    private fun effectiveLogoForBootstrap(): String? = when (val payload = logoPayload) {
        FlyerRemoteImagePayload.Clear -> ""
        is FlyerRemoteImagePayload.DataUrl -> payload.value
        FlyerRemoteImagePayload.LeaveUnchanged -> {
            if (suppressDashboardCustomLogoForPreview) null
            else serverLogoDataUrl ?: logoPreviewDataUrl
        }
    }

    fun effectiveBgPreview(): String? = when (val payload = bgPayload) {
        FlyerRemoteImagePayload.Clear -> null
        is FlyerRemoteImagePayload.DataUrl -> payload.value
        FlyerRemoteImagePayload.LeaveUnchanged -> serverBgDataUrl
    }

    private fun refreshNativeBg() {
        nativeBgDataUrl = effectiveBgPreview()?.trim()?.takeIf { it.isNotEmpty() }
    }

    fun refreshPreviewBootstrap() {
        val bg = effectiveBgPreview()
        val hasNativeBg = !bg.isNullOrBlank()
        bootstrapPreviewBase64 = FlyerBootstrapPreviewPayloadBuilder.base64FromParts(
            state = state,
            businessSlug = slug,
            shareUrl = shareUrl.ifBlank { defaultShareUrl() },
            customLogoDataUrl = effectiveLogoForBootstrap(),
            customBgDataUrl = bg,
            stripCustomBgForNativeUnderlay = hasNativeBg,
            nativeBgActive = hasNativeBg,
            matchPredictionsEnabled = matchPredictionsEnabled,
        )
        persistDraftIfNeeded()
    }

    private fun defaultShareUrl(): String = "https://www.myfidpass.fr/fidelity/${slug.lowercase()}?qr=1"

    fun persistDraftIfNeeded() {
        val b64 = bootstrapPreviewBase64?.trim().orEmpty()
        if (b64.isEmpty()) return
        CommerceFlyerEditorDraftStore.save(
            appContext,
            slug,
            b64,
            CommerceFlyerEditorDraftStore.metaFromPayloads(
                shareURL = shareUrl,
                customBgDataURL = effectiveBgPreview(),
                serverLogoDataUrl = serverLogoDataUrl,
                serverBgDataUrl = serverBgDataUrl,
                logo = logoPayload,
                bg = bgPayload,
                suppressDashboardCustomLogoForPreview = suppressDashboardCustomLogoForPreview,
            ),
        )
    }

    fun generateFlyer() {
        val conceptTrim = concept.trim().ifEmpty { brandName.trim().ifEmpty { "Mon commerce" } }
        if (conceptTrim.length < 3) {
            saveError = "Décrivez votre concept (3 caractères minimum)."
            return
        }
        viewModelScope.launch {
            isGenerating = true
            aiProgress = 0.05f
            saveError = null
            runCatching {
                val accent = accentHex.trim().ifEmpty { "#FF0066" }
                val logoB64 = logoPreviewDataUrl?.let { dataUrlToRawBase64(it) }
                val req = FlyerAiGenerateRequest(
                    brandName = brandName.trim().ifEmpty { "Mon commerce" }.take(80),
                    cuisineOrConcept = conceptTrim,
                    accentColorHex = accent,
                    secondaryColorHex = accent,
                    paletteColorsHex = listOf(accent),
                    logoBase64 = logoB64,
                )
                val result = repository.flyerAiGenerateAndWait(slug, req)
                aiProgress = 1f
                val raw = result.imageBase64?.trim().orEmpty()
                if (raw.isEmpty()) error("Génération sans image")
                val dataUrl = if (raw.startsWith("data:")) raw else "data:image/png;base64,$raw"
                setBackgroundDataUrl(dataUrl)
                selectedBackgroundTemplateKey = null
                result.flyerAiGenerationsRemaining?.let { flyerAiGenerationsRemaining = it }
                result.flyerAiUnlimited?.let { flyerAiUnlimited = it }
            }.onFailure { e ->
                saveError = (e as? FlyerAiGenerateException)?.message ?: e.message ?: "Génération impossible"
            }
            isGenerating = false
        }
    }

    fun validateGeneratedFlyer(onSuccess: () -> Unit = {}) {
        val raw = pendingAiImageB64?.trim().orEmpty()
        if (raw.isEmpty()) return
        viewModelScope.launch {
            isSaving = true
            saveError = null
            runCatching {
                val dataUrl = if (raw.startsWith("data:")) raw else "data:image/png;base64,$raw"
                setBackgroundDataUrl(dataUrl)
                selectedBackgroundTemplateKey = null
                pendingAiImageB64 = null
                refreshPreviewBootstrap()
                if (serverSnapshotWasNonDefault) {
                    revealHeroViewMode()
                } else {
                    revealHeroForEditing()
                }
                onSuccess()
            }.onFailure {
                saveError = it.message ?: "Enregistrement impossible"
            }
            isSaving = false
        }
    }

    fun save(onSuccess: () -> Unit = {}) {
        viewModelScope.launch {
            isSaving = true
            saveError = null
            runCatching {
                if (saveInternal()) {
                    finishSaveToViewMode()
                    onSuccess()
                }
            }.onFailure {
                saveError = it.message ?: "Enregistrement impossible"
            }
            isSaving = false
        }
    }

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    private suspend fun saveInternal(): Boolean {
        val putBody = buildPutBody()
        repository.dashboardFlyerPut(slug, putBody)
        val response = repository.dashboardFlyerGet(slug)
        val b64 = FlyerBootstrapPreviewPayloadBuilder.base64FromDashboardResponse(response, slug, state)
        bootstrapPreviewBase64 = b64
        serverSnapshotWasNonDefault = true
        logoPayload = FlyerRemoteImagePayload.LeaveUnchanged
        bgPayload = FlyerRemoteImagePayload.LeaveUnchanged
        serverLogoDataUrl = response["flyer_prefs"].jsonObjectOrNull()
            ?.get("custom_logo_data_url")?.jsonPrimitive?.content?.trim()?.takeIf { it.isNotEmpty() }
        serverBgDataUrl = response["flyer_prefs"].jsonObjectOrNull()
            ?.get("custom_bg_data_url")?.jsonPrimitive?.content?.trim()?.takeIf { it.isNotEmpty() }
        refreshNativeBg()
        persistCache(response, b64)
        CommerceFlyerEditorDraftStore.clear(appContext, slug)
        return true
    }

    private fun buildPutBody(): JsonObject {
        val st = state.normalizeClamps()
        return buildJsonObject {
            put("state", json.encodeToJsonElement(FlyerStateDto.serializer(), st))
            when (val lp = logoPayload) {
                FlyerRemoteImagePayload.LeaveUnchanged -> Unit
                FlyerRemoteImagePayload.Clear -> put("custom_logo_data_url", JsonNull)
                is FlyerRemoteImagePayload.DataUrl -> put("custom_logo_data_url", lp.value)
            }
            when (val bp = bgPayload) {
                FlyerRemoteImagePayload.LeaveUnchanged -> Unit
                FlyerRemoteImagePayload.Clear -> put("custom_bg_data_url", JsonNull)
                is FlyerRemoteImagePayload.DataUrl -> put("custom_bg_data_url", bp.value)
            }
        }
    }

    fun createFlyer(context: Context) {
        viewModelScope.launch {
            saveError = null
            runCatching {
                if (!hasPersistedBackground()) {
                    FlyerBackgroundTemplates.applyRandomTemplate(context)?.let { (key, dataUrl) ->
                        selectedBackgroundTemplateKey = key
                        setBackgroundDataUrl(dataUrl)
                    }
                }
                val accent = palettePriorityHexes.firstOrNull()?.let { AppVibrantColorPalette.normalizeHex(it) }
                    ?: AppVibrantColorPalette.normalizeHex(accentHex)
                    ?: "#651FFF"
                applyFullFlyerAccentFromWheelPalette(accent)
                logoPreviewDataUrl?.let { setLogoDataUrl(it) }
                refreshPreviewBootstrap()
                revealHeroForEditing()
            }.onFailure {
                saveError = it.message ?: "Impossible de créer le flyer"
            }
        }
    }

    fun selectPaletteHex(hex6: String) {
        val norm = AppVibrantColorPalette.normalizeHex(hex6) ?: return
        palettePriorityHexes = listOf(norm.removePrefix("#"))
        accentHex = norm
        if (flyerHeroRevealed && !isViewMode) {
            applyFullFlyerAccentFromWheelPalette(norm)
        }
    }

    fun applyFullFlyerAccentFromWheelPalette(accentRaw: String) {
        val accent = AppVibrantColorPalette.normalizeHex(accentRaw) ?: return
        val sec = FlyerWheelPairColor.evenHexFromAccent(accent.removePrefix("#"))
        val contrast = FlyerWheelPairColor.contrastingOnAccentHex(accent.removePrefix("#"))
        applyState(
            state.copy(
                wheelColorOdd = accent,
                wheelColorEven = FlyerWheelPairColor.WHEEL_ALTERNATING_LIGHT_HEX,
                colorPrimary = accent,
                colorSecondary = sec,
                colorBgTop = sec,
                colorBgBottom = accent,
                ctaBannerBgColor = accent,
                ctaTextColor = contrast,
                headlineGiftStrokeColor = contrast,
            ),
        )
        accentHex = accent
        palettePriorityHexes = listOf(accent.removePrefix("#"))
    }

    fun applyBackgroundTemplate(context: Context, key: String) {
        val bmp = FlyerBackgroundTemplates.loadBitmap(context, key) ?: return
        selectedBackgroundTemplateKey = key
        setBackgroundDataUrl(bitmapToPngDataUrl(bmp))
    }

    private fun hasPersistedBackground(): Boolean {
        if (!effectiveBgPreview().isNullOrBlank()) return true
        if (!serverBgDataUrl.isNullOrBlank()) return true
        return pendingAiImageB64 != null
    }

    fun clearLogo() {
        if (!suppressUndo) pushUndo()
        logoPreviewDataUrl = null
        logoPayload = FlyerRemoteImagePayload.Clear
        suppressDashboardCustomLogoForPreview = true
        refreshPreviewBootstrap()
    }

    fun restoreLogoFromServer() {
        if (!suppressUndo) pushUndo()
        logoPreviewDataUrl = null
        logoPayload = FlyerRemoteImagePayload.LeaveUnchanged
        suppressDashboardCustomLogoForPreview = false
        refreshPreviewBootstrap()
    }

    val logoEnabled: Boolean
        get() = logoPayload !is FlyerRemoteImagePayload.Clear &&
            (logoPreviewDataUrl != null || serverLogoDataUrl != null || logoPayload is FlyerRemoteImagePayload.DataUrl)

    fun setLogoEnabled(enabled: Boolean) {
        if (enabled) restoreLogoFromServer() else clearLogo()
    }

    fun revealHeroForEditing() {
        flyerHeroRevealed = true
        isViewMode = false
        isEditMode = true
        expandedEditSection = null
    }

    fun finishSaveToViewMode() {
        isViewMode = true
        isEditMode = false
        expandedEditSection = null
    }

    fun revealHeroViewMode() {
        flyerHeroRevealed = true
        isViewMode = true
        isEditMode = false
        expandedEditSection = null
    }

    fun enterEditMode() {
        isViewMode = false
        isEditMode = true
        expandedEditSection = null
    }

    fun exitEditModeToView() {
        isEditMode = false
        isViewMode = true
        expandedEditSection = null
    }

    private fun dataUrlToRawBase64(dataUrl: String): String? {
        val t = dataUrl.trim()
        if (t.isEmpty()) return null
        return t.substringAfter(",", t)
    }

    companion object {
        fun factory(
            container: AppContainer,
            appContext: Context,
            slug: String,
            startCreateAssistant: Boolean,
            openForEdit: Boolean,
        ): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T =
                ProgramFlyerEditorViewModel(
                    repository = container.dashboardRepository,
                    appContext = appContext.applicationContext,
                    slug = slug,
                    startCreateAssistant = startCreateAssistant,
                    openForEdit = openForEdit,
                ) as T
        }
    }
}
