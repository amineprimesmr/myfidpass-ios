package fr.myfidpass.ui.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.repo.DashboardRepository
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/** Bloc « Votre flyer » — aligné iOS `CommerceFlyerSavedBlockView` (résumé + CTA modifier). */
@Composable
fun CommerceFlyerSavedBlock(
    slug: String,
    repository: DashboardRepository,
    onEditFlyer: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var flyerJson by remember(slug) { mutableStateOf<JsonObject?>(null) }
    var loadError by remember(slug) { mutableStateOf<String?>(null) }

    LaunchedEffect(slug) {
        if (slug.isBlank()) return@LaunchedEffect
        loadError = null
        runCatching { flyerJson = repository.dashboardFlyerGet(slug) }
            .onFailure { loadError = it.message }
    }

    val hasBg = flyerJson.stringField("custom_bg_data_url")?.isNotBlank() == true
    val hasLogo = flyerJson.stringField("custom_logo_data_url")?.isNotBlank() == true
    val configured = hasBg || hasLogo || flyerJson != null

    Card(
        onClick = onEditFlyer,
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
    ) {
        Column(Modifier.padding(14.dp)) {
            Text("Votre flyer", fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.titleSmall)
            Spacer(Modifier.height(4.dp))
            when {
                loadError != null -> Text(loadError!!, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                !configured -> Text(
                    "Créez votre flyer QR et page clients.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                else -> Text(
                    buildString {
                        append(if (hasBg) "Fond personnalisé · " else "")
                        append(if (hasLogo) "Logo · " else "")
                        append("Appuyez pour modifier")
                    }.trimEnd(' ', '·'),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

private fun JsonObject?.stringField(key: String): String? {
    val el = this?.get(key) as? JsonPrimitive ?: return null
    return el.content.takeIf { it.isNotBlank() && it != "null" }
}
