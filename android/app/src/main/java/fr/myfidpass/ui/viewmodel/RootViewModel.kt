package fr.myfidpass.ui.viewmodel

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import fr.myfidpass.core.auth.SessionEvents
import fr.myfidpass.data.local.FirstLaunchPreferences
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.repo.AuthRepository
import fr.myfidpass.services.sync.SyncService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import javax.inject.Inject

sealed interface RootUiState {
    data object Loading : RootUiState
    data object MerchantEstablishment : RootUiState
    data object AuthLanding : RootUiState
    data object Admin : RootUiState
    data object Main : RootUiState
}

@HiltViewModel
class RootViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val sessionStore: SessionStore,
    private val firstLaunch: FirstLaunchPreferences,
    private val syncService: SyncService,
) : ViewModel() {

    var state: RootUiState by mutableStateOf(RootUiState.Loading)
        private set

    var bootstrapError: String? by mutableStateOf(null)
        private set

    init {
        SessionEvents.invalidated
            .onEach {
                sessionStore.adminMerchantPilotMode = false
                state = RootUiState.AuthLanding
            }
            .launchIn(viewModelScope)
    }

    fun bootstrap() {
        viewModelScope.launch {
            state = RootUiState.Loading
            bootstrapError = null
            firstLaunch.bootstrapInstallAndMigrateIfNeeded(sessionStore)

            val hasToken = sessionStore.isLoggedIn && !sessionStore.accessToken.isNullOrEmpty()
            if (hasToken) {
                val r = authRepository.refreshAccount()
                if (r.isSuccess) {
                    state = if (sessionStore.isCompletingSignupPaywallPhase) {
                        RootUiState.AuthLanding
                    } else {
                        resolvePostAuthState()
                    }
                } else {
                    val err = r.exceptionOrNull()
                    bootstrapError = err?.message
                    if (authRepository.canKeepLocalSessionAfterBootstrapFailure() &&
                        authRepository.isTransientBootstrapError(err)
                    ) {
                        state = if (sessionStore.isCompletingSignupPaywallPhase) {
                            RootUiState.AuthLanding
                        } else {
                            resolvePostAuthState()
                        }
                    } else if (!sessionStore.isLoggedIn) {
                        state = authOrEstablishment()
                    } else {
                        state = authOrEstablishment()
                    }
                }
                return@launch
            }

            state = authOrEstablishment()
        }
    }

    private fun authOrEstablishment(): RootUiState = RootUiState.AuthLanding

    private fun resolvePostAuthState(): RootUiState {
        if (sessionStore.isAdminUser && !sessionStore.adminMerchantPilotMode) {
            return RootUiState.Admin
        }
        return RootUiState.Main
    }

    fun onMerchantEstablishmentFinished(placeId: String?, description: String?, relax: Boolean) {
        firstLaunch.persistPendingEstablishment(placeId, description, relax)
        firstLaunch.markMerchantPremisesOnboardingFinished()
        state = RootUiState.AuthLanding
    }

    fun onMerchantSkipToAuth() {
        firstLaunch.markMerchantPremisesOnboardingFinished()
        state = RootUiState.AuthLanding
    }

    fun onLoggedIn() {
        state = resolvePostAuthState()
    }

    fun onOpenMerchantFromAdmin() {
        sessionStore.adminMerchantPilotMode = true
        state = RootUiState.Main
    }

    fun onLogout() {
        viewModelScope.launch {
            authRepository.performLogout()
            syncService.resetFlyerHydrationState()
            sessionStore.adminMerchantPilotMode = false
            state = RootUiState.AuthLanding
        }
    }
}
