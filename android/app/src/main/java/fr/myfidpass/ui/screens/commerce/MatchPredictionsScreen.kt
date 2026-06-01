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
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.repo.DashboardRepository
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

private data class MatchRow(
    val id: String,
    val title: String?,
    val teamHome: String,
    val teamAway: String,
    val startsAt: String,
    val resultChoice: String?,
    val entriesCount: Int,
    val pointsDistributed: Int,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MatchPredictionsScreen(
    repository: DashboardRepository,
    snackbar: SnackbarHostState,
    onBack: () -> Unit,
) {
    val slug = repository.currentSlug()
    val scope = rememberCoroutineScope()
    var loading by remember { mutableStateOf(true) }
    var savingConfig by remember { mutableStateOf(false) }
    var scoringId by remember { mutableStateOf<String?>(null) }
    var enabled by remember { mutableStateOf(false) }
    var pointsPerCorrect by remember { mutableIntStateOf(10) }
    var matches by remember { mutableStateOf<List<MatchRow>>(emptyList()) }
    val selectedResults = remember { mutableStateMapOf<String, String>() }
    var message by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    fun apply(json: JsonObject) {
        val cfg = json["config"]?.jsonObject
        enabled = cfg?.get("enabled")?.jsonPrimitive?.content == "true"
        pointsPerCorrect = cfg?.get("points_per_correct_prediction")?.jsonPrimitive?.intOrNull
            ?.coerceIn(1, 500) ?: 10
        matches = json["matches"]?.jsonArray?.mapNotNull { el ->
            val o = el.jsonObject
            val id = o["id"]?.jsonPrimitive?.content ?: return@mapNotNull null
            MatchRow(
                id = id,
                title = o["title"]?.jsonPrimitive?.content,
                teamHome = o["team_home"]?.jsonPrimitive?.content ?: "—",
                teamAway = o["team_away"]?.jsonPrimitive?.content ?: "—",
                startsAt = o["starts_at"]?.jsonPrimitive?.content ?: "",
                resultChoice = o["result_choice"]?.jsonPrimitive?.content,
                entriesCount = o["entries_count"]?.jsonPrimitive?.intOrNull ?: 0,
                pointsDistributed = o["points_distributed"]?.jsonPrimitive?.intOrNull ?: 0,
            )
        }.orEmpty()
        matches.forEach { m ->
            selectedResults[m.id] = m.resultChoice ?: "home"
        }
    }

    fun reload() {
        val s = slug ?: return
        scope.launch {
            loading = true
            error = null
            runCatching { repository.dashboardMatchPredictions(s) }
                .onSuccess { apply(it) }
                .onFailure { error = "Impossible de charger les pronostics." }
            loading = false
        }
    }

    LaunchedEffect(slug) { reload() }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Pronostics foot") },
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
                CircularProgressIndicator(Modifier.align(Alignment.CenterHorizontally))
                return@Column
            }
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            ) {
                Column(Modifier.padding(16.dp)) {
                    Row(
                        Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text("Activer le challenge", style = MaterialTheme.typography.titleSmall)
                            Text(
                                "Les clients voient les matchs dans leur espace fidélité.",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        Switch(checked = enabled, onCheckedChange = { enabled = it })
                    }
                    Spacer(Modifier.height(12.dp))
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Text("Gain par bon pronostic", Modifier.weight(1f))
                        IconButton(onClick = {
                            if (pointsPerCorrect > 1) pointsPerCorrect--
                        }) { Text("−") }
                        Text("+$pointsPerCorrect pts", style = MaterialTheme.typography.titleMedium)
                        IconButton(onClick = {
                            if (pointsPerCorrect < 500) pointsPerCorrect++
                        }) { Text("+") }
                    }
                    Spacer(Modifier.height(12.dp))
                    Button(
                        onClick = {
                            val s = slug ?: return@Button
                            scope.launch {
                                savingConfig = true
                                message = null
                                error = null
                                runCatching {
                                    repository.dashboardMatchPredictionsConfig(
                                        s,
                                        buildJsonObject {
                                            put("enabled", enabled)
                                            put("points_per_correct_prediction", pointsPerCorrect)
                                        },
                                    )
                                    reload()
                                    message = "Configuration enregistrée."
                                }.onFailure {
                                    error = "Enregistrement impossible."
                                }
                                savingConfig = false
                            }
                        },
                        enabled = !savingConfig && slug != null,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(if (savingConfig) "Enregistrement…" else "Enregistrer")
                    }
                    feedbackText(message, error)
                }
            }
            Spacer(Modifier.height(16.dp))
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            ) {
                Column(Modifier.padding(16.dp)) {
                    Text("Matchs sélectionnés", style = MaterialTheme.typography.titleSmall)
                    Spacer(Modifier.height(8.dp))
                    if (matches.isEmpty()) {
                        Text(
                            "Aucun match disponible pour le moment.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    } else {
                        matches.forEachIndexed { idx, match ->
                            MatchRowUi(
                                match = match,
                                choice = selectedResults[match.id] ?: "home",
                                onChoice = { selectedResults[match.id] = it },
                                scoring = scoringId == match.id,
                                onScore = {
                                    val s = slug ?: return@MatchRowUi
                                    val choice = selectedResults[match.id] ?: "home"
                                    scope.launch {
                                        scoringId = match.id
                                        message = null
                                        error = null
                                        runCatching {
                                            val r = repository.dashboardMatchPredictionsSetResult(
                                                s,
                                                match.id,
                                                buildJsonObject { put("result_choice", choice) },
                                            )
                                            val winners = r["winners_count"]?.jsonPrimitive?.intOrNull
                                                ?: r["correct_count"]?.jsonPrimitive?.intOrNull
                                                ?: 0
                                            reload()
                                            message = "Résultat validé : $winners gagnant(s)."
                                        }.onFailure {
                                            error = "Validation du résultat impossible."
                                        }
                                        scoringId = null
                                    }
                                },
                            )
                            if (idx < matches.lastIndex) HorizontalDivider(Modifier.padding(vertical = 8.dp))
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MatchRowUi(
    match: MatchRow,
    choice: String,
    onChoice: (String) -> Unit,
    scoring: Boolean,
    onScore: () -> Unit,
) {
    Column(Modifier.fillMaxWidth()) {
        Text(
            match.title ?: "Match sélectionné",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.primary,
        )
        Text("${match.teamHome} vs ${match.teamAway}", style = MaterialTheme.typography.titleSmall)
        Text(
            formatMatchDate(match.startsAt),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            "${match.entriesCount} pronostics" +
                if (match.pointsDistributed > 0) " · ${match.pointsDistributed} pts distribués" else "",
            style = MaterialTheme.typography.bodySmall,
        )
        Spacer(Modifier.height(8.dp))
        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
            listOf("home" to match.teamHome, "draw" to "Nul", "away" to match.teamAway).forEach { (tag, label) ->
                SegmentedButton(
                    selected = choice == tag,
                    onClick = { onChoice(tag) },
                    shape = SegmentedButtonDefaults.itemShape(index = when (tag) {
                        "home" -> 0
                        "draw" -> 1
                        else -> 2
                    }, count = 3),
                ) { Text(label.take(12), maxLines = 1) }
            }
        }
        Spacer(Modifier.height(8.dp))
        Button(
            onClick = onScore,
            enabled = !scoring,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (scoring) CircularProgressIndicator(Modifier.height(18.dp))
            Text(
                if (match.resultChoice == null) "Valider le résultat" else "Recalculer / confirmer",
            )
        }
    }
}

@Composable
private fun feedbackText(message: String?, error: String?) {
    error?.let {
        Spacer(Modifier.height(8.dp))
        Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
    }
    message?.let {
        Spacer(Modifier.height(8.dp))
        Text(it, color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.bodySmall)
    }
}

private fun formatMatchDate(raw: String): String {
    if (raw.isBlank()) return "—"
    return runCatching {
        val instant = Instant.parse(raw)
        DateTimeFormatter.ofPattern("EEE d MMM HH:mm", Locale.FRANCE)
            .withZone(ZoneId.systemDefault())
            .format(instant)
    }.getOrDefault(raw)
}
