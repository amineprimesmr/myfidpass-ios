package fr.myfidpass.ui.screens.commerce

import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import fr.myfidpass.di.AppContainer
import fr.myfidpass.ui.screens.commerce.flyer.MerchantProgramHubScreen

/** Hub flyer complet — aligné iOS `MerchantProgramHubView`. */
@Composable
fun FlyerToolsScreen(
    container: AppContainer,
    snackbar: SnackbarHostState? = null,
    onBack: () -> Unit,
    startCreateAssistant: Boolean = false,
    openForEdit: Boolean = false,
    onFlyerSaveSuccess: () -> Unit = {},
    @Suppress("UNUSED_PARAMETER") repository: fr.myfidpass.data.repo.DashboardRepository? = null,
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
