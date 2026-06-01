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
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonObject

private val NETWORKS = listOf(
    "instagram" to "Instagram",
    "tiktok" to "TikTok",
    "facebook" to "Facebook",
    "twitter" to "X (Twitter)",
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SocialMissionsScreen(
    repository: DashboardRepository,
    snackbar: SnackbarHostState,
    onBack: () -> Unit,
) {
    val slug = repository.currentSlug()
    val scope = rememberCoroutineScope()
    var loading by remember { mutableStateOf(true) }
    var saving by remember { mutableStateOf(false) }
    var raw by remember { mutableStateOf<JsonObject?>(null) }
    val usernames = remember { mutableStateMapOf<String, String>() }
    val points = remember { mutableStateMapOf<String, String>() }
    val enabled = remember { mutableStateMapOf<String, Boolean>() }

    fun loadFromJson(json: JsonObject) {
        NETWORKS.forEach { (key, _) ->
            val node = json[key]?.jsonObject
            usernames[key] = node?.get("username")?.jsonPrimitive?.content.orEmpty()
            points[key] = (node?.get("points")?.jsonPrimitive?.content ?: "20")
            enabled[key] = when (val el = node?.get("enabled")) {
                null -> false
                else -> el.toString().contains("true", ignoreCase = true) || el.toString() == "1"
            }
        }
    }

    LaunchedEffect(slug) {
        if (slug == null) {
            loading = false
            return@LaunchedEffect
        }
        loading = true
        runCatching {
            raw = repository.dashboardSocialMissions(slug)
            raw?.let { loadFromJson(it) }
        }.onFailure { snackbar.showSnackbar(it.message ?: "Erreur") }
        loading = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Missions réseaux") },
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
                "Récompensez les clients qui vous suivent — aligné iOS SocialMissionsSheet.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(16.dp))
            NETWORKS.forEach { (key, label) ->
                Text(label, style = MaterialTheme.typography.titleSmall)
                Spacer(Modifier.height(6.dp))
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text("Actif", modifier = Modifier.weight(1f))
                    Switch(
                        checked = enabled[key] == true,
                        onCheckedChange = { enabled[key] = it },
                    )
                }
                OutlinedTextField(
                    value = usernames[key].orEmpty(),
                    onValueChange = { usernames[key] = it },
                    label = { Text("Pseudo @$key") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                Spacer(Modifier.height(6.dp))
                OutlinedTextField(
                    value = points[key].orEmpty(),
                    onValueChange = { points[key] = it.filter { c -> c.isDigit() } },
                    label = { Text("Points récompense") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                Spacer(Modifier.height(16.dp))
            }
            Button(
                onClick = {
                    val s = slug ?: return@Button
                    scope.launch {
                        saving = true
                        runCatching {
                            val body = buildJsonObject {
                                NETWORKS.forEach { (key, _) ->
                                    putJsonObject(key) {
                                        put("username", usernames[key].orEmpty().trim())
                                        put("enabled", enabled[key] == true)
                                        put("points", points[key]?.toIntOrNull() ?: 20)
                                    }
                                }
                            }
                            repository.dashboardSocialMissionsPatch(s, body)
                            snackbar.showSnackbar("Missions enregistrées")
                        }.onFailure {
                            snackbar.showSnackbar(it.message ?: "Erreur")
                        }
                        saving = false
                    }
                },
                enabled = !saving && slug != null,
                modifier = Modifier.fillMaxWidth(),
            ) { Text(if (saving) "Enregistrement…" else "Enregistrer") }
        }
    }
}
