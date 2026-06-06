package fr.myfidpass.ui.screens.tabs

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import fr.myfidpass.BuildConfig
import fr.myfidpass.data.dto.CampaignAutomationConfigDto
import fr.myfidpass.data.dto.CampaignAutomationRuleDto
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.util.readUriAsImageDataUrl
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonObject

@Composable
fun CampaignsTabScreen(
    modifier: Modifier = Modifier,
    repository: DashboardRepository,
    sessionStore: SessionStore,
    snackbarHostState: SnackbarHostState,
    hasProAccess: Boolean = true,
    onUnlockPro: () -> Unit = {},
    onRequestAccountRefresh: () -> Unit = {},
) {
    val slug = repository.currentSlug()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val authToken = sessionStore.accessToken

    var title by remember { mutableStateOf("") }
    var bodyText by remember { mutableStateOf("") }
    var selectedSegment by remember { mutableStateOf<String?>(null) }
    var automation by remember { mutableStateOf<CampaignAutomationConfigDto?>(null) }
    var ruleMessages by remember { mutableStateOf<Map<String, String>>(emptyMap()) }
    var perimeterMessage by remember { mutableStateOf("") }
    var locationLat by remember { mutableStateOf<Double?>(null) }
    var locationLng by remember { mutableStateOf<Double?>(null) }
    var locationRadiusMeters by remember { mutableIntStateOf(100) }
    var notificationIconUrl by remember { mutableStateOf<String?>(null) }
    var loadError by remember { mutableStateOf<String?>(null) }
    var dataLoading by remember { mutableStateOf(true) }
    var isSending by remember { mutableStateOf(false) }
    var sendProgress by remember { mutableFloatStateOf(0f) }
    var sendSuccessCount by remember { mutableStateOf<Int?>(null) }
    var uploadingIcon by remember { mutableStateOf(false) }
    var showLogoPopup by remember { mutableStateOf(false) }
    var showPerimeter by remember { mutableStateOf(false) }
    var eventEditorRuleId by remember { mutableStateOf<String?>(null) }
    var showEventEditor by remember { mutableStateOf(false) }
    var pendingDeleteEventId by remember { mutableStateOf<String?>(null) }

    val hasCustomIcon = !notificationIconUrl.isNullOrBlank()
    val iconApiUrl = slug?.let {
        "${BuildConfig.API_BASE_URL.trimEnd('/')}/api/businesses/${it.lowercase()}/notification-icon"
    }

    val pickNotifIcon = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        uri ?: return@rememberLauncherForActivityResult
        val s = slug ?: return@rememberLauncherForActivityResult
        readUriAsImageDataUrl(context, uri, maxBytes = 512 * 1024)?.let { dataUrl ->
            scope.launch {
                uploadingIcon = true
                runCatching {
                    repository.patchDashboardSettings(
                        s,
                        buildJsonObject { put("notification_icon_base64", dataUrl) },
                    )
                    notificationIconUrl = iconApiUrl
                    showLogoPopup = false
                    snackbarHostState.showSnackbar("Icône notification enregistrée")
                    loadCampaignData(repository, s) { settings, auto ->
                        automation = auto
                        notificationIconUrl = settings.notificationIconUrl?.trim()?.takeIf { it.isNotEmpty() }
                            ?: iconApiUrl
                    }
                }.onFailure {
                    snackbarHostState.showSnackbar(it.message ?: "Erreur")
                }
                uploadingIcon = false
            }
        } ?: scope.launch { snackbarHostState.showSnackbar("Image invalide (max 512 Ko)") }
    }

    if (showPerimeter) {
        PerimeterSettingsScreen(
            repository = repository,
            snackbar = snackbarHostState,
            onBack = {
                showPerimeter = false
                slug?.let { s ->
                    scope.launch {
                        loadCampaignData(repository, s) { settings, auto ->
                            automation = auto
                            perimeterMessage = settings.locationRelevantText.orEmpty()
                            locationLat = settings.locationLat
                            locationLng = settings.locationLng
                            locationRadiusMeters = settings.locationRadiusMeters ?: 100
                        }
                    }
                }
            },
        )
        return
    }

    LaunchedEffect(slug) {
        val s = slug ?: run {
            dataLoading = false
            return@LaunchedEffect
        }
        dataLoading = true
        loadError = null
        loadCampaignData(repository, s) { settings, auto ->
            automation = auto
            title = settings.notificationTitleOverride?.takeIf { it.isNotBlank() }.orEmpty()
            bodyText = ""
            perimeterMessage = settings.locationRelevantText.orEmpty()
            locationLat = settings.locationLat
            locationLng = settings.locationLng
            locationRadiusMeters = settings.locationRadiusMeters ?: 100
            notificationIconUrl = settings.notificationIconUrl?.trim()?.takeIf { it.isNotEmpty() }
            ruleMessages = auto?.rules?.mapValues { it.value.message.orEmpty() }.orEmpty()
        }.onFailure { loadError = it.message }
        dataLoading = false
    }

    LaunchedEffect(notificationIconUrl) {
        if (notificationIconUrl.isNullOrBlank()) {
            delay(3000)
            if (notificationIconUrl.isNullOrBlank()) showLogoPopup = true
        } else {
            showLogoPopup = false
        }
    }

    LaunchedEffect(title) {
        val s = slug ?: return@LaunchedEffect
        delay(380)
        runCatching {
            repository.patchDashboardSettings(
                s,
                buildJsonObject {
                    put("notification_title_override", title.trim())
                },
            )
        }
    }

    fun patchAutomation(onDone: () -> Unit = {}) {
        val s = slug ?: return
        scope.launch {
            runCatching {
                val current = automation?.rules?.toMutableMap() ?: mutableMapOf()
                val patch = buildJsonObject {
                    putJsonObject("campaign_automation") {
                        put("version", automation?.version ?: 1)
                        put("global_cooldown_days", automation?.globalCooldownDays ?: 7)
                        putJsonObject("rules") {
                            current.forEach { (k, v) ->
                                putJsonObject(k) {
                                    val iconOk = hasCustomIcon
                                    put("enabled", if (iconOk && v.enabled == true) 1 else 0)
                                    val msg = ruleMessages[k]?.trim()?.takeIf { it.isNotEmpty() } ?: v.message
                                    msg?.let { put("message", it) }
                                    v.eventType?.let { put("event_type", it) }
                                    v.delayMinutes?.let { put("delay_minutes", it) }
                                    v.title?.let { put("title", it) }
                                    v.segment?.let { put("segment", it) }
                                }
                            }
                        }
                    }
                    if (perimeterMessage.isNotBlank()) {
                        put("location_relevant_text", perimeterMessage.trim())
                    }
                }
                repository.patchDashboardSettings(s, patch)
                onDone()
            }.onFailure {
                snackbarHostState.showSnackbar(it.message ?: "Erreur enregistrement")
            }
        }
    }

    fun saveAutomationRule(ruleId: String, enabled: Boolean, message: String) {
        val current = automation?.rules?.toMutableMap() ?: mutableMapOf()
        val row = current[ruleId]?.copy(
            enabled = enabled && hasCustomIcon,
            message = message,
        ) ?: CampaignAutomationRuleDto(enabled = enabled && hasCustomIcon, message = message)
        current[ruleId] = row
        automation = automation?.copy(rules = current) ?: CampaignAutomationConfigDto(rules = current)
        ruleMessages = ruleMessages + (ruleId to message)
        patchAutomation()
    }

    fun sendNotification() {
        val s = slug ?: return
        if (!hasProAccess) {
            scope.launch { snackbarHostState.showSnackbar("Abonnement Pro requis pour l'envoi manuel") }
            return
        }
        if (!hasCustomIcon) {
            showLogoPopup = true
            return
        }
        if (bodyText.isBlank()) return
        scope.launch {
            isSending = true
            sendProgress = 0.08f
            delay(150)
            sendProgress = 0.35f
            val result = runCatching {
                sendProgress = 0.6f
                repository.sendNotification(
                    s,
                    bodyText.trim(),
                    title.trim().takeIf { it.isNotEmpty() },
                    selectedSegment,
                )
            }
            sendProgress = 1f
            result.fold(
                onSuccess = { resp ->
                    val count = resp["total"]?.jsonPrimitive?.intOrNull
                        ?: resp["sent"]?.jsonPrimitive?.intOrNull
                        ?: resp["sent_count"]?.jsonPrimitive?.intOrNull
                        ?: resp["recipients"]?.jsonPrimitive?.intOrNull
                    sendSuccessCount = count ?: 0
                    val accepted = resp["accepted"]?.jsonPrimitive?.booleanOrNull == true
                    val zeroTargets = (count ?: 0) == 0
                    bodyText = ""
                    patchAutomation()
                    delay(1400)
                    sendSuccessCount = null
                    when {
                        zeroTargets -> snackbarHostState.showSnackbar(
                            resp["message"]?.jsonPrimitive?.content
                                ?: "Aucun appareil joignable — les clients doivent avoir la carte dans Wallet ou le navigateur.",
                        )
                        accepted -> snackbarHostState.showSnackbar("Campagne lancée sur le serveur")
                        else -> snackbarHostState.showSnackbar("Notification envoyée")
                    }
                },
                onFailure = {
                    snackbarHostState.showSnackbar(it.message ?: "Erreur lors de l'envoi")
                },
            )
            isSending = false
            sendProgress = 0f
        }
    }

    Box(modifier.fillMaxSize()) {
        Column(
            Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp))
                .background(MaterialTheme.colorScheme.background)
                .verticalScroll(rememberScrollState())
                .padding(top = 12.dp)
                .padding(top = if (isSending) 8.dp else 0.dp)
                .padding(horizontal = 16.dp)
                .padding(bottom = 100.dp),
        ) {
            if (isSending) {
                NotificationSendTopProgressStrip(sendProgress)
                Spacer(Modifier.height(8.dp))
            }

            if (dataLoading) {
                CircularProgressIndicator()
                Spacer(Modifier.height(12.dp))
            }

            loadError?.let {
                Text(it, color = MaterialTheme.colorScheme.error)
                Spacer(Modifier.height(8.dp))
                TextButton(onClick = {
                    slug?.let { s ->
                        scope.launch {
                            dataLoading = true
                            loadCampaignData(repository, s) { settings, auto ->
                                automation = auto
                                notificationIconUrl = settings.notificationIconUrl?.trim()?.takeIf { it.isNotEmpty() }
                            }
                            dataLoading = false
                        }
                    }
                }) { Text("Réessayer") }
                Spacer(Modifier.height(12.dp))
            }

            if (slug == null) {
                Text("Aucun commerce synchronisé.")
                Spacer(Modifier.height(8.dp))
                Button(onClick = onRequestAccountRefresh) { Text("Synchroniser") }
                return@Column
            }

            Box(Modifier.fillMaxWidth()) {
                BorderBeamNotificationComposer(
                    title = title,
                    message = bodyText,
                    onTitleChange = { title = it },
                    onMessageChange = { bodyText = it },
                    selectedSegment = selectedSegment,
                    onSegmentSelected = { selectedSegment = it },
                    onSend = { sendNotification() },
                    sending = isSending,
                    sendEnabled = hasProAccess && bodyText.isNotBlank() && hasCustomIcon,
                    sendSuccessCount = sendSuccessCount,
                    modifier = Modifier.then(
                        if (!hasProAccess) Modifier.blur(5.dp).alpha(0.85f) else Modifier,
                    ),
                )
                if (!hasProAccess) {
                    ProUnlockTeaserButton(
                        onUnlock = onUnlockPro,
                        modifier = Modifier.align(Alignment.Center),
                    )
                }
            }

            Spacer(Modifier.height(20.dp))

            AutomationHubCarousel(
                automation = automation,
                ruleMessages = ruleMessages,
                notificationIconUrl = if (hasCustomIcon) iconApiUrl else null,
                authToken = authToken,
                perimeterMessage = perimeterMessage,
                onPerimeterMessageChange = { perimeterMessage = it; patchAutomation() },
                onRuleMessageChange = { id, msg ->
                    ruleMessages = ruleMessages + (id to msg)
                    patchAutomation()
                },
                onToggle = { id, enabled ->
                    saveAutomationRule(id, enabled, ruleMessages[id].orEmpty())
                },
                onOpenPerimeter = { showPerimeter = true },
                locationLat = locationLat,
                locationLng = locationLng,
                locationRadiusMeters = locationRadiusMeters,
                hasCustomIcon = hasCustomIcon,
                onAddEventProgramming = {
                    eventEditorRuleId = null
                    showEventEditor = true
                },
                onEditEventProgramming = { id ->
                    eventEditorRuleId = id
                    showEventEditor = true
                },
                onDeleteEventProgramming = { pendingDeleteEventId = it },
            )

        }

        if (showLogoPopup && !hasCustomIcon) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.22f))
                    .clickable(
                        indication = null,
                        interactionSource = remember { MutableInteractionSource() },
                        onClick = { showLogoPopup = false },
                    ),
                contentAlignment = Alignment.Center,
            ) {
                NotificationLogoPopupCard(
                    logoUrl = notificationIconUrl,
                    authToken = authToken,
                    uploading = uploadingIcon,
                    onPickLogo = { pickNotifIcon.launch("image/*") },
                    modifier = Modifier.padding(horizontal = 18.dp),
                )
            }
        }
    }

    if (showEventEditor) {
        val rule = eventEditorRuleId?.let { automation?.rules?.get(it) }
        EventAutomationEditorSheet(
            editingRuleId = eventEditorRuleId,
            initialTitle = rule?.title.orEmpty(),
            initialMessage = rule?.message.orEmpty(),
            initialEventType = rule?.eventType.orEmpty(),
            initialDelayMinutes = rule?.delayMinutes ?: 60,
            onDismiss = { showEventEditor = false },
            onSave = { id, t, msg, eventType, delay ->
                val current = automation?.rules?.toMutableMap() ?: mutableMapOf()
                current[id] = CampaignAutomationRuleDto(
                    enabled = hasCustomIcon,
                    message = msg,
                    title = t,
                    eventType = eventType,
                    delayMinutes = delay,
                )
                automation = automation?.copy(rules = current) ?: CampaignAutomationConfigDto(rules = current)
                ruleMessages = ruleMessages + (id to msg)
                patchAutomation()
            },
        )
    }

    pendingDeleteEventId?.let { id ->
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { pendingDeleteEventId = null },
            title = { Text("Supprimer cette programmation ?") },
            text = { Text("La programmation sera supprimée.") },
            confirmButton = {
                TextButton(onClick = {
                    val current = automation?.rules?.toMutableMap() ?: mutableMapOf()
                    current.remove(id)
                    automation = automation?.copy(rules = current)
                    patchAutomation()
                    pendingDeleteEventId = null
                }) { Text("Supprimer", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { pendingDeleteEventId = null }) { Text("Annuler") }
            },
        )
    }
}

private suspend fun loadCampaignData(
    repository: DashboardRepository,
    slug: String,
    onLoaded: (fr.myfidpass.data.dto.BusinessSettingsResponse, CampaignAutomationConfigDto?) -> Unit,
): Result<Unit> = runCatching {
    val settings = repository.businessSettings(slug)
    onLoaded(settings, settings.campaignAutomation)
}
