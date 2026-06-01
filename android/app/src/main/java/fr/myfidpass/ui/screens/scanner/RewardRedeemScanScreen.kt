package fr.myfidpass.ui.screens.scanner

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CardGiftcard
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.ui.components.SlideToConfirm
import fr.myfidpass.ui.theme.Primary
import fr.myfidpass.util.qrCodeImageBitmap
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

data class RewardRedeemScanArgs(
    val memberName: String,
    val barcode: String,
    val rewardLabel: String,
    val pointsRequired: Int,
    val pointsBalance: Int,
    val eligible: Boolean,
    val mode: String,
)

private sealed class ParsedRewardQr {
    data class Points(val tierIndex: Int, val points: Int) : ParsedRewardQr()
    data object Stamps : ParsedRewardQr()
}

private fun parseRewardQr(raw: String): ParsedRewardQr? {
    val prefix = "MYFIDPASS_REDEEM:"
    val s = raw.trim()
    if (!s.uppercase().startsWith(prefix)) return null
    val parts = s.drop(prefix.length).split(":")
    if (parts.size < 3 || parts[0].toIntOrNull() != 1) return null
    return when (parts[2].lowercase()) {
        "s" -> ParsedRewardQr.Stamps
        "p" -> {
            if (parts.size < 5) return null
            val tier = parts[3].toIntOrNull() ?: return null
            val pts = parts[4].toIntOrNull() ?: return null
            if (pts <= 0) return null
            ParsedRewardQr.Points(tier, pts)
        }
        else -> null
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RewardRedeemScanScreen(
    args: RewardRedeemScanArgs,
    repository: DashboardRepository,
    snackbar: SnackbarHostState,
    onDone: () -> Unit,
    onScanSuccessToast: ((String) -> Unit)? = null,
) {
    val scope = rememberCoroutineScope()
    var loading by remember { mutableStateOf(false) }
    var validated by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    val displayName = args.memberName.trim().ifBlank { "Client" }
    val qrImage = remember(args.barcode) { qrCodeImageBitmap(args.barcode, 256) }
    val parsed = remember(args.barcode) { parseRewardQr(args.barcode) }
    val initials = remember(displayName) {
        displayName.split(" ").take(2).mapNotNull { it.firstOrNull()?.uppercaseChar() }.joinToString("").ifBlank { "?" }
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text("Récompense") },
                navigationIcon = {
                    IconButton(onClick = onDone, enabled = !loading) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Retour")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
        bottomBar = {
            if (args.eligible && !validated) {
                Surface(
                    tonalElevation = 2.dp,
                    shadowElevation = 8.dp,
                ) {
                    Column(Modifier.padding(horizontal = 20.dp, vertical = 12.dp)) {
                        SlideToConfirm(
                            label = "Glisser pour valider la récompense",
                            onConfirmed = {
                                val slug = repository.currentSlug() ?: return@SlideToConfirm
                                scope.launch {
                                    loading = true
                                    errorMessage = null
                                    runCatching { repository.integrationRewardRedeem(slug, args.barcode) }
                                        .onSuccess { res ->
                                            validated = true
                                            val label = res.rewardLabel ?: args.rewardLabel
                                            onScanSuccessToast?.invoke("$displayName — $label")
                                            delay(900)
                                            onDone()
                                        }
                                        .onFailure { e ->
                                            errorMessage = e.message ?: "Validation impossible"
                                            snackbar.showSnackbar(errorMessage!!)
                                        }
                                    loading = false
                                }
                            },
                            enabled = !loading && (args.mode == "stamps" || args.pointsRequired > 0),
                        )
                    }
                }
            }
        },
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Box(
                    Modifier
                        .size(52.dp)
                        .clip(CircleShape)
                        .background(Primary.copy(alpha = 0.14f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(initials, fontWeight = FontWeight.Bold, color = Primary, fontSize = 18.sp)
                }
                Column {
                    Text(displayName, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                    Text(
                        "Récompense à valider en caisse",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            Surface(
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surfaceVariant,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.CardGiftcard, contentDescription = null, tint = Color(0xFFFF8C33))
                        Text(args.rewardLabel, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    }
                    if (args.mode == "stamps") {
                        Text(
                            "${args.pointsBalance} tampons · objectif ${args.pointsRequired}",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                        )
                    } else {
                        Row(Modifier.fillMaxWidth()) {
                            Column(Modifier.weight(1f)) {
                                Text("Coût", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                Text(
                                    "${args.pointsRequired} pts",
                                    style = MaterialTheme.typography.headlineMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = if (args.pointsRequired > 0) MaterialTheme.colorScheme.onSurface else Color(0xFFE65100),
                                )
                            }
                            Column(Modifier.weight(1f)) {
                                Text("Solde", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                Text(
                                    "${args.pointsBalance} pts",
                                    style = MaterialTheme.typography.headlineMedium,
                                    fontWeight = FontWeight.Bold,
                                )
                            }
                        }
                    }
                }
            }

            if (args.pointsRequired <= 0 && args.mode != "stamps") {
                WarningBanner("Coût invalide (0 pts). Le client doit régénérer le QR depuis sa carte.")
            }

            errorMessage?.let { WarningBanner(it) }

            if (validated) {
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = Color(0x1A2E7D32),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color(0xFF2E7D32))
                        Column {
                            Text("Récompense validée", fontWeight = FontWeight.SemiBold)
                            Text("$displayName — ${args.rewardLabel}", style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }

            if (!args.eligible) {
                Surface(shape = RoundedCornerShape(14.dp), color = MaterialTheme.colorScheme.surfaceVariant) {
                    Row(Modifier.padding(14.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Icon(Icons.Default.Lock, contentDescription = null)
                        Text(
                            if (args.mode == "stamps") {
                                "Pas assez de tampons pour valider."
                            } else {
                                "Solde insuffisant (il manque ${(args.pointsRequired - args.pointsBalance).coerceAtLeast(0)} pts)."
                            },
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                }
            }

            Text("QR scanné", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Surface(shape = RoundedCornerShape(14.dp), color = MaterialTheme.colorScheme.surface) {
                Row(
                    Modifier.padding(14.dp),
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    qrImage?.let { bitmap ->
                        Image(
                            bitmap = bitmap,
                            contentDescription = "QR récompense",
                            modifier = Modifier
                                .size(88.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(Color.White)
                                .padding(6.dp),
                        )
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        when (parsed) {
                            is ParsedRewardQr.Points -> Text(
                                "Palier #${parsed.tierIndex + 1} · ${parsed.points} pts encodés",
                                style = MaterialTheme.typography.bodySmall,
                                fontWeight = FontWeight.Medium,
                            )
                            ParsedRewardQr.Stamps -> Text(
                                "Récompense tampons",
                                style = MaterialTheme.typography.bodySmall,
                                fontWeight = FontWeight.Medium,
                            )
                            null -> Text(
                                "Format non reconnu — QR « Utiliser en magasin » requis",
                                style = MaterialTheme.typography.bodySmall,
                                color = Color(0xFFE65100),
                            )
                        }
                        Text("Une seule validation par scan.", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }

            Spacer(Modifier.height(80.dp))
        }
    }
}

@Composable
private fun WarningBanner(message: String) {
    Surface(shape = RoundedCornerShape(12.dp), color = Color(0x1AFF9800), modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(Icons.Default.Warning, contentDescription = null, tint = Color(0xFFE65100))
            Text(message, style = MaterialTheme.typography.bodySmall)
        }
    }
}
