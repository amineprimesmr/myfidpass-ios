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
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.repo.DashboardRepository
import kotlinx.coroutines.launch
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EstablishmentEditorScreen(
    repository: DashboardRepository,
    snackbarHostState: SnackbarHostState,
    onBack: () -> Unit,
) {
    val slug = repository.currentSlug()
    val scope = rememberCoroutineScope()
    var loading by remember { mutableStateOf(true) }
    var saving by remember { mutableStateOf(false) }
    var orgName by remember { mutableStateOf("") }
    var bgColor by remember { mutableStateOf("") }
    var fgColor by remember { mutableStateOf("") }
    var labelColor by remember { mutableStateOf("") }
    var logoUrl by remember { mutableStateOf("") }
    var programType by remember { mutableStateOf("") }
    var loyaltyMode by remember { mutableStateOf("") }

    LaunchedEffect(slug) {
        if (slug == null) {
            loading = false
            return@LaunchedEffect
        }
        loading = true
        runCatching { repository.businessSettings(slug) }
            .onSuccess { s ->
                orgName = s.organizationName.orEmpty()
                bgColor = s.backgroundColor.orEmpty()
                fgColor = s.foregroundColor.orEmpty()
                labelColor = s.labelColor.orEmpty()
                logoUrl = s.logoUrl.orEmpty()
                programType = s.programType.orEmpty()
                loyaltyMode = s.loyaltyMode.orEmpty()
            }
        loading = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Fiche établissement") },
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
                "PATCH `/dashboard/settings` — mêmes clés que la réponse API (snake_case).",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(12.dp))
            if (loading) {
                CircularProgressIndicator()
                return@Column
            }
            OutlinedTextField(
                value = orgName,
                onValueChange = { orgName = it },
                label = { Text("Nom organisation") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = bgColor,
                onValueChange = { bgColor = it },
                label = { Text("Couleur fond (hex)") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = fgColor,
                onValueChange = { fgColor = it },
                label = { Text("Couleur premier plan") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = labelColor,
                onValueChange = { labelColor = it },
                label = { Text("Couleur labels") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = logoUrl,
                onValueChange = { logoUrl = it },
                label = { Text("URL logo") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = programType,
                onValueChange = { programType = it },
                label = { Text("Type programme") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = loyaltyMode,
                onValueChange = { loyaltyMode = it },
                label = { Text("Mode fidélité") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            Spacer(Modifier.height(16.dp))
            Button(
                onClick = {
                    val s = slug ?: return@Button
                    scope.launch {
                        saving = true
                        val body = buildJsonObject {
                            put("organization_name", orgName.trim())
                            put("background_color", bgColor.trim())
                            put("foreground_color", fgColor.trim())
                            put("label_color", labelColor.trim())
                            put("logo_url", logoUrl.trim())
                            put("program_type", programType.trim())
                            put("loyalty_mode", loyaltyMode.trim())
                        }
                        runCatching {
                            repository.patchDashboardSettings(s, body)
                            snackbarHostState.showSnackbar("Enregistré")
                        }.onFailure {
                            snackbarHostState.showSnackbar(it.message ?: "Erreur")
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
