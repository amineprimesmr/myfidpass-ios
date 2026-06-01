package fr.myfidpass.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/** Fan carousel type iOS `DashboardSetupHeroCarousel` — cartes fidélité animées. */
@Composable
fun DashboardSetupHeroCarousel(
    modifier: Modifier = Modifier,
) {
    val transition = rememberInfiniteTransition(label = "hero")
    val sway by transition.animateFloat(
        initialValue = -4f,
        targetValue = 4f,
        animationSpec = infiniteRepeatable(tween(2400, easing = LinearEasing), RepeatMode.Reverse),
        label = "sway",
    )
    val cardColors = listOf(
        listOf(Color(0xFF1A1A2E), Color(0xFF16213E)),
        listOf(Color(0xFF2563EB), Color(0xFF1D4ED8)),
        listOf(Color(0xFF7C3AED), Color(0xFF5B21B6)),
    )
    Box(
        modifier
            .fillMaxWidth()
            .height(168.dp),
        contentAlignment = Alignment.Center,
    ) {
        cardColors.forEachIndexed { index, gradient ->
            val offsetX = when (index) {
                0 -> (-36 + sway).dp
                1 -> sway.dp
                else -> (36 - sway).dp
            }
            val rotation = when (index) {
                0 -> -12f + sway * 0.3f
                1 -> 0f
                else -> 12f - sway * 0.3f
            }
            Box(
                Modifier
                    .width(100.dp)
                    .fillMaxHeight(0.92f)
                    .offset(x = offsetX)
                    .rotate(rotation)
                    .clip(RoundedCornerShape(14.dp))
                    .background(Brush.verticalGradient(gradient)),
            )
        }
    }
}
