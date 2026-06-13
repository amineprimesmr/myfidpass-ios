package fr.myfidpass.ui.screens.main

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import fr.myfidpass.di.AppContainer
import fr.myfidpass.ui.components.BusinessSwitchingOverlay
import fr.myfidpass.ui.components.PostCardFlyerPromoEligibility
import fr.myfidpass.ui.components.PostCardFlyerPromoSheet
import fr.myfidpass.ui.components.CustomSideMenu
import fr.myfidpass.ui.components.DashboardHomeMinimalTopBar
import fr.myfidpass.ui.components.DashboardHomeStaffTopBar
import fr.myfidpass.ui.components.MerchantTabShell
import fr.myfidpass.ui.components.MerchantFloatingTabBar
import fr.myfidpass.ui.components.MerchantFloatingTabBarMetrics
import fr.myfidpass.ui.components.MerchantSubscribeFloatingPill
import fr.myfidpass.ui.components.SafeArea
import fr.myfidpass.ui.components.ScanSuccessToastHost
import fr.myfidpass.ui.components.SyncErrorBanner
import fr.myfidpass.ui.components.XStyleSettingsSidebar
import fr.myfidpass.ui.screens.auth.MerchantPaywallScreen
import fr.myfidpass.ui.screens.commerce.AddCommerceScreen
import fr.myfidpass.ui.screens.commerce.CommerceTabNavHost
import fr.myfidpass.ui.screens.commerce.FlyerToolsScreen
import fr.myfidpass.ui.screens.commerce.MatchPredictionsScreen
import fr.myfidpass.ui.screens.settings.SettingsFlowNavHost
import fr.myfidpass.ui.navigation.MerchantAnimatedFullScreenOverlay
import fr.myfidpass.ui.navigation.merchantPaywallEnter
import fr.myfidpass.ui.navigation.merchantPaywallExit
import fr.myfidpass.ui.navigation.merchantTabTransitionSpec
import fr.myfidpass.ui.screens.home.HomeTabNavHost
import fr.myfidpass.ui.theme.MerchantDesignSystem
import fr.myfidpass.ui.screens.profile.StaffAccountScreen
import fr.myfidpass.ui.screens.tabs.CampaignsTabScreen
import fr.myfidpass.ui.viewmodel.DashboardViewModel
import fr.myfidpass.ui.theme.FintechLightPalette
import fr.myfidpass.util.HapticHelper
import fr.myfidpass.util.LegalURLs
import fr.myfidpass.util.openInCustomTab
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun MainTabsScreen(
    container: AppContainer,
    dashboardViewModel: DashboardViewModel,
    snackbarHostState: SnackbarHostState,
    appScope: CoroutineScope,
    onLogout: () -> Unit,
    pendingScanRequest: Int = 0,
    onScanRequestConsumed: () -> Unit = {},
) {
    var tab by rememberSaveable { mutableIntStateOf(0) }
    val isStaff = container.sessionStore.isMerchantStaffUser()
    val fullLayout = container.sessionStore.usesFullMerchantTabLayout()
    val slug = container.sessionStore.currentBusinessSlug?.trim().orEmpty()
    var showSettings by remember { mutableStateOf(false) }
    var showAddCommerce by remember { mutableStateOf(false) }
    var showProPaywall by remember { mutableStateOf(false) }
    var paywallAddingCommerce by remember { mutableStateOf(false) }
    var paywallPendingCommerceName by remember { mutableStateOf<String?>(null) }
    var scanToast by remember { mutableStateOf<String?>(null) }
    var homeImmersiveMyCard by remember { mutableStateOf(false) }
    var homeSidebarExpanded by remember { mutableStateOf(false) }
    var homeAtRoot by remember { mutableStateOf(true) }
    var commerceStatsAtRoot by remember { mutableStateOf(true) }
    var showFlyerHub by remember { mutableStateOf(false) }
    var flyerHubStartCreateAssistant by remember { mutableStateOf(false) }
    var flyerHubOpenForEdit by remember { mutableStateOf(false) }
    var showMatchPredictions by remember { mutableStateOf(false) }
    var flyerAttentionDot by remember { mutableStateOf(false) }
    var isBusinessSwitching by remember { mutableStateOf(false) }
    var openScanTrigger by remember { mutableIntStateOf(0) }
    var showFlyerPromo by remember { mutableStateOf(false) }

    val view = LocalView.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    fun selectTab(index: Int) {
        if (index != tab) HapticHelper.tabSwitch(view)
        tab = index
    }

    fun handleBusinessSwitched() {
        isBusinessSwitching = true
        dashboardViewModel.load()
        scope.launch {
            delay(450)
            isBusinessSwitching = false
        }
    }

    LaunchedEffect(slug, tab) {
        flyerAttentionDot = slug.isNotEmpty() &&
            PostCardFlyerPromoEligibility.showsCreationAttentionBadge(context, slug)
    }

    LaunchedEffect(pendingScanRequest) {
        if (pendingScanRequest > 0) {
            tab = 0
            openScanTrigger = pendingScanRequest
            onScanRequestConsumed()
        }
    }

    LaunchedEffect(slug) {
        if (slug.isBlank()) return@LaunchedEffect
        PostCardFlyerPromoEligibility.resetSessionSuppressionForAppOpen()
        val promoSlug = PostCardFlyerPromoEligibility.dequeuePendingSlugIfEligible(context) ?: slug
        container.syncService.syncIfNeeded(promoSlug, force = true)
        delay(450)
        if (container.syncService.hasCompletedFlyerHydration(promoSlug) &&
            PostCardFlyerPromoEligibility.shouldOffer(context, promoSlug)
        ) {
            showFlyerPromo = true
        }
    }

    fun runAfterHomeSidebarDismisses(action: () -> Unit) {
        if (homeSidebarExpanded) {
            homeSidebarExpanded = false
            scope.launch {
                delay(260)
                action()
            }
        } else {
            action()
        }
    }

    val businessName = container.sessionStore.businesses
        .firstOrNull { it.slug == container.sessionStore.currentBusinessSlug }
        ?.name
        ?: container.sessionStore.currentBusinessSlug
        ?: "Mon commerce"

    fun openPaywall(addingCommerce: Boolean = false, pendingName: String? = null) {
        paywallAddingCommerce = addingCommerce
        paywallPendingCommerceName = pendingName
        showProPaywall = true
    }

    fun openFlyerHub(startCreateAssistant: Boolean = false, openForEdit: Boolean = false) {
        if (!container.sessionStore.merchantProInsightsUnlocked()) {
            openPaywall()
            return
        }
        flyerHubStartCreateAssistant = startCreateAssistant
        flyerHubOpenForEdit = openForEdit
        showFlyerHub = true
    }

    val hasProAccess = container.sessionStore.merchantProInsightsUnlocked()

    val onSubscribe: () -> Unit = {
        val slots = fr.myfidpass.util.MerchantMultiPricing.slotsToPurchase(
            usedBusinesses = container.sessionStore.usedBusinesses,
            allowedBusinesses = container.sessionStore.allowedBusinesses,
            addingAnotherCommerce = false,
        )
        val url = fr.myfidpass.util.LegalURLs.merchantEmbeddedSaasPaymentPage(
            prefilledEmail = container.sessionStore.userEmail,
            planAnnual = false,
            commerceSlots = slots,
            accessToken = container.sessionStore.accessToken,
            refreshToken = container.sessionStore.refreshToken,
        )
        openInCustomTab(context, url)
    }

    val onAddCommerce: () -> Unit = { showAddCommerce = true }

    val onUnlockPro: () -> Unit = { openPaywall() }

    LaunchedEffect(tab, fullLayout) {
        if (tab == 0) dashboardViewModel.refresh()
        if (isStaff && tab > 1) tab = 0
    }

    DisposableEffect(slug) {
        if (slug.isBlank()) return@DisposableEffect onDispose {}
        val lifecycle = ProcessLifecycleOwner.get().lifecycle
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_START) {
                dashboardViewModel.refresh()
            }
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }

    Scaffold(
        containerColor = Color.Black,
    ) {
        Box(Modifier.fillMaxSize()) {
            AnimatedContent(
                targetState = tab,
                transitionSpec = merchantTabTransitionSpec(),
                label = "merchantMainTabs",
                modifier = Modifier.fillMaxSize(),
            ) { currentTab ->
            when {
                currentTab == 0 -> {
                    if (isStaff) {
                        MerchantTabShell(
                            topBar = {
                                if (!homeImmersiveMyCard) {
                                    DashboardHomeStaffTopBar(
                                        title = "Accueil",
                                        onSettingsClick = { tab = 1 },
                                    )
                                }
                            },
                            canvasColor = if (homeImmersiveMyCard) {
                                Color(0xFFF2F2F7)
                            } else {
                                FintechLightPalette.canvas
                            },
                            immersiveContent = homeImmersiveMyCard,
                        ) { contentModifier ->
                            HomeTabNavHost(
                                modifier = contentModifier,
                                dashboardViewModel = dashboardViewModel,
                                sessionStore = container.sessionStore,
                                repository = container.dashboardRepository,
                                syncService = container.syncService,
                                snackbarHostState = snackbarHostState,
                                appScope = appScope,
                                onSubscribe = onSubscribe,
                                isStaff = true,
                                onOpenMerchantStats = { tab = 2 },
                                onScanSuccessToast = {
                                    HapticHelper.scan(view)
                                    scanToast = it
                                },
                                openScanTrigger = openScanTrigger,
                                onUnlockPro = onUnlockPro,
                                onMyCardVisibilityChange = { homeImmersiveMyCard = it },
                                onHomeAtRootChange = { homeAtRoot = it },
                            )
                        }
                    } else {
                        CustomSideMenu(
                            isExpanded = homeSidebarExpanded,
                            onExpandedChange = { homeSidebarExpanded = it },
                            panelBackground = FintechLightPalette.canvas,
                            menuContent = {
                                XStyleSettingsSidebar(
                                    sessionStore = container.sessionStore,
                                    showFlyerAttentionDot = flyerAttentionDot,
                                    onOpenFlyer = {
                                        runAfterHomeSidebarDismisses {
                                            openFlyerHub()
                                        }
                                    },
                                    onOpenFootballGame = {
                                        runAfterHomeSidebarDismisses { showMatchPredictions = true }
                                    },
                                    onOpenLiveGame = {
                                        runAfterHomeSidebarDismisses {
                                            slug.takeIf { it.isNotEmpty() }?.let {
                                                openInCustomTab(context, LegalURLs.fidelityCardPage(it))
                                            }
                                        }
                                    },
                                    onOpenSettings = {
                                        runAfterHomeSidebarDismisses { showSettings = true }
                                    },
                                )
                            },
                            content = {
                            MerchantTabShell(
                                topBar = {
                                    if (!homeImmersiveMyCard) {
                                        DashboardHomeMinimalTopBar(
                                            title = "Accueil",
                                            businessLabel = businessName,
                                            sessionStore = container.sessionStore,
                                            onSettingsClick = { showSettings = true },
                                            onBusinessSwitched = { handleBusinessSwitched() },
                                            onAddCommerce = onAddCommerce,
                                            showBusinessSwitcher = false,
                                            onOpenSideMenu = { homeSidebarExpanded = !homeSidebarExpanded },
                                            dashboardRepository = container.dashboardRepository,
                                            refreshAttentionDotKey = tab to showSettings,
                                        )
                                    }
                                },
                                canvasColor = if (homeImmersiveMyCard) {
                                    Color(0xFFF2F2F7)
                                } else {
                                    FintechLightPalette.canvas
                                },
                                immersiveContent = homeImmersiveMyCard,
                            ) { contentModifier ->
                                HomeTabNavHost(
                                    modifier = contentModifier,
                                    dashboardViewModel = dashboardViewModel,
                                    sessionStore = container.sessionStore,
                                    repository = container.dashboardRepository,
                                    syncService = container.syncService,
                                    snackbarHostState = snackbarHostState,
                                    appScope = appScope,
                                    onSubscribe = onSubscribe,
                                    isStaff = false,
                                    onOpenMerchantStats = { tab = 2 },
                                    onScanSuccessToast = {
                                    HapticHelper.scan(view)
                                    scanToast = it
                                },
                                    openScanTrigger = openScanTrigger,
                                    onUnlockPro = onUnlockPro,
                                    onMyCardVisibilityChange = { homeImmersiveMyCard = it },
                                    onHomeAtRootChange = { homeAtRoot = it },
                                )
                            }
                            },
                        )
                    }
                }
                isStaff && currentTab == 1 -> StaffAccountScreen(
                    container = container,
                    syncService = container.syncService,
                    snackbar = snackbarHostState,
                    onLogout = onLogout,
                )
                fullLayout && currentTab == 1 -> MerchantTabShell(
                    topBar = {
                        DashboardHomeMinimalTopBar(
                            title = "Notifications",
                            businessLabel = businessName,
                            sessionStore = container.sessionStore,
                            onSettingsClick = { showSettings = true },
                            onBusinessSwitched = { handleBusinessSwitched() },
                            onAddCommerce = onAddCommerce,
                            dashboardRepository = container.dashboardRepository,
                            refreshAttentionDotKey = tab to showSettings,
                        )
                    },
                    canvasColor = FintechLightPalette.canvas,
                ) { contentModifier ->
                    CampaignsTabScreen(
                        modifier = contentModifier,
                        repository = container.dashboardRepository,
                        sessionStore = container.sessionStore,
                        snackbarHostState = snackbarHostState,
                        hasProAccess = container.sessionStore.merchantProInsightsUnlocked(),
                        onUnlockPro = onUnlockPro,
                        onRequestAccountRefresh = {
                            scope.launch {
                                runCatching { container.authRepository.refreshAccount() }
                                dashboardViewModel.load()
                            }
                        },
                    )
                }
                fullLayout && currentTab == 2 -> MerchantTabShell(
                    topBar = {
                        DashboardHomeMinimalTopBar(
                            title = "Statistiques",
                            businessLabel = businessName,
                            sessionStore = container.sessionStore,
                            onSettingsClick = { showSettings = true },
                            onBusinessSwitched = { handleBusinessSwitched() },
                            onAddCommerce = onAddCommerce,
                            dashboardRepository = container.dashboardRepository,
                            refreshAttentionDotKey = tab to showSettings,
                        )
                    },
                    canvasColor = FintechLightPalette.canvas,
                ) { contentModifier ->
                    CommerceTabNavHost(
                        modifier = contentModifier,
                        container = container,
                        snackbarHostState = snackbarHostState,
                        appScope = appScope,
                        onLogout = onLogout,
                        embeddedRoot = true,
                        onUnlockPro = onUnlockPro,
                        onCommerceQuotaBlocked = { name -> openPaywall(addingCommerce = true, pendingName = name) },
                        onCommerceStatsAtRootChange = { commerceStatsAtRoot = it },
                    )
                }
            }
            }

            ScanSuccessToastHost(
                message = scanToast,
                onDismiss = { scanToast = null },
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = SafeArea.statusBarTop()),
            )

            container.syncService.lastSyncError?.takeIf { it.isNotBlank() }?.let { syncErr ->
                SyncErrorBanner(
                    message = syncErr,
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .padding(top = SafeArea.statusBarTop() + MerchantDesignSystem.topBarScrollInset),
                )
            }

            val shouldShowSubscribePill = !isStaff && fullLayout &&
                !container.sessionStore.hasPaidMerchantSubscription() &&
                !homeSidebarExpanded &&
                !homeImmersiveMyCard &&
                when (tab) {
                    0 -> homeAtRoot
                    1 -> true
                    2 -> commerceStatsAtRoot
                    else -> false
                }

            if (shouldShowSubscribePill) {
                Box(
                    Modifier
                        .align(Alignment.BottomCenter)
                        .fillMaxWidth()
                        .padding(bottom = MerchantFloatingTabBarMetrics.subscribePillBottomInset),
                    contentAlignment = Alignment.Center,
                ) {
                    MerchantSubscribeFloatingPill(onSubscribe = onUnlockPro)
                }
            }

            if (!(tab == 0 && homeSidebarExpanded && !isStaff) && !homeImmersiveMyCard) {
                MerchantFloatingTabBar(
                    selectedTab = tab,
                    onTabSelected = { selectTab(it) },
                    fullLayout = fullLayout,
                    modifier = Modifier.align(Alignment.BottomCenter),
                )
            }

            AnimatedVisibility(
                visible = showProPaywall,
                enter = merchantPaywallEnter(),
                exit = merchantPaywallExit(),
            ) {
                MerchantPaywallScreen(
                    userEmail = container.sessionStore.userEmail,
                    sessionStore = container.sessionStore,
                    dashboardRepository = container.dashboardRepository,
                    authRepository = container.authRepository,
                    onLogout = onLogout,
                    onAccessGranted = {
                        val wasAddingCommerce = paywallAddingCommerce
                        showProPaywall = false
                        paywallAddingCommerce = false
                        paywallPendingCommerceName = null
                        dashboardViewModel.load()
                        if (wasAddingCommerce && container.sessionStore.canCreateBusiness) {
                            showAddCommerce = true
                        }
                    },
                    allowsClose = true,
                    onClose = {
                        showProPaywall = false
                        paywallAddingCommerce = false
                        paywallPendingCommerceName = null
                    },
                    addingAnotherCommerce = paywallAddingCommerce,
                    pendingCommerceName = paywallPendingCommerceName,
                )
            }

            MerchantAnimatedFullScreenOverlay(visible = showSettings && !isStaff) {
                SettingsFlowNavHost(
                    container = container,
                    snackbarHostState = snackbarHostState,
                    appScope = appScope,
                    onDismiss = { showSettings = false },
                    onLogout = onLogout,
                    onOpenPaywall = { adding, pending -> openPaywall(adding, pending) },
                    onOpenFlyerHub = {
                        showSettings = false
                        openFlyerHub()
                    },
                    showFlyerShortcuts = true,
                    modifier = Modifier.fillMaxSize(),
                )
            }

            MerchantAnimatedFullScreenOverlay(visible = showFlyerHub) {
                FlyerToolsScreen(
                    container = container,
                    snackbar = snackbarHostState,
                    startCreateAssistant = flyerHubStartCreateAssistant,
                    openForEdit = flyerHubOpenForEdit,
                    hasProAccess = hasProAccess,
                    onUnlockPro = onUnlockPro,
                    onFlyerSaveSuccess = { showFlyerHub = false },
                    onBack = {
                        showFlyerHub = false
                        flyerHubStartCreateAssistant = false
                        flyerHubOpenForEdit = false
                    },
                )
            }

            MerchantAnimatedFullScreenOverlay(visible = showAddCommerce) {
                AddCommerceScreen(
                    container = container,
                    businessCreationRepository = container.businessCreationRepository,
                    snackbar = snackbarHostState,
                    onBack = { showAddCommerce = false },
                    onCreated = {
                        showAddCommerce = false
                        dashboardViewModel.load()
                    },
                    onQuotaBlocked = { name ->
                        showAddCommerce = false
                        openPaywall(addingCommerce = true, pendingName = name)
                    },
                )
            }

            MerchantAnimatedFullScreenOverlay(visible = showMatchPredictions) {
                MatchPredictionsScreen(
                    repository = container.dashboardRepository,
                    snackbar = snackbarHostState,
                    onBack = { showMatchPredictions = false },
                )
            }

            BusinessSwitchingOverlay(visible = isBusinessSwitching)

            PostCardFlyerPromoSheet(
                slug = slug,
                visible = showFlyerPromo && slug.isNotEmpty(),
                hasProAccess = hasProAccess,
                onDismiss = { showFlyerPromo = false },
                onUnlockPro = { openPaywall() },
                onCreateFlyer = {
                    showFlyerPromo = false
                    openFlyerHub(startCreateAssistant = true)
                },
            )

        }
    }
}
