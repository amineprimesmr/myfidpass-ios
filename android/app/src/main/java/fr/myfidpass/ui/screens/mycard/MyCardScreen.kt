package fr.myfidpass.ui.screens.mycard

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.ui.components.WalletCardPreviewAndroid
import fr.myfidpass.ui.viewmodel.DashboardViewModel
import fr.myfidpass.util.openInCustomTab

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MyCardScreen(
    viewModel: DashboardViewModel,
    sessionStore: SessionStore,
    onBack: () -> Unit,
) {
    val slug = sessionStore.currentBusinessSlug.orEmpty()
    val context = LocalContext.current
    val fidelityUrl = if (slug.isNotBlank()) {
        "https://myfidpass.fr/fidelity/${slug.lowercase().trim()}"
    } else {
        "https://myfidpass.fr"
    }
    val settings = viewModel.settings
    val stats = viewModel.stats
    val businessName = stats?.businessName?.ifBlank { slug } ?: slug.ifBlank { "Ma carte" }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Ma carte") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
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
                "Même URL publique que sur iOS (`LegalURLs.fidelityCardPage`).",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(12.dp))
            WalletCardPreviewAndroid(
                businessName = businessName,
                organizationLabel = settings?.organizationName,
                qrPayload = fidelityUrl,
                logoUrl = settings?.logoUrl,
                backgroundHex = settings?.backgroundColor,
                labelHex = settings?.labelColor,
                accentHex = settings?.foregroundColor,
            )
            Spacer(Modifier.height(16.dp))
            TextButton(
                onClick = { openInCustomTab(context, fidelityUrl) },
            ) {
                Text("Ouvrir la page fidélité publique")
            }
        }
    }
}
