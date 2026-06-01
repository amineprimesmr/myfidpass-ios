package fr.myfidpass.ui.screens.scanner

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.TextButton
import fr.myfidpass.data.dto.BusinessSettingsResponse
import fr.myfidpass.data.dto.PointsRewardTierDto
import fr.myfidpass.data.dto.ScanRequest
import fr.myfidpass.data.dto.isApiTrue
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.services.scan.ReceiptTicketScanSession
import fr.myfidpass.ui.components.SlideToConfirm
import fr.myfidpass.ui.screens.scanner.ReceiptTicketValidationScreen
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

data class ScanFlowArgs(
    val memberId: String,
    val memberName: String,
    val barcode: String,
    val memberPoints: Int?,
)

private fun shouldUseEuroAmountFlow(settings: BusinessSettingsResponse?): Boolean {
    if (settings == null) return false
    val pt = settings.programType?.trim()?.lowercase().orEmpty()
    if (pt == "stamps") return false
    if (pt == "points") return true
    val lm = settings.loyaltyMode?.lowercase().orEmpty()
    if (lm.contains("point") || lm.contains("cash")) return true
    return (settings.pointsPerEuro ?: 0) > 0
}

private fun shouldUseStampVisitFlow(settings: BusinessSettingsResponse?): Boolean {
    return settings?.programType?.trim()?.lowercase() == "stamps"
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddPointsAfterScanScreen(
    args: ScanFlowArgs,
    settings: BusinessSettingsResponse?,
    repository: DashboardRepository,
    snackbar: SnackbarHostState,
    onDone: () -> Unit,
    onOpenMember: () -> Unit,
    onScanSuccessToast: ((String) -> Unit)? = null,
) {
    val scope = rememberCoroutineScope()
    var loading by remember { mutableStateOf(false) }
    var receiptSession by remember { mutableStateOf<ReceiptTicketScanSession?>(null) }
    var pendingRedeemTier by remember { mutableStateOf<PointsRewardTierDto?>(null) }
    var confirmRedeemTier by remember { mutableStateOf<PointsRewardTierDto?>(null) }
    val memberPoints = args.memberPoints ?: 0
    val rewardTiers = settings?.pointsRewardTiers.orEmpty().filter { it.points > 0 }
    val pointsPerVisit = settings?.pointsPerVisit ?: 0
    val requiredStamps = settings?.requiredStamps ?: 10
    var amountDigits by remember { mutableStateOf("") }
    var amountHasComma by remember { mutableStateOf(false) }
    var amountFrac by remember { mutableStateOf("") }

    fun amountEuros(): Double {
        val intPart = amountDigits.ifEmpty { "0" }.toDoubleOrNull() ?: 0.0
        val frac = if (amountFrac.isEmpty()) 0.0 else amountFrac.toDoubleOrNull()?.div(
            when (amountFrac.length) {
                1 -> 10.0
                else -> 100.0
            },
        ) ?: 0.0
        return intPart + frac
    }

    fun appendDigit(d: Int) {
        if (amountHasComma) {
            if (amountFrac.length >= 2) return
            amountFrac += d.toString()
        } else {
            if (amountDigits == "0" && d == 0) return
            if (amountDigits == "0") amountDigits = d.toString()
            else if (amountDigits.length < 7) amountDigits += d.toString()
        }
    }

    fun appendComma() {
        if (amountHasComma) return
        amountHasComma = true
        if (amountDigits.isEmpty()) amountDigits = "0"
    }

    fun backspace() {
        when {
            amountFrac.isNotEmpty() -> amountFrac = amountFrac.dropLast(1)
            amountHasComma -> amountHasComma = false
            amountDigits.isNotEmpty() -> amountDigits = amountDigits.dropLast(1)
        }
    }

    val pointsPerEuro = maxOf(1, settings?.pointsPerEuro ?: 1)
    val euros = amountEuros()
    val minEur = settings?.pointsMinAmountEur ?: 0.0
    val computedPoints = if (euros < minEur) 0 else (euros * pointsPerEuro).roundToInt()

    fun creditVisit() {
        val slug = repository.currentSlug() ?: return
        scope.launch {
            loading = true
            runCatching {
                repository.scan(
                    slug,
                    fr.myfidpass.data.dto.ScanRequest(
                        barcode = args.barcode,
                        visit = true,
                    ),
                )
            }.onSuccess {
                onScanSuccessToast?.invoke("Visite · ${args.memberName}")
                onDone()
            }.onFailure {
                snackbar.showSnackbar(it.message ?: "Erreur")
            }
            loading = false
        }
    }

    fun performScan(receiptToken: String?) {
        val slug = repository.currentSlug() ?: return
        scope.launch {
            loading = true
            runCatching {
                repository.scan(
                    slug,
                    fr.myfidpass.data.dto.ScanRequest(
                        barcode = args.barcode,
                        amountEur = euros,
                        points = if (computedPoints > 0) computedPoints else null,
                        receiptValidationToken = receiptToken,
                    ),
                )
            }.onSuccess {
                onScanSuccessToast?.invoke("+$computedPoints pts · ${args.memberName}")
                onDone()
            }.onFailure {
                snackbar.showSnackbar(it.message ?: "Erreur")
            }
            loading = false
        }
    }

    fun creditAmount() {
        val slug = repository.currentSlug() ?: return
        if (computedPoints <= 0 && euros > 0) {
            scope.launch {
                snackbar.showSnackbar("Montant insuffisant (minimum ${"%.2f".format(minEur)} €)")
            }
            return
        }
        val needsReceipt = settings?.requireReceiptQrValidation.isApiTrue() && euros > 0
        scope.launch {
            loading = true
            runCatching {
                if (needsReceipt) {
                    val ch = repository.receiptChallenge(slug, euros)
                    val payload = ch.qrPayload.trim()
                    if (payload.isEmpty()) error("Challenge ticket indisponible")
                    receiptSession = ReceiptTicketScanSession(
                        slug = slug,
                        amountEur = euros,
                        qrPayload = payload,
                        expiresAt = ch.expiresAt,
                    )
                } else {
                    performScan(null)
                }
            }.onFailure {
                snackbar.showSnackbar(it.message ?: "Erreur ticket")
            }
            loading = false
        }
    }

    suspend fun redeemTierConfirmed(tier: PointsRewardTierDto, receiptToken: String? = null) {
        val slug = repository.currentSlug() ?: return
        val before = memberPoints
        val ppe = maxOf(1, settings?.pointsPerEuro ?: 1)
        var earned = 0
        if (euros > 0) {
            if (euros < minEur - 1e-9) {
                snackbar.showSnackbar("Montant sous le minimum défini.")
                return
            }
            earned = (euros * ppe).roundToInt()
        }
        val after = before + earned
        loading = true
        runCatching {
            if (before >= tier.points) {
                repository.redeemPoints(slug, args.barcode, tier.points)
            } else if (earned > 0 && after >= tier.points) {
                repository.scan(
                    slug,
                    ScanRequest(
                        barcode = args.barcode,
                        amountEur = euros,
                        points = if (computedPoints > 0) computedPoints else null,
                        receiptValidationToken = receiptToken,
                    ),
                )
                val credited = repository.memberPublic(slug, args.barcode).points ?: after
                if (credited < tier.points) error("Solde insuffisant après crédit")
                repository.redeemPoints(slug, args.barcode, tier.points)
            } else {
                error("Créditez d'abord ${tier.points} pts pour « ${tier.label ?: "récompense"} ».")
            }
        }.onSuccess {
            snackbar.showSnackbar("Récompense offerte : ${tier.label ?: tier.points.toString() + " pts"}")
            onDone()
        }.onFailure {
            snackbar.showSnackbar(it.message ?: "Erreur")
        }
        loading = false
    }

    fun finishCreditWithReceipt(token: String?) {
        receiptSession = null
        if (token == null) {
            pendingRedeemTier = null
            return
        }
        val tier = pendingRedeemTier
        if (tier != null) {
            pendingRedeemTier = null
            scope.launch { redeemTierConfirmed(tier, token) }
        } else {
            performScan(token)
        }
    }

    fun startRedeemTier(tier: PointsRewardTierDto) {
        confirmRedeemTier = null
        val needsReceipt = settings?.requireReceiptQrValidation.isApiTrue() && euros > 0 &&
            memberPoints + computedPoints < tier.points
        if (needsReceipt) {
            val slug = repository.currentSlug() ?: return
            scope.launch {
                loading = true
                runCatching {
                    val ch = repository.receiptChallenge(slug, euros)
                    val payload = ch.qrPayload.trim()
                    if (payload.isEmpty()) error("Challenge ticket indisponible")
                    pendingRedeemTier = tier
                    receiptSession = ReceiptTicketScanSession(slug, euros, payload, ch.expiresAt)
                }.onFailure {
                    snackbar.showSnackbar(it.message ?: "Erreur ticket")
                }
                loading = false
            }
        } else {
            scope.launch { redeemTierConfirmed(tier, null) }
        }
    }

    fun redeemStampsReward() {
        val slug = repository.currentSlug() ?: return
        scope.launch {
            loading = true
            runCatching { repository.redeemStamps(slug, args.barcode) }
                .onSuccess {
                    snackbar.showSnackbar(it.message ?: "Tampons échangés")
                    onDone()
                }
                .onFailure { snackbar.showSnackbar(it.message ?: "Erreur") }
            loading = false
        }
    }

    receiptSession?.let { session ->
        ReceiptTicketValidationScreen(session = session, onComplete = { finishCreditWithReceipt(it) })
        return
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Créditer") },
                navigationIcon = {
                    IconButton(onClick = onDone) {
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
                args.memberName.ifBlank { "Client" },
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
            )
            Text(
                "Solde actuel : ${args.memberPoints ?: "—"} pts",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(16.dp))

            when {
                shouldUseStampVisitFlow(settings) -> {
                    Text(
                        "Programme tampons — enregistrer une visite.",
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    Spacer(Modifier.height(16.dp))
                    SlideToConfirm(
                        label = "Glisser pour enregistrer la visite",
                        enabled = !loading,
                        onConfirmed = { creditVisit() },
                    )
                    if (memberPoints >= requiredStamps) {
                        Spacer(Modifier.height(8.dp))
                        OutlinedButton(
                            onClick = { redeemStampsReward() },
                            enabled = !loading,
                            modifier = Modifier.fillMaxWidth(),
                        ) { Text("Utiliser la récompense (tampons)") }
                    }
                }
                shouldUseEuroAmountFlow(settings) -> {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(
                            containerColor = Color(0xFF2C2C2E),
                        ),
                        shape = RoundedCornerShape(16.dp),
                    ) {
                        Column(Modifier.padding(20.dp)) {
                            Text(
                                "Montant du panier",
                                color = Color.White.copy(alpha = 0.7f),
                                style = MaterialTheme.typography.labelMedium,
                            )
                            Text(
                                text = buildString {
                                    append(amountDigits.ifEmpty { "0" })
                                    if (amountHasComma) {
                                        append(",")
                                        append(amountFrac)
                                    }
                                } + " €",
                                color = Color.White,
                                style = MaterialTheme.typography.displaySmall,
                                fontWeight = FontWeight.Bold,
                            )
                            Spacer(Modifier.height(8.dp))
                            Text(
                                "+$computedPoints points ($pointsPerEuro pt/€)",
                                color = Color(0xFF34C759),
                                style = MaterialTheme.typography.titleMedium,
                            )
                        }
                    }
                    Spacer(Modifier.height(16.dp))
                    EuroKeypad(
                        onDigit = { appendDigit(it) },
                        onComma = { appendComma() },
                        onBackspace = { backspace() },
                    )
                    Spacer(Modifier.height(16.dp))
                    SlideToConfirm(
                        label = "Glisser pour créditer $computedPoints pts",
                        enabled = !loading && euros > 0 && computedPoints > 0,
                        tint = Color(0xFF34C759),
                        onConfirmed = { creditAmount() },
                    )
                    if (pointsPerVisit > 0) {
                        Spacer(Modifier.height(8.dp))
                        SlideToConfirm(
                            label = "Glisser — 1 passage (+$pointsPerVisit pt)",
                            enabled = !loading,
                            onConfirmed = { creditVisit() },
                        )
                    }
                    if (rewardTiers.isNotEmpty()) {
                        Spacer(Modifier.height(16.dp))
                        Text("Utiliser une récompense", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.height(8.dp))
                        rewardTiers.forEach { tier ->
                            val enabled = memberPoints >= tier.points || (computedPoints > 0 && memberPoints + computedPoints >= tier.points)
                            OutlinedButton(
                                onClick = { confirmRedeemTier = tier },
                                enabled = !loading && enabled,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(bottom = 6.dp),
                            ) {
                                Text("${tier.label ?: "${tier.points} pts"} (${tier.points} pts)")
                            }
                        }
                    }
                }
                else -> {
                    Text(
                        "Scan enregistré. Ouvrez la fiche membre pour plus d’actions.",
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    Spacer(Modifier.height(12.dp))
                    Button(onClick = onOpenMember, modifier = Modifier.fillMaxWidth()) {
                        Text("Voir la fiche membre")
                    }
                }
            }

            confirmRedeemTier?.let { tier ->
                AlertDialog(
                    onDismissRequest = { confirmRedeemTier = null },
                    title = { Text("Offrir la récompense ?") },
                    text = { Text("${tier.label ?: "${tier.points} points"} — ${tier.points} pts seront débités.") },
                    confirmButton = {
                        TextButton(onClick = { startRedeemTier(tier) }) { Text("Confirmer") }
                    },
                    dismissButton = {
                        TextButton(onClick = { confirmRedeemTier = null }) { Text("Annuler") }
                    },
                )
            }

            Spacer(Modifier.height(12.dp))
            OutlinedButton(onClick = onOpenMember, modifier = Modifier.fillMaxWidth()) {
                Text("Fiche membre complète")
            }
        }
    }
}

@Composable
private fun EuroKeypad(
    onDigit: (Int) -> Unit,
    onComma: () -> Unit,
    onBackspace: () -> Unit,
) {
    val rows = listOf(
        listOf("1", "2", "3"),
        listOf("4", "5", "6"),
        listOf("7", "8", "9"),
        listOf(",", "0", "⌫"),
    )
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        rows.forEach { row ->
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                row.forEach { key ->
                    OutlinedButton(
                        onClick = {
                            when (key) {
                                "," -> onComma()
                                "⌫" -> onBackspace()
                                else -> onDigit(key.toInt())
                            }
                        },
                        modifier = Modifier.weight(1f),
                    ) {
                        Text(key, style = MaterialTheme.typography.titleLarge)
                    }
                }
            }
        }
    }
}
