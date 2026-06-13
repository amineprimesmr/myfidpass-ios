package fr.myfidpass.ui.screens.tabs

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
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
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.draw.alpha
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
    val animatedProgress by animateFloatAsState(
        targetValue = progress.coerceIn(0f, 1f),
        animationSpec = tween(durationMillis = 380),
        label = "notificationSendProgress",
    )
    Box(
        modifier
            .fillMaxWidth()
            .height(5.dp)
            .background(Color(0xFF1C1C1E)),
    ) {
        Box(
            Modifier
                .fillMaxWidth(animatedProgress)
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
            .background(Color.Black, RoundedCornerShape(corner))
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
                            if (!sending && !success) {
                                drawBorderBeamStroke(size, phase, size.height / 2f, beamColors)
                            }
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
                    when {
                        success ->
                            Icon(
                                Icons.Default.Check,
                                contentDescription = "Envoyé",
                                tint = Color.White,
                                modifier = Modifier.size(18.dp),
                            )
                        sending ->
                            CircularProgressIndicator(
                                modifier = Modifier.size(18.dp),
                                strokeWidth = 2.dp,
                                color = Color.White,
                            )
                        else ->
                            Icon(
                                Icons.Default.ArrowUpward,
                                contentDescription = "Envoyer",
                                tint = if (sendEnabled) Color.White else Color.White.copy(0.5f),
                                modifier = Modifier.size(18.dp),
                            )
                    }
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
    disabledTextColor = Color.White.copy(alpha = 0.45f),
    disabledPlaceholderColor = Color.White.copy(alpha = 0.28f),
    cursorColor = Color.White,
    focusedContainerColor = Color.Transparent,
    unfocusedContainerColor = Color.Transparent,
    disabledContainerColor = Color.Transparent,
    focusedIndicatorColor = Color.Transparent,
    unfocusedIndicatorColor = Color.Transparent,
    disabledIndicatorColor = Color.Transparent,
)

@Composable
fun NotificationsPerimeterFooter(
    perimeterMessage: String,
    onPerimeterMessageChange: (String) -> Unit,
    hasCustomIcon: Boolean,
    logoUrl: String?,
    authToken: String?,
    onEditingChanged: (Boolean) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    WalletNotificationPreviewBlock(
        notificationTitle = "Vous êtes tout près",
        message = perimeterMessage,
        onMessageChange = onPerimeterMessageChange,
        logoUrl = logoUrl,
        authToken = authToken,
        messagePlaceholder = "Message à proximité du magasin…",
        onEditingChanged = onEditingChanged,
        modifier = modifier.then(
            if (hasCustomIcon) Modifier else Modifier.alpha(0.55f),
        ),
        previewSize = WalletNotificationPreviewSize.Standard,
        lightGlassSurface = true,
    )
}


