package fr.myfidpass.ui.components

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Row
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Pastille « Touchez » centrée sur l’aperçu carte Accueil — pulse zoom aligné iOS. */
@Composable
fun HomeCardTouchHintPill(modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "homeCardTouchHint")
    val scale by transition.animateFloat(
        initialValue = 0.96f,
        targetValue = 1.08f,
        animationSpec = infiniteRepeatable(tween(820), RepeatMode.Reverse),
        label = "homeCardTouchHintScale",
    )
    Row(
        modifier = modifier
            .scale(scale)
            .shadow(10.dp, RoundedCornerShape(999.dp), spotColor = Color.Black.copy(0.4f))
            .background(Color(0xFF0A0A0A).copy(0.86f), RoundedCornerShape(999.dp))
            .border(1.2.dp, Color.White.copy(0.42f), RoundedCornerShape(999.dp))
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            Icons.Default.TouchApp,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.padding(end = 8.dp),
        )
        Text(
            "Touchez",
            color = Color.White,
            fontWeight = FontWeight.Black,
            fontSize = 16.sp,
        )
    }
}
