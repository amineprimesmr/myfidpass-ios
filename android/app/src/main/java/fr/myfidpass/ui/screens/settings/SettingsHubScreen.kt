package fr.myfidpass.ui.screens.settings

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Link
import androidx.compose.material.icons.filled.QrCode
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SportsSoccer
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.BuildConfig
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.services.sync.SyncService
import fr.myfidpass.ui.components.GroupedSettingsCard
import fr.myfidpass.ui.components.GroupedSettingsMetrics
import fr.myfidpass.ui.components.GroupedSettingsNavigationRow
import fr.myfidpass.ui.components.GroupedSettingsRowDivider
import fr.myfidpass.ui.components.GroupedSettingsSectionLabel
import fr.myfidpass.util.LegalURLs
import fr.myfidpass.util.openInCustomTab
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Hub « Compte » — aligné iOS `SettingsView.swift`. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsHubScreen(
    sessionStore: SessionStore,
    syncService: SyncService,
    onBack: () -> Unit,
    onAccount: () -> Unit,
    onAppSettings: () -> Unit,
    onScanSecurity: () -> Unit = {},
    onTeam: () -> Unit,
    onLoyaltyNetwork: () -> Unit = {},
    onMatchPredictions: () -> Unit,
    onAccounting: () -> Unit = {},
    onOpenFlyerHub: () -> Unit,
    showFlyerShortcuts: Boolean = false,
) {
    val context = LocalContext.current
    val slug = sessionStore.currentBusinessSlug?.trim().orEmpty()
    val canManageTeam = sessionStore.canManageMerchantTeam()
    val lastSyncText = remember(syncService.lastSyncAtMillis) { formatLastSync(syncService.lastSyncAtMillis) }
    val accountSubtitle = remember(sessionStore.userEmail) {
        sessionStore.userEmail?.trim().orEmpty().ifBlank { "Identité et sécurité du compte" }
    }

    Scaffold(
        containerColor = GroupedSettingsMetrics.pageBackground,
        topBar = {
            TopAppBar(
                title = { Text("Compte", fontWeight = FontWeight.SemiBold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Retour")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = GroupedSettingsMetrics.pageBackground,
                ),
                modifier = Modifier.statusBarsPadding(),
            )
        },
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = GroupedSettingsMetrics.horizontalPadding)
                .padding(top = 8.dp)
                .navigationBarsPadding(),
        ) {
            if (canManageTeam) {
                GroupedSettingsCard {
                    GroupedSettingsNavigationRow(
                        icon = Icons.Default.Groups,
                        title = "Équipe",
                        onClick = onTeam,
                    )
                    GroupedSettingsRowDivider()
                    GroupedSettingsNavigationRow(
                        icon = Icons.Default.Link,
                        title = "Réseau fidélité",
                        subtitle = if (sessionStore.businesses.any { it.isInLoyaltyNetwork }) {
                            "Carte partagée active"
                        } else {
                            "Regrouper plusieurs adresses"
                        },
                        onClick = onLoyaltyNetwork,
                    )
                }
                Spacer(Modifier.height(GroupedSettingsMetrics.interCardSpacing))
            }

            if (slug.isNotEmpty()) {
                GroupedSettingsCard {
                    GroupedSettingsNavigationRow(
                        icon = Icons.Default.SportsSoccer,
                        title = "Challenge pronostics foot",
                        subtitle = "Activation, points et résultats",
                        onClick = onMatchPredictions,
                    )
                }
                Spacer(Modifier.height(GroupedSettingsMetrics.interCardSpacing))
            }

            if (showFlyerShortcuts && slug.isNotEmpty()) {
                GroupedSettingsCard {
                    GroupedSettingsNavigationRow(
                        icon = Icons.Default.Description,
                        title = "Flyer",
                        onClick = onOpenFlyerHub,
                    )
                    GroupedSettingsRowDivider()
                    GroupedSettingsNavigationRow(
                        icon = Icons.Default.QrCode,
                        title = "Tester le jeu",
                        onClick = { openInCustomTab(context, LegalURLs.fidelityCardPage(slug)) },
                    )
                }
                Spacer(Modifier.height(GroupedSettingsMetrics.interCardSpacing))
            }

            GroupedSettingsSectionLabel("Votre espace")
            Spacer(Modifier.height(8.dp))

            GroupedSettingsCard {
                GroupedSettingsNavigationRow(
                    icon = Icons.Default.AccountCircle,
                    title = "Compte",
                    subtitle = accountSubtitle,
                    value = lastSyncText,
                    onClick = onAccount,
                )
            }
            Spacer(Modifier.height(GroupedSettingsMetrics.interCardSpacing))

            GroupedSettingsCard {
                GroupedSettingsNavigationRow(
                    icon = Icons.Default.Settings,
                    title = "Paramètres",
                    subtitle = "Sécurité, pack comptable, légal, support",
                    onClick = onAppSettings,
                )
            }

            Spacer(Modifier.height(8.dp))
            Text(
                "Version ${BuildConfig.VERSION_NAME}",
                fontSize = 12.sp,
                color = Color(0xFF8E8E93),
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(100.dp))
        }
    }
}

internal fun formatLastSync(lastAt: Long?): String {
    if (lastAt == null) return "Jamais"
    val diff = System.currentTimeMillis() - lastAt
    return when {
        diff < 60_000 -> "À l'instant"
        diff < 3_600_000 -> "Il y a ${diff / 60_000} min"
        diff < 86_400_000 -> "Il y a ${diff / 3_600_000} h"
        else -> SimpleDateFormat("d MMM", Locale.FRENCH).format(Date(lastAt))
    }
}
