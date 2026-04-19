package fr.myfidpass.ui.viewmodel

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import fr.myfidpass.data.local.FirstLaunchPreferences
import fr.myfidpass.data.repo.AuthRepository
import fr.myfidpass.data.repo.EmailLoginResult
import kotlinx.coroutines.launch

enum class EmailAuthPhase {
    Email,
    Credentials,
}

class EmailAuthViewModel(
    private val authRepository: AuthRepository,
    private val firstLaunch: FirstLaunchPreferences,
) : ViewModel() {

    var phase by mutableStateOf(EmailAuthPhase.Email)
        private set

    var email by mutableStateOf("")
    var password by mutableStateOf("")
    var displayName by mutableStateOf("")
    var isNewUser by mutableStateOf(false)
    var loading by mutableStateOf(false)
    var errorMessage by mutableStateOf<String?>(null)

    val emailValid: Boolean
        get() {
            val e = email.trim()
            return e.contains("@") && e.split("@").size == 2 && e.length > 4
        }

    fun goToCredentials() {
        if (!emailValid) return
        email = email.trim().lowercase()
        phase = EmailAuthPhase.Credentials
        errorMessage = null
    }

    fun backToEmail() {
        phase = EmailAuthPhase.Email
        errorMessage = null
    }

    fun hasPendingEstablishment(): Boolean {
        val p = firstLaunch.readPendingEstablishment()
        return p.placeId != null || p.relax
    }

    fun submitCredentials(onSuccess: () -> Unit) {
        viewModelScope.launch {
            loading = true
            errorMessage = null
            if (isNewUser) {
                if (!hasPendingEstablishment()) {
                    errorMessage =
                        "Sélectionnez d'abord votre établissement depuis l'accueil pour créer un compte."
                    loading = false
                    return@launch
                }
                if (password.length < 12) {
                    errorMessage = "Au moins 12 caractères."
                    loading = false
                    return@launch
                }
                val r = authRepository.register(email, password, displayName.takeIf { it.isNotBlank() })
                loading = false
                r.fold(
                    onSuccess = { onSuccess() },
                    onFailure = { errorMessage = it.message ?: "Inscription impossible" },
                )
                return@launch
            }
            when (val res = authRepository.loginEmailReturningOutcome(email, password)) {
                is EmailLoginResult.Success -> {
                    loading = false
                    onSuccess()
                }
                is EmailLoginResult.NoAccount -> {
                    loading = false
                    if (hasPendingEstablishment()) {
                        isNewUser = true
                    } else {
                        errorMessage =
                            "Aucun compte trouvé avec cet e-mail. Retournez à l'accueil, sélectionnez votre établissement, puis créez votre compte."
                    }
                }
                is EmailLoginResult.Error -> {
                    loading = false
                    errorMessage = res.message
                }
            }
        }
    }

    fun resetForSheet() {
        phase = EmailAuthPhase.Email
        email = ""
        password = ""
        displayName = ""
        isNewUser = false
        errorMessage = null
    }
}
