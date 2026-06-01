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
import fr.myfidpass.ui.screens.settings.export.exportPeriodParams
import fr.myfidpass.util.shareFiles
import fr.myfidpass.util.writeTempExport
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MerchantAccountingPackScreen(
    repository: DashboardRepository,
    snackbar: SnackbarHostState,
    onBack: () -> Unit,
) {
    val slug = repository.currentSlug()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var period by remember { mutableIntStateOf(ExportPeriodChoice.D30.ordinal) }
    var customFrom by remember { mutableStateOf("") }
    var customTo by remember { mutableStateOf("") }
    var exportLimit by remember { mutableIntStateOf(25_000) }
    var loading by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Pack comptable") },
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
                "Le serveur calcule les montants indicatifs à partir de votre programme. Choisissez la période puis partagez les fichiers CSV pour votre comptable.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(16.dp))
            ExportPeriodPicker(period, { period = it }, customFrom, { customFrom = it }, customTo, { customTo = it })
            Spacer(Modifier.height(12.dp))
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
                    scope.launch {
                        loading = true
                        runCatching {
                            val pack = repository.businessAccountingPack(
                                s,
                                days = p.days,
                                from = p.from,
                                to = p.to,
                                limit = exportLimit,
                            )
                            val stamp = SimpleDateFormat("yyyyMMdd-HHmm", Locale.US).format(Date())
                            val files = pack.files.mapNotNull { f ->
                                val name = f.filename?.trim().orEmpty()
                                val content = f.contentUtf8 ?: return@mapNotNull null
                                if (name.isEmpty()) return@mapNotNull null
                                writeTempExport(context, "pack-comptable-$stamp", name, content.toByteArray(Charsets.UTF_8))
                            }
                            if (files.isEmpty()) error("Réponse vide du serveur.")
                            shareFiles(context, files, "text/csv")
                        }.onFailure {
                            snackbar.showSnackbar(it.message ?: "Téléchargement impossible")
                        }
                        loading = false
                    }
                },
                enabled = !loading && slug != null,
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (loading) CircularProgressIndicator() else Text("Générer et partager le pack")
            }
            Spacer(Modifier.height(12.dp))
            Text(
                "Indicateurs non audités — à valider avec votre expert-comptable.",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
