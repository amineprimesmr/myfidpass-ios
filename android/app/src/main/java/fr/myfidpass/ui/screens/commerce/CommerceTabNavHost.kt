package fr.myfidpass.ui.screens.commerce

import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import fr.myfidpass.di.AppContainer
import fr.myfidpass.ui.navigation.CommerceRoutes
import kotlinx.coroutines.CoroutineScope

@Composable
fun CommerceTabNavHost(
    modifier: Modifier = Modifier,
    container: AppContainer,
    snackbarHostState: SnackbarHostState,
    appScope: CoroutineScope,
    onLogout: () -> Unit,
) {
    val nav = rememberNavController()
    NavHost(
        navController = nav,
        startDestination = CommerceRoutes.HUB,
        modifier = modifier,
    ) {
        composable(CommerceRoutes.HUB) {
            CommerceHubScreen(
                sessionStore = container.sessionStore,
                dashboardRepository = container.dashboardRepository,
                isAdmin = container.sessionStore.isAdminUser,
                onOpenSettings = { nav.navigate(CommerceRoutes.SETTINGS) },
                onOpenStats = { nav.navigate(CommerceRoutes.STATS) },
                onOpenCategories = { nav.navigate(CommerceRoutes.CATEGORIES) },
                onOpenProgram = { nav.navigate(CommerceRoutes.PROGRAM) },
                onOpenAdmin = { nav.navigate(CommerceRoutes.ADMIN) },
                onLogout = onLogout,
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
            StatsTransactionsScreen(
                repository = container.dashboardRepository,
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
                repository = container.dashboardRepository,
                onBack = { nav.popBackStack() },
            )
        }
        composable(CommerceRoutes.SOCIAL) {
            SocialEngagementScreen(
                repository = container.dashboardRepository,
                snackbarHostState = snackbarHostState,
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
        composable(CommerceRoutes.ADMIN) {
            AdminPlatformScreen(
                repository = container.dashboardRepository,
                onBack = { nav.popBackStack() },
            )
        }
    }
}
