package fr.myfidpass.ui.screens.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Badge
import androidx.compose.material.icons.filled.HelpOutline
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.di.AppContainer
import fr.myfidpass.services.sync.SyncService
import fr.myfidpass.ui.components.GroupedSettingsCard
import fr.myfidpass.ui.components.GroupedSettingsLogoutRow
import fr.myfidpass.ui.components.GroupedSettingsMetrics
import fr.myfidpass.ui.components.GroupedSettingsNavigationRow
import fr.myfidpass.ui.components.GroupedSettingsRowDivider
import fr.myfidpass.ui.components.SafeArea
import fr.myfidpass.ui.navigation.MerchantAnimatedFullScreenOverlay
import fr.myfidpass.ui.screens.commerce.ScanSecuritySettingsScreen
import fr.myfidpass.util.LegalURLs
import fr.myfidpass.util.openInCustomTab
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Compte employé — aligné iOS `StaffAccountView.swift`. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StaffAccountScreen(
    container: AppContainer,
    syncService: SyncService,
    snackbar: androidx.compose.material3.SnackbarHostState,
    onLogout: () -> Unit,
) {
    val session = container.sessionStore
    val slug = session.currentBusinessSlug
    val businessName = session.businesses.firstOrNull { it.slug == slug }?.name
    val scope = rememberCoroutineScope()
    var notice by remember { mutableStateOf<String?>(null) }
    var showScanSecurity by remember { mutableStateOf(false) }
    var confirmLogout by remember { mutableStateOf(false) }
    val context = LocalContext.current

    if (confirmLogout) {
        AlertDialog(
            onDismissRequest = { confirmLogout = false },
            title = { Text("Déconnexion") },
            text = { Text("Vous devrez vous reconnecter avec vos identifiants employé.") },
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

    Box(Modifier.fillMaxSize()) {
    Column(
        Modifier
            .fillMaxSize()
            .background(GroupedSettingsMetrics.pageBackground)
            .padding(top = SafeArea.statusBarTop())
            .navigationBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = GroupedSettingsMetrics.horizontalPadding)
            .padding(top = 14.dp),
    ) {
        notice?.let {
            Text(
                it,
                color = Color(0xFF10B981),
                fontWeight = FontWeight.Medium,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0xFF10B981).copy(0.12f), RoundedCornerShape(12.dp))
                    .padding(14.dp),
            )
            Spacer(Modifier.height(GroupedSettingsMetrics.interCardSpacing))
        }

        Text("Compte employé", fontSize = 34.sp, fontWeight = FontWeight.Bold, color = Color(0xFF1C1C1E))
        businessName?.let {
            Text(it, fontSize = 15.sp, color = Color(0xFF8E8E93), modifier = Modifier.padding(top = 4.dp))
        }
        Spacer(Modifier.height(GroupedSettingsMetrics.interCardSpacing))

        GroupedSettingsCard {
            GroupedSettingsNavigationRow(
                icon = Icons.Default.Badge,
                title = session.userStaffLogin ?: session.userEmail ?: "—",
                subtitle = "Identifiant caisse",
                showsChevron = false,
                onClick = null,
            )
        }
        Spacer(Modifier.height(GroupedSettingsMetrics.interCardSpacing))

        GroupedSettingsCard {
            StaffLastSyncBlock(syncService)
            GroupedSettingsRowDivider()
            GroupedSettingsNavigationRow(
                icon = Icons.Default.Sync,
                title = "Synchroniser maintenant",
                showsChevron = false,
                onClick = {
                    val s = slug ?: return@GroupedSettingsNavigationRow
                    scope.launch {
                        syncService.syncIfNeeded(s, force = true)
                        notice = "Synchronisation lancée."
                    }
                },
            )
            GroupedSettingsRowDivider()
            GroupedSettingsNavigationRow(
                icon = Icons.Default.Shield,
                title = "Sécurité caisse & scan",
                onClick = { showScanSecurity = true },
            )
        }
        Spacer(Modifier.height(GroupedSettingsMetrics.interCardSpacing))

        GroupedSettingsCard {
            GroupedSettingsNavigationRow(
                icon = Icons.Default.HelpOutline,
                title = "Aide & support",
                onClick = { openInCustomTab(context, LegalURLs.SUPPORT) },
            )
        }
        Spacer(Modifier.height(GroupedSettingsMetrics.interCardSpacing))

        GroupedSettingsCard {
            GroupedSettingsLogoutRow(onClick = { confirmLogout = true })
        }
        Spacer(Modifier.height(48.dp))
    }

    MerchantAnimatedFullScreenOverlay(visible = showScanSecurity) {
        ScanSecuritySettingsScreen(
            repository = container.dashboardRepository,
            sessionStore = container.sessionStore,
            snackbar = snackbar,
            onBack = { showScanSecurity = false },
        )
    }
    }
}

@Composable
private fun StaffLastSyncBlock(syncService: SyncService) {
    val lastAt = syncService.lastSyncAtMillis
    val lastText = if (lastAt == null) {
        "Jamais"
    } else {
        val diff = System.currentTimeMillis() - lastAt
        when {
            diff < 60_000 -> "À l'instant"
            diff < 3_600_000 -> "Il y a ${diff / 60_000} min"
            else -> SimpleDateFormat("d MMM", Locale.FRENCH).format(Date(lastAt))
        }
    }
    GroupedSettingsNavigationRow(
        icon = Icons.Default.Sync,
        title = "Dernière synchro",
        value = lastText,
        showsChevron = false,
        onClick = null,
    )
}
