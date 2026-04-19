package fr.myfidpass.ui.screens.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.ui.components.WalletCardPreviewAndroid
import fr.myfidpass.ui.theme.BackgroundLight
import fr.myfidpass.ui.theme.TextSecondaryLight
import fr.myfidpass.ui.viewmodel.DashboardViewModel

/**
 * Aligné sur l’esprit [DashboardView] iOS : fond clair type tableau de bord, **aperçu carte** en tête,
 * indicateurs, puis actions (scan, membres, Ma carte).
 */
@Composable
fun HomeDashboardScreen(
    modifier: Modifier = Modifier,
    viewModel: DashboardViewModel,
    sessionStore: SessionStore,
    onMembers: () -> Unit,
    onScan: () -> Unit,
    onMyCard: () -> Unit,
) {
    val slug = sessionStore.currentBusinessSlug?.trim()?.lowercase().orEmpty()
    val publicCardUrl = if (slug.isEmpty()) "" else "https://myfidpass.fr/fidelity/$slug"
    val businessName =
        viewModel.stats?.businessName?.takeIf { !it.isNullOrBlank() }
            ?: viewModel.settings?.organizationName?.takeIf { !it.isNullOrBlank() }
            ?: "Ma boutique"
    val orgLabel = viewModel.settings?.organizationName

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(BackgroundLight)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 18.dp)
            .padding(top = 16.dp, bottom = 24.dp),
    ) {
        Text(
            text = "Accueil",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = "Aperçu carte et indicateurs — même rôle que le dashboard iOS.",
            style = MaterialTheme.typography.bodyMedium,
            color = TextSecondaryLight,
        )
        Spacer(Modifier.height(16.dp))
        if (viewModel.loading) {
            CircularProgressIndicator(Modifier.align(Alignment.CenterHorizontally))
            Spacer(Modifier.height(12.dp))
        }
        viewModel.error?.let {
            Text(it, color = MaterialTheme.colorScheme.error)
            Spacer(Modifier.height(8.dp))
        }
        if (slug.isNotEmpty() && publicCardUrl.isNotEmpty()) {
            WalletCardPreviewAndroid(
                businessName = businessName,
                organizationLabel = orgLabel,
                qrPayload = publicCardUrl,
                logoUrl = viewModel.settings?.logoUrl,
                backgroundHex = viewModel.settings?.backgroundColor,
                labelHex = viewModel.settings?.labelColor,
                accentHex = viewModel.settings?.foregroundColor,
                samplePoints = viewModel.stats?.pointsThisMonth ?: 0,
                sampleMemberLabel = "Client",
            )
            Spacer(Modifier.height(16.dp))
        } else {
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            ) {
                Text(
                    "Sélectionnez un commerce pour afficher l’aperçu de carte.",
                    modifier = Modifier.padding(16.dp),
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSecondaryLight,
                )
            }
            Spacer(Modifier.height(16.dp))
        }
        viewModel.stats?.let { s ->
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                StatCard(
                    title = "Membres",
                    value = s.membersCount?.toString() ?: "—",
                    modifier = Modifier.weight(1f),
                )
                StatCard(
                    title = "Points (mois)",
                    value = s.pointsThisMonth?.toString() ?: "—",
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(Modifier.height(10.dp))
            StatCard(
                title = "Transactions (mois)",
                value = s.transactionsThisMonth?.toString() ?: "—",
                modifier = Modifier.fillMaxWidth(),
            )
        }
        Spacer(Modifier.height(16.dp))
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
        ) {
            Column(Modifier.padding(14.dp)) {
                Text(
                    "Dernières transactions",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    "Sur iOS, ce flux vient du stockage local (Core Data). Sur Android, l’historique détaillé sera branché sur l’API / un cache — à venir.",
                    style = MaterialTheme.typography.bodySmall,
                    color = TextSecondaryLight,
                )
            }
        }
        Spacer(Modifier.height(20.dp))
        Text(
            "Actions",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.height(12.dp))
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Button(
                onClick = onScan,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.QrCodeScanner, contentDescription = null)
                    Spacer(Modifier.width(8.dp))
                    Text("Scanner un QR membre")
                }
            }
            OutlinedButton(
                onClick = onMembers,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.People, contentDescription = null)
                    Spacer(Modifier.width(8.dp))
                    Text("Membres & activité")
                }
            }
            OutlinedButton(
                onClick = onMyCard,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.CreditCard, contentDescription = null)
                    Spacer(Modifier.width(8.dp))
                    Text("Ma carte")
                }
            }
        }
    }
}

@Composable
private fun StatCard(title: String, value: String, modifier: Modifier = Modifier) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, style = MaterialTheme.typography.labelMedium, color = TextSecondaryLight)
            Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        }
    }
}
