package fr.myfidpass.ui.components

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import fr.myfidpass.services.version.PlayStoreVersionChecker

@Composable
fun AppUpdateDialog(
    info: PlayStoreVersionChecker.UpdateInfo,
    onDismiss: () -> Unit,
    onOpenStore: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = if (info.isMandatoryUpdate) { {} } else onDismiss,
        title = { Text("Mise à jour disponible") },
        text = {
            Text(
                if (info.isMandatoryUpdate) {
                    "Une mise à jour obligatoire est disponible : ${info.currentVersion} → ${info.storeVersion}."
                } else {
                    "Version ${info.storeVersion} disponible sur le Play Store.\n" +
                        "Vous utilisez la version ${info.currentVersion}."
                },
            )
        },
        confirmButton = {
            TextButton(onClick = onOpenStore) { Text("Mettre à jour") }
        },
        dismissButton = if (info.isMandatoryUpdate) {
            null
        } else {
            { TextButton(onClick = onDismiss) { Text("Plus tard") } }
        },
    )
}
