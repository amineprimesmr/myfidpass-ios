package fr.myfidpass.ui.screens.commerce

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.repo.AuthRepository
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.util.openInCustomTab
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MerchantSettingsScreen(
    authRepository: AuthRepository,
    dashboardRepository: DashboardRepository,
    sessionStore: SessionStore,
    onBack: () -> Unit,
    snackbarHostState: SnackbarHostState,
    appScope: CoroutineScope,
    onLogout: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var showForgot by remember { mutableStateOf(false) }
    var forgotEmail by remember { mutableStateOf(sessionStore.userEmail.orEmpty()) }
    var showDelete by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Réglages") },
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
                "Compte",
                style = MaterialTheme.typography.titleMedium,
            )
            Spacer(Modifier.height(8.dp))
            sessionStore.userEmail?.let {
                Text(it, style = MaterialTheme.typography.bodyLarge)
            }
            Spacer(Modifier.height(20.dp))
            OutlinedButton(
                onClick = {
                    val slug = sessionStore.currentBusinessSlug ?: return@OutlinedButton
                    scope.launch {
                        runCatching {
                            val r = dashboardRepository.paymentPortal()
                            val url = r.url?.trim()
                            if (!url.isNullOrEmpty()) {
                                openInCustomTab(context, url)
                            } else {
                                snackbarHostState.showSnackbar("Portail indisponible")
                            }
                        }.onFailure {
                            snackbarHostState.showSnackbar(it.message ?: "Erreur")
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Facturation / moyen de paiement (Stripe)") }
            Spacer(Modifier.height(10.dp))
            OutlinedButton(
                onClick = {
                    scope.launch {
                        runCatching {
                            val r = dashboardRepository.paymentReconcile()
                            val ok = r.hasActiveSubscription == true || r.ok == true
                            snackbarHostState.showSnackbar(
                                r.message ?: if (ok) "Abonnement synchronisé" else "Aucun changement",
                            )
                        }.onFailure {
                            snackbarHostState.showSnackbar(it.message ?: "Erreur")
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Synchroniser l’abonnement Stripe") }
            Spacer(Modifier.height(10.dp))
            OutlinedButton(
                onClick = {
                    scope.launch {
                        runCatching {
                            val r = dashboardRepository.paymentCheckout(null)
                            val url = r.url?.trim()
                            if (!url.isNullOrEmpty()) openInCustomTab(context, url)
                            else snackbarHostState.showSnackbar("Session de paiement indisponible")
                        }.onFailure {
                            snackbarHostState.showSnackbar(it.message ?: "Erreur")
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Souscrire / changer d’offre") }
            Spacer(Modifier.height(24.dp))
            OutlinedButton(
                onClick = { showForgot = true },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Mot de passe oublié (e-mail)") }
            Spacer(Modifier.height(10.dp))
            OutlinedButton(
                onClick = { showDelete = true },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Supprimer mon compte") }
            Spacer(Modifier.height(24.dp))
            Button(
                onClick = { onLogout() },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Déconnexion") }
        }
    }

    if (showForgot) {
        AlertDialog(
            onDismissRequest = { showForgot = false },
            title = { Text("Réinitialisation") },
            text = {
                OutlinedTextField(
                    value = forgotEmail,
                    onValueChange = { forgotEmail = it },
                    label = { Text("E-mail") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        scope.launch {
                            runCatching {
                                authRepository.forgotPassword(forgotEmail)
                                snackbarHostState.showSnackbar("Si un compte existe, un e-mail a été envoyé.")
                            }.onFailure {
                                snackbarHostState.showSnackbar(it.message ?: "Erreur")
                            }
                            showForgot = false
                        }
                    },
                ) { Text("Envoyer") }
            },
            dismissButton = {
                TextButton(onClick = { showForgot = false }) { Text("Annuler") }
            },
        )
    }

    if (showDelete) {
        AlertDialog(
            onDismissRequest = { showDelete = false },
            title = { Text("Supprimer le compte ?") },
            text = { Text("Action irréversible. Vos commerces et données seront supprimés selon les CGU.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        appScope.launch {
                            runCatching { authRepository.deleteAccount() }
                            showDelete = false
                            onLogout()
                        }
                    },
                ) { Text("Supprimer", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { showDelete = false }) { Text("Annuler") }
            },
        )
    }
}
