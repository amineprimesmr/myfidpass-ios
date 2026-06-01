package fr.myfidpass.ui.screens.settings

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
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
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.LockReset
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material.icons.filled.Store
import androidx.compose.material.icons.filled.VpnKey
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.ui.components.GroupedSettingsCard
import fr.myfidpass.ui.components.GroupedSettingsDestructiveRow
import fr.myfidpass.ui.components.GroupedSettingsIconBox
import fr.myfidpass.ui.components.GroupedSettingsInfoRow
import fr.myfidpass.ui.components.GroupedSettingsMetrics
import fr.myfidpass.ui.components.GroupedSettingsRowDivider
import fr.myfidpass.services.sync.SyncService
import fr.myfidpass.ui.viewmodel.AccountSettingsViewModel
import fr.myfidpass.util.LegalURLs
import fr.myfidpass.util.openInCustomTab
import kotlinx.coroutines.CoroutineScope

/** Détail compte — aligné iOS `AccountSettingsDetailView.swift`. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountSettingsDetailScreen(
    viewModel: AccountSettingsViewModel,
    syncService: SyncService,
    appScope: CoroutineScope,
    onBack: () -> Unit,
    onLoggedOut: () -> Unit,
) {
    val context = LocalContext.current
    var confirmDelete by remember { mutableStateOf(false) }
    var commerceMenuOpen by remember { mutableStateOf(false) }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) {
        viewModel.refreshPushStatus(context)
    }

    LaunchedEffect(Unit) {
        viewModel.refreshPushStatus(context)
        viewModel.refreshAccount(force = false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Supprimer votre compte ?") },
            text = {
                Text(
                    "Cette action est irréversible : compte commerçant, données et historique associés. " +
                        "Vous serez déconnecté immédiatement après confirmation.",
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    viewModel.deleteAccount(onLoggedOut)
                }) { Text("Supprimer définitivement", color = Color(0xFFFF3B30)) }
            },
            dismissButton = {
                TextButton(onClick = { confirmDelete = false }) { Text("Annuler") }
            },
        )
    }

    viewModel.passwordResetError?.let { err ->
        AlertDialog(
            onDismissRequest = { viewModel.passwordResetError = null },
            title = { Text("Réinitialisation") },
            text = { Text(err) },
            confirmButton = {
                TextButton(onClick = { viewModel.passwordResetError = null }) { Text("OK") }
            },
        )
    }

    Box(Modifier.fillMaxSize()) {
        Scaffold(
            containerColor = GroupedSettingsMetrics.pageBackground,
            topBar = {
                TopAppBar(
                    title = { Text("Compte", fontWeight = FontWeight.Bold) },
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
                viewModel.passwordResetNotice?.let { notice ->
                    Text(
                        notice,
                        color = Color(0xFF10B981),
                        fontWeight = FontWeight.Medium,
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(Color(0xFF10B981).copy(0.12f), androidx.compose.foundation.shape.RoundedCornerShape(12.dp))
                            .padding(14.dp),
                    )
                    Spacer(Modifier.height(GroupedSettingsMetrics.interCardSpacing))
                }

                viewModel.loadError?.let { err ->
                    Column(
                        Modifier
                            .fillMaxWidth()
                            .background(Color(0xFFFF3B30).copy(0.12f), androidx.compose.foundation.shape.RoundedCornerShape(12.dp))
                            .padding(12.dp),
                    ) {
                        Text(err, fontSize = 13.sp, color = Color(0xFFFF3B30))
                        Spacer(Modifier.height(8.dp))
                        TextButton(onClick = { viewModel.refreshAccount(force = true) }) {
                            Text("Réessayer", fontSize = 13.sp)
                        }
                    }
                    Spacer(Modifier.height(GroupedSettingsMetrics.interCardSpacing))
                }

                SettingsLastSyncSection(
                    syncService = syncService,
                    scope = appScope,
                    businessSlug = viewModel.currentSlug.orEmpty(),
                )
                Spacer(Modifier.height(GroupedSettingsMetrics.interCardSpacing))

                GroupedSettingsCard {
                    GroupedSettingsInfoRow(Icons.Default.Email, "E-mail", viewModel.email.ifEmpty { "—" })
                    GroupedSettingsRowDivider()
                    GroupedSettingsInfoRow(Icons.Default.VpnKey, "Connexion", viewModel.authProviderLabel)
                    GroupedSettingsRowDivider()
                    GroupedSettingsInfoRow(Icons.Default.Store, "Commerces", "${viewModel.businesses.size}")
                }
                Spacer(Modifier.height(GroupedSettingsMetrics.interCardSpacing))

                if (viewModel.businesses.size > 1) {
                    GroupedSettingsCard {
                        CommercePickerRow(
                            businesses = viewModel.businesses,
                            currentSlug = viewModel.currentSlug,
                            menuOpen = commerceMenuOpen,
                            onMenuOpen = { commerceMenuOpen = true },
                            onDismiss = { commerceMenuOpen = false },
                            onSelect = {
                                commerceMenuOpen = false
                                viewModel.switchBusiness(it)
                            },
                        )
                    }
                    Spacer(Modifier.height(GroupedSettingsMetrics.interCardSpacing))
                }

                GroupedSettingsCard {
                    if (viewModel.isEmailAuth) {
                        RowAction(
                            icon = Icons.Default.LockReset,
                            label = if (viewModel.isSendingPasswordReset) "Envoi en cours…" else "Réinitialiser le mot de passe",
                            enabled = !viewModel.isSendingPasswordReset && viewModel.email.isNotEmpty(),
                            onClick = { viewModel.sendPasswordReset() },
                        )
                    } else {
                        GroupedSettingsInfoRow(
                            Icons.Default.LockReset,
                            "Mot de passe",
                            viewModel.passwordExternalLabel ?: "—",
                        )
                    }
                }
                Spacer(Modifier.height(GroupedSettingsMetrics.interCardSpacing))

                GroupedSettingsCard {
                    GroupedSettingsInfoRow(Icons.Default.PhoneAndroid, "Cet appareil", viewModel.deviceLine())
                    GroupedSettingsRowDivider()
                    GroupedSettingsInfoRow(
                        Icons.Default.Notifications,
                        "Notifications push",
                        if (viewModel.pushAuthorized) "Autorisées" else "Non autorisées",
                    )
                }
                Spacer(Modifier.height(GroupedSettingsMetrics.interCardSpacing))

                GroupedSettingsCard {
                    GroupedSettingsDestructiveRow(
                        title = "Supprimer mon compte",
                        onClick = { confirmDelete = true },
                    )
                }
                TextButton(
                    onClick = { openInCustomTab(context, LegalURLs.DELETE_ACCOUNT) },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        "Page d'information (suppression de compte)",
                        fontSize = 13.sp,
                        color = Color(0xFF8E8E93),
                        textAlign = TextAlign.Center,
                    )
                }
                Spacer(Modifier.height(32.dp))
            }
        }

        if (viewModel.isDeletingAccount) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Color.White.copy(0.92f)),
                contentAlignment = Alignment.Center,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    CircularProgressIndicator(color = Color(0xFF2563EB))
                    Spacer(Modifier.height(16.dp))
                    Text("Suppression…", fontWeight = FontWeight.SemiBold)
                }
            }
        }

        if (viewModel.loading && viewModel.loadError == null && viewModel.email.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = Color(0xFF2563EB))
            }
        }
    }
}

@Composable
private fun RowAction(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    androidx.compose.foundation.layout.Row(
        Modifier
            .fillMaxWidth()
            .then(if (enabled) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = GroupedSettingsMetrics.horizontalPadding, vertical = GroupedSettingsMetrics.rowVerticalPadding),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        GroupedSettingsIconBox(icon)
        Spacer(Modifier.width(12.dp))
        Text(label, fontWeight = FontWeight.Medium, fontSize = 16.sp, color = if (enabled) Color(0xFF1C1C1E) else Color(0xFF8E8E93))
    }
}

@Composable
private fun CommercePickerRow(
    businesses: List<fr.myfidpass.data.dto.BusinessDto>,
    currentSlug: String?,
    menuOpen: Boolean,
    onMenuOpen: () -> Unit,
    onDismiss: () -> Unit,
    onSelect: (String) -> Unit,
) {
    val activeName = businesses.firstOrNull { it.slug == currentSlug }?.name?.ifBlank { currentSlug } ?: "—"
    Box {
        androidx.compose.foundation.layout.Row(
            Modifier
                .fillMaxWidth()
                .clickable(onClick = onMenuOpen)
                .padding(horizontal = GroupedSettingsMetrics.horizontalPadding, vertical = GroupedSettingsMetrics.rowVerticalPadding),
            verticalAlignment = Alignment.Top,
        ) {
            GroupedSettingsIconBox(Icons.Default.Store)
            Spacer(Modifier.width(12.dp))
            Text("Commerce actif", fontWeight = FontWeight.Medium, fontSize = 16.sp, modifier = Modifier.weight(1f))
            Text(activeName ?: "—", color = Color(0xFF8E8E93), textAlign = TextAlign.End, maxLines = 2)
        }
        DropdownMenu(expanded = menuOpen, onDismissRequest = onDismiss) {
            businesses.forEach { b ->
                DropdownMenuItem(
                    text = { Text(b.name.ifBlank { b.slug }) },
                    onClick = { onSelect(b.slug) },
                )
            }
        }
    }
}
