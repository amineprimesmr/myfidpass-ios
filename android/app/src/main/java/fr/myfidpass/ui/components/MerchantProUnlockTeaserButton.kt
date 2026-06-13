package fr.myfidpass.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Bouton verre clair « Débloquer avec Pro » — aligné iOS `MerchantProUnlockTeaserButton`. */
@Composable
fun MerchantProUnlockTeaserButton(
    onUnlock: () -> Unit,
    modifier: Modifier = Modifier,
    unlockTitle: String = "Débloquer les notifications illimitées avec Pro",
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(Color.White.copy(alpha = 0.92f))
            .border(1.dp, Color.Black.copy(alpha = 0.08f), RoundedCornerShape(20.dp))
            .clickable(onClick = onUnlock)
            .padding(horizontal = 18.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        Icon(
            Icons.Default.Lock,
            contentDescription = null,
            tint = Color(0xFF141518),
            modifier = Modifier.size(17.dp),
        )
        Spacer(Modifier.size(10.dp))
        Text(
            unlockTitle,
            color = Color(0xFF141518),
            fontWeight = FontWeight.SemiBold,
            fontSize = 15.5.sp,
            lineHeight = 20.sp,
            textAlign = TextAlign.Center,
        )
    }
}
