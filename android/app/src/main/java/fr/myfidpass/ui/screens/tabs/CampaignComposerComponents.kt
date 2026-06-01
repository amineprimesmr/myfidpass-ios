package fr.myfidpass.ui.screens.tabs

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.data.dto.CampaignAutomationConfigDto
import fr.myfidpass.ui.components.PerimeterMapView
import fr.myfidpass.data.dto.CampaignAutomationRuleDto
import fr.myfidpass.data.dto.CampaignRuleSpec
import fr.myfidpass.data.dto.automationHubRules
import fr.myfidpass.data.dto.defaultAutomationRuleMessages
import fr.myfidpass.data.dto.mergedAutomationRules
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale

val manualSegmentChoices: Map<String, String> = mapOf(
    "inactive14" to "Client inactif +14 jours",
    "recurrent" to "Clients fidèles (+10 visites par mois)",
)

val manualSegmentDefaultMessages: Map<String, String> = mapOf(
    "inactive14" to "Ça fait un moment... Revenez nous voir aujourd'hui et profitez de -10 %.",
    "recurrent" to "Offre pour nos clients les plus assidus ce mois-ci.",
)

@Composable
fun NotificationSendTopProgressStrip(progress: Float, modifier: Modifier = Modifier) {
    Box(
        modifier
            .fillMaxWidth()
            .height(5.dp)
            .background(Color(0xFF1C1C1E)),
    ) {
        Box(
            Modifier
                .fillMaxWidth(progress.coerceIn(0f, 1f))
                .height(5.dp)
                .background(Color.White),
        )
    }
}

/** Composer manuel — aligné iOS `BorderBeamManualNotificationComposerView` (thème sombre + beam). */
@Composable
fun BorderBeamNotificationComposer(
    title: String,
    message: String,
    onTitleChange: (String) -> Unit,
    onMessageChange: (String) -> Unit,
    selectedSegment: String?,
    onSegmentSelected: (String?) -> Unit,
    onSend: () -> Unit,
    sending: Boolean,
    sendEnabled: Boolean,
    sendSuccessCount: Int? = null,
    modifier: Modifier = Modifier,
) {
    val infinite = rememberInfiniteTransition(label = "beam")
    val phase by infinite.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(2500, easing = LinearEasing), RepeatMode.Restart),
        label = "phase",
    )
    var segmentMenuOpen by remember { mutableStateOf(false) }
    var messagePlaceholderIndex by remember { mutableIntStateOf(0) }
    val titlePlaceholderLabel = "Titre du message"
    val messagePlaceholderFull = "Écrivez votre message"
    val corner = 20.dp
    val beamColors = listOf(
        Color(0xFF22C55E),
        Color(0xFF2563EB),
        Color(0xFFEC4899),
        Color(0xFFF97316),
        Color(0xFF6366F1),
    )

    LaunchedEffect(message) {
        if (message.isNotBlank()) {
            messagePlaceholderIndex = 0
            return@LaunchedEffect
        }
        while (true) {
            for (i in 0..messagePlaceholderFull.length) {
                messagePlaceholderIndex = i
                kotlinx.coroutines.delay(48)
            }
            kotlinx.coroutines.delay(900)
        }
    }

    LaunchedEffect(selectedSegment) {
        val key = selectedSegment ?: return@LaunchedEffect
        if (message.isBlank()) {
            manualSegmentDefaultMessages[key]?.let { onMessageChange(it) }
        }
    }

    Box(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(corner))
            .drawBehind {
                drawBorderBeamStroke(size, phase, corner.toPx(), beamColors)
            }
            .background(Color(0xFF1C1C1E).copy(alpha = 0.92f), RoundedCornerShape(corner))
            .padding(15.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Box(Modifier.fillMaxWidth()) {
                TextField(
                    value = title,
                    onValueChange = onTitleChange,
                    placeholder = {
                        Text(titlePlaceholderLabel, color = Color.White.copy(0.42f))
                    },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    colors = darkFieldColors(),
                )
            }
            Box(Modifier.fillMaxWidth()) {
                TextField(
                    value = message,
                    onValueChange = { onMessageChange(it.replace("\n", "")) },
                    placeholder = {
                        if (message.isBlank()) {
                            Text(messagePlaceholderFull.take(messagePlaceholderIndex), color = Color.White.copy(0.42f))
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 3,
                    colors = darkFieldColors(),
                )
            }
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                val segmentLabel = selectedSegment?.let { manualSegmentChoices[it] ?: "Tous les clients" } ?: "Tous les clients"
                Box {
                    Box(
                        Modifier
                            .height(35.dp)
                            .clip(RoundedCornerShape(999.dp))
                            .drawBehind {
                                drawBorderBeamStroke(size, phase, size.height / 2f, beamColors)
                            }
                            .background(Color(0xFF2C2C2E))
                            .clickable { segmentMenuOpen = true }
                            .padding(horizontal = 12.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(
                                segmentLabel,
                                color = Color.White,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 12.sp,
                                maxLines = 1,
                            )
                            Icon(
                                Icons.Default.KeyboardArrowDown,
                                contentDescription = null,
                                tint = Color.White.copy(0.85f),
                                modifier = Modifier.size(16.dp),
                            )
                        }
                    }
                    DropdownMenu(expanded = segmentMenuOpen, onDismissRequest = { segmentMenuOpen = false }) {
                        DropdownMenuItem(
                            text = { Text("Tous les clients") },
                            onClick = { onSegmentSelected(null); segmentMenuOpen = false },
                        )
                        manualSegmentChoices.forEach { (k, label) ->
                            DropdownMenuItem(
                                text = { Text(label) },
                                onClick = { onSegmentSelected(k); segmentMenuOpen = false },
                            )
                        }
                    }
                }
                Spacer(Modifier.weight(1f))
                val success = sendSuccessCount != null
                Box(
                    Modifier
                        .size(35.dp)
                        .clip(RoundedCornerShape(999.dp))
                        .drawBehind {
                            drawBorderBeamStroke(size, phase, size.height / 2f, beamColors)
                        }
                        .background(
                            when {
                                success -> Color(0xFF22C55E)
                                sendEnabled -> Color(0xFF2C2C2E)
                                else -> Color(0xFF2C2C2E).copy(alpha = 0.45f)
                            },
                        )
                        .clickable(enabled = sendEnabled && !sending && !success) { onSend() },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        if (success || sending) Icons.Default.Check else Icons.Default.ArrowUpward,
                        contentDescription = "Envoyer",
                        tint = if (success) Color.White else if (sendEnabled) Color.White else Color.White.copy(0.5f),
                        modifier = Modifier.size(18.dp),
                    )
                }
            }
        }
    }
}

private fun DrawScope.drawBorderBeamStroke(
    size: Size,
    phase: Float,
    cornerRadiusPx: Float,
    colors: List<Color>,
) {
    drawRoundRect(
        brush = Brush.sweepGradient(
            colors,
            center = Offset(size.width * phase, size.height * 0.5f),
        ),
        size = size,
        cornerRadius = CornerRadius(cornerRadiusPx),
        style = Stroke(1.5f),
    )
}

@Composable
private fun darkFieldColors() = TextFieldDefaults.colors(
    focusedTextColor = Color.White,
    unfocusedTextColor = Color.White,
    cursorColor = Color(0xFF2563EB),
    focusedContainerColor = Color.Transparent,
    unfocusedContainerColor = Color.Transparent,
    focusedIndicatorColor = Color.Transparent,
    unfocusedIndicatorColor = Color.Transparent,
)

private val AutomationHubCarouselSlideBg = Color.White
private val AutomationHubCarouselSlideBorder = Color.Black.copy(alpha = 0.07f)
private val AutomationHubHeaderSubtitleMinHeight = 30.dp
private val AutomationHubSlideContentHeight = 228.dp
private val AutomationHubInnerPadding = 12.dp
private val AutomationHubOuterHorizontalPadding = 10.dp
private val AutomationHubPageIndicatorSlotWidth = 18.dp
private val AutomationHubPageIndicatorHeight = 5.dp

private sealed interface AutomationHubCarouselPage {
    data class HubRule(val id: String) : AutomationHubCarouselPage
    data class CustomRule(val id: String) : AutomationHubCarouselPage
    data object Programming : AutomationHubCarouselPage
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun AutomationHubCarousel(
    automation: CampaignAutomationConfigDto?,
    ruleMessages: Map<String, String>,
    notificationIconUrl: String?,
    authToken: String?,
    perimeterMessage: String,
    onPerimeterMessageChange: (String) -> Unit,
    onRuleMessageChange: (ruleId: String, message: String) -> Unit,
    onToggle: (ruleId: String, enabled: Boolean) -> Unit,
    onOpenPerimeter: () -> Unit,
    locationLat: Double? = null,
    locationLng: Double? = null,
    locationRadiusMeters: Int = 100,
    hasCustomIcon: Boolean,
    onAddEventProgramming: () -> Unit,
    onEditEventProgramming: (ruleId: String) -> Unit,
    onDeleteEventProgramming: (ruleId: String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val merged = remember(automation, ruleMessages) { mergedAutomationRules(automation) }
    val customIds = automation?.rules?.keys?.filter { it.startsWith("custom_") }?.sorted().orEmpty()
    val eventIds = automation?.rules?.keys
        ?.filter { it.startsWith("event_") }
        ?.filter { id ->
            val et = automation.rules?.get(id)?.eventType?.trim()?.lowercase().orEmpty()
            et != "member_created"
        }
        ?.sorted()
        .orEmpty()
    val pages: List<AutomationHubCarouselPage> = buildList {
        addAll(automationHubRules.map { AutomationHubCarouselPage.HubRule(it.id) })
        addAll(customIds.map { AutomationHubCarouselPage.CustomRule(it) })
        add(AutomationHubCarouselPage.Programming)
    }
    val pagerState = rememberPagerState(pageCount = { pages.size })

    fun headerTitle(page: Int): String = when (val p = pages.getOrNull(page)) {
        is AutomationHubCarouselPage.HubRule -> {
            if (p.id == "locationEntry") "Automatisations"
            else automationHubRules.firstOrNull { it.id == p.id }?.title ?: "Automatisations"
        }
        is AutomationHubCarouselPage.CustomRule -> {
            automation?.rules?.get(p.id)?.title?.trim().orEmpty()
                .ifBlank { "Automatisation personnalisée" }
        }
        AutomationHubCarouselPage.Programming -> "Notification automatique"
        null -> "Automatisations"
    }

    fun headerSubtitle(page: Int): String? = when (val p = pages.getOrNull(page)) {
        is AutomationHubCarouselPage.HubRule -> {
            if (p.id == "locationEntry") {
                "Notification quand le client entre dans votre périmètre Wallet."
            } else {
                val spec = automationHubRules.firstOrNull { it.id == p.id }
                spec?.timingCaption?.ifBlank { spec.subtitle } ?: spec?.subtitle
            }
        }
        is AutomationHubCarouselPage.CustomRule -> {
            val seg = automation?.rules?.get(p.id)?.segment.orEmpty()
            val label = segmentKeyLabels[seg] ?: seg
            "Segment « $label » — envoi automatique côté serveur."
        }
        AutomationHubCarouselPage.Programming ->
            "Rappel à une date précise ou chaque jour à la même heure."
        null -> null
    }

    Column(
        modifier
            .fillMaxWidth()
            .padding(horizontal = AutomationHubOuterHorizontalPadding, vertical = 2.dp),
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .shadow(
                    elevation = 3.dp,
                    shape = RoundedCornerShape(14.dp),
                    spotColor = Color.Black.copy(alpha = 0.06f),
                )
                .clip(RoundedCornerShape(14.dp))
                .background(AutomationHubCarouselSlideBg)
                .border(1.dp, AutomationHubCarouselSlideBorder, RoundedCornerShape(14.dp))
                .padding(AutomationHubInnerPadding),
        ) {
            Text(
                headerTitle(pagerState.currentPage),
                fontWeight = FontWeight.SemiBold,
                style = MaterialTheme.typography.titleSmall,
                minLines = 1,
                maxLines = 1,
            )
            Box(
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = AutomationHubHeaderSubtitleMinHeight),
            ) {
                headerSubtitle(pagerState.currentPage)?.let { sub ->
                    Text(
                        sub,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        lineHeight = MaterialTheme.typography.bodySmall.lineHeight * 1.08f,
                        maxLines = 2,
                        modifier = Modifier.align(Alignment.TopStart),
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
            HorizontalPager(
                state = pagerState,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(AutomationHubSlideContentHeight),
                pageSpacing = 0.dp,
            ) { pageIndex ->
                Box(
                    Modifier
                        .fillMaxSize()
                        .clipToBounds(),
                ) {
                    when (val page = pages[pageIndex]) {
                is AutomationHubCarouselPage.HubRule -> {
                    val ruleId = page.id
                    val spec = automationHubRules.firstOrNull { it.id == ruleId }
                    val rule = merged[ruleId]
                    val msg = ruleMessages[ruleId]?.ifBlank { rule?.message.orEmpty() }
                        ?: rule?.message.orEmpty().ifBlank { defaultAutomationRuleMessages[ruleId].orEmpty() }
                    if (spec?.id == "locationEntry") {
                        LocationEntryHubPage(
                            message = perimeterMessage.ifBlank { msg },
                            onMessageChange = onPerimeterMessageChange,
                            enabled = rule?.enabled == true && hasCustomIcon,
                            onToggle = { onToggle("locationEntry", rule?.enabled != true) },
                            onOpenPerimeter = onOpenPerimeter,
                            locationLat = locationLat,
                            locationLng = locationLng,
                            locationRadiusMeters = locationRadiusMeters,
                            notificationIconUrl = notificationIconUrl,
                            authToken = authToken,
                        )
                    } else if (spec != null) {
                        StandardAutomationHubPage(
                            spec = spec,
                            message = msg,
                            onMessageChange = { onRuleMessageChange(ruleId, it) },
                            enabled = rule?.enabled == true && hasCustomIcon,
                            onToggle = { onToggle(ruleId, rule?.enabled != true) },
                            notificationIconUrl = notificationIconUrl,
                            authToken = authToken,
                        )
                    }
                }
                is AutomationHubCarouselPage.CustomRule -> {
                    val ruleId = page.id
                    val rule = merged[ruleId]
                    val msg = ruleMessages[ruleId]?.ifBlank { rule?.message.orEmpty() }
                        ?: rule?.message.orEmpty()
                    CustomRuleHubPage(
                        ruleId = ruleId,
                        message = msg,
                        onMessageChange = { onRuleMessageChange(ruleId, it) },
                        enabled = rule?.enabled == true,
                        onToggle = { onToggle(ruleId, rule?.enabled != true) },
                        notificationIconUrl = notificationIconUrl,
                        authToken = authToken,
                    )
                }
                AutomationHubCarouselPage.Programming -> {
                    EventProgrammingCarouselPage(
                        eventIds = eventIds,
                        automation = automation,
                        notificationIconUrl = notificationIconUrl,
                        authToken = authToken,
                        onAdd = onAddEventProgramming,
                        onEdit = onEditEventProgramming,
                        onDelete = onDeleteEventProgramming,
                    )
                }
                    }
                }
            }
            Spacer(Modifier.height(8.dp))
            Row(
                Modifier
                    .fillMaxWidth()
                    .height(AutomationHubPageIndicatorHeight),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
            repeat(pages.size) { i ->
                val active = i == pagerState.currentPage
                Box(
                    Modifier
                        .padding(horizontal = 4.dp)
                        .width(AutomationHubPageIndicatorSlotWidth)
                        .height(AutomationHubPageIndicatorHeight),
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        Modifier
                            .width(if (active) AutomationHubPageIndicatorSlotWidth else 6.dp)
                            .height(AutomationHubPageIndicatorHeight)
                            .clip(RoundedCornerShape(999.dp))
                            .background(
                                if (active) Color(0xFF2563EB)
                                else Color.Black.copy(alpha = 0.18f),
                            ),
                    )
                }
            }
            }
        }
    }
}

@Composable
private fun StandardAutomationHubPage(
    spec: CampaignRuleSpec,
    message: String,
    onMessageChange: (String) -> Unit,
    enabled: Boolean,
    onToggle: () -> Unit,
    notificationIconUrl: String?,
    authToken: String?,
) {
    Column(
        Modifier
            .fillMaxSize()
            .fillMaxWidth(),
    ) {
        WalletNotificationPreviewBlock(
            notificationTitle = spec.notificationPreviewTitle ?: spec.title,
            message = message,
            onMessageChange = onMessageChange,
            logoUrl = notificationIconUrl,
            authToken = authToken,
            messagePlaceholder = "Tapez le message…",
            previewSize = WalletNotificationPreviewSize.Standard,
            footer = { AutomationToggleRow(enabled, onToggle) },
        )
    }
}

@Composable
private fun LocationEntryHubPage(
    message: String,
    onMessageChange: (String) -> Unit,
    enabled: Boolean,
    onToggle: () -> Unit,
    onOpenPerimeter: () -> Unit,
    locationLat: Double?,
    locationLng: Double?,
    locationRadiusMeters: Int,
    notificationIconUrl: String?,
    authToken: String?,
) {
    Box(
        Modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(18.dp)),
    ) {
        PerimeterMapView(
            latitude = locationLat,
            longitude = locationLng,
            radiusMeters = locationRadiusMeters,
            showMapChrome = false,
            modifier = Modifier
                .fillMaxSize()
                .clickable(onClick = onOpenPerimeter),
        )
        WalletNotificationPreviewBlock(
            notificationTitle = "Vous êtes tout près",
            message = message,
            onMessageChange = onMessageChange,
            logoUrl = notificationIconUrl,
            authToken = authToken,
            messagePlaceholder = "Message à proximité du magasin…",
            previewSize = WalletNotificationPreviewSize.Standard,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(horizontal = 8.dp, vertical = 8.dp),
        )
    }
}

@Composable
private fun CustomRuleHubPage(
    ruleId: String,
    message: String,
    onMessageChange: (String) -> Unit,
    enabled: Boolean,
    onToggle: () -> Unit,
    notificationIconUrl: String?,
    authToken: String?,
) {
    Column(
        Modifier
            .fillMaxSize()
            .fillMaxWidth(),
    ) {
        WalletNotificationPreviewBlock(
            notificationTitle = "Message programmé",
            message = message,
            onMessageChange = onMessageChange,
            logoUrl = notificationIconUrl,
            authToken = authToken,
            messagePlaceholder = "Message pour ce groupe…",
            previewSize = WalletNotificationPreviewSize.Standard,
            footer = { AutomationToggleRow(enabled, onToggle) },
        )
    }
}

@Composable
private fun AutomationToggleRow(enabled: Boolean, onToggle: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(top = 2.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            if (enabled) "Activé" else "Activer",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Switch(
            checked = enabled,
            onCheckedChange = { onToggle() },
            modifier = Modifier.scale(0.88f),
        )
    }
}

@Composable
private fun EventProgrammingCarouselPage(
    eventIds: List<String>,
    automation: CampaignAutomationConfigDto?,
    notificationIconUrl: String?,
    authToken: String?,
    onAdd: () -> Unit,
    onEdit: (ruleId: String) -> Unit,
    onDelete: (ruleId: String) -> Unit,
) {
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
        ) {
            OutlinedButton(onClick = onAdd) {
                Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(4.dp))
                Text("Nouvelle notification")
            }
        }
        if (eventIds.isNotEmpty()) {
            Spacer(Modifier.height(12.dp))
            Column(Modifier.fillMaxWidth()) {
                eventIds.forEach { id ->
                    val rule = automation?.rules?.get(id)
                    EventProgrammingRow(
                        ruleId = id,
                        rule = rule,
                        notificationIconUrl = notificationIconUrl,
                        authToken = authToken,
                        onEdit = { onEdit(id) },
                        onDelete = { onDelete(id) },
                    )
                    Spacer(Modifier.height(10.dp))
                }
            }
        }
    }
}

@Composable
private fun EventProgrammingRow(
    ruleId: String,
    rule: CampaignAutomationRuleDto?,
    notificationIconUrl: String?,
    authToken: String?,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    val schedule = readableEventLabel(rule?.eventType, rule?.delayMinutes)
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Color(0xFFF8FAFC))
            .clickable(onClick = onEdit)
            .padding(12.dp),
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(rule?.title?.ifBlank { ruleId } ?: ruleId, fontWeight = FontWeight.SemiBold)
            IconButton(onClick = onDelete) {
                Icon(Icons.Default.Delete, contentDescription = "Supprimer", tint = MaterialTheme.colorScheme.error)
            }
        }
        Text(schedule, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(8.dp))
        WalletNotificationPreviewBlock(
            notificationTitle = eventPreviewTitle(rule?.eventType),
            message = rule?.message.orEmpty(),
            onMessageChange = {},
            logoUrl = notificationIconUrl,
            authToken = authToken,
            previewSize = WalletNotificationPreviewSize.Standard,
        )
    }
}

fun readableEventLabel(eventType: String?, delayMinutes: Int?): String {
    val et = eventType.orEmpty()
    val delay = delayMinutes?.takeIf { it > 0 }?.let { "+$it min" }.orEmpty()
    return when {
        et.startsWith("daily_at:") -> {
            val parts = et.removePrefix("daily_at:").split(":")
            "Chaque jour à ${parts.getOrNull(0).orEmpty()}h${parts.getOrNull(1).orEmpty()} $delay".trim()
        }
        et.startsWith("once_at:") -> "Une fois — ${et.removePrefix("once_at:")} $delay".trim()
        et.contains("inactive") -> "Inactif depuis Nj $delay".trim()
        et == "member_created" -> "Carte ajoutée $delay".trim()
        et == "first_scan" -> "Premier scan $delay".trim()
        et == "reward_unlocked" -> "Récompense débloquée $delay".trim()
        else -> "Message programmé $delay".trim()
    }
}

fun eventPreviewTitle(eventType: String?): String = when {
    eventType == null -> "Message programmé"
    eventType.contains("welcome", ignoreCase = true) || eventType == "member_created" -> "Bienvenue"
    eventType.contains("reward", ignoreCase = true) -> "Récompense débloquée"
    eventType.contains("inactive", ignoreCase = true) -> "Ça fait un moment"
    eventType.startsWith("daily_at:") -> "Rappel du jour"
    else -> "Notification"
}

enum class ScheduleKind { ONE_TIME, DAILY }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EventAutomationEditorSheet(
    editingRuleId: String?,
    initialTitle: String,
    initialMessage: String,
    initialEventType: String,
    initialDelayMinutes: Int,
    onDismiss: () -> Unit,
    onSave: (ruleId: String, title: String, message: String, eventType: String, delayMinutes: Int) -> Unit,
) {
    var title by remember(editingRuleId) { mutableStateOf(initialTitle) }
    var message by remember(editingRuleId) { mutableStateOf(initialMessage) }
    var delayMinutes by remember(editingRuleId) { mutableIntStateOf(initialDelayMinutes.coerceIn(1, 120)) }
    var scheduleKind by remember(editingRuleId) {
        mutableStateOf(if (initialEventType.startsWith("daily_at:")) ScheduleKind.DAILY else ScheduleKind.ONE_TIME)
    }
    var hour by remember(editingRuleId) {
        mutableIntStateOf(initialEventType.removePrefix("daily_at:").split(":").getOrNull(0)?.toIntOrNull() ?: 9)
    }
    var minute by remember(editingRuleId) {
        mutableIntStateOf(initialEventType.removePrefix("daily_at:").split(":").getOrNull(1)?.toIntOrNull() ?: 0)
    }
    var oneShotMillis by remember(editingRuleId) { mutableStateOf(System.currentTimeMillis()) }
    var showDatePicker by remember { mutableStateOf(false) }
    var showTimePicker by remember { mutableStateOf(false) }

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(Modifier.padding(20.dp)) {
            Text(
                if (editingRuleId == null) "Programmation" else "Modifier",
                fontWeight = FontWeight.Bold,
                style = MaterialTheme.typography.titleLarge,
            )
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(title, { title = it }, label = { Text("Nom") }, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(onClick = { scheduleKind = ScheduleKind.ONE_TIME }) {
                    Text(if (scheduleKind == ScheduleKind.ONE_TIME) "● Une date" else "Une date")
                }
                OutlinedButton(onClick = { scheduleKind = ScheduleKind.DAILY }) {
                    Text(if (scheduleKind == ScheduleKind.DAILY) "● Chaque jour" else "Chaque jour")
                }
            }
            Spacer(Modifier.height(8.dp))
            if (scheduleKind == ScheduleKind.ONE_TIME) {
                OutlinedButton(onClick = { showDatePicker = true }, modifier = Modifier.fillMaxWidth()) {
                    Text("Date et heure")
                }
            } else {
                Text("Heure : ${hour.toString().padStart(2, '0')}h${minute.toString().padStart(2, '0')}")
                Row {
                    OutlinedButton(onClick = { showTimePicker = true }) { Text("Choisir l'heure") }
                }
            }
            Spacer(Modifier.height(8.dp))
            Text("+${delayMinutes} min après l'instant")
            androidx.compose.material3.Slider(
                value = delayMinutes.toFloat(),
                onValueChange = { delayMinutes = it.toInt() },
                valueRange = 1f..120f,
                steps = 118,
            )
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                message,
                { message = it.take(200) },
                label = { Text("Message") },
                modifier = Modifier.fillMaxWidth(),
                minLines = 3,
            )
            Text("${message.length}/200", style = MaterialTheme.typography.labelSmall)
            Spacer(Modifier.height(8.dp))
            Text(
                "Heure stockée en UTC (fuseau de l'appareil). Tous les membres avec la carte.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(16.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                TextButton(onClick = onDismiss, modifier = Modifier.weight(1f)) { Text("Annuler") }
                Button(
                    onClick = {
                        val eventType = when (scheduleKind) {
                            ScheduleKind.DAILY -> {
                                val utc = java.time.LocalTime.of(hour, minute).atDate(java.time.LocalDate.now())
                                    .atZone(java.time.ZoneId.systemDefault()).withZoneSameInstant(ZoneOffset.UTC)
                                "daily_at:${utc.hour}:${utc.minute}"
                            }
                            ScheduleKind.ONE_TIME -> {
                                val inst = Instant.ofEpochMilli(oneShotMillis).atZone(ZoneOffset.UTC)
                                "once_at:${inst.format(DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm"))}"
                            }
                        }
                        val id = editingRuleId ?: "event_${System.currentTimeMillis()}"
                        onSave(id, title.trim(), message.trim(), eventType, delayMinutes)
                        onDismiss()
                    },
                    modifier = Modifier.weight(1f),
                    enabled = message.isNotBlank(),
                ) { Text("Enregistrer") }
            }
            Spacer(Modifier.height(24.dp))
        }
    }

    if (showDatePicker) {
        val state = rememberDatePickerState(initialSelectedDateMillis = oneShotMillis)
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let { oneShotMillis = it }
                    showDatePicker = false
                    showTimePicker = true
                }) { Text("OK") }
            },
        ) { DatePicker(state = state) }
    }
    if (showTimePicker) {
        val tState = rememberTimePickerState(
            initialHour = java.time.Instant.ofEpochMilli(oneShotMillis).atZone(java.time.ZoneId.systemDefault()).hour,
            initialMinute = java.time.Instant.ofEpochMilli(oneShotMillis).atZone(java.time.ZoneId.systemDefault()).minute,
        )
        AlertDialog(
            onDismissRequest = { showTimePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    val z = java.time.Instant.ofEpochMilli(oneShotMillis).atZone(java.time.ZoneId.systemDefault())
                    oneShotMillis = z.withHour(tState.hour).withMinute(tState.minute).toInstant().toEpochMilli()
                    showTimePicker = false
                }) { Text("OK") }
            },
            text = { TimePicker(state = tState) },
        )
    }
}

@Composable
fun ProUnlockTeaserButton(onUnlock: () -> Unit, modifier: Modifier = Modifier) {
    Button(
        onClick = onUnlock,
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(999.dp),
        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0A0A0A)),
    ) {
        Text("Débloquer avec Pro", fontWeight = FontWeight.SemiBold)
    }
}
