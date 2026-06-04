package fr.myfidpass.ui.screens.home

import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import fr.myfidpass.ui.navigation.merchantModalEnter
import fr.myfidpass.ui.navigation.merchantModalExit
import fr.myfidpass.ui.navigation.merchantModalPopEnter
import fr.myfidpass.ui.navigation.merchantModalPopExit
import fr.myfidpass.ui.navigation.merchantPopEnter
import fr.myfidpass.ui.navigation.merchantPopExit
import fr.myfidpass.ui.navigation.merchantPushEnter
import fr.myfidpass.ui.navigation.merchantPushExit
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.ui.navigation.HomeRoutes
import fr.myfidpass.ui.screens.members.MemberDetailScreen
import fr.myfidpass.ui.screens.members.MembersListScreen
import fr.myfidpass.ui.screens.mycard.MyCardScreen
import fr.myfidpass.ui.screens.scanner.AddPointsAfterScanScreen
import fr.myfidpass.ui.screens.scanner.RewardRedeemScanArgs
import fr.myfidpass.ui.screens.scanner.RewardRedeemScanScreen
import fr.myfidpass.ui.screens.scanner.ScanFlowArgs
import fr.myfidpass.ui.screens.scanner.QrScannerScreen
import fr.myfidpass.ui.viewmodel.DashboardViewModel
import fr.myfidpass.util.effectiveRewardRedeemEligible
import fr.myfidpass.util.effectiveRewardRedeemPoints
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.URLDecoder

@Composable
fun HomeTabNavHost(
    modifier: Modifier = Modifier,
    dashboardViewModel: DashboardViewModel,
    sessionStore: SessionStore,
    repository: DashboardRepository,
    syncService: fr.myfidpass.services.sync.SyncService,
    snackbarHostState: SnackbarHostState,
    appScope: CoroutineScope,
    onSubscribe: () -> Unit = {},
    isStaff: Boolean = false,
    onOpenMerchantStats: () -> Unit = {},
    onScanSuccessToast: ((String) -> Unit)? = null,
    openScanTrigger: Int = 0,
    onUnlockPro: () -> Unit = {},
    onMyCardVisibilityChange: (Boolean) -> Unit = {},
    onHomeAtRootChange: (Boolean) -> Unit = {},
) {
    val nav = rememberNavController()
    val backStackEntry by nav.currentBackStackEntryAsState()
    val isAtRoot = backStackEntry?.destination?.route == HomeRoutes.DASHBOARD

    LaunchedEffect(isAtRoot) {
        onHomeAtRootChange(isAtRoot)
    }

    LaunchedEffect(backStackEntry?.destination?.route) {
        onMyCardVisibilityChange(backStackEntry?.destination?.route == HomeRoutes.MYCARD)
    }

    LaunchedEffect(openScanTrigger) {
        if (openScanTrigger > 0) {
            nav.navigate(HomeRoutes.SCAN) {
                launchSingleTop = true
            }
        }
    }
    NavHost(
        navController = nav,
        startDestination = HomeRoutes.DASHBOARD,
        modifier = modifier,
        enterTransition = { merchantPushEnter() },
        exitTransition = { merchantPushExit() },
        popEnterTransition = { merchantPopEnter() },
        popExitTransition = { merchantPopExit() },
    ) {
        composable(HomeRoutes.DASHBOARD) {
            HomeDashboardScreen(
                viewModel = dashboardViewModel,
                sessionStore = sessionStore,
                isStaff = isStaff,
                repository = repository,
                onUnlockPro = onUnlockPro,
                onMembers = { nav.navigate(HomeRoutes.MEMBERS) },
                onScan = { nav.navigate(HomeRoutes.SCAN) },
                onMyCard = {
                    nav.navigate(HomeRoutes.MYCARD) {
                        launchSingleTop = true
                    }
                },
                onActivityFull = { nav.navigate(HomeRoutes.ACTIVITY_FULL) },
                onMerchantStats = onOpenMerchantStats,
                onSubscribe = onSubscribe,
            )
        }
        composable(HomeRoutes.ACTIVITY_FULL) {
            DashboardActivityFullScreen(
                repository = repository,
                onBack = { nav.popBackStack() },
                onMemberClick = { id -> nav.navigate(HomeRoutes.memberDetail(id)) },
            )
        }
        composable(HomeRoutes.MEMBERS) {
            MembersListScreen(
                repository = repository,
                syncService = syncService,
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
        composable(
            route = HomeRoutes.SCAN,
            enterTransition = { merchantModalEnter() },
            exitTransition = { merchantModalExit() },
            popEnterTransition = { merchantModalPopEnter() },
            popExitTransition = { merchantModalPopExit() },
        ) {
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
                                    if (mid != null) {
                                        val name = env.member?.name ?: env.member?.email ?: "Client"
                                        val redeem = env.rewardRedeem
                                        if (redeem?.label != null) {
                                            val balance = redeem.pointsBalance ?: (env.member?.points ?: 0)
                                            val cost = effectiveRewardRedeemPoints(redeem.pointsRequired, code)
                                            nav.navigate(
                                                HomeRoutes.scanRewardRedeem(
                                                    memberName = name,
                                                    barcode = code,
                                                    rewardLabel = redeem.label,
                                                    pointsRequired = cost,
                                                    pointsBalance = balance,
                                                    eligible = effectiveRewardRedeemEligible(
                                                        redeem.eligible,
                                                        redeem.pointsRequired,
                                                        balance,
                                                        code,
                                                    ),
                                                    mode = redeem.mode ?: "points",
                                                ),
                                            ) {
                                                popUpTo(HomeRoutes.SCAN) { inclusive = true }
                                                launchSingleTop = true
                                            }
                                        } else {
                                            nav.navigate(
                                                HomeRoutes.scanCredit(
                                                    memberId = mid,
                                                    memberName = name,
                                                    barcode = code,
                                                    memberPoints = env.member?.points,
                                                ),
                                            ) {
                                                popUpTo(HomeRoutes.SCAN) { inclusive = true }
                                                launchSingleTop = true
                                            }
                                        }
                                    } else {
                                        nav.popBackStack()
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
        composable(
            route = HomeRoutes.SCAN_CREDIT,
            arguments = listOf(
                navArgument("memberId") { type = NavType.StringType },
                navArgument("memberName") { type = NavType.StringType },
                navArgument("barcode") { type = NavType.StringType },
                navArgument("memberPoints") { type = NavType.StringType },
            ),
        ) { entry ->
            val memberId = entry.arguments?.getString("memberId").orEmpty()
            val memberName = URLDecoder.decode(
                entry.arguments?.getString("memberName").orEmpty(),
                Charsets.UTF_8.name(),
            )
            val barcode = URLDecoder.decode(
                entry.arguments?.getString("barcode").orEmpty(),
                Charsets.UTF_8.name(),
            )
            val ptsRaw = entry.arguments?.getString("memberPoints")
            val memberPoints = if (ptsRaw == "null" || ptsRaw.isNullOrBlank()) null else ptsRaw.toIntOrNull()
            AddPointsAfterScanScreen(
                args = ScanFlowArgs(memberId, memberName, barcode, memberPoints),
                settings = dashboardViewModel.settings,
                repository = repository,
                snackbar = snackbarHostState,
                onDone = {
                    dashboardViewModel.refresh()
                    nav.popBackStack(HomeRoutes.DASHBOARD, false)
                },
                onOpenMember = { nav.navigate(HomeRoutes.memberDetail(memberId)) },
                onScanSuccessToast = onScanSuccessToast,
            )
        }
        composable(
            route = HomeRoutes.SCAN_REWARD_REDEEM,
            arguments = listOf(
                navArgument("memberName") { type = NavType.StringType },
                navArgument("barcode") { type = NavType.StringType },
                navArgument("rewardLabel") { type = NavType.StringType },
                navArgument("pointsRequired") { type = NavType.IntType },
                navArgument("pointsBalance") { type = NavType.IntType },
                navArgument("eligible") { type = NavType.StringType },
                navArgument("mode") { type = NavType.StringType },
            ),
        ) { entry ->
            val memberName = URLDecoder.decode(entry.arguments?.getString("memberName").orEmpty(), Charsets.UTF_8.name())
            val barcode = URLDecoder.decode(entry.arguments?.getString("barcode").orEmpty(), Charsets.UTF_8.name())
            val rewardLabel = URLDecoder.decode(entry.arguments?.getString("rewardLabel").orEmpty(), Charsets.UTF_8.name())
            val pointsRequired = entry.arguments?.getInt("pointsRequired") ?: 0
            val pointsBalance = entry.arguments?.getInt("pointsBalance") ?: 0
            val eligible = entry.arguments?.getString("eligible") == "1"
            val mode = entry.arguments?.getString("mode").orEmpty().ifBlank { "points" }
            RewardRedeemScanScreen(
                args = RewardRedeemScanArgs(
                    memberName = memberName,
                    barcode = barcode,
                    rewardLabel = rewardLabel,
                    pointsRequired = pointsRequired,
                    pointsBalance = pointsBalance,
                    eligible = eligible,
                    mode = mode,
                ),
                repository = repository,
                snackbar = snackbarHostState,
                onDone = {
                    dashboardViewModel.refresh()
                    nav.popBackStack(HomeRoutes.DASHBOARD, false)
                },
                onScanSuccessToast = onScanSuccessToast,
            )
        }
        composable(HomeRoutes.MYCARD) {
            MyCardScreen(
                viewModel = dashboardViewModel,
                sessionStore = sessionStore,
                repository = repository,
                syncService = syncService,
                snackbar = snackbarHostState,
                onBack = { nav.popBackStack() },
            )
        }
    }
}
