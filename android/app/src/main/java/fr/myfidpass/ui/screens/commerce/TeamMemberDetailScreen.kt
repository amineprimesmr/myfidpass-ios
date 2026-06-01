package fr.myfidpass.ui.screens.commerce

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.dto.WorkspaceTeamActivityDto
import fr.myfidpass.data.dto.WorkspaceTeamMemberDto
import fr.myfidpass.data.repo.DashboardRepository
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TeamMemberDetailScreen(
    repository: DashboardRepository,
    memberId: String,
    snackbar: SnackbarHostState,
    onBack: () -> Unit,
    onRevoked: () -> Unit,
) {
    val slug = repository.currentSlug()
    val scope = rememberCoroutineScope()
    var loading by remember { mutableStateOf(true) }
    var member by remember { mutableStateOf<WorkspaceTeamMemberDto?>(null) }
    var activity by remember { mutableStateOf<List<WorkspaceTeamActivityDto>>(emptyList()) }
    var showRevoke by remember { mutableStateOf(false) }
    var showRename by remember { mutableStateOf(false) }
    var renameDraft by remember { mutableStateOf("") }
    var actionBusy by remember { mutableStateOf(false) }

    fun reload() {
        val s = slug ?: return
        scope.launch {
            loading = true
            runCatching { repository.workspaceTeamMemberDetail(s, memberId) }
                .onSuccess {
                    member = it.member
                    activity = it.recentActivity
                }
                .onFailure { snackbar.showSnackbar(it.message ?: "Erreur") }
            loading = false
        }
    }

    LaunchedEffect(slug, memberId) { reload() }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(member?.displayName ?: "Employé") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Retour")
                    }
                },
                actions = {
                    IconButton(onClick = { reload() }) { Text("↻") }
                },
            )
        },
    ) { padding ->
        if (loading && member == null) {
            CircularProgressIndicator(Modifier.padding(padding).padding(24.dp))
        } else {
            Column(
                Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(16.dp)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                member?.let { m ->
                    profileSection(m)
                    statsSection(m)
                    if (activity.isNotEmpty()) {
                        activitySection(activity)
                    }
                    if (!m.isOwner) {
                        actionsSection(
                            member = m,
                            actionBusy = actionBusy,
                            onRename = {
                                renameDraft = m.name ?: ""
                                showRename = true
                            },
                            onSetRole = { role ->
                                val s = slug ?: return@actionsSection
                                scope.launch {
                                    actionBusy = true
                                    runCatching { repository.workspaceTeamMemberPatch(s, memberId, role = role) }
                                        .onSuccess {
                                            snackbar.showSnackbar("Rôle mis à jour")
                                            reload()
                                        }
                                        .onFailure { snackbar.showSnackbar(it.message ?: "Erreur") }
                                    actionBusy = false
                                }
                            },
                            onResend = {
                                val s = slug ?: return@actionsSection
                                scope.launch {
                                    actionBusy = true
                                    runCatching { repository.workspaceTeamMemberResendAccess(s, memberId) }
                                        .onSuccess { snackbar.showSnackbar(it.message ?: "E-mail envoyé") }
                                        .onFailure { snackbar.showSnackbar(it.message ?: "Erreur") }
                                    actionBusy = false
                                }
                            },
                            onRevoke = { showRevoke = true },
                        )
                    }
                }
            }
        }
    }

    if (showRename) {
        AlertDialog(
            onDismissRequest = { showRename = false },
            title = { Text("Modifier le nom") },
            text = {
                OutlinedTextField(
                    value = renameDraft,
                    onValueChange = { renameDraft = it },
                    label = { Text("Nom affiché") },
                    modifier = Modifier.fillMaxWidth(),
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        val s = slug ?: return@TextButton
                        scope.launch {
                            actionBusy = true
                            runCatching {
                                repository.workspaceTeamMemberPatch(s, memberId, name = renameDraft.trim())
                            }.onSuccess {
                                snackbar.showSnackbar("Nom mis à jour")
                                showRename = false
                                reload()
                            }.onFailure { snackbar.showSnackbar(it.message ?: "Erreur") }
                            actionBusy = false
                        }
                    },
                ) { Text("Enregistrer") }
            },
            dismissButton = { TextButton(onClick = { showRename = false }) { Text("Annuler") } },
        )
    }

    if (showRevoke) {
        AlertDialog(
            onDismissRequest = { showRevoke = false },
            title = { Text("Retirer l'accès ?") },
            text = { Text("Cet employé ne pourra plus accéder à ce commerce.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        val s = slug ?: return@TextButton
                        scope.launch {
                            actionBusy = true
                            runCatching { repository.workspaceTeamRevoke(s, memberId) }
                                .onSuccess {
                                    snackbar.showSnackbar("Accès retiré")
                                    showRevoke = false
                                    onRevoked()
                                }
                                .onFailure { snackbar.showSnackbar(it.message ?: "Erreur") }
                            actionBusy = false
                        }
                    },
                ) { Text("Retirer") }
            },
            dismissButton = { TextButton(onClick = { showRevoke = false }) { Text("Annuler") } },
        )
    }
}

@Composable
private fun profileSection(m: WorkspaceTeamMemberDto) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                TeamMemberAvatarChip(m.displayName, m.role)
                Spacer(Modifier.size(12.dp))
                Column {
                    Text(m.displayName, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Text(TeamUi.roleLabel(m.role), color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            m.email?.takeIf { it.isNotBlank() }?.let { Text("E-mail : $it", style = MaterialTheme.typography.bodySmall) }
            m.createdAt?.let { Text("Ajouté le : ${it.take(10)}", style = MaterialTheme.typography.bodySmall) }
            m.invitedByLabel?.let { Text("Invité par : $it", style = MaterialTheme.typography.bodySmall) }
        }
    }
}

@Composable
private fun statsSection(m: WorkspaceTeamMemberDto) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Activité caisse", fontWeight = FontWeight.SemiBold)
            statRow("Scans total", m.scanCount ?: 0)
            statRow("7 jours", m.scans7d ?: 0)
            statRow("30 jours", m.scans30d ?: 0)
            statRow("Crédits pts", m.pointsAddCount ?: 0)
            statRow("Récompenses", m.rewardRedeemCount ?: 0)
            statRow("Points attribués", m.pointsIssued ?: 0)
            m.amountEurSum?.takeIf { it > 0 }?.let {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("Montants saisis", style = MaterialTheme.typography.bodyMedium)
                    Text("%.2f €".format(it), fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
private fun statRow(label: String, value: Int) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, style = MaterialTheme.typography.bodyMedium)
        Text("$value", fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun activitySection(items: List<WorkspaceTeamActivityDto>) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("Activité récente", fontWeight = FontWeight.SemiBold)
            items.forEach { row ->
                Column {
                    Text(TeamUi.activityLabel(row.type, row.points, row.amountEur), fontWeight = FontWeight.Medium)
                    row.memberName?.let { Text(it, style = MaterialTheme.typography.bodySmall) }
                    row.createdAt?.let {
                        Text(it.take(16).replace('T', ' '), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}

@Composable
private fun actionsSection(
    member: WorkspaceTeamMemberDto,
    actionBusy: Boolean,
    onRename: () -> Unit,
    onSetRole: (String) -> Unit,
    onResend: () -> Unit,
    onRevoke: () -> Unit,
) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Gestion du compte", fontWeight = FontWeight.SemiBold)
            OutlinedButton(onClick = onRename, enabled = !actionBusy, modifier = Modifier.fillMaxWidth()) {
                Text("Modifier le nom")
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(onClick = { onSetRole("staff") }, enabled = !actionBusy, modifier = Modifier.weight(1f)) {
                    Text("Employé")
                }
                OutlinedButton(onClick = { onSetRole("manager") }, enabled = !actionBusy, modifier = Modifier.weight(1f)) {
                    Text("Gérant")
                }
            }
            if (!member.email.isNullOrBlank()) {
                OutlinedButton(onClick = onResend, enabled = !actionBusy, modifier = Modifier.fillMaxWidth()) {
                    Text("Renvoyer l'invitation")
                }
            }
            Button(onClick = onRevoke, enabled = !actionBusy, modifier = Modifier.fillMaxWidth()) {
                Text("Retirer l'accès")
            }
        }
    }
}
