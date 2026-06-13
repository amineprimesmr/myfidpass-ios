package fr.myfidpass.ui.screens.mycard

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp

/**
 * Conteneur GPU pour le zoom logo Ma Carte — l’animation reste isolée ici
 * pour éviter de recomposer tout [MyCardScreen] à chaque frame.
 */
@Composable
fun MyCardLogoZoomFrame(
    zoomFocused: Boolean,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    val scale by animateFloatAsState(
        targetValue = if (zoomFocused) 1.75f else 1f,
        animationSpec = if (zoomFocused) {
            spring(dampingRatio = 0.86f, stiffness = 700f)
        } else {
            tween(durationMillis = 140, easing = FastOutSlowInEasing)
        },
        label = "cardLogoZoomScale",
    )
    val offsetX by animateDpAsState(
        targetValue = if (zoomFocused) 16.dp else 0.dp,
        animationSpec = if (zoomFocused) {
            spring(dampingRatio = 0.86f, stiffness = 700f)
        } else {
            tween(durationMillis = 140, easing = FastOutSlowInEasing)
        },
        label = "cardLogoZoomOffsetX",
    )
    val offsetY by animateDpAsState(
        targetValue = if (zoomFocused) 4.dp else 0.dp,
        animationSpec = if (zoomFocused) {
            spring(dampingRatio = 0.86f, stiffness = 700f)
        } else {
            tween(durationMillis = 140, easing = FastOutSlowInEasing)
        },
        label = "cardLogoZoomOffsetY",
    )

    Box(
        modifier
            .fillMaxWidth()
            .heightIn(min = if (zoomFocused) 240.dp else 0.dp)
            .offset(x = offsetX, y = offsetY)
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
                transformOrigin = TransformOrigin(0f, 0f)
            },
    ) {
        content()
    }
}
