package fr.myfidpass.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import fr.myfidpass.AppContainer
import fr.myfidpass.ui.screens.LoginScreen
import fr.myfidpass.ui.screens.MainTabsScreen
import fr.myfidpass.ui.screens.MemberDetailScreen
import fr.myfidpass.ui.screens.MembersListScreen
import fr.myfidpass.ui.screens.SplashScreen

sealed class AppRoute(val route: String) {
    data object Splash : AppRoute("splash")
    data object Login : AppRoute("login")
    data object Main : AppRoute("main")
    data object MembersList : AppRoute("members")
    data object MemberDetail : AppRoute("members/{memberId}") {
        fun create(memberId: String) = "members/$memberId"
    }
}

@Composable
fun AppNavGraph(
    navController: NavHostController = rememberNavController(),
    container: AppContainer
) {
    val authState by container.authRepository.state.collectAsState()

    NavHost(
        navController = navController,
        startDestination = AppRoute.Splash.route
    ) {
        composable(AppRoute.Splash.route) {
            SplashScreen(
                authRepository = container.authRepository,
                authState = authState,
                onNavigateToLogin = { navController.navigate(AppRoute.Login.route) { popUpTo(0) { inclusive = true } } },
                onNavigateToMain = { navController.navigate(AppRoute.Main.route) { popUpTo(0) { inclusive = true } } }
            )
        }
        composable(AppRoute.Login.route) {
            LoginScreen(
                authRepository = container.authRepository,
                onLoginSuccess = { navController.navigate(AppRoute.Main.route) { popUpTo(AppRoute.Login.route) { inclusive = true } } }
            )
        }
        composable(AppRoute.Main.route) {
            MainTabsScreen(
                container = container,
                navController = navController,
                onLogout = {
                    navController.navigate(AppRoute.Login.route) {
                        popUpTo(AppRoute.Main.route) { inclusive = true }
                    }
                }
            )
        }
        composable(AppRoute.MembersList.route) {
            MembersListScreen(
                container = container,
                onMemberClick = { memberId -> navController.navigate(AppRoute.MemberDetail.create(memberId)) },
                onBack = { navController.popBackStack() }
            )
        }
        composable(
            route = AppRoute.MemberDetail.route,
            arguments = listOf(navArgument("memberId") { type = NavType.StringType })
        ) { backStackEntry ->
            val memberId = backStackEntry.arguments?.getString("memberId") ?: return@composable
            MemberDetailScreen(
                container = container,
                memberId = memberId,
                onBack = { navController.popBackStack() }
            )
        }
    }
}
