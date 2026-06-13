package fr.myfidpass.ui.screens.tabs

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
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
import fr.myfidpass.data.dto.LOCATION_ENTRY_RULE_ID
import fr.myfidpass.data.dto.defaultPerimeterNotificationMessage
import fr.myfidpass.data.dto.mergedAutomationRules
import fr.myfidpass.data.dto.NotificationBusinessReadinessDto
import fr.myfidpass.data.local.NotificationSendLocalHistoryStore
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.util.MerchantUXFeedback
import fr.myfidpass.util.readUriAsImageDataUrl
import fr.myfidpass.ui.components.MerchantFloatingTabBarMetrics
import fr.myfidpass.ui.components.MerchantProUnlockTeaserButton
import fr.myfidpass.ui.components.PerimeterMapView
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
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
    var isPerimeterEditing by remember { mutableStateOf(false) }
    var readinessRows by remember { mutableStateOf<List<NotificationBusinessReadinessDto>>(emptyList()) }
    var selectedSendSlugs by remember { mutableStateOf<Set<String>>(emptySet()) }

    val hasCustomIcon = !notificationIconUrl.isNullOrBlank()
    val showsMultiCommerceTargets = readinessRows.size > 1
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

    LaunchedEffect(slug) {
        val s = slug ?: run {
            dataLoading = false
            return@LaunchedEffect
        }
        dataLoading = true
        loadError = null
        loadCampaignData(repository, s) { settings, auto ->
            val mergedRules = mergedAutomationRules(auto)
            automation = CampaignAutomationConfigDto(rules = mergedRules)
            val commerceName = settings.organizationName?.trim()?.takeIf { it.isNotEmpty() }
                ?: sessionStore.businesses.firstOrNull { it.slug == s }?.organizationName?.trim()?.takeIf { it.isNotEmpty() }
                ?: sessionStore.businesses.firstOrNull { it.slug == s }?.name?.trim()?.takeIf { it.isNotEmpty() }
                ?: ""
            title = settings.notificationTitleOverride?.trim()?.takeIf { it.isNotEmpty() } ?: commerceName
            bodyText = ""
            perimeterMessage = settings.locationRelevantText.orEmpty().ifBlank {
                mergedRules[LOCATION_ENTRY_RULE_ID]?.message.orEmpty()
            }
            locationLat = settings.locationLat
            locationLng = settings.locationLng
            locationRadiusMeters = settings.locationRadiusMeters ?: 100
            notificationIconUrl = settings.notificationIconUrl?.trim()?.takeIf { it.isNotEmpty() }
        }.onFailure { loadError = it.message }
        dataLoading = false
        if (sessionStore.businesses.size > 1) {
            runCatching { repository.notificationReadiness() }
                .onSuccess { resp ->
                    readinessRows = resp.businesses.orEmpty()
                    if (selectedSendSlugs.isEmpty()) {
                        selectedSendSlugs = setOfNotNull(s)
                    }
                }
        }
    }

    LaunchedEffect(slug) {
        val s = slug?.trim().orEmpty()
        if (s.isNotEmpty()) {
            if (selectedSendSlugs.isEmpty() || selectedSendSlugs.size == 1) {
                selectedSendSlugs = setOf(s)
            } else {
                selectedSendSlugs = selectedSendSlugs + s
            }
        }
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
                val locEnabled = hasCustomIcon && (automation?.rules?.get(LOCATION_ENTRY_RULE_ID)?.enabled == true)
                val msg = perimeterMessage.trim().ifBlank { defaultPerimeterNotificationMessage }
                val patch = buildJsonObject {
                    putJsonObject("campaign_automation") {
                        put("version", automation?.version ?: 1)
                        put("global_cooldown_days", automation?.globalCooldownDays ?: 7)
                        putJsonObject("rules") {
                            putJsonObject(LOCATION_ENTRY_RULE_ID) {
                                put("enabled", if (locEnabled) 1 else 0)
                                put("message", msg)
                            }
                        }
                    }
                    put("location_relevant_text", if (locEnabled) msg else "")
                }
                repository.patchDashboardSettings(s, patch)
                onDone()
            }.onFailure {
                snackbarHostState.showSnackbar(it.message ?: "Erreur enregistrement")
            }
        }
    }

    fun saveLocationEntry(enabled: Boolean) {
        val current = automation?.rules?.toMutableMap() ?: mutableMapOf()
        val msg = perimeterMessage.trim().ifBlank { defaultPerimeterNotificationMessage }
        current[LOCATION_ENTRY_RULE_ID] = CampaignAutomationRuleDto(
            enabled = enabled && hasCustomIcon,
            message = msg,
        )
        automation = automation?.copy(rules = current) ?: CampaignAutomationConfigDto(rules = current)
        patchAutomation()
    }

    fun sendNotification() {
        val s = slug ?: return
        if (!hasProAccess) {
            scope.launch { snackbarHostState.showSnackbar("Abonnement Pro requis pour l'envoi manuel") }
            return
        }
        val sendSlugs = selectedSendSlugs.map { it.trim() }.filter { it.isNotEmpty() }
        if (showsMultiCommerceTargets) {
            val readyCount = readinessRows.count { row ->
                val rs = row.slug?.trim().orEmpty()
                rs.isNotEmpty() && sendSlugs.contains(rs) && row.ready == true
            }
            if (sendSlugs.isNotEmpty() && readyCount == 0) {
                scope.launch {
                    snackbarHostState.showSnackbar(
                        readinessRows
                            .filter { row -> sendSlugs.contains(row.slug) }
                            .joinToString(" · ") { "${it.displayName} : ${it.blockMessage ?: "non prêt"}" },
                    )
                }
                return
            }
        } else if (!hasCustomIcon) {
            showLogoPopup = true
            return
        }
        if (bodyText.isBlank()) return
        scope.launch {
            isSending = true
            sendProgress = 0.06f
            try {
                sendProgress = 0.20f
                val trimmedMessage = bodyText.trim()
                val trimmedTitle = title.trim().takeIf { it.isNotEmpty() }
                val result = runCatching {
                    repository.sendNotification(
                        s,
                        trimmedMessage,
                        trimmedTitle,
                        selectedSegment,
                        businessSlugs = sendSlugs.takeIf { it.size > 1 },
                    )
                }
                result.fold(
                    onSuccess = { resp ->
                        val serverMsg = resp["message"]?.jsonPrimitive?.content?.trim()
                        val code = resp["code"]?.jsonPrimitive?.contentOrNull
                        if (code == "no_real_clients") {
                            snackbarHostState.showSnackbar(
                                serverMsg?.takeIf { it.isNotEmpty() }
                                    ?: "Aucun vrai client n'a encore ajouté la carte. Partage le lien de ta carte pour que tes clients l'ajoutent à Apple Wallet.",
                            )
                            return@fold
                        }

                        val count = resp["total"]?.jsonPrimitive?.intOrNull
                            ?: resp["sent"]?.jsonPrimitive?.intOrNull
                            ?: resp["sent_count"]?.jsonPrimitive?.intOrNull
                            ?: resp["recipients"]?.jsonPrimitive?.intOrNull
                        val zeroTargets = (count ?: 0) == 0
                        val multiResults = if (resp["multi"]?.jsonPrimitive?.booleanOrNull == true) {
                            (resp["results"] as? JsonArray)
                                ?.mapNotNull { it as? JsonObject }
                                ?.filter { it["ok"]?.jsonPrimitive?.booleanOrNull == true }
                                .orEmpty()
                        } else {
                            emptyList()
                        }
                        if (zeroTargets) {
                            snackbarHostState.showSnackbar(
                                serverMsg?.takeIf { it.isNotEmpty() }
                                    ?: "Aucun appareil joignable — les clients doivent avoir la carte dans Wallet ou le navigateur.",
                            )
                            return@fold
                        }

                        sendProgress = 0.64f
                        if (multiResults.isNotEmpty()) {
                            for (row in multiResults) {
                                val rowSlug = row["slug"]?.jsonPrimitive?.contentOrNull ?: s
                                val rowJob = row["job_id"]?.jsonPrimitive?.contentOrNull
                                val rowBatch = row["batch_id"]?.jsonPrimitive?.contentOrNull?.trim().orEmpty()
                                if (!rowJob.isNullOrBlank()) {
                                    scope.launch {
                                        pollNotificationJob(
                                            repository = repository,
                                            context = context,
                                            slug = rowSlug,
                                            jobId = rowJob,
                                            batchId = rowBatch,
                                            title = trimmedTitle,
                                            message = trimmedMessage,
                                            expectedDevices = row["deliverable_devices"]?.jsonPrimitive?.intOrNull
                                                ?: row["total_devices"]?.jsonPrimitive?.intOrNull ?: 0,
                                            playSoundOnDelivered = false,
                                        )
                                    }
                                }
                            }
                        } else {
                            val batchId = resp["batch_id"]?.jsonPrimitive?.contentOrNull?.trim().orEmpty()
                            val jobId = resp["job_id"]?.jsonPrimitive?.contentOrNull
                            if (!jobId.isNullOrBlank()) {
                                scope.launch {
                                    pollNotificationJob(
                                        repository = repository,
                                        context = context,
                                        slug = s,
                                        jobId = jobId,
                                        batchId = batchId,
                                        title = trimmedTitle,
                                        message = trimmedMessage,
                                        expectedDevices = count ?: 0,
                                        playSoundOnDelivered = false,
                                    )
                                }
                            }
                        }

                        val successMessage = when {
                            multiResults.isNotEmpty() ->
                                "Notification envoyée vers ${multiResults.size} commerce${if (multiResults.size > 1) "s" else ""}."
                            else ->
                                "Notification envoyée à ${count ?: 0} client${if ((count ?: 0) > 1) "s" else ""}."
                        }

                        sendSuccessCount = if (multiResults.isNotEmpty()) {
                            count ?: multiResults.size
                        } else {
                            count ?: 0
                        }
                        delay(350)
                        sendProgress = 0.72f

                        bodyText = ""
                        patchAutomation()
                        sendProgress = 0.80f
                        sendProgress = 0.86f
                        sendProgress = 0.91f
                        sendProgress = 0.97f
                        sendProgress = 1f

                        delay(280)
                        MerchantUXFeedback.playNotificationSent(context = context)
                        snackbarHostState.showSnackbar(successMessage)
                        delay(900)
                        sendSuccessCount = null
                    },
                    onFailure = {
                        snackbarHostState.showSnackbar(it.message ?: "Erreur lors de l'envoi")
                    },
                )
            } finally {
                isSending = false
                sendProgress = 0f
            }
        }
    }

    Box(modifier.fillMaxSize()) {
        val panelShape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp)
        if (slug != null) {
            PerimeterMapView(
                latitude = locationLat,
                longitude = locationLng,
                radiusMeters = locationRadiusMeters,
                showMapChrome = false,
                darkAppearance = true,
                modifier = Modifier
                    .fillMaxSize()
                    .clip(panelShape),
            )
        } else {
            Box(
                Modifier
                    .fillMaxSize()
                    .clip(panelShape)
                    .background(MaterialTheme.colorScheme.background),
            )
        }

        Column(
            Modifier
                .fillMaxSize()
                .clip(panelShape)
                .then(if (isPerimeterEditing) Modifier.imePadding() else Modifier),
        ) {
            Box(
                Modifier
                    .weight(1f)
                    .fillMaxWidth(),
            ) {
                Column(
                    Modifier
                        .fillMaxSize()
                        .then(
                            if (!hasProAccess) {
                                Modifier.blur(10.dp).alpha(0.88f)
                            } else {
                                Modifier
                            },
                        ),
                ) {
                    Column(
                        Modifier
                            .weight(1f)
                            .fillMaxWidth()
                            .padding(top = 12.dp)
                            .padding(top = if (isSending) 8.dp else 0.dp)
                            .padding(horizontal = 16.dp),
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

            if (showsMultiCommerceTargets) {
                Text("Commerces ciblés", fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground)
                Spacer(Modifier.height(4.dp))
                Text(
                    "Chaque point de vente a sa propre icône notif et ses cartes Wallet.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(8.dp)) {
                    FilterChip(
                        selected = false,
                        onClick = {
                            selectedSendSlugs = readinessRows.mapNotNull { it.slug?.trim()?.takeIf { s -> s.isNotEmpty() } }.toSet()
                        },
                        label = { Text("Tous") },
                    )
                    FilterChip(
                        selected = false,
                        onClick = {
                            selectedSendSlugs = readinessRows
                                .filter { it.ready == true }
                                .mapNotNull { it.slug?.trim()?.takeIf { s -> s.isNotEmpty() } }
                                .toSet()
                        },
                        label = { Text("Prêts") },
                    )
                    slug?.let { active ->
                        FilterChip(
                            selected = false,
                            onClick = { selectedSendSlugs = setOf(active) },
                            label = { Text("Actif") },
                        )
                    }
                }
                Spacer(Modifier.height(10.dp))
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
                    shape = RoundedCornerShape(16.dp),
                ) {
                    readinessRows.forEachIndexed { index, row ->
                        val rs = row.slug?.trim().orEmpty()
                        if (rs.isEmpty()) return@forEachIndexed
                        val selected = selectedSendSlugs.contains(rs)
                        val ready = row.ready == true
                        Column(
                            Modifier
                                .fillMaxWidth()
                                .background(
                                    if (selected) MaterialTheme.colorScheme.primary.copy(alpha = 0.08f)
                                    else Color.Transparent,
                                )
                                .clickable {
                                    selectedSendSlugs = if (selected) {
                                        if (selectedSendSlugs.size > 1) selectedSendSlugs - rs else selectedSendSlugs
                                    } else {
                                        selectedSendSlugs + rs
                                    }
                                }
                                .padding(horizontal = 14.dp, vertical = 12.dp),
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(
                                    if (selected) "✓" else "○",
                                    color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline,
                                    fontWeight = FontWeight.Bold,
                                )
                                Spacer(Modifier.padding(horizontal = 4.dp))
                                Text(
                                    row.displayName,
                                    fontWeight = FontWeight.SemiBold,
                                    color = MaterialTheme.colorScheme.onSurface,
                                    modifier = Modifier.weight(1f),
                                )
                                Text(
                                    if (ready) "Prêt" else "À configurer",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = if (ready) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
                                    modifier = Modifier
                                        .background(
                                            (if (ready) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error)
                                                .copy(alpha = 0.12f),
                                            RoundedCornerShape(999.dp),
                                        )
                                        .padding(horizontal = 8.dp, vertical = 4.dp),
                                )
                            }
                            Spacer(Modifier.height(4.dp))
                            val previewOnly = row.previewOnly == true
                            Text(
                                when {
                                    ready && previewOnly ->
                                        row.deliveryHint?.takeIf { it.isNotBlank() }
                                            ?: "Aperçu seulement : partage le lien de ta carte pour que de vrais clients l'ajoutent à Apple Wallet."
                                    ready ->
                                        "${row.realClientDeviceCount} client(s) joignable(s) · ${row.membersCount ?: 0} client(s) enregistré(s)"
                                    else ->
                                        row.blockMessage ?: "Icône ou appareils manquants"
                                },
                                style = MaterialTheme.typography.bodySmall,
                                color = if (ready && !previewOnly) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        if (index < readinessRows.lastIndex) {
                            Box(
                                Modifier
                                    .fillMaxWidth()
                                    .height(1.dp)
                                    .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                            )
                        }
                    }
                }
                val summaryDevices = readinessRows
                    .filter { selectedSendSlugs.contains(it.slug) }
                    .sumOf { it.realClientDeviceCount }
                Text(
                    "${selectedSendSlugs.size} commerce(s) · $summaryDevices client(s) joignable(s)",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(14.dp))
            }

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
            )
            Spacer(Modifier.weight(1f))
                    }

                    if (slug != null) {
                        NotificationsPerimeterFooter(
                            perimeterMessage = perimeterMessage,
                            onPerimeterMessageChange = { newMessage ->
                                perimeterMessage = newMessage
                                if (hasCustomIcon) {
                                    saveLocationEntry(enabled = true)
                                }
                            },
                            hasCustomIcon = hasCustomIcon,
                            logoUrl = notificationIconUrl ?: iconApiUrl,
                            authToken = authToken,
                            onEditingChanged = { isPerimeterEditing = it },
                            modifier = Modifier
                                .padding(horizontal = 16.dp)
                                .padding(
                                    bottom = when {
                                        isPerimeterEditing -> 8.dp
                                        !hasProAccess -> MerchantFloatingTabBarMetrics.notificationsPerimeterBottomWithSubscribePill
                                        else -> MerchantFloatingTabBarMetrics.contentBottomInset
                                    },
                                ),
                        )
                    }
                }

                if (!hasProAccess) {
                    Box(
                        Modifier
                            .matchParentSize()
                            .background(Color.Black.copy(alpha = 0.14f)),
                    )
                    MerchantProUnlockTeaserButton(
                        onUnlock = onUnlockPro,
                        modifier = Modifier
                            .align(Alignment.Center)
                            .padding(horizontal = 24.dp),
                    )
                }
            }
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
}

private suspend fun pollNotificationJob(
    repository: DashboardRepository,
    context: android.content.Context,
    slug: String,
    jobId: String,
    batchId: String,
    title: String?,
    message: String,
    expectedDevices: Int,
    playSoundOnDelivered: Boolean = false,
) {
    val terminal = setOf("delivered", "partial", "failed", "no_targets", "dead")
    val delaysMs = listOf(1_000L, 2_000L, 4_000L, 8_000L, 15_000L, 30_000L, 60_000L)
    for (waitMs in delaysMs) {
        delay(waitMs)
        val status = runCatching { repository.notificationJobStatus(slug, jobId) }.getOrNull() ?: continue
        val delivery = status["delivery_status"]?.jsonPrimitive?.contentOrNull?.lowercase().orEmpty()
        val recipients = status["recipients_distinct"]?.jsonPrimitive?.intOrNull ?: 0
        val sent = status["sent"]?.jsonPrimitive?.intOrNull
            ?: status["sent_total"]?.jsonPrimitive?.intOrNull
            ?: 0
        val serverBatch = status["batch_id"]?.jsonPrimitive?.contentOrNull?.trim().orEmpty()
        val jobStatus = status["job_status"]?.jsonPrimitive?.contentOrNull
        if (terminal.contains(delivery) || jobStatus == "done" || jobStatus == "dead") {
            val finalBatch = serverBatch.ifEmpty { batchId.ifEmpty { "job:$jobId" } }
            val finalStatus = delivery.ifBlank { if (jobStatus == "dead") "failed" else "delivered" }
            NotificationSendLocalHistoryStore.recordDelivered(
                context = context,
                slug = slug,
                batchId = finalBatch,
                jobId = jobId,
                title = title,
                message = message,
                expectedDevices = expectedDevices,
                deliveryStatus = finalStatus,
                recipientsDistinct = maxOf(recipients, sent),
            )
            if (playSoundOnDelivered && (delivery == "delivered" || delivery == "partial")) {
                MerchantUXFeedback.playNotificationSent(context = context)
            }
            return
        }
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
