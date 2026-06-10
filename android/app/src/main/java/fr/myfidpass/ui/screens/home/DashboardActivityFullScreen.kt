package fr.myfidpass.ui.screens.home

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.dto.TransactionDto
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.ui.components.FintechLoadMoreTransactionsButton
import fr.myfidpass.ui.theme.FintechLightPalette
import kotlinx.coroutines.launch

private const val ACTIVITY_PAGE_SIZE = 20

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardActivityFullScreen(
    repository: DashboardRepository,
    onBack: () -> Unit,
    onMemberClick: (String) -> Unit,
) {
    val slug = repository.currentSlug()
    val scope = rememberCoroutineScope()
    val palette = FintechLightPalette
    val scrollState = rememberScrollState()

    var loading by remember { mutableStateOf(true) }
    var loadingMore by remember { mutableStateOf(false) }
    var filter by remember { mutableStateOf("all") }
    var transactions by remember { mutableStateOf<List<TransactionDto>>(emptyList()) }
    var transactionsTotal by remember { mutableIntStateOf(0) }

    val hasMore = transactions.size < transactionsTotal

    val loadMore: () -> Unit = loadMore@{
        val currentSlug = slug ?: return@loadMore
        if (loadingMore || !hasMore) return@loadMore
        scope.launch {
            loadingMore = true
            runCatching {
                val response = repository.businessTransactions(
                    slug = currentSlug,
                    limit = ACTIVITY_PAGE_SIZE,
                    offset = transactions.size,
                    sort = "desc",
                    type = if (filter == "all") null else filter,
                    days = if (filter == "today") 1 else null,
                )
                transactionsTotal = response.total ?: transactionsTotal
                transactions = transactions + response.transactions
            }
            loadingMore = false
        }
    }

    LaunchedEffect(slug, filter) {
        val currentSlug = slug ?: return@LaunchedEffect
        loading = true
        transactions = emptyList()
        transactionsTotal = 0
        runCatching {
            val response = repository.businessTransactions(
                slug = currentSlug,
                limit = ACTIVITY_PAGE_SIZE,
                sort = "desc",
                type = if (filter == "all") null else filter,
                days = if (filter == "today") 1 else null,
            )
            transactions = response.transactions
            transactionsTotal = response.total ?: response.transactions.size
        }
        loading = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Activité") },
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
                .padding(16.dp),
        ) {
            RowFilters(filter) { filter = it }
            Spacer(Modifier.height(12.dp))
            if (loading) {
                CircularProgressIndicator()
            } else if (transactions.isEmpty()) {
                Text("Aucune opération.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            } else {
                Column(Modifier.verticalScroll(scrollState)) {
                    transactions.forEach { t ->
                        ActivityRow(t, onMemberClick)
                        Spacer(Modifier.height(6.dp))
                    }
                    if (hasMore) {
                        Spacer(Modifier.height(4.dp))
                        FintechLoadMoreTransactionsButton(
                            palette = palette,
                            isLoading = loadingMore,
                            onClick = loadMore,
                        )
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RowFilters(selected: String, onSelect: (String) -> Unit) {
    androidx.compose.foundation.layout.Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(8.dp),
    ) {
        listOf("all" to "Tout", "today" to "Aujourd'hui", "credit" to "Crédits", "redeem" to "Échanges").forEach { (k, label) ->
            FilterChip(selected = selected == k, onClick = { onSelect(k) }, label = { Text(label) })
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ActivityRow(t: TransactionDto, onMemberClick: (String) -> Unit) {
    Card(
        onClick = { t.memberId?.let(onMemberClick) },
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
    ) {
        Column(Modifier.padding(12.dp)) {
            Text(
                t.memberName?.ifBlank { t.memberEmail } ?: t.type ?: "Opération",
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                "${t.points ?: "—"} pts · ${t.createdAt?.take(16) ?: ""}",
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}
