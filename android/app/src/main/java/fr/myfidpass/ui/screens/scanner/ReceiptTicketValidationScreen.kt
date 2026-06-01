package fr.myfidpass.ui.screens.scanner

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import fr.myfidpass.services.scan.ReceiptTicketScanSession
import fr.myfidpass.util.qrCodeImageBitmap
import java.util.Locale

@Composable
fun ReceiptTicketValidationScreen(
    session: ReceiptTicketScanSession,
    onComplete: (String?) -> Unit,
) {
    var showReference by remember { mutableStateOf(false) }
    var scanError by remember { mutableStateOf<String?>(null) }
    val amountText = String.format(Locale.FRANCE, "%.2f", session.amountEur)
    val expected = session.qrPayload.trim()

    Box(
        Modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(
                    listOf(Color(0xFF0A0F1A), Color(0xFF050810), Color.Black),
                ),
            ),
    ) {
        Column(Modifier.fillMaxSize()) {
            Column(Modifier.padding(horizontal = 18.dp, vertical = 12.dp)) {
                IconButton(
                    onClick = { onComplete(null) },
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.14f)),
                ) {
                    Icon(Icons.Default.Close, contentDescription = "Annuler", tint = Color.White)
                }
                Text(
                    "Ticket de caisse",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                )
                Text(
                    "Montant attendu : $amountText €",
                    style = MaterialTheme.typography.titleSmall,
                    color = Color(0xFF67E8F9),
                )
            }
            Box(
                Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .clip(RoundedCornerShape(28.dp)),
            ) {
                QrScannerScreen(
                    onBarcode = { raw -> onComplete(raw.trim()) },
                    onClose = { onComplete(null) },
                    validateBarcode = { it.trim() == expected },
                    embeddedMode = true,
                    modifier = Modifier.fillMaxSize(),
                )
            }
            Column(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 18.dp, vertical = 12.dp),
            ) {
                scanError?.let {
                    Text(it, color = Color(0xFFFF9F0A))
                    Spacer(Modifier.height(6.dp))
                }
                Text(
                    "Alignez le QR imprimé sur le ticket de caisse",
                    color = Color.White.copy(alpha = 0.82f),
                    style = MaterialTheme.typography.bodyMedium,
                )
                Button(
                    onClick = { showReference = !showReference },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 10.dp),
                ) {
                    Text(if (showReference) "Masquer le QR à imprimer" else "Afficher le QR à imprimer")
                }
                if (showReference) {
                    Column(
                        Modifier.fillMaxWidth(),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Image(
                            bitmap = qrCodeImageBitmap(session.qrPayload, 240),
                            contentDescription = null,
                            modifier = Modifier
                                .size(180.dp)
                                .clip(RoundedCornerShape(16.dp))
                                .background(Color.White)
                                .padding(10.dp),
                        )
                    }
                }
            }
        }
    }
}
