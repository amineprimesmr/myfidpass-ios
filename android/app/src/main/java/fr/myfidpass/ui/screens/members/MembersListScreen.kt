package fr.myfidpass.ui.screens.members

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.dto.MemberDto
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.services.sync.SyncService
import fr.myfidpass.util.shareFiles
import fr.myfidpass.util.writeTempExport
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MembersListScreen(
    repository: DashboardRepository,
    syncService: SyncService,
    snackbarHostState: SnackbarHostState,
    appScope: CoroutineScope,
    onBack: () -> Unit,
    onMemberClick: (String) -> Unit,
) {
    val slug = repository.currentSlug()
    val context = LocalContext.current
    var members by remember { mutableStateOf<List<MemberDto>>(emptyList()) }
    var total by remember { mutableStateOf<Int?>(null) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var query by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()
    var searchJob by remember { mutableStateOf<Job?>(null) }
    var showCreate by remember { mutableStateOf(false) }
    var newEmail by remember { mutableStateOf("") }
    var newName by remember { mutableStateOf("") }

    fun load(search: String) {
        if (slug == null) return
        scope.launch {
            loading = true
            error = null
            runCatching {
                val r = repository.businessMembers(slug, search = search.trim().takeIf { it.isNotEmpty() })
                members = r.members
                total = r.total
            }.onFailure { error = it.message }
            loading = false
        }
    }

    val pickImport = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        uri ?: return@rememberLauncherForActivityResult
        val s = slug ?: return@rememberLauncherForActivityResult
        scope.launch {
            runCatching {
                val csv = context.contentResolver.openInputStream(uri)?.bufferedReader()?.readText()
                    ?: error("Fichier illisible")
                repository.membersImport(s, csv)
                snackbarHostState.showSnackbar("Import terminé")
                load(query)
            }.onFailure {
                snackbarHostState.showSnackbar(it.message ?: "Import impossible")
            }
        }
    }

    LaunchedEffect(slug) {
        slug?.let { syncService.syncIfNeeded(it) }
    }

    LaunchedEffect(slug, query) {
        val s = slug ?: return@LaunchedEffect
        val q = query.trim()
        if (q.isEmpty()) {
            syncService.memberDao.observeBySlug(s).collect { cached ->
                members = cached.map { e ->
                    MemberDto(id = e.id, name = e.name, email = e.email, points = e.points)
                }
                if (total == null || cached.isNotEmpty()) total = members.size
                loading = false
            }
        }
    }

    LaunchedEffect(slug) {
        if (slug != null && query.trim().isEmpty() && members.isEmpty()) {
            // Fallback API si cache vide au premier lancement
            load("")
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Membres${total?.let { " ($it)" } ?: ""}") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Retour")
                    }
                },
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = { showCreate = true }) {
                Icon(Icons.Default.Add, contentDescription = "Créer un membre")
            }
        },
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp),
        ) {
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = query,
                onValueChange = { q ->
                    query = q
                    searchJob?.cancel()
                    if (q.trim().isEmpty()) return@OutlinedTextField
                    val currentSlug = slug ?: return@OutlinedTextField
                    searchJob = scope.launch {
                        delay(320)
                        val local = syncService.memberDao.search(currentSlug, q.trim())
                        if (local.isNotEmpty()) {
                            members = local.map { e ->
                                MemberDto(id = e.id, name = e.name, email = e.email, points = e.points)
                            }
                            total = members.size
                            loading = false
                        } else {
                            load(q)
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Recherche") },
                singleLine = true,
            )
            Spacer(Modifier.height(8.dp))
            OutlinedButton(
                onClick = {
                    val s = slug ?: return@OutlinedButton
                    scope.launch {
                        runCatching {
                            val bytes = repository.businessMembersExportCsv(s, query.trim().ifEmpty { null })
                            val file = writeTempExport(context, "exports", "membres-$s.csv", bytes)
                            shareFiles(context, listOf(file), "text/csv")
                        }.onFailure {
                            snackbarHostState.showSnackbar(it.message ?: "Export impossible")
                        }
                    }
                },
                enabled = slug != null,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Exporter CSV") }
            Spacer(Modifier.height(8.dp))
            OutlinedButton(
                onClick = { pickImport.launch("text/*") },
                enabled = slug != null,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Importer CSV") }
            Spacer(Modifier.height(12.dp))
            if (loading) {
                CircularProgressIndicator()
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            LazyColumn {
                items(members, key = { it.id }) { m ->
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 6.dp)
                            .clickable { onMemberClick(m.id) },
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    ) {
                        Column(Modifier.padding(14.dp)) {
                            Text(
                                m.name?.ifBlank { m.email ?: "Membre" } ?: "Membre",
                                style = MaterialTheme.typography.titleMedium,
                            )
                            m.email?.takeIf { it.isNotBlank() }?.let {
                                Text(it, style = MaterialTheme.typography.bodySmall)
                            }
                            Text(
                                "Points : ${m.points ?: "—"}",
                                style = MaterialTheme.typography.bodyMedium,
                            )
                        }
                    }
                }
            }
        }
    }

    if (showCreate) {
        AlertDialog(
            onDismissRequest = { showCreate = false },
            title = { Text("Nouveau membre") },
            text = {
                Column {
                    OutlinedTextField(
                        value = newEmail,
                        onValueChange = { newEmail = it },
                        label = { Text("E-mail") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                    )
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(
                        value = newName,
                        onValueChange = { newName = it },
                        label = { Text("Nom") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                    )
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        if (slug == null || newEmail.isBlank() || newName.isBlank()) return@TextButton
                        appScope.launch {
                            runCatching {
                                repository.createMember(slug, newEmail.trim(), newName.trim())
                                snackbarHostState.showSnackbar("Membre créé")
                                newEmail = ""
                                newName = ""
                                showCreate = false
                                load(query)
                            }.onFailure {
                                snackbarHostState.showSnackbar(it.message ?: "Erreur")
                            }
                        }
                    },
                ) { Text("Créer") }
            },
            dismissButton = {
                TextButton(onClick = { showCreate = false }) { Text("Annuler") }
            },
        )
    }
}
