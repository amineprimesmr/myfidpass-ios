package fr.myfidpass.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.TrendingDown
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material.icons.filled.Receipt
import androidx.compose.material.icons.outlined.History
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.dto.TransactionDto
import fr.myfidpass.ui.theme.DashboardFintechPalette
import fr.myfidpass.util.MerchantTransactionEventLabels
import fr.myfidpass.ui.theme.MerchantDesignSystem
import fr.myfidpass.util.MerchantActivityDateFormat
import fr.myfidpass.ui.theme.FintechLightPalette

@Composable
fun FintechTransactionsHeader(
    palette: DashboardFintechPalette = FintechLightPalette,
    onSeeAll: (() -> Unit)?,
    onScan: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Column(
            modifier = Modifier
                .weight(1f)
                .then(if (onSeeAll != null) Modifier.clickable(onClick = onSeeAll) else Modifier),
        ) {
            Text(
                "Dernières",
                style = MaterialTheme.typography.titleMedium,
                color = palette.secondaryText,
            )
            Text(
                "Transactions",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.SemiBold,
                color = palette.onCanvasPrimary,
            )
        }
        IconButton(
            onClick = onScan,
            modifier = Modifier
                .size(68.dp)
                .clip(CircleShape)
                .background(palette.barButtonFill),
        ) {
            Icon(
                Icons.Default.QrCodeScanner,
                contentDescription = "Scanner",
                tint = palette.onCanvasPrimary,
                modifier = Modifier.size(32.dp),
            )
        }
    }
}

@Composable
fun FintechTransactionsEmptyState(
    palette: DashboardFintechPalette = FintechLightPalette,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(MerchantDesignSystem.radiusTransactionPill))
            .background(palette.transactionPillBg)
            .padding(horizontal = 18.dp, vertical = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            Icons.Outlined.History,
            contentDescription = null,
            modifier = Modifier.size(28.dp),
            tint = palette.secondaryText,
        )
        Text(
            "Aucune transaction récente",
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Bold,
            color = palette.onCanvasPrimary,
        )
    }
}

@Composable
fun FintechTransactionPill(
    transaction: TransactionDto,
    palette: DashboardFintechPalette = FintechLightPalette,
    isPointsProgram: Boolean = true,
    modifier: Modifier = Modifier,
) {
    val kind = transaction.type?.lowercase().orEmpty()
    val (icon, tint) = when {
        kind.contains("redeem") || (transaction.points ?: 0) < 0 ->
            Icons.AutoMirrored.Filled.TrendingDown to palette.secondaryText
        kind.contains("credit") || (transaction.points ?: 0) > 0 ->
            Icons.AutoMirrored.Filled.TrendingUp to palette.accentBlue
        else -> Icons.Default.Receipt to palette.secondaryText
    }
    val label = transaction.memberName?.ifBlank { transaction.memberEmail }
        ?: transaction.memberEmail
        ?: transaction.type
        ?: "Opération"
    val rewardLabel = MerchantTransactionEventLabels.rewardLabelFromMetadata(transaction.metadata)
    val ptsLabel = MerchantTransactionEventLabels.dashboardAmountLine(
        type = transaction.type,
        points = transaction.points,
        isPointsProgram = isPointsProgram,
        rewardLabel = rewardLabel,
    )
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(MerchantDesignSystem.radiusTransactionPill))
            .background(palette.transactionPillBg)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(palette.transactionIconDisc),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(20.dp))
        }
        Column(Modifier.weight(1f)) {
            Text(
                label,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = palette.onCanvasPrimary,
                maxLines = 1,
            )
            MerchantActivityDateFormat.activitySubtitle(transaction.createdAt)?.let {
                Text(it, style = MaterialTheme.typography.labelSmall, color = palette.secondaryText)
            }
        }
        if (ptsLabel.isNotEmpty()) {
            Text(
                ptsLabel,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = palette.onCanvasPrimary,
            )
        }
    }
}

@Composable
fun FintechQuickLink(
    label: String,
    icon: ImageVector,
    onClick: () -> Unit,
    palette: DashboardFintechPalette = FintechLightPalette,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .background(palette.card)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(icon, contentDescription = null, tint = palette.accentBlue)
        Text(label, style = MaterialTheme.typography.bodyMedium, color = palette.onCanvasPrimary)
    }
}
