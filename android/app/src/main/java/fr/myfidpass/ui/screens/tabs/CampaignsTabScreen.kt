package fr.myfidpass.ui.screens.tabs

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.repo.DashboardRepository
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonObject

@Composable
fun CampaignsTabScreen(
    modifier: Modifier = Modifier,
    repository: DashboardRepository,
    snackbarHostState: SnackbarHostState,
) {
    var message by remember { mutableStateOf("") }
    var title by remember { mutableStateOf("") }
    var status by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(false) }
    var dataLoading by remember { mutableStateOf(true) }
    var segments by remember { mutableStateOf<JsonObject?>(null) }
    var stats by remember { mutableStateOf<JsonObject?>(null) }
    var statsError by remember { mutableStateOf<String?>(null) }
    var showDebugJson by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val slug = repository.currentSlug()

    LaunchedEffect(slug) {
        val s = slug ?: run {
            dataLoading = false
            return@LaunchedEffect
        }
        dataLoading = true
        statsError = null
        runCatching { segments = repository.notificationSegments(s) }
            .onFailure { statsError = it.message }
        runCatching { stats = repository.notificationStats(s) }
            .onFailure { statsError = it.message }
        dataLoading = false
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
    ) {
        Text("Notifs", style = MaterialTheme.typography.titleLarge)
        Spacer(Modifier.height(4.dp))
        Text(
            "Envoie une notification push à tes clients (Web, Apple Wallet, app commerçant selon configuration). " +
                "Les blocs ci‑dessous viennent du serveur : ce ne sont pas des erreurs, mais des compteurs et des textes d’aide pour le dépannage.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(12.dp))

        if (dataLoading) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
                CircularProgressIndicator()
            }
            Spacer(Modifier.height(8.dp))
        }

        segments?.takeIf { it.isNotEmpty() }?.let { seg ->
            Text("Ciblage (segments)", style = MaterialTheme.typography.titleSmall)
            Spacer(Modifier.height(4.dp))
            Text(
                "Nombre de membres correspondant à chaque critère (inactifs, nouveaux, anniversaires, etc.). " +
                    "Tu choisis le segment au moment de l’envoi côté SaaS / logique serveur ; ici c’est un aperçu des volumes.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(8.dp))
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            ) {
                Column(Modifier.padding(12.dp)) {
                    seg.entries.sortedBy { it.key }.forEach { (k, v) ->
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .padding(vertical = 4.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Text(
                                segmentKeyLabels[k] ?: k,
                                style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.weight(1f),
                            )
                            Text(
                                v.displayValue(),
                                style = MaterialTheme.typography.bodyMedium,
                            )
                        }
                    }
                }
            }
            Spacer(Modifier.height(12.dp))
        }

        stats?.let { st ->
            Text("Canaux & diagnostic", style = MaterialTheme.typography.titleSmall)
            Spacer(Modifier.height(4.dp))
            Text(
                "Résumé technique : combien de membres, d’abonnements push, de passes Wallet enregistrés, etc. " +
                    "Les longs textes en bas sont des guides si « 0 appareil » alors que tu as des clients.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(8.dp))
            st.lastBatchSummary()?.let { line ->
                Text(line, style = MaterialTheme.typography.labelLarge)
                Spacer(Modifier.height(6.dp))
            }
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            ) {
                Column(Modifier.padding(12.dp)) {
                    st.statsKpiEntries().forEach { (label, value) ->
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .padding(vertical = 4.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Text(label, style = MaterialTheme.typography.bodySmall, modifier = Modifier.weight(1f))
                            Text(value, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
            Spacer(Modifier.height(8.dp))
            st.pickLongHelp().forEach { (helpTitle, body) ->
                ExpandableHelpBlock(title = helpTitle, body = body)
                Spacer(Modifier.height(6.dp))
            }
            Spacer(Modifier.height(4.dp))
            Row(
                Modifier
                    .fillMaxWidth()
                    .clickable { showDebugJson = !showDebugJson }
                    .padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    if (showDebugJson) "Masquer le JSON brut" else "Voir le JSON brut (support)",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                )
                Icon(
                    if (showDebugJson) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                )
            }
            AnimatedVisibility(visible = showDebugJson) {
                Text(
                    st.toString(),
                    style = MaterialTheme.typography.bodySmall,
                    fontFamily = FontFamily.Monospace,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Spacer(Modifier.height(8.dp))
        }

        statsError?.let {
            Text(it, color = MaterialTheme.colorScheme.error)
            Spacer(Modifier.height(8.dp))
        }

        HorizontalDivider()
        Spacer(Modifier.height(12.dp))
        Text("Nouvelle notification", style = MaterialTheme.typography.titleSmall)
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = title,
            onValueChange = { title = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Titre (optionnel)") },
            singleLine = true,
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = message,
            onValueChange = { message = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Message") },
            minLines = 3,
        )
        Spacer(Modifier.height(12.dp))
        Button(
            onClick = {
                val s = repository.currentSlug() ?: return@Button
                if (message.isBlank()) return@Button
                scope.launch {
                    loading = true
                    status = runCatching {
                        repository.sendNotification(
                            s,
                            message.trim(),
                            null,
                            title.trim().takeIf { it.isNotEmpty() },
                            null,
                        )
                    }.fold(
                        onSuccess = { "Envoyé" },
                        onFailure = { it.message ?: "Erreur" },
                    )
                    loading = false
                }
            },
            enabled = !loading,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(if (loading) "Envoi…" else "Envoyer")
        }
        status?.let {
            Spacer(Modifier.height(12.dp))
            Text(it, color = MaterialTheme.colorScheme.primary)
        }
        Spacer(Modifier.height(24.dp))
        Text("Pass Apple (test)", style = MaterialTheme.typography.titleSmall)
        Spacer(Modifier.height(4.dp))
        Text(
            "Outils commerçant : envoyer un pass de test ou retirer l’appareil de test du Wallet.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(8.dp))
        OutlinedButton(
            onClick = {
                val s = slug ?: return@OutlinedButton
                scope.launch {
                    runCatching {
                        repository.dashboardTestPasskit(s)
                        snackbarHostState.showSnackbar("PassKit test déclenché")
                    }.onFailure {
                        snackbarHostState.showSnackbar(it.message ?: "Erreur")
                    }
                }
            },
            enabled = slug != null,
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Tester PassKit") }
        Spacer(Modifier.height(8.dp))
        OutlinedButton(
            onClick = {
                val s = slug ?: return@OutlinedButton
                scope.launch {
                    runCatching {
                        repository.dashboardRemoveTestDevice(s)
                        snackbarHostState.showSnackbar("Device de test retiré")
                    }.onFailure {
                        snackbarHostState.showSnackbar(it.message ?: "Erreur")
                    }
                }
            },
            enabled = slug != null,
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Retirer le device de test") }
    }
}

@Composable
private fun ExpandableHelpBlock(title: String, body: String) {
    var expanded by remember { mutableStateOf(false) }
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { expanded = !expanded },
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
    ) {
        Column(Modifier.padding(12.dp)) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(title, style = MaterialTheme.typography.titleSmall)
                Icon(
                    if (expanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                    contentDescription = null,
                )
            }
            if (!expanded) {
                Text(
                    body.take(100).let { if (body.length > 100) "$it…" else it },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    "Appuyer pour tout lire",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
            AnimatedVisibility(visible = expanded) {
                Text(
                    body,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
        }
    }
}
