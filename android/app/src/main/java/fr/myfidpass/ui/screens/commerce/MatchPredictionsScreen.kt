package fr.myfidpass.ui.screens.commerce

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material3.Button
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
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.data.repo.DashboardRepository
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.booleanOrNull
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

private data class NextMatchPreview(
    val id: String,
    val title: String?,
    val teamHome: String,
    val teamAway: String,
    val teamHomeFlag: String?,
    val teamAwayFlag: String?,
    val startsAt: String,
    val roundLabel: String?,
    val entriesCount: Int,
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
    var enabled by remember { mutableStateOf(false) }
    var pointsPerCorrect by remember { mutableIntStateOf(10) }
    var nextMatch by remember { mutableStateOf<NextMatchPreview?>(null) }
    var totalPredictions by remember { mutableIntStateOf(0) }
    var predictionsOnNext by remember { mutableIntStateOf(0) }
    var message by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    fun parseNextMatch(o: JsonObject?): NextMatchPreview? {
        if (o == null) return null
        val id = o["id"]?.jsonPrimitive?.content ?: return null
        return NextMatchPreview(
            id = id,
            title = o["title"]?.jsonPrimitive?.content,
            teamHome = o["team_home"]?.jsonPrimitive?.content ?: "—",
            teamAway = o["team_away"]?.jsonPrimitive?.content ?: "—",
            teamHomeFlag = o["team_home_flag"]?.jsonPrimitive?.content,
            teamAwayFlag = o["team_away_flag"]?.jsonPrimitive?.content,
            startsAt = o["starts_at"]?.jsonPrimitive?.content ?: "",
            roundLabel = o["round_label"]?.jsonPrimitive?.content,
            entriesCount = o["entries_count"]?.jsonPrimitive?.intOrNull ?: 0,
        )
    }

    fun apply(json: JsonObject) {
        val cfg = json["config"]?.jsonObject
        enabled = cfg?.get("enabled")?.jsonPrimitive?.booleanOrNull
            ?: (cfg?.get("enabled")?.jsonPrimitive?.intOrNull?.let { it != 0 })
            ?: false
        pointsPerCorrect = cfg?.get("points_per_correct_prediction")?.jsonPrimitive?.intOrNull
            ?.coerceIn(1, 500) ?: 10
        nextMatch = parseNextMatch(json["next_match"]?.jsonObject)
            ?: parseNextMatch(json["matches"]?.jsonArray?.firstOrNull()?.jsonObject)
        val stats = json["stats"]?.jsonObject
        totalPredictions = stats?.get("total_predictions")?.jsonPrimitive?.intOrNull ?: 0
        predictionsOnNext = stats?.get("predictions_on_next_match")?.jsonPrimitive?.intOrNull
            ?: nextMatch?.entriesCount
            ?: 0
    }

    fun reload() {
        val s = slug ?: return
        scope.launch {
            loading = true
            error = null
            runCatching { repository.dashboardMatchPredictions(s) }
                .onSuccess { apply(it) }
                .onFailure { error = "Impossible de charger la configuration." }
            loading = false
        }
    }

    LaunchedEffect(slug) { reload() }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Coupe du monde 2026") },
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
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            if (loading) {
                CircularProgressIndicator(Modifier.align(Alignment.CenterHorizontally))
                return@Column
            }

            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.35f),
                ),
            ) {
                Row(
                    Modifier.padding(14.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Icon(
                        Icons.Default.Groups,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                    )
                    Column {
                        Text(
                            "Pronostics côté clients",
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold,
                        )
                        Text(
                            "Tes clients pronostiquent le prochain match sur leur carte fidélité. " +
                                "Tu actives le jeu et les points ici — pas depuis l’app commerçant.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
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
                                "Bandeau sur le flyer + bloc sur la carte client.",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        Switch(checked = enabled, onCheckedChange = { enabled = it })
                    }
                    Spacer(Modifier.height(12.dp))
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Text("Points par bon pronostic", Modifier.weight(1f))
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

            if (enabled) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Text(
                            "Prochain match (aperçu client)",
                            style = MaterialTheme.typography.titleSmall,
                        )
                        Spacer(Modifier.height(12.dp))
                        val match = nextMatch
                        if (match == null) {
                            Text(
                                "Aucun match ouvert pour l’instant. Le calendrier se met à jour automatiquement.",
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        } else {
                            NextMatchPreviewCard(
                                match = match,
                                predictionsCount = predictionsOnNext,
                                totalPredictions = totalPredictions,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun NextMatchPreviewCard(
    match: NextMatchPreview,
    predictionsCount: Int,
    totalPredictions: Int,
) {
    Column(
        Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            match.roundLabel ?: match.title ?: "Phase de groupes",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.primary,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.height(12.dp))
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TeamColumn(
                flag = match.teamHomeFlag,
                name = match.teamHome,
                modifier = Modifier.weight(1f),
            )
            Text("VS", style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Black)
            TeamColumn(
                flag = match.teamAwayFlag,
                name = match.teamAway,
                modifier = Modifier.weight(1f),
            )
        }
        Spacer(Modifier.height(8.dp))
        Text(
            formatMatchDate(match.startsAt),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            buildString {
                append("$predictionsCount pronostics")
                if (totalPredictions > 0) append(" · $totalPredictions au total")
            },
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

@Composable
private fun RowScope.TeamColumn(flag: String?, name: String, modifier: Modifier = Modifier) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier,
    ) {
        Text(flag ?: "🏳️", fontSize = 36.sp)
        Text(
            name,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            maxLines = 2,
        )
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
        DateTimeFormatter.ofPattern("EEEE d MMMM HH:mm", Locale.FRANCE)
            .withZone(ZoneId.systemDefault())
            .format(instant)
    }.getOrDefault(raw)
}
