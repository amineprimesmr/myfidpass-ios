package fr.myfidpass.ui.screens.commerce

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import fr.myfidpass.di.AppContainer
import fr.myfidpass.data.repo.BusinessCreationRepository
import fr.myfidpass.ui.screens.onboarding.MerchantEstablishmentScreen
import fr.myfidpass.ui.viewModelFactory
import fr.myfidpass.ui.viewmodel.MerchantOnboardingViewModel
import kotlinx.coroutines.launch

@Composable
fun AddCommerceScreen(
    container: AppContainer,
    businessCreationRepository: BusinessCreationRepository,
    snackbar: SnackbarHostState,
    onBack: () -> Unit,
    onCreated: () -> Unit,
) {
    val factory = viewModelFactory(container)
    val vm: MerchantOnboardingViewModel = viewModel(factory = factory)
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
            scope.launch {
                runCatching {
                    businessCreationRepository.createFromPlace(pid, desc)
                    snackbar.showSnackbar("Commerce ajouté")
                    onCreated()
                }.onFailure {
                    snackbar.showSnackbar(it.message ?: "Erreur")
                }
            }
        },
        onAlreadyHaveAccount = onBack,
    )
}
