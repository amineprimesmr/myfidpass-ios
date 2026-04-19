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
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.util.openInCustomTab
import fr.myfidpass.util.optHttpUrl
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonObject

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SocialEngagementScreen(
    repository: DashboardRepository,
    snackbarHostState: SnackbarHostState,
    onBack: () -> Unit,
) {
    val slug = repository.currentSlug()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var loading by remember { mutableStateOf(true) }
    var metrics by remember { mutableStateOf<JsonObject?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    fun load() {
        if (slug == null) return
        scope.launch {
            loading = true
            error = null
            runCatching { metrics = repository.dashboardSocialMetrics(slug) }
                .onFailure { error = it.message }
            loading = false
        }
    }

    LaunchedEffect(slug) {
        if (slug == null) {
            loading = false
            return@LaunchedEffect
        }
        load()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Réseaux & avis") },
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
            Button(
                onClick = { load() },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Rafraîchir les métriques") }
            Spacer(Modifier.height(8.dp))
            OutlinedButton(
                onClick = {
                    if (slug == null) return@OutlinedButton
                    scope.launch {
                        runCatching {
                            repository.dashboardSocialMetricsRefresh(slug)
                            snackbarHostState.showSnackbar("Rafraîchissement demandé")
                            load()
                        }.onFailure {
                            snackbarHostState.showSnackbar(it.message ?: "Erreur")
                        }
                    }
                },
                enabled = slug != null,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Actualiser côté serveur (refresh)") }
            Spacer(Modifier.height(12.dp))
            fun openOAuth(block: suspend () -> JsonObject) {
                if (slug == null) return
                scope.launch {
                    runCatching {
                        val j = block()
                        j.optHttpUrl()?.let { openInCustomTab(context, it) }
                    }
                }
            }
            OutlinedButton(
                onClick = { openOAuth { repository.socialOAuthMetaStart(slug!!) } },
                enabled = slug != null,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("OAuth Meta / Instagram") }
            OutlinedButton(
                onClick = { openOAuth { repository.socialOAuthGoogleYoutubeStart(slug!!) } },
                enabled = slug != null,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("OAuth Google YouTube") }
            OutlinedButton(
                onClick = { openOAuth { repository.socialOAuthGoogleBusinessStart(slug!!) } },
                enabled = slug != null,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("OAuth Google Business") }
            OutlinedButton(
                onClick = { openOAuth { repository.socialOAuthTiktokStart(slug!!) } },
                enabled = slug != null,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("OAuth TikTok") }
            Spacer(Modifier.height(16.dp))
            if (loading) {
                CircularProgressIndicator()
                return@Column
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            metrics?.let { Text(it.toString(), style = MaterialTheme.typography.bodySmall) }
        }
    }
}
