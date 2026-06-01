package fr.myfidpass.ui.screens.commerce

import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.NavType
import androidx.navigation.navArgument
import fr.myfidpass.di.AppContainer
import fr.myfidpass.ui.navigation.CommerceRoutes
import fr.myfidpass.ui.navigation.merchantPopEnter
import fr.myfidpass.ui.navigation.merchantPopExit
import fr.myfidpass.ui.navigation.merchantPushEnter
import fr.myfidpass.ui.navigation.merchantPushExit
import androidx.lifecycle.viewmodel.compose.viewModel
import fr.myfidpass.ui.screens.commerce.MatchPredictionsScreen
import fr.myfidpass.ui.screens.commerce.SocialMissionsScreen
import fr.myfidpass.ui.screens.settings.AccountSettingsDetailScreen
import fr.myfidpass.ui.screens.settings.MerchantAccountingPackScreen
import fr.myfidpass.ui.screens.settings.MerchantTraceabilityExportScreen
import fr.myfidpass.ui.screens.settings.AppSettingsHubScreen
import fr.myfidpass.ui.screens.settings.SettingsHubScreen
import androidx.compose.runtime.remember
import fr.myfidpass.ui.screens.stats.CommerceStatisticsDashboardScreen
import fr.myfidpass.ui.viewModelFactory
import fr.myfidpass.ui.viewmodel.MerchantStatsViewModel
import kotlinx.coroutines.CoroutineScope

@Composable
fun CommerceTabNavHost(
    modifier: Modifier = Modifier,
    container: AppContainer,
    snackbarHostState: SnackbarHostState,
    appScope: CoroutineScope,
    onLogout: () -> Unit,
    embeddedRoot: Boolean = false,
    initialRoute: String = if (embeddedRoot) CommerceRoutes.STATS else CommerceRoutes.HUB,
    onHubBack: (() -> Unit)? = null,
    onUnlockPro: () -> Unit = {},
    onCommerceStatsAtRootChange: (Boolean) -> Unit = {},
) {
    val factory = remember(container) { viewModelFactory(container) }
    val nav = rememberNavController()
    val backStackEntry by nav.currentBackStackEntryAsState()
    val isStatsRoot = embeddedRoot && backStackEntry?.destination?.route == CommerceRoutes.STATS

    LaunchedEffect(isStatsRoot) {
        if (embeddedRoot) onCommerceStatsAtRootChange(isStatsRoot)
    }
    NavHost(
        navController = nav,
        startDestination = initialRoute,
        modifier = modifier,
        enterTransition = { merchantPushEnter() },
        exitTransition = { merchantPushExit() },
        popEnterTransition = { merchantPopEnter() },
        popExitTransition = { merchantPopExit() },
    ) {
        composable(CommerceRoutes.HUB) {
            CommerceHubScreen(
                sessionStore = container.sessionStore,
                dashboardRepository = container.dashboardRepository,
                isAdmin = container.sessionStore.isAdminUser,
                onOpenSettings = { nav.navigate(CommerceRoutes.SETTINGS_HUB) },
                onOpenStats = { nav.navigate(CommerceRoutes.STATS) },
                onOpenCategories = { nav.navigate(CommerceRoutes.CATEGORIES) },
                onOpenProgram = { nav.navigate(CommerceRoutes.PROGRAM) },
                onOpenFlyer = { nav.navigate(CommerceRoutes.FLYER) },
                onOpenTeam = { nav.navigate(CommerceRoutes.TEAM) },
                onOpenScanSecurity = { nav.navigate(CommerceRoutes.SCAN_SECURITY) },
                onOpenAdmin = { nav.navigate(CommerceRoutes.ADMIN) },
                onLogout = onLogout,
            )
        }
        composable(CommerceRoutes.SETTINGS_HUB) {
            SettingsHubScreen(
                sessionStore = container.sessionStore,
                syncService = container.syncService,
                onBack = {
                    if (nav.previousBackStackEntry != null) nav.popBackStack()
                    else onHubBack?.invoke()
                },
                onAccount = { nav.navigate(CommerceRoutes.ACCOUNT) },
                onAppSettings = { nav.navigate(CommerceRoutes.SETTINGS_APP) },
                onScanSecurity = { nav.navigate(CommerceRoutes.SCAN_SECURITY) },
                onTeam = { nav.navigate(CommerceRoutes.TEAM) },
                onMatchPredictions = { nav.navigate(CommerceRoutes.MATCH_PREDICTIONS) },
                onAccounting = { nav.navigate(CommerceRoutes.ACCOUNTING) },
                onOpenFlyerHub = { nav.navigate(CommerceRoutes.FLYER) },
                showFlyerShortcuts = true,
                onCategories = { nav.navigate(CommerceRoutes.CATEGORIES) },
            )
        }
        composable(CommerceRoutes.SETTINGS_APP) {
            AppSettingsHubScreen(
                onBack = { nav.popBackStack() },
                onScanSecurity = { nav.navigate(CommerceRoutes.SCAN_SECURITY) },
                onAccounting = { nav.navigate(CommerceRoutes.ACCOUNTING) },
                onLogout = onLogout,
            )
        }
        composable(CommerceRoutes.ACCOUNT) {
            val vm: fr.myfidpass.ui.viewmodel.AccountSettingsViewModel = viewModel(factory = factory)
            AccountSettingsDetailScreen(
                viewModel = vm,
                syncService = container.syncService,
                appScope = appScope,
                onBack = { nav.popBackStack() },
                onLoggedOut = onLogout,
            )
        }
        composable(CommerceRoutes.ADD_COMMERCE) {
            AddCommerceScreen(
                container = container,
                businessCreationRepository = container.businessCreationRepository,
                snackbar = snackbarHostState,
                onBack = { nav.popBackStack() },
                onCreated = { nav.popBackStack(CommerceRoutes.HUB, false) },
            )
        }
        composable(CommerceRoutes.SETTINGS) {
            MerchantSettingsScreen(
                authRepository = container.authRepository,
                dashboardRepository = container.dashboardRepository,
                sessionStore = container.sessionStore,
                onBack = { nav.popBackStack() },
                snackbarHostState = snackbarHostState,
                appScope = appScope,
                onLogout = onLogout,
            )
        }
        composable(CommerceRoutes.STATS) {
            val statsVm: MerchantStatsViewModel = viewModel(factory = factory)
            CommerceStatisticsDashboardScreen(
                repository = container.dashboardRepository,
                hasProInsights = container.sessionStore.merchantProInsightsUnlocked(),
                onUnlockPro = onUnlockPro,
                embeddedRoot = embeddedRoot,
                statsViewModel = statsVm,
                onBack = {
                    if (!embeddedRoot) {
                        nav.popBackStack()
                    }
                },
                onAccounting = { nav.navigate(CommerceRoutes.ACCOUNTING) },
                onTraceability = { nav.navigate(CommerceRoutes.TRACEABILITY) },
                onStatsTransactions = { nav.navigate(CommerceRoutes.STATS_TRANSACTIONS) },
                onOpenSocial = { nav.navigate(CommerceRoutes.SOCIAL_MISSIONS) },
            )
        }
        composable(CommerceRoutes.STATS_TRANSACTIONS) {
            StatsTransactionsScreen(
                repository = container.dashboardRepository,
                onBack = { nav.popBackStack() },
            )
        }
        composable(CommerceRoutes.ACCOUNTING) {
            MerchantAccountingPackScreen(
                repository = container.dashboardRepository,
                snackbar = snackbarHostState,
                onBack = { nav.popBackStack() },
            )
        }
        composable(CommerceRoutes.TRACEABILITY) {
            MerchantTraceabilityExportScreen(
                repository = container.dashboardRepository,
                snackbar = snackbarHostState,
                onBack = { nav.popBackStack() },
            )
        }
        composable(CommerceRoutes.CATEGORIES) {
            CategoriesScreen(
                repository = container.dashboardRepository,
                snackbarHostState = snackbarHostState,
                onBack = { nav.popBackStack() },
            )
        }
        composable(CommerceRoutes.PROGRAM) {
            ProgramHubScreen(
                onBack = { nav.popBackStack() },
                onGames = { nav.navigate(CommerceRoutes.GAMES) },
                onFlyer = { nav.navigate(CommerceRoutes.FLYER) },
                onSocial = { nav.navigate(CommerceRoutes.SOCIAL) },
                onTools = { nav.navigate(CommerceRoutes.TOOLS) },
                onEstablishment = { nav.navigate(CommerceRoutes.ESTABLISHMENT) },
                onGoogleBusiness = { nav.navigate(CommerceRoutes.GOOGLE_BUSINESS) },
            )
        }
        composable(CommerceRoutes.GAMES) {
            GamesScreen(
                repository = container.dashboardRepository,
                snackbarHostState = snackbarHostState,
                onBack = { nav.popBackStack() },
            )
        }
        composable(CommerceRoutes.FLYER) {
            FlyerToolsScreen(
                container = container,
                snackbar = snackbarHostState,
                openForEdit = true,
                onBack = { nav.popBackStack() },
            )
        }
        composable(CommerceRoutes.SOCIAL) {
            SocialEngagementScreen(
                repository = container.dashboardRepository,
                snackbarHostState = snackbarHostState,
                onBack = { nav.popBackStack() },
                onOpenMissions = { nav.navigate(CommerceRoutes.SOCIAL_MISSIONS) },
            )
        }
        composable(CommerceRoutes.SOCIAL_MISSIONS) {
            SocialMissionsScreen(
                repository = container.dashboardRepository,
                snackbar = snackbarHostState,
                onBack = { nav.popBackStack() },
            )
        }
        composable(CommerceRoutes.TOOLS) {
            EngagementToolsScreen(
                repository = container.dashboardRepository,
                snackbarHostState = snackbarHostState,
                onBack = { nav.popBackStack() },
            )
        }
        composable(CommerceRoutes.ESTABLISHMENT) {
            EstablishmentEditorScreen(
                repository = container.dashboardRepository,
                snackbarHostState = snackbarHostState,
                onBack = { nav.popBackStack() },
            )
        }
        composable(CommerceRoutes.GOOGLE_BUSINESS) {
            GoogleBusinessHubScreen(
                repository = container.dashboardRepository,
                snackbarHostState = snackbarHostState,
                onBack = { nav.popBackStack() },
            )
        }
        composable(CommerceRoutes.ADMIN) {
            AdminPlatformScreen(
                repository = container.dashboardRepository,
                onBack = { nav.popBackStack() },
            )
        }
        composable(CommerceRoutes.TEAM) {
            TeamManagementScreen(
                repository = container.dashboardRepository,
                snackbar = snackbarHostState,
                onBack = { nav.popBackStack() },
                onOpenMember = { memberId -> nav.navigate(CommerceRoutes.teamMember(memberId)) },
            )
        }
        composable(
            route = CommerceRoutes.TEAM_MEMBER,
            arguments = listOf(navArgument("memberId") { type = NavType.StringType }),
        ) { entry ->
            val memberId = entry.arguments?.getString("memberId") ?: return@composable
            TeamMemberDetailScreen(
                repository = container.dashboardRepository,
                memberId = memberId,
                snackbar = snackbarHostState,
                onBack = { nav.popBackStack() },
                onRevoked = {
                    nav.popBackStack(CommerceRoutes.TEAM, inclusive = false)
                },
            )
        }
        composable(CommerceRoutes.MATCH_PREDICTIONS) {
            MatchPredictionsScreen(
                repository = container.dashboardRepository,
                snackbar = snackbarHostState,
                onBack = { nav.popBackStack() },
            )
        }
        composable(CommerceRoutes.SCAN_SECURITY) {
            ScanSecuritySettingsScreen(
                repository = container.dashboardRepository,
                snackbar = snackbarHostState,
                onBack = { nav.popBackStack() },
            )
        }
    }
}
