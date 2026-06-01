package fr.myfidpass.ui.screens.commerce

import androidx.compose.foundation.clickable
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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonObject

private data class RewardEditRow(
    val code: String,
    val label: String,
    val kind: String,
    val weight: Int,
    val active: Boolean,
    val stock: Int?,
    val points: Int?,
    val stamps: Int?,
)

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
    var expandedCode by remember { mutableStateOf<String?>(null) }
    var ticketCost by remember { mutableStateOf("") }
    var dailyLimit by remember { mutableStateOf("") }
    var savingPatch by remember { mutableStateOf(false) }
    var rewardsDialogCode by remember { mutableStateOf<String?>(null) }
    var rewardsLoading by remember { mutableStateOf(false) }
    var rewardsSaving by remember { mutableStateOf(false) }
    var rewardRows by remember { mutableStateOf<List<RewardEditRow>>(emptyList()) }

    fun reloadGames() {
        val s = slug ?: return
        scope.launch {
            loading = true
            runCatching { games = repository.dashboardGames(s).games }
                .onFailure { snackbarHostState.showSnackbar(it.message ?: "Erreur") }
            loading = false
        }
    }

    LaunchedEffect(slug) { reloadGames() }

    fun loadRewards(gameCode: String) {
        val s = slug ?: return
        scope.launch {
            rewardsLoading = true
            runCatching {
                val json = repository.dashboardGameRewardsGet(s, gameCode)
                rewardRows = json["rewards"]?.jsonArray?.mapNotNull { el ->
                    val o = el.jsonObject
                    val code = o["code"]?.jsonPrimitive?.content ?: return@mapNotNull null
                    val value = o["value"]?.jsonObject
                    RewardEditRow(
                        code = code,
                        label = o["label"]?.jsonPrimitive?.content ?: code,
                        kind = o["kind"]?.jsonPrimitive?.content ?: "points",
                        weight = o["weight"]?.jsonPrimitive?.intOrNull ?: 1,
                        active = o["active"]?.jsonPrimitive?.content != "false",
                        stock = o["stock"]?.jsonPrimitive?.intOrNull,
                        points = value?.get("points")?.jsonPrimitive?.intOrNull,
                        stamps = value?.get("stamps")?.jsonPrimitive?.intOrNull,
                    )
                }.orEmpty()
                rewardsDialogCode = gameCode
            }.onFailure {
                snackbarHostState.showSnackbar(it.message ?: "Récompenses indisponibles")
            }
            rewardsLoading = false
        }
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
            Text(
                "Activez les jeux, ajustez le coût ticket et éditez les récompenses — aligné iOS.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(12.dp))
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
                val expanded = expandedCode == code
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 6.dp)
                        .clickable {
                            expandedCode = if (expanded) null else code
                            ticketCost = g.ticketCost?.toString().orEmpty()
                            dailyLimit = g.dailySpinLimit?.toString().orEmpty()
                        },
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                ) {
                    Column(Modifier.padding(12.dp)) {
                        Row(
                            Modifier.fillMaxWidth(),
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
                                            reloadGames()
                                        }.onFailure {
                                            snackbarHostState.showSnackbar(it.message ?: "Erreur")
                                        }
                                    }
                                },
                            )
                        }
                        if (expanded && code.isNotEmpty()) {
                            Spacer(Modifier.height(10.dp))
                            OutlinedTextField(
                                value = ticketCost,
                                onValueChange = { ticketCost = it.filter { c -> c.isDigit() } },
                                label = { Text("Coût ticket (points)") },
                                modifier = Modifier.fillMaxWidth(),
                                singleLine = true,
                            )
                            Spacer(Modifier.height(8.dp))
                            OutlinedTextField(
                                value = dailyLimit,
                                onValueChange = { dailyLimit = it.filter { c -> c.isDigit() } },
                                label = { Text("Limite quotidienne") },
                                modifier = Modifier.fillMaxWidth(),
                                singleLine = true,
                            )
                            Spacer(Modifier.height(8.dp))
                            Button(
                                onClick = {
                                    val s = slug ?: return@Button
                                    scope.launch {
                                        savingPatch = true
                                        runCatching {
                                            repository.dashboardPatchGame(
                                                s,
                                                code,
                                                PatchGameRequest(
                                                    ticketCost = ticketCost.toIntOrNull(),
                                                    dailySpinLimit = dailyLimit.toIntOrNull(),
                                                ),
                                            )
                                            reloadGames()
                                            snackbarHostState.showSnackbar("Jeu mis à jour")
                                        }.onFailure {
                                            snackbarHostState.showSnackbar(it.message ?: "Erreur")
                                        }
                                        savingPatch = false
                                    }
                                },
                                enabled = !savingPatch,
                                modifier = Modifier.fillMaxWidth(),
                            ) { Text(if (savingPatch) "…" else "Enregistrer les paramètres") }
                            Spacer(Modifier.height(8.dp))
                            OutlinedButton(
                                onClick = { loadRewards(code) },
                                modifier = Modifier.fillMaxWidth(),
                            ) { Text("Éditer les récompenses") }
                        }
                    }
                }
            }
        }
    }

    val dialogCode = rewardsDialogCode
    if (dialogCode != null) {
        AlertDialog(
            onDismissRequest = { rewardsDialogCode = null },
            title = { Text("Récompenses — $dialogCode") },
            text = {
                Column(Modifier.verticalScroll(rememberScrollState())) {
                    if (rewardsLoading) {
                        CircularProgressIndicator()
                    } else if (rewardRows.isEmpty()) {
                        Text("Aucune récompense configurée.")
                    } else {
                        rewardRows.forEachIndexed { idx, row ->
                            Row(
                                Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Column(Modifier.weight(1f)) {
                                    Text(row.label, style = MaterialTheme.typography.titleSmall)
                                    Text(
                                        "${row.kind} · poids ${row.weight}" +
                                            row.points?.let { " · +$it pts" }.orEmpty() +
                                            row.stamps?.let { " · +$it tampons" }.orEmpty(),
                                        style = MaterialTheme.typography.bodySmall,
                                    )
                                }
                                Switch(
                                    checked = row.active,
                                    onCheckedChange = { on ->
                                        rewardRows = rewardRows.toMutableList().also {
                                            it[idx] = row.copy(active = on)
                                        }
                                    },
                                )
                            }
                            Spacer(Modifier.height(8.dp))
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        val s = slug ?: return@TextButton
                        scope.launch {
                            rewardsSaving = true
                            runCatching {
                                val rewardsArray = kotlinx.serialization.json.buildJsonArray {
                                    rewardRows.forEach { r ->
                                        add(
                                            buildJsonObject {
                                                put("code", r.code)
                                                put("label", r.label)
                                                put("kind", r.kind)
                                                put("weight", r.weight)
                                                put("active", r.active)
                                                r.stock?.let { put("stock", it) }
                                                if (r.points != null || r.stamps != null) {
                                                    putJsonObject("value") {
                                                        r.points?.let { put("points", it) }
                                                        r.stamps?.let { put("stamps", it) }
                                                    }
                                                }
                                            },
                                        )
                                    }
                                }
                                repository.dashboardGameRewardsPut(
                                    s,
                                    dialogCode,
                                    buildJsonObject { put("rewards", rewardsArray) },
                                )
                                snackbarHostState.showSnackbar("Récompenses enregistrées")
                                rewardsDialogCode = null
                            }.onFailure {
                                snackbarHostState.showSnackbar(it.message ?: "Erreur")
                            }
                            rewardsSaving = false
                        }
                    },
                    enabled = !rewardsSaving && !rewardsLoading,
                ) { Text(if (rewardsSaving) "…" else "Enregistrer") }
            },
            dismissButton = {
                TextButton(onClick = { rewardsDialogCode = null }) { Text("Fermer") }
            },
        )
    }
}
