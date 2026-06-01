package fr.myfidpass.ui.components

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.ui.mycard.CardPreviewEditZone
import kotlin.math.roundToInt

@Composable
fun CardPreviewConfiguratorPill(modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "pillPulse")
    val scale by transition.animateFloat(
        initialValue = 0.96f,
        targetValue = 1.08f,
        animationSpec = infiniteRepeatable(tween(820), RepeatMode.Reverse),
        label = "pillScale",
    )
    Row(
        modifier = modifier
            .scale(scale)
            .background(Color.Black.copy(alpha = 0.82f), RoundedCornerShape(50))
            .border(1.dp, Color.White.copy(alpha = 0.34f), RoundedCornerShape(50))
            .padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Default.TouchApp, contentDescription = null, tint = Color.White, modifier = Modifier.padding(end = 4.dp))
        Text("Touchez", color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold)
    }
}

enum class CardPreviewPillsLayoutStyle {
    WALLET_POINTS,
    /** Tampons sans image : grille dans le bandeau (zone MAIN_METRICS). */
    STAMP_GRID_IN_BANNER,
    /** Pass Google Wallet : zone rouge (header + QR) puis bannière hero en bas. */
    GOOGLE_WALLET,
}

@Composable
fun CardPreviewCompletionPillsOverlay(
    cardWidth: Float,
    totalHeight: Float,
    zones: Set<CardPreviewEditZone>,
    layoutStyle: CardPreviewPillsLayoutStyle = CardPreviewPillsLayoutStyle.WALLET_POINTS,
    onTapZone: (CardPreviewEditZone) -> Unit,
    modifier: Modifier = Modifier,
) {
    val w = maxOf(1f, cardWidth)
    val h = maxOf(1f, totalHeight)
    val (headH, banH, bodyH) = when (layoutStyle) {
        CardPreviewPillsLayoutStyle.GOOGLE_WALLET -> {
            val heroH = maxOf(1f, h * 0.26f)
            val body = maxOf(1f, h - heroH)
            Triple(0f, heroH, body)
        }
        else -> {
            val head = h * (100f / 478f)
            val ban = maxOf(1f, w / (750f / 246f))
            val body = maxOf(0f, h - head - ban)
            Triple(head, ban, body)
        }
    }
    Box(modifier) {
        if (CardPreviewEditZone.LOGO_BAND in zones && layoutStyle != CardPreviewPillsLayoutStyle.GOOGLE_WALLET) {
            val y = when (layoutStyle) {
                CardPreviewPillsLayoutStyle.GOOGLE_WALLET -> bodyH * 0.1f
                else -> headH * 0.42f
            }
            PillAt(w * 0.22f, y) { onTapZone(CardPreviewEditZone.LOGO_BAND) }
        }
        if (CardPreviewEditZone.HEADER_RIGHT in zones && layoutStyle != CardPreviewPillsLayoutStyle.GOOGLE_WALLET) {
            val y = when (layoutStyle) {
                CardPreviewPillsLayoutStyle.GOOGLE_WALLET -> bodyH * 0.08f
                else -> headH * 0.44f
            }
            PillAt(w * 0.82f, y) { onTapZone(CardPreviewEditZone.HEADER_RIGHT) }
        }
        if (CardPreviewEditZone.BACKGROUND_IMAGE in zones) {
            val y = when (layoutStyle) {
                CardPreviewPillsLayoutStyle.GOOGLE_WALLET -> bodyH + banH * 0.5f
                else -> headH + banH * 0.5f
            }
            PillAt(w * 0.5f, y) { onTapZone(CardPreviewEditZone.BACKGROUND_IMAGE) }
        }
        if (CardPreviewEditZone.MAIN_METRICS in zones) {
            val (x, y) = when (layoutStyle) {
                CardPreviewPillsLayoutStyle.WALLET_POINTS ->
                    w * 0.24f to headH + banH + bodyH * 0.2f
                CardPreviewPillsLayoutStyle.STAMP_GRID_IN_BANNER ->
                    w * 0.5f to headH + banH * 0.5f
                CardPreviewPillsLayoutStyle.GOOGLE_WALLET ->
                    w * 0.5f to bodyH + banH * 0.5f
            }
            PillAt(x, y) { onTapZone(CardPreviewEditZone.MAIN_METRICS) }
        }
        if (CardPreviewEditZone.CARD_APPEARANCE in zones) {
            val y = when (layoutStyle) {
                CardPreviewPillsLayoutStyle.GOOGLE_WALLET -> bodyH * 0.55f
                else -> headH + banH + bodyH * 0.55f
            }
            PillAt(w * 0.72f, y) { onTapZone(CardPreviewEditZone.CARD_APPEARANCE) }
        }
    }
}

@Composable
private fun PillAt(x: Float, y: Float, onClick: () -> Unit) {
    Box(Modifier.offset { IntOffset((x - 40f).roundToInt(), (y - 14f).roundToInt()) }) {
        CardPreviewConfiguratorPill(modifier = Modifier.clickable(onClick = onClick))
    }
}
