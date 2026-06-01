package fr.myfidpass.ui.screens.commerce

import androidx.compose.foundation.background
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
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.AdminPanelSettings
import androidx.compose.material.icons.filled.Category
import androidx.compose.material.icons.filled.Extension
import androidx.compose.material.icons.filled.QrCode2
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.ShowChart
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.data.dto.BusinessStatsResponse
import fr.myfidpass.data.dto.DashboardTrafficPatternsResponse
import fr.myfidpass.ui.components.BusinessSwitcher
import fr.myfidpass.ui.components.CommerceFlyerSavedBlock
import fr.myfidpass.ui.components.CommerceStatsSummary
import fr.myfidpass.ui.theme.BackgroundLight
import fr.myfidpass.ui.theme.TextSecondaryLight
import fr.myfidpass.util.openInCustomTab
import fr.myfidpass.util.qrCodeImageBitmap
import androidx.compose.foundation.Image
import androidx.compose.ui.platform.LocalContext

/**
 * Aligné sur [ProfileView] iOS : bandeau noir (identité + QR + réglages), contenu sur surface claire arrondie,
 * section « Votre commerce » puis raccourcis (réglages, stats, catégories, programme, admin).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CommerceHubScreen(
    sessionStore: SessionStore,
    dashboardRepository: DashboardRepository,
    isAdmin: Boolean,
    onOpenSettings: () -> Unit,
    onOpenStats: () -> Unit,
    onOpenCategories: () -> Unit,
    onOpenProgram: () -> Unit,
    onOpenFlyer: () -> Unit = onOpenProgram,
    onOpenTeam: () -> Unit = {},
    onOpenScanSecurity: () -> Unit = {},
    onOpenAdmin: () -> Unit,
    onLogout: () -> Unit,
) {
    val context = LocalContext.current
    val slug = sessionStore.currentBusinessSlug?.trim()?.lowercase().orEmpty()
    var organizationName by remember { mutableStateOf<String?>(null) }
    var showQrDialog by remember { mutableStateOf(false) }
    var stats by remember { mutableStateOf<BusinessStatsResponse?>(null) }
    var traffic by remember { mutableStateOf<DashboardTrafficPatternsResponse?>(null) }

    LaunchedEffect(slug) {
        if (slug.isEmpty()) return@LaunchedEffect
        runCatching {
            val settings = dashboardRepository.businessSettings(slug)
            organizationName = settings.organizationName
            stats = dashboardRepository.businessStats(slug)
            traffic = dashboardRepository.businessStatsTraffic(slug)
        }
    }

    val publicPageUrl = remember(slug) {
        if (slug.isEmpty()) "" else "https://myfidpass.fr/fidelity/$slug"
    }
    val title = organizationName?.trim()?.takeIf { it.isNotEmpty() } ?: "Ma boutique"
    val initials = remember(title) {
        val w = title.split(" ").filter { it.isNotBlank() }.take(2)
        if (w.isEmpty()) "Mb"
        else w.joinToString("") { it.first().uppercaseChar().toString() }
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(Color.Black),
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier
                    .size(36.dp)
                    .background(Color(0xFFE5E5E5), CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    initials,
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(0xFF111111),
                )
            }
            Text(
                title,
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 10.dp),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = Color.White,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            IconButton(
                onClick = { if (publicPageUrl.isNotEmpty()) showQrDialog = true },
                enabled = publicPageUrl.isNotEmpty(),
            ) {
                Icon(
                    Icons.Default.QrCode2,
                    contentDescription = "QR page fidélité",
                    tint = Color.White,
                )
            }
            IconButton(onClick = onOpenSettings) {
                Icon(
                    Icons.Default.Settings,
                    contentDescription = "Réglages",
                    tint = Color.White,
                )
            }
        }

        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            shape = RoundedCornerShape(topStart = 22.dp, topEnd = 22.dp),
            color = BackgroundLight,
            tonalElevation = 0.dp,
        ) {
            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 14.dp)
                    .padding(top = 10.dp, bottom = 24.dp),
            ) {
                BusinessSwitcher(sessionStore = sessionStore)
                Spacer(Modifier.height(12.dp))
                CommerceStatsSummary(stats = stats, traffic = traffic)
                Spacer(Modifier.height(16.dp))
                if (slug.isNotEmpty()) {
                    CommerceFlyerSavedBlock(
                        slug = slug,
                        repository = dashboardRepository,
                        onEditFlyer = onOpenFlyer,
                    )
                    Spacer(Modifier.height(12.dp))
                }
                Text(
                    "Votre commerce",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    "Flyer, page clients et réputation — même logique que l’app iOS.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSecondaryLight,
                )
                Spacer(Modifier.height(16.dp))

                Card(
                    onClick = onOpenProgram,
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Text(
                            "Flyer & programme",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            "Jeux, flyer QR, réseaux, caisse, fiche établissement.",
                            style = MaterialTheme.typography.bodySmall,
                            color = TextSecondaryLight,
                        )
                    }
                }
                Spacer(Modifier.height(12.dp))
                Text(
                    "Raccourcis",
                    style = MaterialTheme.typography.labelLarge,
                    color = TextSecondaryLight,
                    modifier = Modifier.padding(bottom = 8.dp),
                )
                HubRow(Icons.Default.Settings, "Réglages & abonnement", onOpenSettings)
                Spacer(Modifier.height(10.dp))
                HubRow(Icons.Default.ShowChart, "Statistiques & activité", onOpenStats)
                Spacer(Modifier.height(10.dp))
                HubRow(Icons.Default.Category, "Catégories membres", onOpenCategories)
                Spacer(Modifier.height(10.dp))
                HubRow(Icons.Default.Group, "Équipe & accès staff", onOpenTeam)
                Spacer(Modifier.height(10.dp))
                HubRow(Icons.Default.Security, "Sécurité scan & anti-fraude", onOpenScanSecurity)
                Spacer(Modifier.height(10.dp))
                HubRow(Icons.Default.Extension, "Programme & outils (détail)", onOpenProgram)
                if (isAdmin) {
                    Spacer(Modifier.height(10.dp))
                    HubRow(Icons.Default.AdminPanelSettings, "Administration plateforme", onOpenAdmin)
                }
                Spacer(Modifier.height(8.dp))
                sessionStore.userEmail?.let {
                    Text(
                        "Compte : $it",
                        style = MaterialTheme.typography.bodySmall,
                        color = TextSecondaryLight,
                    )
                }
                Spacer(Modifier.height(20.dp))
                Button(
                    onClick = onLogout,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("Déconnexion") }
            }
        }
    }

    if (showQrDialog && publicPageUrl.isNotEmpty()) {
        Dialog(
            onDismissRequest = { showQrDialog = false },
            properties = DialogProperties(usePlatformDefaultWidth = false),
        ) {
            Surface(shape = RoundedCornerShape(16.dp)) {
                Column(
                    Modifier.padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        "Page fidélité publique",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Spacer(Modifier.height(12.dp))
                    Image(
                        bitmap = qrCodeImageBitmap(publicPageUrl, 320),
                        contentDescription = null,
                        modifier = Modifier.size(200.dp),
                    )
                    Spacer(Modifier.height(12.dp))
                    Button(
                        onClick = {
                            openInCustomTab(context, publicPageUrl)
                            showQrDialog = false
                        },
                        modifier = Modifier.fillMaxWidth(),
                    ) { Text("Ouvrir dans le navigateur") }
                }
            }
        }
    }
}

@Composable
private fun HubRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    onClick: () -> Unit,
) {
    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            Text(
                label,
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 12.dp),
                style = MaterialTheme.typography.titleMedium,
            )
            Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = null)
        }
    }
}
