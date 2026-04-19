package fr.myfidpass.ui.screens.main

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import fr.myfidpass.di.AppContainer
import fr.myfidpass.ui.screens.auth.MerchantPaywallScreen
import fr.myfidpass.ui.screens.home.HomeTabNavHost
import fr.myfidpass.ui.screens.tabs.CampaignsTabScreen
import fr.myfidpass.ui.screens.commerce.CommerceTabNavHost
import fr.myfidpass.ui.viewmodel.DashboardViewModel
import kotlinx.coroutines.CoroutineScope

@Composable
fun MainTabsScreen(
    container: AppContainer,
    dashboardViewModel: DashboardViewModel,
    snackbarHostState: SnackbarHostState,
    appScope: CoroutineScope,
    onLogout: () -> Unit,
) {
    var tab by rememberSaveable { mutableIntStateOf(0) }
    LaunchedEffect(tab) {
        if (tab == 0) dashboardViewModel.load()
    }
    if (!container.sessionStore.isMerchantAccessGranted()) {
        MerchantPaywallScreen(
            userEmail = container.sessionStore.userEmail,
            onLogout = onLogout,
        )
        return
    }
    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = tab == 0,
                    onClick = { tab = 0 },
                    icon = { Icon(Icons.Default.Home, contentDescription = null) },
                    label = { Text("Accueil") },
                )
                NavigationBarItem(
                    selected = tab == 1,
                    onClick = { tab = 1 },
                    icon = { Icon(Icons.Default.Notifications, contentDescription = null) },
                    label = { Text("Notifs") },
                )
                NavigationBarItem(
                    selected = tab == 2,
                    onClick = { tab = 2 },
                    icon = { Icon(Icons.Default.Person, contentDescription = null) },
                    label = { Text("Commerce") },
                )
            }
        },
    ) { padding ->
        when (tab) {
            0 -> HomeTabNavHost(
                modifier = Modifier.padding(padding),
                dashboardViewModel = dashboardViewModel,
                sessionStore = container.sessionStore,
                repository = container.dashboardRepository,
                snackbarHostState = snackbarHostState,
                appScope = appScope,
            )
            1 -> CampaignsTabScreen(
                modifier = Modifier.padding(padding),
                repository = container.dashboardRepository,
                snackbarHostState = snackbarHostState,
            )
            2 -> CommerceTabNavHost(
                modifier = Modifier.padding(padding),
                container = container,
                snackbarHostState = snackbarHostState,
                appScope = appScope,
                onLogout = onLogout,
            )
        }
    }
}
