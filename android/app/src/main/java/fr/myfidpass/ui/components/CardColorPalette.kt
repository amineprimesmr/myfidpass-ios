package fr.myfidpass.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import fr.myfidpass.flyer.AppVibrantColorPalette
import fr.myfidpass.util.toComposeColorOr

val CardColorPresets: List<Pair<String, String>> = AppVibrantColorPalette.cardRowPresets

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun CanvaColorPaletteRow(
    label: String,
    selectedHex: String,
    suggestedHexes: List<String> = emptyList(),
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier) {
        Text(label, style = MaterialTheme.typography.labelMedium)
        Spacer(Modifier.height(8.dp))
        val all = (suggestedHexes.map { it.removePrefix("#").uppercase() } + CardColorPresets.map { it.first })
            .distinct()
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            all.forEach { hex ->
                val normalized = "#$hex"
                val selected = selectedHex.removePrefix("#").equals(hex, ignoreCase = true)
                Box(
                    Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(normalized.toComposeColorOr(Color.Gray))
                        .border(
                            width = if (selected) 2.dp else 1.dp,
                            color = if (selected) Color(0xFF2563EB) else Color.Black.copy(alpha = 0.12f),
                            shape = CircleShape,
                        )
                        .clickable { onSelect(normalized) },
                )
            }
        }
    }
}
