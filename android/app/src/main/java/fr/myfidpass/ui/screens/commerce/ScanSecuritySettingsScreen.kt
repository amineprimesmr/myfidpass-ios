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
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
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
import fr.myfidpass.data.dto.isApiTrue
import fr.myfidpass.data.repo.DashboardRepository
import kotlinx.coroutines.launch
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScanSecuritySettingsScreen(
    repository: DashboardRepository,
    snackbar: SnackbarHostState,
    onBack: () -> Unit,
) {
    val slug = repository.currentSlug()
    val scope = rememberCoroutineScope()
    var loading by remember { mutableStateOf(true) }
    var saving by remember { mutableStateOf(false) }
    var maxPasses by remember { mutableStateOf("0") }
    var maxPoints by remember { mutableStateOf("0") }
    var requireReceipt by remember { mutableStateOf(false) }
    var toleranceCents by remember { mutableStateOf("5") }

    LaunchedEffect(slug) {
        if (slug == null) return@LaunchedEffect
        loading = true
        runCatching { repository.businessSettings(slug) }.onSuccess { s ->
            maxPasses = (s.scanMaxPassesPerMemberPerDay ?: 0).toString()
            maxPoints = (s.scanMaxPointsPerTransaction ?: 0).toString()
            requireReceipt = s.requireReceiptQrValidation.isApiTrue()
            toleranceCents = (s.receiptQrToleranceCents ?: 5).toString()
        }
        loading = false
    }

    fun save() {
        if (slug == null) return
        scope.launch {
            saving = true
            runCatching {
                val patch = buildJsonObject {
                    put("scan_max_passes_per_member_per_day", maxPasses.toIntOrNull() ?: 0)
                    put("scan_max_points_per_transaction", maxPoints.toIntOrNull() ?: 0)
                    put("require_receipt_qr_validation", if (requireReceipt) 1 else 0)
                    put("receipt_qr_tolerance_cents", toleranceCents.toIntOrNull() ?: 5)
                }
                repository.patchDashboardSettings(slug, patch)
            }.onSuccess {
                snackbar.showSnackbar("Sécurité scan enregistrée")
                onBack()
            }.onFailure {
                snackbar.showSnackbar(it.message ?: "Erreur")
            }
            saving = false
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Sécurité scan") },
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
            Text(
                "Plafonds anti-fraude (alignés iOS SettingsScanSecurityView). 0 = illimité.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(16.dp))
            OutlinedTextField(
                value = maxPasses,
                onValueChange = { maxPasses = it.filter { c -> c.isDigit() } },
                label = { Text("Passages max / client / jour") },
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = maxPoints,
                onValueChange = { maxPoints = it.filter { c -> c.isDigit() } },
                label = { Text("Points max par opération") },
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(16.dp))
            Row(
                Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Validation ticket de caisse", modifier = Modifier.weight(1f))
                Switch(checked = requireReceipt, onCheckedChange = { requireReceipt = it })
            }
            if (requireReceipt) {
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = toleranceCents,
                    onValueChange = { toleranceCents = it.filter { c -> c.isDigit() } },
                    label = { Text("Tolérance montant (centimes)") },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            Spacer(Modifier.height(24.dp))
            Button(
                onClick = { save() },
                enabled = !saving && slug != null,
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (saving) CircularProgressIndicator()
                else Text("Enregistrer")
            }
        }
    }
}
