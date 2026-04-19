package fr.myfidpass.ui.screens.commerce

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.dto.BusinessGameDto
import fr.myfidpass.data.dto.PatchGameRequest
import fr.myfidpass.data.repo.DashboardRepository
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GamesScreen(
    repository: DashboardRepository,
    snackbarHostState: SnackbarHostState,
    onBack: () -> Unit,
) {
    val slug = repository.currentSlug()
    val scope = rememberCoroutineScope()
    var loading by remember { mutableStateOf(true) }
    var games by remember { mutableStateOf<List<BusinessGameDto>>(emptyList()) }

    LaunchedEffect(slug) {
        if (slug == null) {
            loading = false
            return@LaunchedEffect
        }
        loading = true
        runCatching { games = repository.dashboardGames(slug).games }
        loading = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Jeux dashboard") },
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
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
        ) {
            if (loading) {
                CircularProgressIndicator()
                return@Column
            }
            if (games.isEmpty()) {
                Text("Aucun jeu configuré.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                return@Column
            }
            games.forEach { g ->
                val code = g.gameCode?.trim().orEmpty()
                Card(
                    Modifier
                        .fillMaxWidth()
                        .padding(vertical = 6.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                ) {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(
                                g.gameName?.ifBlank { code } ?: code.ifBlank { "Jeu" },
                                style = MaterialTheme.typography.titleSmall,
                            )
                            g.ticketCost?.let {
                                Text("Coût ticket : $it", style = MaterialTheme.typography.bodySmall)
                            }
                        }
                        Switch(
                            checked = g.enabled == true,
                            onCheckedChange = { on ->
                                if (slug == null || code.isEmpty()) return@Switch
                                scope.launch {
                                    runCatching {
                                        repository.dashboardPatchGame(
                                            slug,
                                            code,
                                            PatchGameRequest(enabled = on),
                                        )
                                        games = repository.dashboardGames(slug).games
                                    }.onFailure {
                                        snackbarHostState.showSnackbar(it.message ?: "Erreur")
                                    }
                                }
                            },
                        )
                    }
                }
            }
        }
    }
}
