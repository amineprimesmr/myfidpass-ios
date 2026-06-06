package fr.myfidpass.ui.screens.members

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
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.dto.isApiTrue
import fr.myfidpass.services.scan.ReceiptTicketScanSession
import fr.myfidpass.ui.screens.scanner.ReceiptTicketValidationScreen
import fr.myfidpass.data.dto.MemberGameRewardDto
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.util.openInCustomTab
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MemberDetailScreen(
    memberId: String,
    repository: DashboardRepository,
    sessionStore: SessionStore,
    onBack: () -> Unit,
    snackbar: SnackbarHostState,
) {
    val slug = sessionStore.currentBusinessSlug
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var name by remember { mutableStateOf<String?>(null) }
    var email by remember { mutableStateOf<String?>(null) }
    var points by remember { mutableStateOf<Int?>(null) }
    var pointsInput by remember { mutableStateOf("10") }
    var removeInput by remember { mutableStateOf("1") }
    var actionLoading by remember { mutableStateOf(false) }
    var ticketBalance by remember { mutableStateOf<Int?>(null) }
    var ticketsMode by remember { mutableStateOf<String?>(null) }
    var pointsPerTicket by remember { mutableStateOf<Int?>(null) }
    var showDelete by remember { mutableStateOf(false) }
    var convertPointsInput by remember { mutableStateOf("50") }
    var rewards by remember { mutableStateOf<List<MemberGameRewardDto>>(emptyList()) }
    var amountEurInput by remember { mutableStateOf("") }
    var receiptSession by remember { mutableStateOf<ReceiptTicketScanSession?>(null) }
    var pendingAmountCredit by remember { mutableStateOf<Double?>(null) }
    var settings by remember { mutableStateOf<fr.myfidpass.data.dto.BusinessSettingsResponse?>(null) }

    fun reload() {
        if (slug == null) return
        scope.launch {
            loading = true
            error = null
            runCatching { repository.memberPublic(slug, memberId) }
                .onSuccess { m ->
                    name = m.name
                    email = m.email
                    points = m.points
                }
                .onFailure { error = it.message }
            runCatching {
                val t = repository.memberTickets(slug, memberId)
                ticketBalance = t.ticketBalance
                ticketsMode = t.loyaltyMode
                pointsPerTicket = t.pointsPerTicket
            }
            runCatching {
                rewards = repository.memberRewardsList(slug, memberId).rewards
            }
            runCatching {
                settings = repository.businessSettings(slug)
            }
            loading = false
        }
    }

    LaunchedEffect(memberId, slug) {
        reload()
    }

    fun creditAmountEur(amount: Double, receiptToken: String? = null) {
        if (slug == null || amount <= 0) return
        scope.launch {
            actionLoading = true
            val ppe = maxOf(1, settings?.pointsPerEuro ?: 1)
            val pts = (amount * ppe).toInt()
            runCatching {
                repository.creditMemberPoints(
                    slug,
                    memberId,
                    amountEur = amount,
                    points = if (pts > 0) pts else null,
                    receiptValidationToken = receiptToken,
                )
            }.onSuccess {
                points = it.newBalance ?: points
                snackbar.showSnackbar("+$pts points")
                reload()
            }.onFailure {
                snackbar.showSnackbar(it.message ?: "Erreur")
            }
            actionLoading = false
        }
    }

    fun submitAmountCredit() {
        val amount = amountEurInput.replace(',', '.').toDoubleOrNull() ?: return
        if (slug == null || amount <= 0) return
        if (settings?.requireReceiptQrValidation.isApiTrue()) {
            scope.launch {
                actionLoading = true
                runCatching {
                    val ch = repository.receiptChallenge(slug, amount)
                    val payload = ch.qrPayload.trim()
                    if (payload.isEmpty()) error("Challenge ticket indisponible")
                    pendingAmountCredit = amount
                    receiptSession = ReceiptTicketScanSession(slug, amount, payload, ch.expiresAt)
                }.onFailure {
                    snackbar.showSnackbar(it.message ?: "Erreur ticket")
                }
                actionLoading = false
            }
        } else {
            creditAmountEur(amount)
        }
    }

    receiptSession?.let { session ->
        ReceiptTicketValidationScreen(session = session) { token ->
            receiptSession = null
            val amt = pendingAmountCredit
            pendingAmountCredit = null
            if (token != null && amt != null) creditAmountEur(amt, token)
        }
        return
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Fiche membre") },
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
            error?.let {
                Text(it, color = MaterialTheme.colorScheme.error)
                Spacer(Modifier.height(12.dp))
            }
            Text(
                name?.ifBlank { email ?: "Membre" } ?: "Membre",
                style = MaterialTheme.typography.headlineSmall,
            )
            email?.takeIf { it.isNotBlank() }?.let {
                Text(it, style = MaterialTheme.typography.bodyMedium)
            }
            Spacer(Modifier.height(8.dp))
            Text(
                "Solde : ${points ?: "—"} pts",
                style = MaterialTheme.typography.titleMedium,
            )
            if (ticketBalance != null || ticketsMode != null) {
                Spacer(Modifier.height(6.dp))
                Text(
                    "Tickets : ${ticketBalance ?: "—"} · Mode : ${ticketsMode ?: "—"}" +
                        (pointsPerTicket?.let { " · $it pts / ticket" } ?: ""),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = convertPointsInput,
                onValueChange = { convertPointsInput = it.filter { c -> c.isDigit() } },
                label = { Text("Points → tickets") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            Spacer(Modifier.height(8.dp))
            OutlinedButton(
                onClick = {
                    val pts = convertPointsInput.toIntOrNull() ?: return@OutlinedButton
                    if (slug == null || pts <= 0) return@OutlinedButton
                    scope.launch {
                        actionLoading = true
                        runCatching {
                            repository.memberTicketsConvert(slug, memberId, pts)
                            snackbar.showSnackbar("Conversion demandée")
                            reload()
                        }.onFailure {
                            snackbar.showSnackbar(it.message ?: "Erreur")
                        }
                        actionLoading = false
                    }
                },
                enabled = !actionLoading && slug != null && convertPointsInput.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Convertir des points en tickets") }
            Spacer(Modifier.height(20.dp))
            if (rewards.isNotEmpty()) {
                Text("Récompenses jeu", style = MaterialTheme.typography.titleSmall)
                Spacer(Modifier.height(8.dp))
                rewards.forEach { r ->
                    val gid = r.id
                    val label = r.reward?.label ?: r.reward?.code ?: gid ?: "Récompense"
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            "$label · ${r.status ?: "—"}",
                            modifier = Modifier.weight(1f),
                            style = MaterialTheme.typography.bodySmall,
                        )
                        if (!gid.isNullOrBlank() && !r.status.equals("claimed", true)) {
                            TextButton(
                                onClick = {
                                    if (slug == null) return@TextButton
                                    scope.launch {
                                        runCatching {
                                            repository.claimMemberReward(slug, memberId, gid)
                                            snackbar.showSnackbar("Récompense réclamée")
                                            reload()
                                        }.onFailure {
                                            snackbar.showSnackbar(it.message ?: "Erreur")
                                        }
                                    }
                                },
                            ) { Text("Réclamer") }
                        }
                    }
                }
                Spacer(Modifier.height(16.dp))
            }
            Spacer(Modifier.height(8.dp))
            OutlinedButton(
                onClick = {
                    if (slug == null) return@OutlinedButton
                    scope.launch {
                        actionLoading = true
                        val r = runCatching {
                            repository.creditMemberPoints(slug, memberId, visit = true)
                        }
                        actionLoading = false
                        r.onSuccess {
                            points = it.newBalance ?: points
                            snackbar.showSnackbar("Visite enregistrée")
                            reload()
                        }.onFailure {
                            snackbar.showSnackbar(it.message ?: "Erreur")
                        }
                    }
                },
                enabled = !actionLoading && slug != null,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Enregistrer une visite (tampon)") }
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = amountEurInput,
                onValueChange = { amountEurInput = it.filter { c -> c.isDigit() || c == '.' || c == ',' } },
                label = { Text("Montant € (crédit points)") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            Spacer(Modifier.height(8.dp))
            OutlinedButton(
                onClick = { submitAmountCredit() },
                enabled = !actionLoading && slug != null && amountEurInput.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Créditer via montant €") }
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = pointsInput,
                onValueChange = { pointsInput = it.filter { c -> c.isDigit() } },
                label = { Text("Points à créditer") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            Spacer(Modifier.height(8.dp))
            Button(
                onClick = {
                    val p = pointsInput.toIntOrNull() ?: return@Button
                    if (slug == null) return@Button
                    scope.launch {
                        actionLoading = true
                        val r = runCatching {
                            repository.creditMemberPoints(slug, memberId, points = p)
                        }
                        actionLoading = false
                        r.onSuccess {
                            points = it.newBalance ?: (points?.plus(p))
                            snackbar.showSnackbar("+$p points")
                            reload()
                        }.onFailure {
                            snackbar.showSnackbar(it.message ?: "Erreur")
                        }
                    }
                },
                enabled = !actionLoading && slug != null && pointsInput.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Créditer les points") }
            Spacer(Modifier.height(16.dp))
            OutlinedTextField(
                value = removeInput,
                onValueChange = { removeInput = it.filter { c -> c.isDigit() } },
                label = { Text("Points à retirer (correction)") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            Spacer(Modifier.height(8.dp))
            OutlinedButton(
                onClick = {
                    val p = removeInput.toIntOrNull() ?: return@OutlinedButton
                    if (slug == null || p <= 0) return@OutlinedButton
                    scope.launch {
                        actionLoading = true
                        val r = runCatching {
                            repository.removeMemberPoints(slug, memberId, p)
                        }
                        actionLoading = false
                        r.onSuccess {
                            points = it.newBalance ?: points
                            snackbar.showSnackbar("-$p points")
                            reload()
                        }.onFailure {
                            snackbar.showSnackbar(it.message ?: "Erreur")
                        }
                    }
                },
                enabled = !actionLoading && slug != null && removeInput.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Retirer des points") }
            Spacer(Modifier.height(12.dp))
            OutlinedButton(
                onClick = {
                    if (slug == null) return@OutlinedButton
                    scope.launch {
                        val r = runCatching { repository.redeemStamps(slug, memberId) }
                        r.onSuccess {
                            points = it.newPoints ?: points
                            snackbar.showSnackbar(it.message ?: "Tampons échangés")
                            reload()
                        }.onFailure {
                            snackbar.showSnackbar(it.message ?: "Erreur")
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Échanger les tampons (récompense)") }
            Spacer(Modifier.height(16.dp))
            OutlinedButton(
                onClick = {
                    if (slug == null) return@OutlinedButton
                    scope.launch {
                        val r = runCatching { repository.googleWalletMemberUrl(slug, memberId) }
                        r.onSuccess { resp ->
                            val url = resp.url?.trim()
                            if (!url.isNullOrEmpty()) {
                                openInCustomTab(context, url)
                            } else {
                                snackbar.showSnackbar("Lien Google Wallet indisponible")
                            }
                        }.onFailure {
                            snackbar.showSnackbar(it.message ?: "Erreur")
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Ajouter au Google Wallet (client)") }
            Spacer(Modifier.height(24.dp))
            OutlinedButton(
                onClick = { showDelete = true },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Supprimer ce membre", color = MaterialTheme.colorScheme.error) }
        }
    }

    if (showDelete) {
        AlertDialog(
            onDismissRequest = { showDelete = false },
            title = { Text("Supprimer le membre ?") },
            text = { Text("Pass, historique et données associés seront supprimés côté serveur.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        if (slug == null) return@TextButton
                        scope.launch {
                            runCatching {
                                repository.deleteDashboardMember(slug, memberId)
                                snackbar.showSnackbar("Membre supprimé")
                                showDelete = false
                                onBack()
                            }.onFailure {
                                snackbar.showSnackbar(it.message ?: "Erreur")
                            }
                        }
                    },
                ) { Text("Supprimer", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { showDelete = false }) { Text("Annuler") }
            },
        )
    }
}
