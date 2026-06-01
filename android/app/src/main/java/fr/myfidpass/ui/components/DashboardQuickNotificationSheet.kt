package fr.myfidpass.ui.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
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
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.repo.DashboardRepository
import kotlinx.coroutines.launch

/** Envoi rapide depuis l'accueil — aligné iOS menu notification dashboard. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardQuickNotificationSheet(
    visible: Boolean,
    repository: DashboardRepository,
    slug: String?,
    hasProAccess: Boolean,
    onDismiss: () -> Unit,
    onUnlockPro: () -> Unit,
    onSent: (String) -> Unit,
) {
    if (!visible) return
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var title by remember { mutableStateOf("") }
    var body by remember { mutableStateOf("") }
    var sending by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 32.dp)) {
            Text("Message à tous les membres", fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(12.dp))
            if (!hasProAccess) {
                Text("Abonnement Pro requis pour l'envoi manuel.")
                Spacer(Modifier.height(12.dp))
                Button(onClick = { onDismiss(); onUnlockPro() }, modifier = Modifier.fillMaxWidth()) {
                    Text("Débloquer Pro")
                }
                return@Column
            }
            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                label = { Text("Titre (optionnel)") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = body,
                onValueChange = { body = it },
                label = { Text("Message") },
                modifier = Modifier.fillMaxWidth(),
                minLines = 3,
            )
            Spacer(Modifier.height(16.dp))
            Button(
                onClick = {
                    val s = slug ?: return@Button
                    if (body.isBlank()) return@Button
                    scope.launch {
                        sending = true
                        runCatching {
                            repository.sendNotification(
                                s,
                                body.trim(),
                                null,
                                title.trim().takeIf { it.isNotEmpty() },
                                null,
                            )
                        }.fold(
                            onSuccess = {
                                onSent("Notification envoyée")
                                onDismiss()
                            },
                            onFailure = { onSent(it.message ?: "Erreur d'envoi") },
                        )
                        sending = false
                    }
                },
                enabled = !sending && body.isNotBlank() && slug != null,
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (sending) CircularProgressIndicator(strokeWidth = 2.dp)
                else Text("Envoyer", fontWeight = FontWeight.SemiBold)
            }
        }
    }
}
