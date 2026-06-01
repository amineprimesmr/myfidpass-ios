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

class EmailAuthViewModel(
    private val authRepository: AuthRepository,
    private val firstLaunch: FirstLaunchPreferences,
) : ViewModel() {

    var signUpMode by mutableStateOf(true)
        private set

    var email by mutableStateOf("")
    var password by mutableStateOf("")
    var loading by mutableStateOf(false)
    var errorMessage by mutableStateOf<String?>(null)

    val identifierValid: Boolean
        get() {
            val e = email.trim()
            if (e.isEmpty()) return false
            if (e.contains("@")) {
                if (e.length < 5) return false
                val parts = e.split("@")
                if (parts.size != 2) return false
                return parts[1].contains(".")
            }
            return e.length >= 3
        }

    val canSubmit: Boolean
        get() = if (signUpMode) {
            identifierValid && password.length >= 12 && !loading
        } else {
            identifierValid && password.isNotEmpty() && !loading
        }

    fun hasPendingEstablishment(): Boolean =
        firstLaunch.hasCompletePendingEstablishmentForRegistration()

    fun submit(onSuccess: () -> Unit) {
        viewModelScope.launch {
            loading = true
            errorMessage = null
            val normalized = email.trim().let { if (it.contains("@")) it.lowercase() else it }
            email = normalized

            if (signUpMode) {
                if (!hasPendingEstablishment()) {
                    errorMessage =
                        "Sélectionnez d'abord votre établissement (COMMENCER) pour créer un compte."
                    loading = false
                    return@launch
                }
                if (password.length < 12) {
                    errorMessage = "Au moins 12 caractères."
                    loading = false
                    return@launch
                }
                val r = authRepository.register(normalized, password, name = null)
                loading = false
                r.fold(
                    onSuccess = { onSuccess() },
                    onFailure = { errorMessage = it.message ?: "Inscription impossible" },
                )
                return@launch
            }

            when (val res = authRepository.loginEmailReturningOutcome(normalized, password)) {
                is EmailLoginResult.Success -> {
                    loading = false
                    onSuccess()
                }
                is EmailLoginResult.NoAccount -> {
                    loading = false
                    errorMessage =
                        "Aucun compte trouvé avec cet identifiant. Créez un compte via COMMENCER."
                }
                is EmailLoginResult.Error -> {
                    loading = false
                    errorMessage = res.message
                }
            }
        }
    }

    fun resetForSheet(signUpMode: Boolean = true) {
        this.signUpMode = signUpMode
        email = ""
        password = ""
        errorMessage = null
        loading = false
    }
}
