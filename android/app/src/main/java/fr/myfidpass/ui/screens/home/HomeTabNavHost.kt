package fr.myfidpass.ui.screens.home

import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.ui.navigation.HomeRoutes
import fr.myfidpass.ui.screens.members.MemberDetailScreen
import fr.myfidpass.ui.screens.members.MembersListScreen
import fr.myfidpass.ui.screens.mycard.MyCardScreen
import fr.myfidpass.ui.screens.scanner.QrScannerScreen
import fr.myfidpass.ui.viewmodel.DashboardViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun HomeTabNavHost(
    modifier: Modifier = Modifier,
    dashboardViewModel: DashboardViewModel,
    sessionStore: SessionStore,
    repository: DashboardRepository,
    snackbarHostState: SnackbarHostState,
    appScope: CoroutineScope,
) {
    val nav = rememberNavController()
    NavHost(
        navController = nav,
        startDestination = HomeRoutes.DASHBOARD,
        modifier = modifier,
    ) {
        composable(HomeRoutes.DASHBOARD) {
            HomeDashboardScreen(
                viewModel = dashboardViewModel,
                sessionStore = sessionStore,
                onMembers = { nav.navigate(HomeRoutes.MEMBERS) },
                onScan = { nav.navigate(HomeRoutes.SCAN) },
                onMyCard = { nav.navigate(HomeRoutes.MYCARD) },
            )
        }
        composable(HomeRoutes.MEMBERS) {
            MembersListScreen(
                repository = repository,
                snackbarHostState = snackbarHostState,
                appScope = appScope,
                onBack = { nav.popBackStack() },
                onMemberClick = { id -> nav.navigate(HomeRoutes.memberDetail(id)) },
            )
        }
        composable(
            route = HomeRoutes.MEMBER_DETAIL,
            arguments = listOf(navArgument("memberId") { type = NavType.StringType }),
        ) { entry ->
            val memberId = entry.arguments?.getString("memberId").orEmpty()
            MemberDetailScreen(
                memberId = memberId,
                repository = repository,
                sessionStore = sessionStore,
                onBack = { nav.popBackStack() },
                snackbar = snackbarHostState,
            )
        }
        composable(HomeRoutes.SCAN) {
            QrScannerScreen(
                onBarcode = { code ->
                    appScope.launch {
                        val slug = sessionStore.currentBusinessSlug
                        if (slug == null) {
                            withContext(Dispatchers.Main) {
                                snackbarHostState.showSnackbar("Session invalide")
                                nav.popBackStack()
                            }
                            return@launch
                        }
                        val result = withContext(Dispatchers.IO) {
                            runCatching { repository.scanLookup(slug, code) }
                        }
                        withContext(Dispatchers.Main) {
                            result.fold(
                                onSuccess = { env ->
                                    val mid = env.member?.id
                                    nav.popBackStack()
                                    if (mid != null) {
                                        nav.navigate(HomeRoutes.memberDetail(mid))
                                    } else {
                                        snackbarHostState.showSnackbar("Code non reconnu")
                                    }
                                },
                                onFailure = { e ->
                                    nav.popBackStack()
                                    snackbarHostState.showSnackbar(e.message ?: "Erreur scan")
                                },
                            )
                        }
                    }
                },
                onClose = { nav.popBackStack() },
            )
        }
        composable(HomeRoutes.MYCARD) {
            MyCardScreen(
                viewModel = dashboardViewModel,
                sessionStore = sessionStore,
                onBack = { nav.popBackStack() },
            )
        }
    }
}
