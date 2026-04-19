package fr.myfidpass.ui.screens.commerce

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.dto.DashboardEvolutionResponse
import fr.myfidpass.data.dto.TransactionDto
import fr.myfidpass.data.repo.DashboardRepository

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StatsTransactionsScreen(
    repository: DashboardRepository,
    onBack: () -> Unit,
) {
    val slug = repository.currentSlug()
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var evolution by remember { mutableStateOf<DashboardEvolutionResponse?>(null) }
    var transactions by remember { mutableStateOf<List<TransactionDto>>(emptyList()) }

    LaunchedEffect(slug) {
        if (slug == null) {
            loading = false
            return@LaunchedEffect
        }
        loading = true
        error = null
        runCatching {
            evolution = repository.businessEvolution(slug, weeks = 12)
            transactions = repository.businessTransactions(slug, limit = 40).transactions
        }.onFailure { error = it.message }
        loading = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Stats & activité") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Retour")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp),
        ) {
            if (loading) {
                CircularProgressIndicator(Modifier.padding(24.dp))
                return@Column
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            Text("Évolution (semaines)", style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(8.dp))
            evolution?.evolution?.takeIf { it.isNotEmpty() }?.let { weeks ->
                weeks.forEach { w ->
                    Text(
                        "Semaine ${w.weekIndex ?: "—"} : ${w.operationsCount ?: 0} op., ${w.membersCount ?: 0} membres actifs",
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.padding(vertical = 4.dp),
                    )
                }
            } ?: Text("Pas de données d’évolution.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(20.dp))
            Text("Dernières transactions", style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(8.dp))
            LazyColumn {
                items(transactions, key = { it.id ?: it.createdAt ?: "" }) { t ->
                    Card(
                        Modifier
                            .fillMaxWidth()
                            .padding(vertical = 6.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    ) {
                        Column(Modifier.padding(12.dp)) {
                            Text(
                                t.memberName?.ifBlank { t.memberEmail } ?: t.type ?: "Transaction",
                                style = MaterialTheme.typography.titleSmall,
                            )
                            Text(
                                "${t.points ?: "—"} pts · ${t.createdAt ?: ""}",
                                style = MaterialTheme.typography.bodySmall,
                            )
                        }
                    }
                }
            }
        }
    }
}
