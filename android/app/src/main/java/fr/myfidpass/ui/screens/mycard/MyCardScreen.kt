package fr.myfidpass.ui.screens.mycard

import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Alignment
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material.icons.filled.Check
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import fr.myfidpass.util.HapticHelper
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.BuildConfig
import fr.myfidpass.data.local.CardPreviewSnapshotStore
import fr.myfidpass.data.local.CommerceFlyerStateCache
import fr.myfidpass.ui.components.PostCardFlyerPromoEligibility
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.services.sync.SyncService
import fr.myfidpass.ui.components.ImageCropDialog
import fr.myfidpass.ui.components.ImageCropSpec
import fr.myfidpass.ui.components.GoogleWalletLoyaltyPreviewAndroid
import fr.myfidpass.ui.mycard.CardMissingRequirement
import fr.myfidpass.ui.mycard.CardPreviewEditZone
import fr.myfidpass.ui.mycard.MyCardCompletionRequirements
import fr.myfidpass.ui.mycard.MyCardDraftState
import fr.myfidpass.ui.mycard.StampIconCatalog
import fr.myfidpass.ui.mycard.applySavedMediaFrom
import fr.myfidpass.ui.mycard.MyCardMediaUrls
import fr.myfidpass.ui.mycard.snapshotForDirtyCompare
import fr.myfidpass.ui.mycard.runGoogleWalletPreview
import fr.myfidpass.ui.viewmodel.DashboardViewModel
import fr.myfidpass.data.repo.mapWalletPreviewError
import kotlinx.serialization.SerializationException
import fr.myfidpass.ui.components.SafeArea
import fr.myfidpass.util.openInCustomTab
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MyCardScreen(
    viewModel: DashboardViewModel,
    sessionStore: SessionStore,
    repository: DashboardRepository,
    syncService: SyncService,
    snackbar: SnackbarHostState,
    onBack: () -> Unit,
) {
    val slug = sessionStore.currentBusinessSlug.orEmpty()
    val context = LocalContext.current
    val view = LocalView.current
    val scope = rememberCoroutineScope()
    var draft by remember { mutableStateOf(MyCardDraftState()) }
    var baseline by remember { mutableStateOf<MyCardDraftState?>(null) }
    var saving by remember { mutableStateOf(false) }
    var walletLoading by remember { mutableStateOf(false) }
    var activeZone by remember { mutableStateOf<CardPreviewEditZone?>(null) }
    var cardLogoZoomFocused by remember { mutableStateOf(false) }
    var showLeaveAlert by remember { mutableStateOf(false) }
    var showProgramSwitchConfirm by remember { mutableStateOf(false) }
    var pendingProgramType by remember { mutableStateOf<String?>(null) }
    var pendingProgramSwitchMemberCount by remember { mutableStateOf(0) }
    var cropUri by remember { mutableStateOf<Uri?>(null) }
    var cropSpec by remember { mutableStateOf(ImageCropSpec.WALLET_STRIP_LOGO) }
    var showCrop by remember { mutableStateOf(false) }

    val fidelityUrl = if (slug.isNotBlank()) {
        "https://www.myfidpass.fr/fidelity/${slug.lowercase().trim()}?qr=1"
    } else {
        "https://www.myfidpass.fr"
    }
    val settings = viewModel.settings
    val logoPreviewModel = MyCardMediaUrls.resolvedLogoModel(draft, settings)
    val backgroundPreviewModel = MyCardMediaUrls.resolvedBackgroundModel(
        draft = draft,
        settings = settings,
        apiBase = BuildConfig.API_BASE_URL,
        slug = slug,
    )

    val stampIconApiUrl = if (
        slug.isNotBlank() &&
        draft.isStampsMode &&
        draft.pendingStampIconDataUrl == null &&
        !draft.stampIconWasRemoved &&
        draft.serverHasStampIcon &&
        !StampIconCatalog.isCatalogKey(draft.stampEmoji)
    ) {
        "${BuildConfig.API_BASE_URL.trimEnd('/')}/api/businesses/${slug.lowercase()}/stamp-icon"
    } else null

    val pickLogo = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        uri ?: return@rememberLauncherForActivityResult
        cropSpec = ImageCropSpec.WALLET_STRIP_LOGO
        cropUri = uri
        showCrop = true
    }
    val pickBackground = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        uri ?: return@rememberLauncherForActivityResult
        cropSpec = ImageCropSpec.WALLET_CARD_BACKGROUND
        cropUri = uri
        showCrop = true
    }
    val pickStampIcon = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        uri ?: return@rememberLauncherForActivityResult
        cropSpec = ImageCropSpec.STAMP_ICON
        cropUri = uri
        showCrop = true
    }

    LaunchedEffect(slug) {
        if (slug.isBlank()) return@LaunchedEffect
        viewModel.refreshAndWait()
    }

    LaunchedEffect(viewModel.settings, slug) {
        val s = viewModel.settings ?: return@LaunchedEffect
        val snap = slug.takeIf { it.isNotBlank() }?.let { CardPreviewSnapshotStore.load(context, it) }
        val loaded = MyCardDraftState().apply { loadFrom(s, snap) }
        loaded.previewPoints = viewModel.stats?.pointsThisMonth ?: 0
        loaded.previewStamps = 0
        val currentBaseline = baseline
        if (currentBaseline == null) {
            draft = loaded
            baseline = loaded.snapshotForDirtyCompare()
            return@LaunchedEffect
        }
        if (draft.snapshotForDirtyCompare() == currentBaseline) {
            draft = loaded
            baseline = loaded.snapshotForDirtyCompare()
        }
    }

    val hasUnsaved = baseline != null && draft.snapshotForDirtyCompare() != baseline
    val missing = draft.missingRequirements()
    val completionZones = buildSet {
        addAll(missing.map { it.suggestedEditZone })
        if (missing.any { it == CardMissingRequirement.Couleurs }) {
            add(CardPreviewEditZone.CARD_APPEARANCE)
        }
    }
    val rewardsConfigurationComplete = !missing.contains(CardMissingRequirement.Recompenses)
    val cardPreviewSnapshot = slug.takeIf { it.isNotBlank() }?.let { CardPreviewSnapshotStore.load(context, it) }
    val cardConfiguredHint = slug.isNotBlank() &&
        MyCardCompletionRequirements.isConfigured(viewModel.settings, cardPreviewSnapshot)
    val shouldShowCompletionPills = missing.isNotEmpty() &&
        !(cardConfiguredHint && viewModel.settings == null)

    fun testWallet() {
        if (slug.isBlank()) return
        scope.launch {
            walletLoading = true
            runGoogleWalletPreview(
                repository = repository,
                memberDao = syncService.memberDao,
                slug = slug,
                onSuccess = { url ->
                    openInCustomTab(context, url)
                    scope.launch { snackbar.showSnackbar("Ajoutez votre carte dans Google Wallet") }
                },
                onFailure = { msg -> scope.launch { snackbar.showSnackbar(msg) } },
            )
            walletLoading = false
        }
    }

    fun requestBack() {
        if (cardLogoZoomFocused) {
            cardLogoZoomFocused = false
            return
        }
        if (hasUnsaved) showLeaveAlert = true else onBack()
    }

    BackHandler { requestBack() }

    fun applyRewardExamples() {
        draft = if (draft.isStampsMode) {
            draft.copy(
                startGameRewardLabel = "Boisson offerte",
                stampMidRewardLabel = "-50 % sur l'addition",
                stampRewardLabel = "Menu offert",
            )
        } else {
            draft.copy(
                startGameRewardLabel = "Boisson offerte",
                tierPoints = listOf("50", "100", "150", "200", "250"),
                tierLabels = listOf(
                    "Boisson offerte",
                    "-10% sur l'addition",
                    "Dessert offert",
                    "-20% sur l'addition",
                    "Menu offert",
                ),
            )
        }
    }

    fun saveRewardsOnly(onDone: () -> Unit = {}) {
        if (slug.isBlank()) return
        if (!rewardsConfigurationComplete) {
            scope.launch {
                snackbar.showSnackbar("Renseignez toutes les récompenses, y compris « Début du jeu ».")
            }
            return
        }
        scope.launch {
            saving = true
            runCatching {
                repository.patchDashboardSettings(slug, draft.buildRewardsSavePatch())
                viewModel.refreshAndWait()
                val snap = draft.toSnapshot(viewModel.settings?.logoUrl)
                CardPreviewSnapshotStore.save(context, slug, snap)
                baseline = draft.snapshotForDirtyCompare()
            }.onSuccess {
                snackbar.showSnackbar("Récompenses enregistrées")
                onDone()
            }.onFailure {
                snackbar.showSnackbar(formatSaveError(it))
            }
            saving = false
        }
    }

    fun saveCard(onDone: () -> Unit = {}) {
        if (slug.isBlank()) return
        if (missing.isNotEmpty()) {
            scope.launch {
                snackbar.showSnackbar("Complétez d'abord : ${missing.joinToString(" · ") { it.title }}")
            }
            return
        }
        scope.launch {
            saving = true
            runCatching {
                repository.patchDashboardSettings(slug, draft.buildSavePatch())
                viewModel.refreshAndWait()
                val savedSettings = viewModel.settings
                draft = draft.applySavedMediaFrom(savedSettings)
                val snap = draft.toSnapshot(savedSettings?.logoUrl)
                CardPreviewSnapshotStore.save(context, slug, snap)
                baseline = draft.snapshotForDirtyCompare()
            }.onSuccess {
                HapticHelper.save(view)
                snackbar.showSnackbar("Carte enregistrée")
                PostCardFlyerPromoEligibility.queuePresentationOnMerchantHome(context, slug)
                onDone()
            }.onFailure {
                snackbar.showSnackbar(formatSaveError(it))
            }
            saving = false
        }
    }

    fun openCustomizationZone(zone: CardPreviewEditZone) {
        if (zone == CardPreviewEditZone.QR_CODE) {
            openInCustomTab(context, fidelityUrl)
            return
        }
        if (zone == CardPreviewEditZone.LOGO_BAND) {
            cardLogoZoomFocused = true
        } else {
            cardLogoZoomFocused = false
        }
        activeZone = zone
    }

    fun handleZoneTap(zone: CardPreviewEditZone) {
        if (zone == CardPreviewEditZone.LOGO_BAND) {
            openCustomizationZone(zone)
            return
        }
        if (cardLogoZoomFocused) {
            cardLogoZoomFocused = false
        }
        openCustomizationZone(zone)
    }

    fun programModeLabel(type: String): String =
        if (type.trim().lowercase() == "stamps") "Tampons" else "Points"

    fun trySwitchProgramType(next: String) {
        val current = draft.programType.trim().lowercase()
        val normalized = next.trim().lowercase()
        if (current == normalized) return
        scope.launch {
            val localCount = if (slug.isNotBlank()) {
                runCatching { syncService.memberDao.countForSlug(slug) }.getOrDefault(0)
            } else {
                0
            }
            val statsCount = viewModel.stats?.membersCount ?: 0
            val memberCount = maxOf(localCount, statsCount)
            if (memberCount > 0) {
                pendingProgramType = normalized
                pendingProgramSwitchMemberCount = memberCount
                showProgramSwitchConfirm = true
            } else {
                val updated = draft.copy(programType = normalized)
                updated.applyProgramTypeSideEffects(normalized)
                draft = updated
            }
        }
    }

    fun confirmProgramSwitch() {
        val next = pendingProgramType ?: return
        val updated = draft.copy(programType = next)
        updated.applyProgramTypeSideEffects(next)
        draft = updated
        pendingProgramType = null
        showProgramSwitchConfirm = false
    }

    val logoZoomScale by animateFloatAsState(
        targetValue = if (cardLogoZoomFocused) 1.75f else 1f,
        animationSpec = spring(dampingRatio = 0.86f, stiffness = 420f),
        label = "cardLogoZoom",
    )

    val pageBg = Color(0xFFF2F2F7)

    Column(
        Modifier
            .fillMaxSize()
            .background(pageBg),
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(top = SafeArea.statusBarTop())
                .padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = { requestBack() }) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Retour", tint = Color(0xFF007AFF))
            }
            Text(
                "Ma carte",
                modifier = Modifier.weight(1f),
                fontWeight = FontWeight.SemiBold,
                color = Color.Black,
            )
            if (hasUnsaved) {
                IconButton(onClick = { saveCard() }, enabled = !saving) {
                    if (saving) {
                        CircularProgressIndicator(
                            strokeWidth = 2.dp,
                            modifier = Modifier.size(20.dp),
                            color = Color(0xFF007AFF),
                        )
                    } else {
                        Icon(
                            Icons.Filled.Check,
                            contentDescription = "Enregistrer",
                            tint = Color(0xFF007AFF),
                            modifier = Modifier.size(22.dp),
                        )
                    }
                }
            } else {
                Spacer(Modifier.size(48.dp))
            }
        }

        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(bottom = 32.dp),
        ) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 8.dp),
                shape = RoundedCornerShape(24.dp),
                color = Color(0xFFE5E5EA),
            ) {
                SingleChoiceSegmentedButtonRow(
                    Modifier
                        .fillMaxWidth()
                        .padding(4.dp),
                ) {
                    SegmentedButton(
                        selected = !draft.isStampsMode,
                        onClick = { trySwitchProgramType("points") },
                        shape = SegmentedButtonDefaults.itemShape(index = 0, count = 2),
                        colors = SegmentedButtonDefaults.colors(
                            activeContainerColor = Color.White,
                            inactiveContainerColor = Color.Transparent,
                        ),
                    ) { Text("Points") }
                    SegmentedButton(
                        selected = draft.isStampsMode,
                        onClick = { trySwitchProgramType("stamps") },
                        shape = SegmentedButtonDefaults.itemShape(index = 1, count = 2),
                        colors = SegmentedButtonDefaults.colors(
                            activeContainerColor = Color.White,
                            inactiveContainerColor = Color.Transparent,
                        ),
                    ) { Text("Tampons") }
                }
            }

            Box(
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = if (cardLogoZoomFocused) 240.dp else 0.dp)
                    .padding(horizontal = 14.dp, vertical = 12.dp)
                    .graphicsLayer {
                        scaleX = logoZoomScale
                        scaleY = logoZoomScale
                        transformOrigin = TransformOrigin(0f, 0f)
                    },
            ) {
                GoogleWalletLoyaltyPreviewAndroid(
                    businessName = draft.displayName.ifBlank { "Ma Carte Fidélité" },
                    qrPayload = fidelityUrl,
                    logoUrl = logoPreviewModel,
                    backgroundHex = draft.primaryHex,
                    labelHex = draft.labelHex,
                    accentHex = draft.accentHex,
                    modifier = Modifier.fillMaxWidth(),
                    samplePoints = draft.previewPoints,
                    sampleMemberLabel = "Prévisualisation",
                    programType = draft.programType,
                    requiredStamps = draft.requiredStamps,
                    previewStampsCount = draft.previewStamps,
                    stampEmoji = draft.stampEmoji,
                    stripDisplayMode = draft.stripDisplayMode,
                    stripText = draft.stripText,
                    backgroundImageUrl = backgroundPreviewModel,
                    stampHeroImageUrl = null,
                    pendingBackgroundDataUrl = null,
                    pendingLogoDataUrl = null,
                    pendingStampIconDataUrl = draft.pendingStampIconDataUrl,
                    stampIconRemoteUrl = stampIconApiUrl,
                    stampMidRewardLabel = draft.stampMidRewardLabel,
                    stampRewardLabel = draft.stampRewardLabel,
                    startGameRewardLabel = draft.startGameRewardLabel,
                    tierPoints = draft.tierPoints,
                    tierLabels = draft.tierLabels,
                    authToken = sessionStore.accessToken,
                    completionHighlightZones = if (shouldShowCompletionPills) completionZones else emptySet(),
                    onZoneTap = ::handleZoneTap,
                    onCompletionPillTap = ::openCustomizationZone,
                )
            }
            Text(
                "Aperçu Google Wallet — le rendu final s’affiche dans l’app Wallet.",
                modifier = Modifier
                    .padding(horizontal = 28.dp)
                    .padding(bottom = 8.dp),
                fontSize = 12.sp,
                color = Color.Black.copy(alpha = 0.45f),
                textAlign = TextAlign.Center,
            )

            Button(
                onClick = {
                    if (hasUnsaved) {
                        if (missing.isNotEmpty()) {
                            scope.launch {
                                snackbar.showSnackbar(
                                    "Complétez : ${missing.joinToString(" · ") { it.title }}. Puis enregistrez.",
                                )
                            }
                            return@Button
                        }
                        saveCard { testWallet() }
                        return@Button
                    }
                    testWallet()
                },
                enabled = !walletLoading,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 8.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color.Black, contentColor = Color.White),
                shape = RoundedCornerShape(50),
            ) {
                if (walletLoading) {
                    CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.height(20.dp))
                } else {
                    Text("Tester dans Google Wallet", fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }

    activeZone?.let { zone ->
        CardCustomizationBottomSheet(
            zone = zone,
            draft = draft,
            onDraftChange = { draft = it },
            onDismiss = {
                activeZone = null
                cardLogoZoomFocused = false
            },
            onApplyExamples = { applyRewardExamples() },
            onSaveRewards = { saveRewardsOnly(onDone = { activeZone = null }) },
            canSaveRewards = rewardsConfigurationComplete,
            rewardsSaving = saving,
            onPickLogo = { pickLogo.launch("image/*") },
            onPickLogoUri = { uri ->
                cropSpec = when (activeZone) {
                    CardPreviewEditZone.BACKGROUND_IMAGE,
                    CardPreviewEditZone.MAIN_METRICS,
                    -> ImageCropSpec.WALLET_CARD_BACKGROUND
                    else -> ImageCropSpec.WALLET_STRIP_LOGO
                }
                cropUri = uri
                showCrop = true
            },
            onPickBackground = { pickBackground.launch("image/*") },
            onPickStampIcon = { pickStampIcon.launch("image/*") },
            onLogoNobg = {
                scope.launch {
                    runCatching {
                        repository.dashboardLogoNobg(slug)
                        viewModel.refresh()
                        draft = draft.copy(logoUrl = viewModel.settings?.logoUrl.orEmpty())
                        snackbar.showSnackbar("Logo détouré (sans fond)")
                    }.onFailure { snackbar.showSnackbar(it.message ?: "Erreur") }
                }
            },
            onRemoveLogo = { draft = draft.copy(logoUrl = "", pendingLogoDataUrl = null) },
            onRemoveBackground = {
                draft = draft.copy(
                    pendingBackgroundDataUrl = null,
                    cardBackgroundRemoteUrl = "",
                    cardBackgroundWasRemoved = true,
                )
            },
        )
    }

    cropUri?.let { uri ->
        val activeSpec = cropSpec
        ImageCropDialog(
            uri = uri,
            spec = activeSpec,
            visible = showCrop,
            onDismiss = {
                showCrop = false
                cropUri = null
            },
            onCropped = { dataUrl ->
                draft = when (activeSpec) {
                    ImageCropSpec.WALLET_STRIP_LOGO ->
                        draft.copy(pendingLogoDataUrl = dataUrl)
                    ImageCropSpec.WALLET_CARD_BACKGROUND ->
                        draft.copy(
                            pendingBackgroundDataUrl = dataUrl,
                            cardBackgroundWasRemoved = false,
                        )
                    ImageCropSpec.STAMP_ICON ->
                        draft.copy(pendingStampIconDataUrl = dataUrl)
                    else -> draft
                }
                cropUri = null
                showCrop = false
            },
        )
    }

    if (showProgramSwitchConfirm) {
        val fromLabel = programModeLabel(draft.programType)
        val toLabel = programModeLabel(pendingProgramType ?: draft.programType)
        val n = pendingProgramSwitchMemberCount
        AlertDialog(
            onDismissRequest = {
                showProgramSwitchConfirm = false
                pendingProgramType = null
            },
            title = { Text("Changer le mode ?") },
            text = {
                Text(
                    "Vous avez $n client${if (n > 1) "s" else ""}. " +
                        "Passer de $fromLabel à $toLabel remet tous les soldes à zéro et efface l’historique. " +
                        "Irréversible — enregistrez ensuite la carte.",
                )
            },
            confirmButton = {
                TextButton(onClick = { confirmProgramSwitch() }) {
                    Text("Confirmer", color = Color(0xFFFF3B30))
                }
            },
            dismissButton = {
                TextButton(onClick = {
                    showProgramSwitchConfirm = false
                    pendingProgramType = null
                }) { Text("Annuler") }
            },
        )
    }

    if (showLeaveAlert) {
        AlertDialog(
            onDismissRequest = { showLeaveAlert = false },
            title = { Text("Modifications non enregistrées") },
            text = { Text("Voulez-vous enregistrer vos changements avant de quitter ?") },
            confirmButton = {
                TextButton(onClick = {
                    showLeaveAlert = false
                    saveCard(onBack)
                }) { Text("Enregistrer") }
            },
            dismissButton = {
                TextButton(onClick = {
                    showLeaveAlert = false
                    baseline?.let { draft = it }
                    onBack()
                }) { Text("Ne pas enregistrer") }
            },
        )
    }
}

private fun formatSaveError(error: Throwable): String = when (error) {
    is SerializationException -> "Réponse serveur inattendue — vérifiez que la carte est bien enregistrée."
    else -> error.message ?: "Erreur d'enregistrement"
}
