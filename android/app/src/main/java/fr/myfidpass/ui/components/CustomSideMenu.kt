package fr.myfidpass.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

private val SideMenuWidth = 280.dp

/** Panneau latéral coulissant — aligné iOS `CustomSideMenu`. */
@Composable
fun CustomSideMenu(
    isExpanded: Boolean,
    onExpandedChange: (Boolean) -> Unit,
    isEnabled: Boolean = true,
    panelBackground: Color = Color(0xFFF5F7FC),
    menuContent: @Composable () -> Unit,
    content: @Composable () -> Unit,
    modifier: Modifier = Modifier,
) {
    val scope = rememberCoroutineScope()
    val density = LocalDensity.current
    val sideMenuWidthPx = with(density) { SideMenuWidth.toPx() }
    val progress = remember { Animatable(0f) }
    var dragOffset by remember { mutableFloatStateOf(0f) }

    LaunchedEffect(isExpanded) {
        progress.animateTo(
            if (isExpanded) 1f else 0f,
            spring(stiffness = Spring.StiffnessMediumLow, dampingRatio = 0.86f),
        )
        dragOffset = 0f
    }

    val effectiveProgress = ((progress.value * sideMenuWidthPx + dragOffset) / sideMenuWidthPx)
        .coerceIn(0f, 1f)
    val contentOffsetPx = effectiveProgress * sideMenuWidthPx

    fun snapMenu(open: Boolean) {
        scope.launch {
            onExpandedChange(open)
            dragOffset = 0f
            progress.animateTo(
                if (open) 1f else 0f,
                spring(stiffness = Spring.StiffnessMediumLow, dampingRatio = 0.86f),
            )
        }
    }

    BoxWithConstraints(modifier.fillMaxSize()) {
        if (effectiveProgress > 0.001f) {
            Box(Modifier.fillMaxSize().background(Color.Black))
        }

        Box(
            Modifier
                .width(SideMenuWidth)
                .fillMaxHeight()
                .graphicsLayer {
                    alpha = effectiveProgress
                    scaleX = 0.95f + 0.05f * effectiveProgress
                    scaleY = 0.95f + 0.05f * effectiveProgress
                },
        ) {
            menuContent()
        }

        Box(
            Modifier
                .fillMaxSize()
                .offset { IntOffset(contentOffsetPx.roundToInt(), 0) }
                .background(panelBackground)
                .graphicsLayer { shadowElevation = 8f * effectiveProgress }
                .then(
                    if (isEnabled) {
                        Modifier.pointerInput(isExpanded, sideMenuWidthPx) {
                            detectHorizontalDragGestures(
                                onDragEnd = {
                                    snapMenu(contentOffsetPx > sideMenuWidthPx / 2f)
                                },
                                onHorizontalDrag = { _, dragAmount ->
                                    val base = progress.value * sideMenuWidthPx
                                    dragOffset = (dragOffset + dragAmount)
                                        .coerceIn(-base, sideMenuWidthPx - base)
                                },
                            )
                        }
                    } else Modifier,
                ),
        ) {
            content()
            if (effectiveProgress > 0.001f) {
                Box(
                    Modifier
                        .fillMaxSize()
                        .background(Color.Black.copy(alpha = 0.06f * effectiveProgress))
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                            onClick = { snapMenu(false) },
                        ),
                )
            }
        }
    }
}
