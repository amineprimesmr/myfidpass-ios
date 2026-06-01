package fr.myfidpass.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import kotlin.math.roundToInt

/** Glisser pour confirmer — aligné iOS `SlideToConfirm`. */
@Composable
fun SlideToConfirm(
    label: String,
    modifier: Modifier = Modifier,
    tint: Color = MaterialTheme.colorScheme.primary,
    enabled: Boolean = true,
    onConfirmed: () -> Unit,
) {
    var dragPx by remember { mutableFloatStateOf(0f) }
    var completed by remember { mutableStateOf(false) }
    val trackHeight = 52.dp

    BoxWithConstraints(
        modifier = modifier
            .fillMaxWidth()
            .height(trackHeight),
    ) {
        val knobPx = with(LocalDensity.current) { trackHeight.toPx() }
        val maxDrag = (constraints.maxWidth - knobPx).coerceAtLeast(0f)
        val progress by animateFloatAsState(
            if (completed) 1f else if (maxDrag > 0f) (dragPx / maxDrag).coerceIn(0f, 1f) else 0f,
            label = "slideProgress",
        )

        Box(
            Modifier
                .matchParentSize()
                .clip(RoundedCornerShape(50))
                .background(Color.Black.copy(alpha = 0.08f)),
        )
        Box(
            Modifier
                .fillMaxHeight()
                .fillMaxWidth(progress.coerceAtLeast(0.01f))
                .clip(RoundedCornerShape(50))
                .background(tint.copy(alpha = 0.35f)),
        )
        Text(
            label,
            modifier = Modifier.align(Alignment.Center),
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.65f),
        )
        Box(
            Modifier
                .offset {
                    IntOffset(
                        if (completed) maxDrag.roundToInt() else dragPx.roundToInt(),
                        0,
                    )
                }
                .size(trackHeight)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.surface)
                .then(
                    if (!enabled || completed) {
                        Modifier
                    } else {
                        Modifier.pointerInput(maxDrag) {
                            detectHorizontalDragGestures(
                                onDragEnd = {
                                    if (dragPx >= maxDrag * 0.92f) {
                                        dragPx = maxDrag
                                        completed = true
                                        onConfirmed()
                                    } else {
                                        dragPx = 0f
                                    }
                                },
                                onHorizontalDrag = { _, delta ->
                                    dragPx = (dragPx + delta).coerceIn(0f, maxDrag)
                                },
                            )
                        }
                    },
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                if (progress > 0.85f || completed) Icons.Default.Check else Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = tint,
            )
        }
    }
}
