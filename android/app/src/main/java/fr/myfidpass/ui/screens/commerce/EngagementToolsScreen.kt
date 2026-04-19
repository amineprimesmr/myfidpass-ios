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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.repo.DashboardRepository
import kotlinx.coroutines.launch
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EngagementToolsScreen(
    repository: DashboardRepository,
    snackbarHostState: SnackbarHostState,
    onBack: () -> Unit,
) {
    val slug = repository.currentSlug()
    val scope = rememberCoroutineScope()
    var receiptAmount by remember { mutableStateOf("10.00") }
    var receiptQr by remember { mutableStateOf<String?>(null) }
    var showReceiptDialog by remember { mutableStateOf(false) }
    var notifyMessage by remember { mutableStateOf("") }
    var aiText by remember { mutableStateOf("") }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Caisse & clients") },
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
                "Défi ticket (JWT) — aligné `dashboardReceiptChallenge` iOS.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = receiptAmount,
                onValueChange = { receiptAmount = it },
                label = { Text("Montant €") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            Spacer(Modifier.height(8.dp))
            Button(
                onClick = {
                    val s = slug ?: return@Button
                    val amt = receiptAmount.replace(',', '.').toDoubleOrNull() ?: return@Button
                    scope.launch {
                        runCatching {
                            val r = repository.receiptChallenge(s, amt)
                            receiptQr = r.qrPayload
                            showReceiptDialog = true
                            snackbarHostState.showSnackbar("QR ticket généré")
                        }.onFailure {
                            snackbarHostState.showSnackbar(it.message ?: "Erreur")
                        }
                    }
                },
                enabled = slug != null,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Générer le défi reçu") }
            Spacer(Modifier.height(24.dp))
            Text("Message aux clients (`POST /notify`)", style = MaterialTheme.typography.titleSmall)
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = notifyMessage,
                onValueChange = { notifyMessage = it },
                label = { Text("Message") },
                modifier = Modifier.fillMaxWidth(),
                minLines = 2,
            )
            Spacer(Modifier.height(8.dp))
            OutlinedButton(
                onClick = {
                    val s = slug ?: return@OutlinedButton
                    val m = notifyMessage.trim()
                    if (m.isEmpty()) return@OutlinedButton
                    scope.launch {
                        runCatching {
                            repository.notifyClients(s, m, null)
                            snackbarHostState.showSnackbar("Notification envoyée")
                        }.onFailure {
                            snackbarHostState.showSnackbar(it.message ?: "Erreur")
                        }
                    }
                },
                enabled = slug != null && notifyMessage.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Notifier les clients") }
            Spacer(Modifier.height(24.dp))
            Text(
                "IA automation (texte brut → règle JSON)",
                style = MaterialTheme.typography.titleSmall,
            )
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = aiText,
                onValueChange = { aiText = it },
                label = { Text("Décrivez la règle de campagne") },
                modifier = Modifier.fillMaxWidth(),
                minLines = 2,
            )
            Button(
                onClick = {
                    val s = slug ?: return@Button
                    val t = aiText.trim()
                    if (t.isEmpty()) return@Button
                    scope.launch {
                        runCatching {
                            val body = buildJsonObject { put("text", t) }
                            val r = repository.dashboardCampaignAutomationParse(s, body)
                            snackbarHostState.showSnackbar("Réponse : ${r.toString().take(120)}…")
                        }.onFailure {
                            snackbarHostState.showSnackbar(it.message ?: "Erreur")
                        }
                    }
                },
                enabled = slug != null && aiText.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Parser avec l’IA") }
        }
    }

    if (showReceiptDialog && receiptQr != null) {
        AlertDialog(
            onDismissRequest = { showReceiptDialog = false },
            title = { Text("Payload QR ticket") },
            text = { Text(receiptQr ?: "") },
            confirmButton = {
                TextButton(onClick = { showReceiptDialog = false }) { Text("OK") }
            },
        )
    }
}
