package fr.myfidpass.ui.screens.commerce

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import fr.myfidpass.di.AppContainer
import fr.myfidpass.ui.components.FlyerProUnlockOverlay
import fr.myfidpass.ui.screens.commerce.flyer.MerchantProgramHubScreen

/** Hub flyer complet — aligné iOS `MerchantProgramHubView`. */
@Composable
fun FlyerToolsScreen(
    container: AppContainer,
    snackbar: SnackbarHostState? = null,
    onBack: () -> Unit,
    startCreateAssistant: Boolean = false,
    openForEdit: Boolean = false,
    hasProAccess: Boolean = true,
    onUnlockPro: () -> Unit = {},
    onFlyerSaveSuccess: () -> Unit = {},
    @Suppress("UNUSED_PARAMETER") repository: fr.myfidpass.data.repo.DashboardRepository? = null,
) {
    FlyerProUnlockOverlay(
        locked = !hasProAccess,
        onUnlock = onUnlockPro,
        modifier = Modifier.fillMaxSize(),
    ) {
        MerchantProgramHubScreen(
            container = container,
            onBack = onBack,
            startCreateAssistant = startCreateAssistant,
            openForEdit = openForEdit,
            onFlyerSaveSuccess = onFlyerSaveSuccess,
            snackbar = snackbar,
        )
    }
}
