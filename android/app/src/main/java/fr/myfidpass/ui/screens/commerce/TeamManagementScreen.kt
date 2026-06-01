package fr.myfidpass.ui.screens.commerce

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.dto.WorkspaceTeamMemberDto
import fr.myfidpass.data.dto.WorkspaceTeamTotalsDto
import fr.myfidpass.data.repo.DashboardRepository
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TeamManagementScreen(
    repository: DashboardRepository,
    snackbar: SnackbarHostState,
    onBack: () -> Unit,
    onOpenMember: (String) -> Unit,
) {
    val slug = repository.currentSlug()
    val scope = rememberCoroutineScope()
    var loading by remember { mutableStateOf(true) }
    var members by remember { mutableStateOf<List<WorkspaceTeamMemberDto>>(emptyList()) }
    var totals by remember { mutableStateOf<WorkspaceTeamTotalsDto?>(null) }
    var showAdd by remember { mutableStateOf(false) }
    var addEmail by remember { mutableStateOf("") }
    var addName by remember { mutableStateOf("") }
    var addRole by remember { mutableStateOf("staff") }
    var adding by remember { mutableStateOf(false) }

    fun reload() {
        if (slug == null) return
        scope.launch {
            loading = true
            runCatching { repository.workspaceTeamList(slug) }
                .onSuccess {
                    members = it.resolved()
                    totals = it.teamTotals
                }
                .onFailure { snackbar.showSnackbar(it.message ?: "Erreur") }
            loading = false
        }
    }

    LaunchedEffect(slug) { reload() }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Équipe") },
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
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(
                "Suivez l'activité caisse de chaque employé : scans, crédits et récompenses.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            totals?.let { t ->
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f))) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Vue d'ensemble", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Employés")
                            Text("${t.memberCount ?: members.count { !it.isOwner }}", fontWeight = FontWeight.Bold)
                        }
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Scans (30 j)")
                            Text("${t.scans30d ?: 0}", fontWeight = FontWeight.Bold)
                        }
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Scans total")
                            Text("${t.scanCount ?: 0}", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }

            Button(onClick = { showAdd = true }, modifier = Modifier.fillMaxWidth()) {
                Text("Ajouter un employé")
            }

            if (loading) {
                CircularProgressIndicator()
            } else if (members.isEmpty()) {
                Text("Aucun membre d'équipe.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            } else {
                members.forEach { m ->
                    TeamMemberListRow(m, onClick = {
                        m.apiMemberId?.let(onOpenMember)
                    })
                }
            }
        }
    }

    if (showAdd) {
        AlertDialog(
            onDismissRequest = { showAdd = false },
            title = { Text("Ajouter un employé") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = addEmail,
                        onValueChange = { addEmail = it },
                        label = { Text("E-mail") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                    )
                    OutlinedTextField(
                        value = addName,
                        onValueChange = { addName = it },
                        label = { Text("Nom (optionnel)") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                    )
                    Text("Rôle", style = MaterialTheme.typography.labelMedium)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        RadioButton(selected = addRole == "staff", onClick = { addRole = "staff" })
                        Text("Employé")
                        Spacer(Modifier.size(16.dp))
                        RadioButton(selected = addRole == "manager", onClick = { addRole = "manager" })
                        Text("Gérant")
                    }
                    Text(
                        "L'employé recevra un e-mail d'invitation avec les liens App Store et Google Play. Connexion par e-mail uniquement.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        val s = slug ?: return@TextButton
                        if (addEmail.isBlank()) return@TextButton
                        scope.launch {
                            adding = true
                            runCatching {
                                repository.businessTeamStaffAccount(
                                    s,
                                    email = addEmail.trim(),
                                    name = addName.trim().ifBlank { null },
                                    role = addRole,
                                )
                            }.onSuccess {
                                snackbar.showSnackbar(it.message ?: "Employé ajouté")
                                showAdd = false
                                addEmail = ""
                                addName = ""
                                addRole = "staff"
                                reload()
                            }.onFailure {
                                snackbar.showSnackbar(it.message ?: "Erreur")
                            }
                            adding = false
                        }
                    },
                    enabled = !adding && addEmail.contains("@"),
                ) { Text(if (adding) "…" else "Inviter") }
            },
            dismissButton = {
                TextButton(onClick = { showAdd = false }) { Text("Annuler") }
            },
        )
    }
}

@Composable
private fun TeamMemberListRow(member: WorkspaceTeamMemberDto, onClick: () -> Unit) {
    val clickable = member.apiMemberId != null
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (clickable) Modifier.clickable(onClick = onClick) else Modifier),
    ) {
        Row(
            Modifier.padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TeamMemberAvatarChip(member.displayName, member.role)
            Spacer(Modifier.size(12.dp))
            Column(Modifier.weight(1f)) {
                Text(member.displayName, fontWeight = FontWeight.SemiBold)
                Text(TeamUi.roleLabel(member.role), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                val scans = member.scanCount ?: 0
                Text(
                    if (scans > 0) "$scans scan(s) · ${member.scans7d ?: 0} cette semaine" else "Aucune activité caisse",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (clickable) {
                Icon(Icons.Default.ChevronRight, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
fun TeamMemberAvatarChip(name: String, role: String?) {
    val initials = name.split(" ").take(2).mapNotNull { it.firstOrNull()?.uppercaseChar()?.toString() }.joinToString("").ifBlank { "?" }
    val color = when (role?.lowercase()) {
        "owner" -> MaterialTheme.colorScheme.tertiary
        "manager" -> MaterialTheme.colorScheme.primary
        else -> MaterialTheme.colorScheme.secondary
    }
    Text(
        initials,
        modifier = Modifier
            .size(44.dp)
            .clip(CircleShape)
            .background(color.copy(alpha = 0.18f))
            .padding(10.dp),
        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold, color = color),
    )
}

object TeamUi {
    fun roleLabel(role: String?): String = when (role?.lowercase()) {
        "owner" -> "Propriétaire"
        "manager" -> "Gérant"
        "staff" -> "Employé"
        else -> role ?: "—"
    }

    fun activityLabel(type: String?, points: Int?, amountEur: Double?): String = when (type?.lowercase()) {
        "points_add" -> buildString {
            append("Crédit de points")
            points?.takeIf { it != 0 }?.let { append(" (+$it)") }
            amountEur?.takeIf { it > 0 }?.let { append(" · %.2f €".format(it)) }
        }
        "reward_redeem" -> "Récompense utilisée"
        "points_correction" -> "Correction de points"
        else -> type ?: "Opération caisse"
    }
}
