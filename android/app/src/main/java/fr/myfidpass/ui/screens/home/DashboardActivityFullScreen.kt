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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.dto.TransactionDto
import fr.myfidpass.data.repo.DashboardRepository

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardActivityFullScreen(
    repository: DashboardRepository,
    onBack: () -> Unit,
    onMemberClick: (String) -> Unit,
) {
    val slug = repository.currentSlug()
    var loading by remember { mutableStateOf(true) }
    var filter by remember { mutableStateOf("all") }
    var transactions by remember { mutableStateOf<List<TransactionDto>>(emptyList()) }

    LaunchedEffect(slug, filter) {
        if (slug == null) return@LaunchedEffect
        loading = true
        runCatching {
            transactions = repository.businessTransactions(
                slug,
                limit = 80,
                sort = "desc",
                type = if (filter == "all") null else filter,
                days = if (filter == "today") 1 else null,
            ).transactions
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
                Column(Modifier.verticalScroll(rememberScrollState())) {
                    transactions.forEach { t ->
                        ActivityRow(t, onMemberClick)
                        Spacer(Modifier.height(6.dp))
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
