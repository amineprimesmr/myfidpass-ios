package fr.myfidpass.ui.viewmodel

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import fr.myfidpass.data.local.FirstLaunchPreferences
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.repo.AuthRepository
import kotlinx.coroutines.launch

sealed interface RootUiState {
    data object Loading : RootUiState
    /** Premier lancement : recherche d’établissement (comme `MyfidpassMerchantOnboardingRootView`). */
    data object MerchantEstablishment : RootUiState
    /** Accueil auth : Google / Apple / e-mail / créer un compte (`OnboardingChoiceView`). */
    data object AuthLanding : RootUiState
    data object Main : RootUiState
}

class RootViewModel(
    private val authRepository: AuthRepository,
    private val sessionStore: SessionStore,
    private val firstLaunch: FirstLaunchPreferences,
) : ViewModel() {

    var state: RootUiState by mutableStateOf(RootUiState.Loading)
        private set

    var bootstrapError: String? by mutableStateOf(null)
        private set

    fun bootstrap() {
        viewModelScope.launch {
            state = RootUiState.Loading
            bootstrapError = null
            firstLaunch.bootstrapInstallAndMigrateIfNeeded(sessionStore)

            val hasToken = sessionStore.isLoggedIn && !sessionStore.accessToken.isNullOrEmpty()
            if (hasToken) {
                val r = authRepository.refreshAccount()
                if (r.isSuccess) {
                    state = RootUiState.Main
                } else {
                    bootstrapError = r.exceptionOrNull()?.message
                    state = if (firstLaunch.shouldShowMerchantPremisesBeforeAuth) {
                        RootUiState.MerchantEstablishment
                    } else {
                        RootUiState.AuthLanding
                    }
                }
                return@launch
            }

            state = if (firstLaunch.shouldShowMerchantPremisesBeforeAuth) {
                RootUiState.MerchantEstablishment
            } else {
                RootUiState.AuthLanding
            }
        }
    }

    /** Après sélection établissement + CONTINUER. */
    fun onMerchantEstablishmentFinished(placeId: String?, description: String?, relax: Boolean) {
        firstLaunch.persistPendingEstablishment(placeId, description, relax)
        firstLaunch.markMerchantPremisesOnboardingFinished()
        state = RootUiState.AuthLanding
    }

    /** « J’ai déjà un compte » — sans lieu. */
    fun onMerchantSkipToAuth() {
        firstLaunch.markMerchantPremisesOnboardingFinished()
        state = RootUiState.AuthLanding
    }

    fun onLoggedIn() {
        state = RootUiState.Main
    }

    fun onLogout() {
        viewModelScope.launch {
            authRepository.performLogout()
            state = RootUiState.AuthLanding
        }
    }
}
