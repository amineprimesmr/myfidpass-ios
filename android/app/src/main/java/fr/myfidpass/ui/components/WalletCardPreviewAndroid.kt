package fr.myfidpass.ui.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import fr.myfidpass.util.qrCodeImageBitmap
import fr.myfidpass.util.toComposeColorOr

/** Aperçu proche du pass Wallet iOS : fond marque, bandeau clair, QR, corps points / membre. */
@Composable
fun WalletCardPreviewAndroid(
    businessName: String,
    organizationLabel: String?,
    qrPayload: String,
    logoUrl: String?,
    backgroundHex: String?,
    labelHex: String?,
    accentHex: String?,
    modifier: Modifier = Modifier,
    samplePoints: Int = 120,
    sampleMemberLabel: String = "Membre",
) {
    val bg = backgroundHex.toComposeColorOr(Color(0xFF0F766E))
    val labelC = labelHex.toComposeColorOr(Color(0xFF134E4A))
    val stripBg = Color.White
    val ratio = 0.82f

    Column(
        modifier = modifier
            .fillMaxWidth()
            .aspectRatio(ratio)
            .clip(RoundedCornerShape(14.dp))
            .background(bg),
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .weight(0.22f),
            contentAlignment = Alignment.Center,
        ) {
            if (!logoUrl.isNullOrBlank()) {
                AsyncImage(
                    model = logoUrl,
                    contentDescription = null,
                    modifier = Modifier
                        .fillMaxWidth(0.45f)
                        .height(40.dp),
                    contentScale = ContentScale.Fit,
                )
            } else {
                Text(
                    businessName,
                    color = stripBg,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
        Column(
            Modifier
                .fillMaxWidth()
                .weight(0.78f)
                .background(stripBg)
                .padding(horizontal = 14.dp, vertical = 12.dp),
        ) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .weight(1f),
                contentAlignment = Alignment.Center,
            ) {
                Image(
                    bitmap = qrCodeImageBitmap(qrPayload, 320),
                    contentDescription = null,
                    modifier = Modifier
                        .fillMaxWidth(0.62f)
                        .aspectRatio(1f),
                )
            }
            Spacer(Modifier.height(8.dp))
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
                Column(Modifier.weight(1f)) {
                    Text(
                        "Points",
                        style = MaterialTheme.typography.labelSmall,
                        color = labelC.copy(alpha = 0.75f),
                    )
                    Text(
                        samplePoints.toString(),
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        color = labelC,
                    )
                }
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.End) {
                    Text(
                        organizationLabel?.ifBlank { "Membre" } ?: "Membre",
                        style = MaterialTheme.typography.labelSmall,
                        color = labelC.copy(alpha = 0.75f),
                    )
                    Text(
                        sampleMemberLabel,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = accentHex.toComposeColorOr(labelC),
                    )
                }
            }
        }
    }
}
