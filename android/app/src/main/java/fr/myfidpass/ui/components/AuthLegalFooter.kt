package fr.myfidpass.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import fr.myfidpass.util.LegalURLs
import fr.myfidpass.util.openInCustomTab

@Composable
fun AuthLegalFooter(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.Center,
    ) {
        TextButton(onClick = { openInCustomTab(context, LegalURLs.PRIVACY) }) {
            Text("Politique de confidentialité", style = MaterialTheme.typography.labelSmall)
        }
        Text("·", style = MaterialTheme.typography.labelSmall, color = Color.Black.copy(0.35f))
        TextButton(onClick = { openInCustomTab(context, LegalURLs.TERMS) }) {
            Text("Conditions d'utilisation (EULA)", style = MaterialTheme.typography.labelSmall)
        }
    }
}
