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
import fr.myfidpass.data.dto.BusinessMembersResponse
import fr.myfidpass.data.dto.MemberDto
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.services.sync.SyncService
import fr.myfidpass.util.MerchantTechnicalMember
import fr.myfidpass.util.shareFiles
import fr.myfidpass.util.writeTempExport
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private const val MEMBERS_PAGE_SIZE = 200

private suspend fun DashboardRepository.fetchAllMembers(
    slug: String,
    search: String? = null,
): BusinessMembersResponse {
    var offset = 0
    val collected = mutableListOf<MemberDto>()
    var total: Int? = null
    while (offset < 20_000) {
        val page = businessMembers(
            slug = slug,
            limit = MEMBERS_PAGE_SIZE,
            offset = offset,
            search = search?.trim()?.takeIf { it.isNotEmpty() },
        )
        total = page.total ?: total
        if (page.members.isEmpty()) break
        collected.addAll(page.members)
        if (page.members.size < MEMBERS_PAGE_SIZE) break
        offset += MEMBERS_PAGE_SIZE
    }
    return BusinessMembersResponse(
        members = collected,
        total = total ?: collected.size,
    )
}

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

    fun applyResponse(response: BusinessMembersResponse) {
        val real = response.members.filter {
            !MerchantTechnicalMember.shouldExcludeFromMerchantActivity(it.email)
        }
        members = real
        total = real.size
    }

    fun loadAll(search: String = query) {
        val currentSlug = slug ?: return
        scope.launch {
            loading = true
            error = null
            runCatching {
                syncService.syncIfNeeded(currentSlug, force = true)
                applyResponse(repository.fetchAllMembers(currentSlug, search = search))
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
                loadAll()
            }.onFailure {
                snackbarHostState.showSnackbar(it.message ?: "Import impossible")
            }
        }
    }

    LaunchedEffect(slug) {
        slug?.let { syncService.syncIfNeeded(it, force = true) }
        if (slug != null) loadAll("")
    }

    LaunchedEffect(slug, query) {
        val currentSlug = slug ?: return@LaunchedEffect
        val q = query.trim()
        searchJob?.cancel()
        if (q.isEmpty()) return@LaunchedEffect
        searchJob = scope.launch {
            delay(280)
            loading = true
            error = null
            runCatching {
                applyResponse(repository.fetchAllMembers(currentSlug, search = q))
            }.onFailure { error = it.message }
            loading = false
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Tous les clients${total?.let { " ($it)" } ?: ""}") },
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
                    if (q.trim().isEmpty()) {
                        searchJob?.cancel()
                        loadAll("")
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Nom, e-mail ou identifiant…") },
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
            if (loading && members.isEmpty()) {
                CircularProgressIndicator()
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            if (!loading && members.isEmpty() && error == null) {
                Text(
                    if (query.isBlank()) "Aucun client synchronisé." else "Aucun client trouvé.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
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
                                m.name?.ifBlank { m.email ?: "Client" } ?: "Client",
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
                                loadAll(query)
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
