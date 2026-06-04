package fr.myfidpass.ui.screens.settings

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
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
import fr.myfidpass.ui.screens.commerce.AddCommerceScreen
import fr.myfidpass.ui.screens.commerce.CategoriesScreen
import fr.myfidpass.ui.screens.commerce.MatchPredictionsScreen
import fr.myfidpass.ui.screens.commerce.ScanSecuritySettingsScreen
import fr.myfidpass.ui.screens.commerce.TeamManagementScreen
import fr.myfidpass.ui.screens.commerce.TeamMemberDetailScreen
import fr.myfidpass.ui.viewModelFactory
import fr.myfidpass.ui.viewmodel.AccountSettingsViewModel
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.remember
import kotlinx.coroutines.CoroutineScope

/** Flux Réglages / Compte — aligné iOS sheet `NavigationStack { SettingsView() }`. */
@Composable
fun SettingsFlowNavHost(
    container: AppContainer,
    snackbarHostState: SnackbarHostState,
    appScope: CoroutineScope,
    onDismiss: () -> Unit,
    onLogout: () -> Unit,
    onOpenPaywall: () -> Unit,
    onOpenFlyerHub: () -> Unit = {},
    modifier: Modifier = Modifier,
    showFlyerShortcuts: Boolean = false,
) {
    val factory = remember(container) { viewModelFactory(container) }
    val nav = rememberNavController()

    NavHost(
        navController = nav,
        startDestination = CommerceRoutes.SETTINGS_HUB,
        modifier = modifier,
        enterTransition = { merchantPushEnter() },
        exitTransition = { merchantPushExit() },
        popEnterTransition = { merchantPopEnter() },
        popExitTransition = { merchantPopExit() },
    ) {
        composable(CommerceRoutes.SETTINGS_HUB) {
            SettingsHubScreen(
                sessionStore = container.sessionStore,
                syncService = container.syncService,
                onBack = onDismiss,
                onAccount = { nav.navigate(CommerceRoutes.ACCOUNT) },
                onAppSettings = { nav.navigate(CommerceRoutes.SETTINGS_APP) },
                onScanSecurity = { nav.navigate(CommerceRoutes.SCAN_SECURITY) },
                onTeam = { nav.navigate(CommerceRoutes.TEAM) },
                onMatchPredictions = { nav.navigate(CommerceRoutes.MATCH_PREDICTIONS) },
                onAccounting = { nav.navigate(CommerceRoutes.ACCOUNTING) },
                onOpenFlyerHub = onOpenFlyerHub,
                showFlyerShortcuts = showFlyerShortcuts,
                onCategories = { nav.navigate(CommerceRoutes.CATEGORIES) },
            )
        }
        composable(CommerceRoutes.CATEGORIES) {
            CategoriesScreen(
                repository = container.dashboardRepository,
                snackbarHostState = snackbarHostState,
                onBack = { nav.popBackStack() },
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
            val vm: AccountSettingsViewModel = viewModel(factory = factory)
            AccountSettingsDetailScreen(
                viewModel = vm,
                syncService = container.syncService,
                appScope = appScope,
                onBack = { nav.popBackStack() },
                onLoggedOut = onLogout,
            )
        }
        composable(CommerceRoutes.SCAN_SECURITY) {
            ScanSecuritySettingsScreen(
                repository = container.dashboardRepository,
                sessionStore = container.sessionStore,
                snackbar = snackbarHostState,
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
        composable(CommerceRoutes.ACCOUNTING) {
            MerchantAccountingPackScreen(
                repository = container.dashboardRepository,
                snackbar = snackbarHostState,
                onBack = { nav.popBackStack() },
            )
        }
        composable(CommerceRoutes.ADD_COMMERCE) {
            AddCommerceScreen(
                container = container,
                businessCreationRepository = container.businessCreationRepository,
                snackbar = snackbarHostState,
                onBack = { nav.popBackStack() },
                onCreated = { nav.popBackStack() },
            )
        }
    }
}
