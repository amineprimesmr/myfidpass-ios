package fr.myfidpass.ui.screens.commerce.flyer

import android.net.Uri
import android.webkit.WebView
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.draw.shadow
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import fr.myfidpass.BuildConfig
import fr.myfidpass.di.AppContainer
import fr.myfidpass.flyer.FlyerBackgroundTemplates
import fr.myfidpass.flyer.FlyerShareHelper
import fr.myfidpass.ui.components.FlyerNativeUnderlayStack
import fr.myfidpass.ui.components.FlyerPreviewWebView
import fr.myfidpass.ui.components.ImageCropDialog
import fr.myfidpass.ui.components.ImageCropSpec
import fr.myfidpass.ui.viewmodel.ProgramFlyerEditorViewModel

/** Même ratio que le canvas HTML / iOS (`2400×3600`). */
private const val FLYER_CANVAS_ASPECT = 2400f / 3600f
private val FLYER_HERO_MAX_WIDTH = 320.dp
private val FLYER_HERO_CORNER = 20.dp

@Composable
fun MerchantProgramHubScreen(
    container: AppContainer,
    onBack: () -> Unit,
    startCreateAssistant: Boolean = false,
    openForEdit: Boolean = false,
    onFlyerSaveSuccess: () -> Unit = {},
    snackbar: SnackbarHostState? = null,
) {
    val context = LocalContext.current
    val slug = container.dashboardRepository.currentSlug()?.trim().orEmpty()
    if (slug.isEmpty()) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("Aucun commerce sélectionné")
        }
        return
    }

    val vm: ProgramFlyerEditorViewModel = viewModel(
        key = "flyer-$slug-$startCreateAssistant-$openForEdit",
        factory = ProgramFlyerEditorViewModel.factory(
            container = container,
            appContext = context,
            slug = slug,
            startCreateAssistant = startCreateAssistant,
            openForEdit = openForEdit,
        ),
    )

    var webViewRef by remember { mutableStateOf<WebView?>(null) }
    var logoCropUri by remember { mutableStateOf<Uri?>(null) }
    var bgCropUri by remember { mutableStateOf<Uri?>(null) }
    var showAiConceptDialog by remember { mutableStateOf(false) }
    var aiConceptDraft by remember { mutableStateOf("") }
    val templateKeys = remember { FlyerBackgroundTemplates.keys() }

    val pickLogo = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        logoCropUri = uri
    }
    val pickBg = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        bgCropUri = uri
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(FlyerStudioTheme.canvas),
    ) {
        Column(Modifier.fillMaxSize()) {
            FlyerHubTopBar(
                vm = vm,
                onBack = onBack,
                onSave = { vm.save { onFlyerSaveSuccess() } },
            )

            when {
                vm.isLoading && !vm.flyerHeroRevealed && vm.bootstrapPreviewBase64 == null -> {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = FlyerStudioTheme.accent)
                    }
                }
                else -> {
                    Column(Modifier.weight(1f)) {
                        Column(
                            Modifier
                                .weight(1f)
                                .verticalScroll(rememberScrollState())
                                .padding(horizontal = 16.dp)
                                .padding(bottom = 8.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            if (vm.flyerHeroRevealed && vm.isViewMode && vm.serverSnapshotWasNonDefault) {
                                Spacer(Modifier.height(4.dp))
                                FlyerViewModeHeader(
                                    onEdit = { vm.enterEditMode() },
                                    onClose = onBack,
                                    modifier = Modifier.fillMaxWidth(),
                                )
                                Spacer(Modifier.height(12.dp))
                            }

                            if (vm.flyerHeroRevealed) {
                                FlyerHeroPreview(vm, onWebViewReady = { webViewRef = it })
                                Spacer(Modifier.height(16.dp))

                                if (vm.isGenerating) {
                                    FlyerAiGenerationProgress(vm.aiProgress)
                                    Spacer(Modifier.height(12.dp))
                                }

                                if (vm.isViewMode && vm.serverSnapshotWasNonDefault && !vm.isGenerating) {
                                    FlyerViewModeUsageGuideCard(Modifier.fillMaxWidth())
                                    Spacer(Modifier.height(12.dp))
                                }

                                if (!vm.isViewMode && !vm.isGenerating) {
                                    FlyerInlineEditSection(
                                        vm = vm,
                                        templateKeys = templateKeys,
                                        onPickBg = { pickBg.launch("image/*") },
                                        onPickLogo = { pickLogo.launch("image/*") },
                                        onGenerateAi = {
                                            aiConceptDraft = vm.concept.ifBlank { vm.brandName }
                                            showAiConceptDialog = true
                                        },
                                        onApplyTemplate = { vm.applyBackgroundTemplate(context, it) },
                                    )
                                }
                            }

                            if (!vm.flyerHeroRevealed) {
                                Spacer(Modifier.height(8.dp))
                                FlyerLogoPickerCard(
                                    logoDataUrl = vm.logoPreviewDataUrl,
                                    onPickLogo = { pickLogo.launch("image/*") },
                                )
                                Spacer(Modifier.height(14.dp))
                                FlyerAccentColorsCard(
                                    selectedHex6 = vm.palettePriorityHexes.firstOrNull() ?: vm.accentHex.removePrefix("#"),
                                    onSelect = { vm.selectPaletteHex(it) },
                                )
                            }
                        }

                        Column(
                            Modifier
                                .fillMaxWidth()
                                .navigationBarsPadding()
                                .padding(horizontal = 16.dp)
                                .padding(bottom = 12.dp),
                        ) {
                            when {
                                !vm.flyerHeroRevealed -> {
                                    FlyerCreatePrimaryButton(
                                        onClick = { vm.createFlyer(context) },
                                        enabled = !vm.isGenerating,
                                        loading = vm.isGenerating,
                                    )
                                }
                                vm.isViewMode && vm.serverSnapshotWasNonDefault && !vm.isGenerating -> {
                                    FlyerDownloadBar(
                                        onDownload = {
                                            webViewRef?.let { wv ->
                                                FlyerShareHelper.shareWebViewCapture(context, wv)
                                            }
                                        },
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        (vm.saveError ?: vm.loadError)?.let { err ->
            Text(
                err,
                color = Color(0xFFFCA5A5),
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .navigationBarsPadding()
                    .padding(16.dp),
                fontSize = 13.sp,
            )
        }
    }

    if (showAiConceptDialog) {
        AlertDialog(
            onDismissRequest = { showAiConceptDialog = false },
            title = { Text("Concept visuel") },
            text = {
                OutlinedTextField(
                    value = aiConceptDraft,
                    onValueChange = { aiConceptDraft = it },
                    label = { Text("Ambiance / concept") },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 2,
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        vm.concept = aiConceptDraft
                        showAiConceptDialog = false
                        vm.generateFlyer()
                    },
                ) { Text("Générer") }
            },
            dismissButton = {
                TextButton(onClick = { showAiConceptDialog = false }) { Text("Annuler") }
            },
        )
    }

    logoCropUri?.let { uri ->
        ImageCropDialog(
            uri = uri,
            spec = ImageCropSpec.FLYER_PROMO_LOGO,
            visible = true,
            onDismiss = { logoCropUri = null },
            onCropped = { dataUrl ->
                vm.setLogoDataUrl(dataUrl)
                logoCropUri = null
            },
        )
    }
    bgCropUri?.let { uri ->
        ImageCropDialog(
            uri = uri,
            spec = ImageCropSpec.FLYER_CUSTOM_BACKGROUND,
            visible = true,
            onDismiss = { bgCropUri = null },
            onCropped = { dataUrl ->
                vm.setBackgroundDataUrl(dataUrl)
                vm.selectedBackgroundTemplateKey = null
                bgCropUri = null
            },
        )
    }
}

@Composable
private fun FlyerHubTopBar(
    vm: ProgramFlyerEditorViewModel,
    onBack: () -> Unit,
    onSave: () -> Unit,
) {
    RowTopBar(
        vm = vm,
        onBack = {
            if (vm.flyerHeroRevealed && !vm.isViewMode && vm.canUndo) {
                onBack()
            } else if (vm.flyerHeroRevealed && !vm.isViewMode && vm.serverSnapshotWasNonDefault) {
                vm.exitEditModeToView()
            } else {
                onBack()
            }
        },
        onSave = onSave,
    )
}

@Composable
private fun RowTopBar(
    vm: ProgramFlyerEditorViewModel,
    onBack: () -> Unit,
    onSave: () -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = onBack) {
            Icon(
                if (vm.flyerHeroRevealed) Icons.AutoMirrored.Filled.ArrowBack else Icons.Default.Close,
                contentDescription = "Retour",
                tint = FlyerStudioTheme.textPrimary.copy(0.85f),
            )
        }
        Spacer(Modifier.weight(1f))
        if (vm.flyerHeroRevealed && !vm.isViewMode) {
            TextButton(onClick = onSave, enabled = !vm.isSaving) {
                if (vm.isSaving) {
                    CircularProgressIndicator(
                        color = FlyerStudioTheme.textPrimary,
                        modifier = Modifier.height(18.dp).padding(end = 4.dp),
                        strokeWidth = 2.dp,
                    )
                }
                Text(
                    "Sauvegarder",
                    color = FlyerStudioTheme.textPrimary,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }
}

@Composable
private fun FlyerInlineEditSection(
    vm: ProgramFlyerEditorViewModel,
    templateKeys: List<String>,
    onPickBg: () -> Unit,
    onPickLogo: () -> Unit,
    onGenerateAi: () -> Unit,
    onApplyTemplate: (String) -> Unit,
) {
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.Start) {
        FlyerBackgroundCarousel(
            vm = vm,
            templateKeys = templateKeys,
            onPickCustomBg = onPickBg,
            onGenerateAi = onGenerateAi,
            onApplyTemplate = onApplyTemplate,
        )
        Spacer(Modifier.height(14.dp))

        if (vm.nativeBgDataUrl == null) {
            Text(
                "Couleur du fond",
                color = FlyerStudioTheme.textSecondary,
                fontWeight = FontWeight.SemiBold,
                fontSize = 12.sp,
            )
            Spacer(Modifier.height(8.dp))
            FlyerAccentPaletteRow(
                selectedHex6 = vm.state.colorBgBottom.removePrefix("#"),
                onSelect = { hex ->
                    val norm = "#$hex"
                    vm.updateStringField {
                        it.copy(colorBgTop = norm, colorBgBottom = norm, colorPrimary = norm)
                    }
                },
            )
            Spacer(Modifier.height(14.dp))
        }

        Text(
            "Couleur « CADEAU ! » + pastille + roue",
            color = FlyerStudioTheme.textSecondary,
            fontWeight = FontWeight.SemiBold,
            fontSize = 12.sp,
        )
        Spacer(Modifier.height(8.dp))
        FlyerAccentPaletteRow(
            selectedHex6 = vm.state.ctaBannerBgColor.removePrefix("#"),
            onSelect = { vm.applyFullFlyerAccentFromWheelPalette("#$it") },
        )
        Spacer(Modifier.height(14.dp))
        FlyerInlineLogoSection(vm = vm, onPickLogo = onPickLogo)
    }
}

@Composable
private fun FlyerHeroPreview(
    vm: ProgramFlyerEditorViewModel,
    onWebViewReady: (WebView) -> Unit,
    modifier: Modifier = Modifier,
) {
    BoxWithConstraints(
        modifier.fillMaxWidth(),
        contentAlignment = Alignment.TopCenter,
    ) {
        val previewWidth = minOf(maxWidth, FLYER_HERO_MAX_WIDTH)
        Box(
            Modifier
                .width(previewWidth)
                .aspectRatio(FLYER_CANVAS_ASPECT)
                .shadow(16.dp, RoundedCornerShape(FLYER_HERO_CORNER), clip = false)
                .clip(RoundedCornerShape(FLYER_HERO_CORNER))
                .background(Color.White),
        ) {
            FlyerNativeUnderlayStack(
                state = vm.state,
                customBgDataUrl = vm.nativeBgDataUrl,
                modifier = Modifier.fillMaxSize(),
            )
            FlyerPreviewWebView(
                url = BuildConfig.FLYER_EMBED_URL,
                bootstrapBase64 = vm.bootstrapPreviewBase64,
                onWebViewReady = onWebViewReady,
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}
