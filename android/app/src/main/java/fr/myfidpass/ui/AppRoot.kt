package fr.myfidpass.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import fr.myfidpass.di.AppContainer
import fr.myfidpass.ui.screens.auth.AuthLandingScreen
import fr.myfidpass.ui.screens.auth.EmailAuthModalSheet
import fr.myfidpass.ui.screens.onboarding.MerchantEstablishmentScreen
import fr.myfidpass.ui.screens.main.MainTabsScreen
import fr.myfidpass.ui.theme.BackgroundLight
import fr.myfidpass.ui.viewmodel.DashboardViewModel
import fr.myfidpass.ui.viewmodel.EmailAuthViewModel
import fr.myfidpass.ui.viewmodel.MerchantOnboardingViewModel
import fr.myfidpass.ui.viewmodel.RootUiState
import fr.myfidpass.ui.viewmodel.RootViewModel
import kotlinx.coroutines.launch

@Composable
fun AppRoot(container: AppContainer) {
    val factory = remember(container) { viewModelFactory(container) }
    val rootVm: RootViewModel = viewModel(factory = factory)
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        rootVm.bootstrap()
    }

    var showEmailSheet by remember { mutableStateOf(false) }
    var showMerchantOverlay by remember { mutableStateOf(false) }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
    ) { padding ->
        Box(Modifier.fillMaxSize().background(BackgroundLight)) {
            when (val s = rootVm.state) {
                RootUiState.Loading -> {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }
                RootUiState.MerchantEstablishment -> {
                    val merchantVm: MerchantOnboardingViewModel = viewModel(factory = factory)
                    MerchantEstablishmentScreen(
                        viewModel = merchantVm,
                        showTopBarBack = false,
                        onBack = null,
                        onContinue = { p, d, r ->
                            rootVm.onMerchantEstablishmentFinished(p, d, r)
                        },
                        onAlreadyHaveAccount = { rootVm.onMerchantSkipToAuth() },
                    )
                }
                RootUiState.AuthLanding -> {
                    Box(Modifier.fillMaxSize()) {
                        AuthLandingScreen(
                            onContinueWithGoogle = {
                                scope.launch {
                                    snackbarHostState.showSnackbar(
                                        "Connexion Google : branchez votre Web Client ID (comme iOS) puis réessayez. En attendant, utilisez l'e-mail.",
                                    )
                                }
                            },
                            onContinueWithEmail = { showEmailSheet = true },
                            onCreateAccountChooseEstablishment = {
                                showMerchantOverlay = true
                            },
                        )
                        if (showMerchantOverlay) {
                            val overlayVm: MerchantOnboardingViewModel = viewModel(
                                key = "merchant_overlay",
                                factory = factory,
                            )
                            LaunchedEffect(showMerchantOverlay) {
                                if (showMerchantOverlay) overlayVm.resetForNewFlow()
                            }
                            Box(
                                Modifier
                                    .fillMaxSize()
                                    .background(BackgroundLight),
                            ) {
                                MerchantEstablishmentScreen(
                                    viewModel = overlayVm,
                                    showTopBarBack = true,
                                    onBack = { showMerchantOverlay = false },
                                    onContinue = { p, d, r ->
                                        container.firstLaunchPreferences.persistPendingEstablishment(p, d, r)
                                        showMerchantOverlay = false
                                    },
                                    onAlreadyHaveAccount = { showMerchantOverlay = false },
                                )
                            }
                        }
                    }
                }
                RootUiState.Main -> {
                    val dashVm: DashboardViewModel = viewModel(factory = factory)
                    MainTabsScreen(
                        container = container,
                        dashboardViewModel = dashVm,
                        snackbarHostState = snackbarHostState,
                        appScope = scope,
                        onLogout = { rootVm.onLogout() },
                    )
                }
            }
        }
    }

    if (showEmailSheet) {
        val emailVm: EmailAuthViewModel = viewModel(factory = factory)
        LaunchedEffect(Unit) {
            emailVm.resetForSheet()
        }
        EmailAuthModalSheet(
            viewModel = emailVm,
            onDismiss = { showEmailSheet = false },
            onSuccess = {
                showEmailSheet = false
                rootVm.onLoggedIn()
            },
        )
    }
}
