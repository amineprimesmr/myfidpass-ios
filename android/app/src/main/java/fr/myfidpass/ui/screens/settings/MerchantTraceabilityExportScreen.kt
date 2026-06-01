package fr.myfidpass.ui.screens.settings

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
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.ui.screens.settings.export.ExportPeriodChoice
import fr.myfidpass.ui.screens.settings.export.ExportPeriodPicker
import fr.myfidpass.ui.screens.settings.export.TraceabilityMovementFilter
import fr.myfidpass.ui.screens.settings.export.exportPeriodParams
import fr.myfidpass.util.TransactionExportPdfBuilder
import fr.myfidpass.util.shareFiles
import fr.myfidpass.util.writeTempExport
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MerchantTraceabilityExportScreen(
    repository: DashboardRepository,
    snackbar: SnackbarHostState,
    onBack: () -> Unit,
) {
    val slug = repository.currentSlug()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var period by remember { mutableIntStateOf(ExportPeriodChoice.D30.ordinal) }
    var movement by remember { mutableIntStateOf(0) }
    var customFrom by remember { mutableStateOf("") }
    var customTo by remember { mutableStateOf("") }
    var memberId by remember { mutableStateOf("") }
    var exportLimit by remember { mutableIntStateOf(25_000) }
    var loadingCsv by remember { mutableStateOf(false) }
    var loadingPdf by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Traçabilité & exports") },
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
                "Historique des opérations fidélité : CSV pour tableur, PDF pour archivage.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(16.dp))
            ExportPeriodPicker(period, { period = it }, customFrom, { customFrom = it }, customTo, { customTo = it })
            Spacer(Modifier.height(12.dp))
            MovementFilterDropdown(
                movement,
                { movement = it },
                TraceabilityMovementFilter.entries.map { it.label },
            )
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = memberId,
                onValueChange = { memberId = it },
                label = { Text("ID membre (optionnel)") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = exportLimit.toString(),
                onValueChange = { exportLimit = it.filter { c -> c.isDigit() }.toIntOrNull() ?: exportLimit },
                label = { Text("Lignes max.") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            Spacer(Modifier.height(16.dp))
            Button(
                onClick = {
                    val s = slug ?: return@Button
                    val p = exportPeriodParams(period, customFrom, customTo)
                    val types = TraceabilityMovementFilter.entries.getOrElse(movement) { TraceabilityMovementFilter.ALL }.typesParam
                    scope.launch {
                        loadingCsv = true
                        runCatching {
                            val bytes = repository.businessTransactionsExportCsv(
                                slug = s,
                                days = p.days,
                                from = p.from,
                                to = p.to,
                                types = types,
                                memberId = memberId.trim().ifEmpty { null },
                                limit = exportLimit,
                            )
                            val file = writeTempExport(context, "exports", "transactions-$s.csv", bytes)
                            shareFiles(context, listOf(file), "text/csv")
                        }.onFailure {
                            snackbar.showSnackbar(it.message ?: "Export CSV impossible")
                        }
                        loadingCsv = false
                    }
                },
                enabled = !loadingCsv && !loadingPdf && slug != null,
                modifier = Modifier.fillMaxWidth(),
            ) { Text(if (loadingCsv) "Export…" else "Télécharger CSV") }
            Spacer(Modifier.height(8.dp))
            OutlinedButton(
                onClick = {
                    val s = slug ?: return@OutlinedButton
                    val p = exportPeriodParams(period, customFrom, customTo)
                    val types = TraceabilityMovementFilter.entries.getOrElse(movement) { TraceabilityMovementFilter.ALL }.typesParam
                    scope.launch {
                        loadingPdf = true
                        runCatching {
                            val report = repository.businessTransactionsExportJson(
                                slug = s,
                                days = p.days,
                                from = p.from,
                                to = p.to,
                                types = types,
                                memberId = memberId.trim().ifEmpty { null },
                                limit = exportLimit,
                            )
                            val pdf = TransactionExportPdfBuilder.buildPdf(report)
                            val stamp = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
                            val file = writeTempExport(context, "exports", "rapport-fidelite-$s-$stamp.pdf", pdf)
                            shareFiles(context, listOf(file), "application/pdf")
                        }.onFailure {
                            snackbar.showSnackbar(it.message ?: "Export PDF impossible")
                        }
                        loadingPdf = false
                    }
                },
                enabled = !loadingCsv && !loadingPdf && slug != null,
                modifier = Modifier.fillMaxWidth(),
            ) { Text(if (loadingPdf) "PDF…" else "Télécharger PDF") }
        }
    }
}
