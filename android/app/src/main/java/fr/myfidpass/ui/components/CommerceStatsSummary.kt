package fr.myfidpass.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.dto.BusinessStatsResponse
import fr.myfidpass.data.dto.DashboardTrafficPatternsResponse

@Composable
fun CommerceStatsSummary(
    stats: BusinessStatsResponse?,
    traffic: DashboardTrafficPatternsResponse?,
    modifier: Modifier = Modifier,
) {
    if (stats == null && traffic == null) return
    Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            "Statistiques",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
        )
        stats?.let { s ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                StatChip("Membres", s.membersCount?.toString() ?: "—", Modifier.weight(1f))
                StatChip("Pts (mois)", s.pointsThisMonth?.toString() ?: "—", Modifier.weight(1f))
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                StatChip("Tx (mois)", s.transactionsThisMonth?.toString() ?: "—", Modifier.weight(1f))
                StatChip(
                    "Panier moy.",
                    s.avgBasketEur?.let { "%.2f €".format(it) } ?: "—",
                    Modifier.weight(1f),
                )
            }
        }
        traffic?.peakHour?.let { peak ->
            Text(
                "Heure de pointe : ${peak.hour}h · ${peak.count} ops",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun StatChip(title: String, value: String, modifier: Modifier = Modifier) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Column(Modifier.padding(12.dp)) {
            Text(title, style = MaterialTheme.typography.labelMedium)
            Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        }
    }
}
