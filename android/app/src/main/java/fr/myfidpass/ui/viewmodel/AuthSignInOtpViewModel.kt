package fr.myfidpass.ui.viewmodel

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import fr.myfidpass.data.local.FirstLaunchPreferences
import fr.myfidpass.data.repo.AuthRepository
import fr.myfidpass.ui.screens.onboarding.OnboardingEmailValidation
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject

enum class AuthSignInStep { Identifier, Otp }

@HiltViewModel
class AuthSignInOtpViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val firstLaunch: FirstLaunchPreferences,
) : ViewModel() {

    var currentStep by mutableIntStateOf(AuthSignInStep.Identifier.ordinal)
        private set

    var identifier by mutableStateOf("")
        private set

    var otpCode by mutableStateOf("")
        private set

    var identifierError by mutableStateOf<String?>(null)
        private set

    var otpError by mutableStateOf<String?>(null)
        private set

    var isCheckingIdentifier by mutableStateOf(false)
        private set

    var isSendingCode by mutableStateOf(false)
        private set

    var isVerifying by mutableStateOf(false)
        private set

    var otpShowSuccess by mutableStateOf(false)
        private set

    var otpSubmitInFlight by mutableStateOf(false)
        private set

    val normalizedIdentifier: String
        get() = OnboardingEmailValidation.normalized(identifier)

    val isIdentifierValid: Boolean
        get() = OnboardingEmailValidation.isValid(identifier)

    fun bootstrap(initialIdentifier: String?, skipExistenceCheck: Boolean) {
        initialIdentifier?.trim()?.takeIf { it.isNotEmpty() }?.let { identifier = it }
        if (skipExistenceCheck && isIdentifierValid) {
            viewModelScope.launch { sendCodeAndAdvance() }
        }
    }

    fun onIdentifierChange(value: String) {
        identifier = value
        if (identifierError != null) identifierError = null
    }

    fun onOtpChange(value: String) {
        otpCode = value.filter { it.isDigit() }.take(6)
        if (otpError != null) otpError = null
    }

    fun goBack() {
        if (currentStep == AuthSignInStep.Otp.ordinal) {
            otpCode = ""
            otpError = null
            otpShowSuccess = false
            currentStep = AuthSignInStep.Identifier.ordinal
        }
    }

    fun filledProgressSegments(): Int = when (currentStep) {
        AuthSignInStep.Identifier.ordinal -> 1
        else -> 2
    }

    fun handleIdentifierContinue() {
        if (!isIdentifierValid || isCheckingIdentifier || isSendingCode) return
        viewModelScope.launch {
            identifierError = null
            isCheckingIdentifier = true
            try {
                val exists = authRepository.checkIdentifier(normalizedIdentifier).accountExists == true
                if (!exists) {
                    identifierError = "Aucun compte trouvé pour cet e-mail."
                } else {
                    firstLaunch.persistSignupEmail(normalizedIdentifier)
                    sendCodeAndAdvance()
                }
            } catch (e: Exception) {
                identifierError = e.message ?: "Impossible de vérifier l'e-mail."
            } finally {
                isCheckingIdentifier = false
            }
        }
    }

    fun resendCode() {
        viewModelScope.launch {
            otpError = null
            isSendingCode = true
            authRepository.sendEmailOtp(normalizedIdentifier).fold(
                onSuccess = { },
                onFailure = { otpError = it.message ?: "Impossible d'envoyer le code." },
            )
            isSendingCode = false
        }
    }

    fun verifyOtp(onSuccess: () -> Unit) {
        if (otpCode.length != 6 || isVerifying || otpSubmitInFlight) return
        viewModelScope.launch {
            otpError = null
            isVerifying = true
            otpSubmitInFlight = true
            val result = authRepository.verifyEmailOtpAndSignIn(
                email = normalizedIdentifier,
                code = otpCode,
                isSignup = false,
            )
            isVerifying = false
            result.fold(
                onSuccess = {
                    otpShowSuccess = true
                    delay(780)
                    otpShowSuccess = false
                    otpSubmitInFlight = false
                    onSuccess()
                },
                onFailure = {
                    otpSubmitInFlight = false
                    otpError = it.message ?: "Code incorrect ou expiré."
                    otpCode = ""
                },
            )
        }
    }

    private suspend fun sendCodeAndAdvance() {
        isSendingCode = true
        val send = authRepository.sendEmailOtp(normalizedIdentifier)
        isSendingCode = false
        send.fold(
            onSuccess = {
                otpCode = ""
                otpError = null
                currentStep = AuthSignInStep.Otp.ordinal
            },
            onFailure = { identifierError = it.message ?: "Impossible d'envoyer le code." },
        )
    }
}
