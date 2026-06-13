package fr.myfidpass.ui.screens.commerce

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import fr.myfidpass.di.AppContainer
import fr.myfidpass.data.repo.BusinessCreationRepository
import fr.myfidpass.ui.screens.onboarding.MerchantEstablishmentScreen
import fr.myfidpass.ui.viewmodel.MerchantOnboardingViewModel
import kotlinx.coroutines.launch

@Composable
fun AddCommerceScreen(
    container: AppContainer,
    businessCreationRepository: BusinessCreationRepository,
    snackbar: SnackbarHostState,
    onBack: () -> Unit,
    onCreated: () -> Unit,
    onQuotaBlocked: (establishmentName: String) -> Unit = {},
) {
    val vm: MerchantOnboardingViewModel = hiltViewModel()
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        vm.resetForNewFlow()
    }

    MerchantEstablishmentScreen(
        viewModel = vm,
        showTopBarBack = true,
        onBack = onBack,
        onContinue = { placeId, description, _ ->
            val pid = placeId?.trim().orEmpty()
            val desc = description?.trim().orEmpty()
            if (pid.isEmpty() || desc.isEmpty()) {
                scope.launch { snackbar.showSnackbar("Choisissez un établissement Google.") }
                return@MerchantEstablishmentScreen
            }
            val establishmentName = desc.substringBefore(",").trim().ifEmpty { desc }
            if (!container.sessionStore.canCreateBusiness) {
                onQuotaBlocked(establishmentName)
                return@MerchantEstablishmentScreen
            }
            scope.launch {
                runCatching {
                    businessCreationRepository.createFromPlace(pid, desc)
                    snackbar.showSnackbar("Commerce ajouté")
                    onCreated()
                }.onFailure {
                    val msg = it.message.orEmpty()
                    if (msg.contains("quota", ignoreCase = true) ||
                        msg.contains("abonnement", ignoreCase = true) ||
                        msg.contains("403")
                    ) {
                        onQuotaBlocked(establishmentName)
                    } else {
                        snackbar.showSnackbar(msg.ifEmpty { "Erreur" })
                    }
                }
            }
        },
        onAlreadyHaveAccount = onBack,
    )
}
