package fr.myfidpass.ui.screens.settings

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.ManageSearch
import androidx.compose.material.icons.filled.PrivacyTip
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import fr.myfidpass.ui.components.GroupedSettingsCard
import fr.myfidpass.ui.components.GroupedSettingsLogoutRow
import fr.myfidpass.ui.components.GroupedSettingsMetrics
import fr.myfidpass.ui.components.GroupedSettingsNavigationRow
import fr.myfidpass.ui.components.GroupedSettingsRowDivider
import fr.myfidpass.ui.components.GroupedSettingsSectionLabel
import fr.myfidpass.util.LegalURLs
import fr.myfidpass.util.openInCustomTab

/** Hub Paramètres — aligné iOS `MerchantAppSettingsHubView`. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppSettingsHubScreen(
    onBack: () -> Unit,
    onScanSecurity: () -> Unit,
    onAccounting: () -> Unit,
    onLogout: () -> Unit,
    showsAccountingPack: Boolean = true,
) {
    val context = LocalContext.current
    var confirmLogout by remember { mutableStateOf(false) }

    if (confirmLogout) {
        AlertDialog(
            onDismissRequest = { confirmLogout = false },
            title = { Text("Déconnexion") },
            text = { Text("Vous devrez vous reconnecter.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmLogout = false
                    onLogout()
                }) { Text("Se déconnecter") }
            },
            dismissButton = {
                TextButton(onClick = { confirmLogout = false }) { Text("Annuler") }
            },
        )
    }

    Scaffold(
        containerColor = GroupedSettingsMetrics.pageBackground,
        topBar = {
            TopAppBar(
                title = { Text("Paramètres", fontWeight = FontWeight.Bold) },
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
                .navigationBarsPadding(),
        ) {
            Spacer(Modifier.height(8.dp))
            GroupedSettingsSectionLabel("Commerce & sécurité")
            Spacer(Modifier.height(8.dp))
            GroupedSettingsCard {
                GroupedSettingsNavigationRow(
                    icon = Icons.Default.Shield,
                    title = "Sécurité caisse & scan",
                    subtitle = "QR, tickets, anti-fraude",
                    onClick = onScanSecurity,
                )
                if (showsAccountingPack) {
                    GroupedSettingsRowDivider()
                    GroupedSettingsNavigationRow(
                        icon = Icons.Default.ManageSearch,
                        title = "Pack comptable (bilan)",
                        subtitle = "Exports CSV pour votre expert-comptable",
                        onClick = onAccounting,
                    )
                }
            }
            Spacer(Modifier.height(GroupedSettingsMetrics.interCardSpacing))
            GroupedSettingsSectionLabel("Informations légales")
            Spacer(Modifier.height(8.dp))
            GroupedSettingsCard {
                GroupedSettingsNavigationRow(
                    icon = Icons.Default.Description,
                    title = "Conditions d'utilisation",
                    onClick = { openInCustomTab(context, LegalURLs.TERMS) },
                )
                GroupedSettingsRowDivider()
                GroupedSettingsNavigationRow(
                    icon = Icons.Default.PrivacyTip,
                    title = "Politique de confidentialité",
                    onClick = { openInCustomTab(context, LegalURLs.PRIVACY) },
                )
            }
            Spacer(Modifier.height(GroupedSettingsMetrics.interCardSpacing))
            GroupedSettingsSectionLabel("Assistance")
            Spacer(Modifier.height(8.dp))
            GroupedSettingsCard {
                GroupedSettingsNavigationRow(
                    icon = Icons.Default.Email,
                    title = "Contacter le support",
                    subtitle = "E-mail à l'équipe MyFidpass",
                    onClick = { openInCustomTab(context, LegalURLs.SUPPORT) },
                )
            }
            Spacer(Modifier.height(GroupedSettingsMetrics.interCardSpacing))
            GroupedSettingsCard {
                GroupedSettingsLogoutRow(onClick = { confirmLogout = true })
            }
            Spacer(Modifier.height(32.dp))
        }
    }
}
