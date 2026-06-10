package fr.myfidpass.ui

import android.net.Uri
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.animation.core.tween
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.viewmodel.compose.viewModel
import fr.myfidpass.di.AppContainer
import fr.myfidpass.services.auth.GoogleOAuthFlow
import fr.myfidpass.ui.screens.admin.PlatformAdminRootScreen
import fr.myfidpass.ui.screens.auth.WelcomeFlowScreen
import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import fr.myfidpass.ui.screens.main.MainTabsScreen
import fr.myfidpass.services.notifications.NotificationPermissionHelper
import fr.myfidpass.services.version.PlayStoreVersionChecker
import fr.myfidpass.ui.components.AppUpdateDialog
import fr.myfidpass.ui.components.PaymentThankYouOverlay
import fr.myfidpass.ui.navigation.MerchantMotion
import fr.myfidpass.ui.theme.BackgroundLight
import fr.myfidpass.ui.viewmodel.DashboardViewModel
import fr.myfidpass.ui.viewmodel.RootUiState
import fr.myfidpass.ui.viewmodel.RootViewModel
import fr.myfidpass.util.openInCustomTab
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun AppRoot(
    container: AppContainer,
    pendingOAuthUri: Uri? = null,
    onOAuthUriConsumed: () -> Unit = {},
    pendingScanRequest: Int = 0,
    onScanRequestConsumed: () -> Unit = {},
) {
    val factory = remember(container) { viewModelFactory(container) }
    val rootVm: RootViewModel = viewModel(factory = factory)
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    var appUpdateInfo by remember { mutableStateOf<PlayStoreVersionChecker.UpdateInfo?>(null) }
    var didColdLaunchUpdateCheck by remember { mutableStateOf(false) }

    suspend fun checkAppStoreUpdate(ignoreThrottle: Boolean = false) {
        appUpdateInfo = PlayStoreVersionChecker.check(context, ignoreThrottle = ignoreThrottle)
    }
    var notificationPermissionRequested by remember { mutableStateOf(false) }
    var showPaymentThankYou by remember { mutableStateOf(false) }

    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) {
        container.deviceRegistration.registerAfterLogin()
        container.deviceRegistration.retryPendingIfNeeded()
    }

    fun ensureNotificationsAndRegister() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            NotificationPermissionHelper.needsRuntimePermission(context)
        ) {
            if (!notificationPermissionRequested) {
                notificationPermissionRequested = true
                notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                return
            }
        }
        container.deviceRegistration.registerAfterLogin()
        container.deviceRegistration.retryPendingIfNeeded()
    }

    fun presentPendingSubscriptionThankYouIfNeeded() {
        if (!container.sessionStore.pendingSubscriptionThankYouAfterSignup) return
        container.sessionStore.consumePendingSubscriptionThankYouAfterSignup()
        scope.launch {
            container.syncService.invalidateThrottle()
            delay(450)
            runCatching { container.authRepository.refreshAccount() }
            runCatching {
                container.dashboardRepository.currentSlug()?.let { slug ->
                    container.syncService.syncIfNeeded(slug, force = true)
                }
            }
            if (container.sessionStore.hasPaidMerchantSubscription()) {
                showPaymentThankYou = true
                delay(2400)
                showPaymentThankYou = false
            }
        }
    }

    LaunchedEffect(Unit) {
        rootVm.bootstrap()
    }

    LaunchedEffect(pendingOAuthUri) {
        val uri = pendingOAuthUri ?: return@LaunchedEffect
        runCatching {
            val parsed = GoogleOAuthFlow.parseCallbackUri(uri)
            container.authRepository.applyGoogleOAuthCallback(parsed).getOrThrow()
            ensureNotificationsAndRegister()
            rootVm.onLoggedIn()
        }.onFailure {
            snackbarHostState.showSnackbar(it.message ?: "Connexion Google échouée")
        }
        onOAuthUriConsumed()
    }

    LaunchedEffect(rootVm.state) {
        if (rootVm.state is RootUiState.Main || rootVm.state is RootUiState.AuthLanding) {
            if (!didColdLaunchUpdateCheck) {
                kotlinx.coroutines.delay(900)
                checkAppStoreUpdate(ignoreThrottle = true)
                didColdLaunchUpdateCheck = true
            }
        }
        if (rootVm.state is RootUiState.Main) {
            presentPendingSubscriptionThankYouIfNeeded()
        }
    }

    androidx.compose.runtime.DisposableEffect(lifecycleOwner, rootVm.state) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME &&
                didColdLaunchUpdateCheck &&
                (rootVm.state is RootUiState.Main || rootVm.state is RootUiState.AuthLanding)
            ) {
                scope.launch { checkAppStoreUpdate(ignoreThrottle = false) }
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    appUpdateInfo?.let { info ->
        AppUpdateDialog(
            info = info,
            onDismiss = {
                PlayStoreVersionChecker.dismiss(context, info.storeVersion)
                appUpdateInfo = null
            },
            onOpenStore = {
                openInCustomTab(context, info.playStoreUrl)
                PlayStoreVersionChecker.dismiss(context, info.storeVersion)
                appUpdateInfo = null
            },
        )
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
    ) {
        Box(Modifier.fillMaxSize().background(BackgroundLight)) {
            AnimatedContent(
                targetState = rootVm.state,
                transitionSpec = {
                    fadeIn(tween(MerchantMotion.TabCrossfadeMs, easing = MerchantMotion.navEasing)) togetherWith
                        fadeOut(tween(MerchantMotion.TabCrossfadeMs, easing = MerchantMotion.navEasing))
                },
                label = "appRootState",
                modifier = Modifier.fillMaxSize(),
            ) { state ->
            when (state) {
                RootUiState.Loading -> {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }
                RootUiState.AuthLanding, RootUiState.MerchantEstablishment -> {
                    androidx.compose.runtime.key(container.firstLaunchPreferences.restartEpoch) {
                        WelcomeFlowScreen(
                            container = container,
                            onLoggedIn = {
                                ensureNotificationsAndRegister()
                                rootVm.onLoggedIn()
                                presentPendingSubscriptionThankYouIfNeeded()
                            },
                            onGoogleSignIn = { signUp ->
                                scope.launch {
                                    runCatching {
                                        val config = container.authRepository.authConfig()
                                        val url = GoogleOAuthFlow.buildAuthorizationUrl(
                                            config,
                                            container.firstLaunchPreferences,
                                            mode = if (signUp) "sign_up" else "sign_in",
                                        )
                                        openInCustomTab(context, url)
                                    }.onFailure {
                                        snackbarHostState.showSnackbar(it.message ?: "Connexion Google impossible")
                                    }
                                }
                            },
                            onAuthError = { msg ->
                                scope.launch { snackbarHostState.showSnackbar(msg) }
                            },
                        )
                    }
                }
                RootUiState.Admin -> {
                    PlatformAdminRootScreen(
                        repository = container.dashboardRepository,
                        sessionStore = container.sessionStore,
                        onOpenMerchantApp = { rootVm.onOpenMerchantFromAdmin() },
                    )
                }
                RootUiState.Main -> {
                    val dashVm: DashboardViewModel = viewModel(factory = factory)
                    LaunchedEffect(Unit) {
                        ensureNotificationsAndRegister()
                    }
                    MainTabsScreen(
                        container = container,
                        dashboardViewModel = dashVm,
                        snackbarHostState = snackbarHostState,
                        appScope = scope,
                        onLogout = { rootVm.onLogout() },
                        pendingScanRequest = pendingScanRequest,
                        onScanRequestConsumed = onScanRequestConsumed,
                    )
                    PaymentThankYouOverlay(visible = showPaymentThankYou)
                }
            }
            }
        }
    }
}
