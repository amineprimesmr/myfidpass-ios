package fr.myfidpass.ui.screens.stats

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.ui.theme.CommerceStatsLightEmbedded
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MerchantStatsPanierRepereSheet(
    initialEuro: Double?,
    visible: Boolean,
    onDismiss: () -> Unit,
    onSave: suspend (value: Double?, clear: Boolean) -> Result<Unit>,
) {
    if (!visible) return
    val palette = CommerceStatsLightEmbedded
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    var amountText by remember(initialEuro, visible) {
        mutableStateOf(
            when {
                initialEuro == null || initialEuro <= 0.0 -> ""
                initialEuro % 1.0 < 0.05 -> initialEuro.toInt().toString()
                else -> "%.2f".format(initialEuro).replace('.', ',')
            },
        )
    }
    var saving by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    fun parseAmount(raw: String): Double? {
        val normalized = raw.trim().replace(',', '.')
        if (normalized.isEmpty()) return null
        val v = normalized.toDoubleOrNull() ?: return null
        if (v < 0 || v > 100_000) return null
        return v
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = palette.tileSurfaceLight,
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp),
        ) {
            Text(
                "Quel est votre panier moyen actuel ?",
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp,
                color = palette.onTilePrimary,
            )
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = amountText,
                onValueChange = { amountText = it; error = null },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("Ex. 24,90") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                singleLine = true,
                shape = RoundedCornerShape(14.dp),
            )
            error?.let {
                Spacer(Modifier.height(8.dp))
                Text(it, color = palette.negative, fontSize = 13.sp)
            }
            if (initialEuro != null && initialEuro > 0) {
                Spacer(Modifier.height(10.dp))
                OutlinedButton(
                    onClick = {
                        if (saving) return@OutlinedButton
                        saving = true
                        scope.launch {
                            onSave(null, true)
                                .onSuccess { onDismiss() }
                                .onFailure { error = it.message ?: "Erreur" }
                            saving = false
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !saving,
                ) {
                    Text("Supprimer le repère")
                }
            }
            Spacer(Modifier.height(16.dp))
            Button(
                onClick = {
                    if (saving) return@Button
                    val parsed = parseAmount(amountText)
                    if (parsed == null) {
                        error = "Saisissez un montant entre 0 et 100 000 € (ex. 24,90)."
                        return@Button
                    }
                    saving = true
                    scope.launch {
                        onSave(parsed, false)
                            .onSuccess { onDismiss() }
                            .onFailure { error = it.message ?: "Erreur" }
                        saving = false
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                enabled = !saving,
            ) {
                Text(if (saving) "Enregistrement…" else "Enregistrer", fontWeight = FontWeight.SemiBold)
            }
        }
    }
}
