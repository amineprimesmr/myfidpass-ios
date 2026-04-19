package fr.myfidpass.ui.screens.commerce

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
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import fr.myfidpass.BuildConfig
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.util.openInCustomTab
import kotlinx.serialization.json.JsonObject

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FlyerToolsScreen(
    repository: DashboardRepository,
    onBack: () -> Unit,
) {
    val slug = repository.currentSlug()
    val context = LocalContext.current
    var loading by remember { mutableStateOf(true) }
    var flyerJson by remember { mutableStateOf<JsonObject?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(slug) {
        if (slug == null) {
            loading = false
            return@LaunchedEffect
        }
        loading = true
        error = null
        runCatching { flyerJson = repository.dashboardFlyerGet(slug) }
            .onFailure { error = it.message }
        loading = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Flyer") },
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
            Text(
                "État serveur (GET /dashboard/flyer). Édition avancée : SaaS web ou iOS.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(12.dp))
            Button(
                onClick = { openInCustomTab(context, BuildConfig.FLYER_EMBED_URL) },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Ouvrir l’aperçu flyer (embed)") }
            Spacer(Modifier.height(12.dp))
            OutlinedButton(
                onClick = {
                    val s = slug?.trim()?.lowercase().orEmpty()
                    if (s.isNotEmpty()) {
                        openInCustomTab(context, "https://myfidpass.fr/fidelity/$s")
                    }
                },
                enabled = !slug.isNullOrBlank(),
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Page fidélité publique") }
            Spacer(Modifier.height(16.dp))
            if (loading) {
                CircularProgressIndicator()
                return@Column
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            flyerJson?.let {
                Text(it.toString(), style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}
