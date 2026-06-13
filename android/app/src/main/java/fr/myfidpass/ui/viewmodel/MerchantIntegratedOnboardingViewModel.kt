package fr.myfidpass.ui.viewmodel

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import fr.myfidpass.data.local.FirstLaunchPreferences
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.repo.AuthRepository
import fr.myfidpass.ui.screens.onboarding.IntegratedOnboardingStep
import fr.myfidpass.ui.screens.onboarding.OnboardingEmailValidation
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject

@HiltViewModel
class MerchantIntegratedOnboardingViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val firstLaunch: FirstLaunchPreferences,
    private val sessionStore: SessionStore,
) : ViewModel() {

    var currentStep by mutableStateOf(IntegratedOnboardingStep.Welcome)
        private set

    var signupEmail by mutableStateOf("")
        private set

    var otpCode by mutableStateOf("")
        private set

    var emailError by mutableStateOf<String?>(null)
        private set

    var otpError by mutableStateOf<String?>(null)
        private set

    var isCheckingEmail by mutableStateOf(false)
        private set

    var isSendingOtp by mutableStateOf(false)
        private set

    var isVerifyingOtp by mutableStateOf(false)
        private set

    var otpShowSuccess by mutableStateOf(false)
        private set

    var showExistingAccountSheet by mutableStateOf(false)
        private set

    val normalizedEmail: String
        get() = OnboardingEmailValidation.normalized(signupEmail)

    val isSignupEmailValid: Boolean
        get() = OnboardingEmailValidation.isValid(signupEmail)

    fun restoreIfPaywallPending() {
        if (sessionStore.isLoggedIn && sessionStore.isCompletingSignupPaywallPhase) {
            currentStep = IntegratedOnboardingStep.SubscriptionPaywall
        }
        firstLaunch.readSignupEmail()?.let { onSignupEmailChange(it) }
    }

    fun onSignupEmailChange(value: String) {
        signupEmail = value
        if (emailError != null) emailError = null
    }

    fun onOtpChange(value: String) {
        otpCode = value.filter { it.isDigit() }.take(6)
        if (otpError != null) otpError = null
    }

    fun goToEstablishment() {
        currentStep = IntegratedOnboardingStep.EstablishmentSearch
    }

    fun goToEmailCapture() {
        currentStep = IntegratedOnboardingStep.EmailCapture
    }

    fun goBackFromPaywall() {
        sessionStore.finishSignupPaywallPhase(honorPaidThankYou = false)
        currentStep = IntegratedOnboardingStep.OtpVerification
    }

    fun goBack() {
        when (currentStep) {
            IntegratedOnboardingStep.EstablishmentSearch -> currentStep = IntegratedOnboardingStep.Welcome
            IntegratedOnboardingStep.EmailCapture -> currentStep = IntegratedOnboardingStep.EstablishmentSearch
            IntegratedOnboardingStep.OtpVerification -> {
                otpCode = ""
                otpError = null
                otpShowSuccess = false
                currentStep = IntegratedOnboardingStep.EmailCapture
            }
            IntegratedOnboardingStep.SubscriptionPaywall -> goBackFromPaywall()
            IntegratedOnboardingStep.Welcome -> Unit
        }
    }

    fun dismissExistingAccountSheet() {
        showExistingAccountSheet = false
    }

    fun filledProgressSegments(): Int = when (currentStep) {
        IntegratedOnboardingStep.Welcome -> 0
        IntegratedOnboardingStep.EstablishmentSearch -> 1
        IntegratedOnboardingStep.EmailCapture -> 2
        IntegratedOnboardingStep.OtpVerification -> 3
        IntegratedOnboardingStep.SubscriptionPaywall -> 3
    }

    fun handleEmailContinue() {
        if (!isSignupEmailValid || isCheckingEmail || isSendingOtp) return
        viewModelScope.launch {
            emailError = null
            isCheckingEmail = true
            try {
                val exists = authRepository.checkIdentifier(normalizedEmail).accountExists == true
                if (exists) {
                    showExistingAccountSheet = true
                } else {
                    firstLaunch.persistSignupEmail(normalizedEmail)
                    sendOtpAndAdvance()
                }
            } catch (e: Exception) {
                emailError = e.message ?: "Impossible de vérifier l'e-mail. Réessayez."
            } finally {
                isCheckingEmail = false
            }
        }
    }

    fun confirmExistingAccountSwitch(onExistingAccount: (String) -> Unit) {
        showExistingAccountSheet = false
        firstLaunch.persistSignupEmail(normalizedEmail)
        onExistingAccount(normalizedEmail)
    }

    fun resendOtp() {
        viewModelScope.launch {
            otpError = null
            isSendingOtp = true
            authRepository.sendEmailOtp(normalizedEmail).fold(
                onSuccess = { },
                onFailure = { otpError = it.message ?: "Impossible d'envoyer le code." },
            )
            isSendingOtp = false
        }
    }

    fun verifyOtp(onCompleteWithoutPaywall: () -> Unit) {
        if (otpCode.length != 6 || isVerifyingOtp || otpShowSuccess) return
        viewModelScope.launch {
            otpError = null
            isVerifyingOtp = true
            val result = authRepository.verifyEmailOtpAndSignIn(
                email = normalizedEmail,
                code = otpCode,
                isSignup = true,
            )
            isVerifyingOtp = false
            result.fold(
                onSuccess = {
                    otpShowSuccess = true
                    delay(780)
                    otpShowSuccess = false
                    completeSignupAfterOtp(onCompleteWithoutPaywall)
                },
                onFailure = {
                    otpError = it.message ?: "Code incorrect ou expiré."
                    otpCode = ""
                },
            )
        }
    }

    private suspend fun sendOtpAndAdvance() {
        isSendingOtp = true
        val send = authRepository.sendEmailOtp(normalizedEmail)
        isSendingOtp = false
        send.fold(
            onSuccess = {
                otpCode = ""
                otpError = null
                currentStep = IntegratedOnboardingStep.OtpVerification
            },
            onFailure = { emailError = it.message ?: "Impossible d'envoyer le code." },
        )
    }

    private fun completeSignupAfterOtp(onCompleteWithoutPaywall: () -> Unit) {
        sessionStore.beginSignupPaywallPhaseIfNeeded()
        if (sessionStore.isCompletingSignupPaywallPhase) {
            currentStep = IntegratedOnboardingStep.SubscriptionPaywall
        } else {
            sessionStore.finishSignupPaywallPhase(honorPaidThankYou = false)
            onCompleteWithoutPaywall()
        }
    }

    fun finishMandatoryPaywall(honorThankYou: Boolean, onComplete: () -> Unit) {
        sessionStore.finishSignupPaywallPhase(honorPaidThankYou = honorThankYou)
        onComplete()
    }
}
