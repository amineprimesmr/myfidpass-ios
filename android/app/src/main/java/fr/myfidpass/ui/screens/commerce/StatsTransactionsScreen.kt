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
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.dto.DashboardEvolutionResponse
import fr.myfidpass.data.dto.TransactionDto
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.ui.components.FintechLoadMoreTransactionsButton
import fr.myfidpass.ui.theme.FintechLightPalette
import kotlinx.coroutines.launch

private const val TRANSACTIONS_PAGE_SIZE = 20

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StatsTransactionsScreen(
    repository: DashboardRepository,
    onBack: () -> Unit,
) {
    val slug = repository.currentSlug()
    val scope = rememberCoroutineScope()
    val palette = FintechLightPalette

    var loading by remember { mutableStateOf(true) }
    var loadingMore by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var evolution by remember { mutableStateOf<DashboardEvolutionResponse?>(null) }
    var transactions by remember { mutableStateOf<List<TransactionDto>>(emptyList()) }
    var transactionsTotal by remember { mutableIntStateOf(0) }

    val hasMore = transactions.size < transactionsTotal

    fun loadMore() {
        val currentSlug = slug ?: return
        if (loadingMore || !hasMore) return
        scope.launch {
            loadingMore = true
            runCatching {
                val response = repository.businessTransactions(
                    slug = currentSlug,
                    limit = TRANSACTIONS_PAGE_SIZE,
                    offset = transactions.size,
                    sort = "desc",
                )
                transactionsTotal = response.total ?: transactionsTotal
                transactions = transactions + response.transactions
            }.onFailure { error = it.message }
            loadingMore = false
        }
    }

    LaunchedEffect(slug) {
        if (slug == null) {
            loading = false
            return@LaunchedEffect
        }
        loading = true
        error = null
        transactions = emptyList()
        transactionsTotal = 0
        runCatching {
            evolution = repository.businessEvolution(slug, weeks = 12)
            val response = repository.businessTransactions(
                slug = slug,
                limit = TRANSACTIONS_PAGE_SIZE,
                sort = "desc",
            )
            transactions = response.transactions
            transactionsTotal = response.total ?: response.transactions.size
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
        if (loading) {
            CircularProgressIndicator(Modifier.padding(padding).padding(24.dp))
            return@Scaffold
        }

        LazyColumn(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp),
        ) {
            error?.let { message ->
                item(key = "error") {
                    Text(message, color = MaterialTheme.colorScheme.error)
                    Spacer(Modifier.height(12.dp))
                }
            }
            item(key = "evolution-title") {
                Text("Évolution (semaines)", style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(8.dp))
            }
            evolution?.evolution?.takeIf { it.isNotEmpty() }?.let { weeks ->
                items(weeks, key = { it.weekIndex ?: it.hashCode() }) { w ->
                    Text(
                        "Semaine ${w.weekIndex ?: "—"} : ${w.operationsCount ?: 0} op., ${w.membersCount ?: 0} membres actifs",
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.padding(vertical = 4.dp),
                    )
                }
            } ?: item(key = "evolution-empty") {
                Text("Pas de données d’évolution.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            item(key = "transactions-title") {
                Spacer(Modifier.height(20.dp))
                Text("Dernières transactions", style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(8.dp))
            }
            if (transactions.isEmpty()) {
                item(key = "transactions-empty") {
                    Text("Aucune transaction récente.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            } else {
                items(transactions, key = { it.id ?: it.createdAt ?: it.hashCode() }) { t ->
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
                if (hasMore) {
                    item(key = "load-more") {
                        FintechLoadMoreTransactionsButton(
                            palette = palette,
                            isLoading = loadingMore,
                            onClick = ::loadMore,
                            modifier = Modifier.padding(vertical = 8.dp),
                        )
                        Spacer(Modifier.height(16.dp))
                    }
                }
            }
        }
    }
}
