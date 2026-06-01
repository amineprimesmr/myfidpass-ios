package fr.myfidpass.ui.screens.onboarding

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import fr.myfidpass.di.AppContainer
import fr.myfidpass.ui.components.GlassIconButton
import fr.myfidpass.ui.screens.auth.AuthLaunchEntryScreen
import fr.myfidpass.ui.screens.auth.MerchantPaywallScreen
import fr.myfidpass.ui.viewModelFactory
import fr.myfidpass.ui.viewmodel.MerchantIntegratedOnboardingViewModel
import fr.myfidpass.ui.viewmodel.MerchantOnboardingViewModel

private const val ONBOARDING_PROGRESS_SEGMENTS = 3

/**
 * Parcours intégré aligné iOS `MyfidpassMerchantOnboardingRootView` :
 * welcome → établissement → e-mail → OTP → paywall obligatoire.
 */
@Composable
fun MerchantOnboardingRootScreen(
    container: AppContainer,
    onSignupComplete: () -> Unit,
    onSignIn: () -> Unit,
    onExistingAccountEmail: (String) -> Unit,
    onGoogleSignIn: (signUp: Boolean) -> Unit,
) {
    val factory = remember(container) { viewModelFactory(container) }
    val flowVm: MerchantIntegratedOnboardingViewModel = viewModel(factory = factory)
    val establishmentVm: MerchantOnboardingViewModel = viewModel(
        key = "integrated_establishment",
        factory = factory,
    )
    val firstLaunch = container.firstLaunchPreferences
    val statusTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val navBottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

    LaunchedEffect(Unit) {
        flowVm.restoreIfPaywallPending()
    }

    val step = flowVm.currentStep
    val showProcessHeader = step != IntegratedOnboardingStep.Welcome &&
        step != IntegratedOnboardingStep.SubscriptionPaywall
    val showBottomContinue = step == IntegratedOnboardingStep.EmailCapture

    if (flowVm.showExistingAccountSheet) {
        AlertDialog(
            onDismissRequest = { flowVm.dismissExistingAccountSheet() },
            title = { Text("Compte existant") },
            text = {
                Text("Un compte existe déjà avec ${flowVm.normalizedEmail}. Connectez-vous pour continuer.")
            },
            confirmButton = {
                TextButton(onClick = { flowVm.confirmExistingAccountSwitch(onExistingAccountEmail) }) {
                    Text("Se connecter")
                }
            },
            dismissButton = {
                TextButton(onClick = { flowVm.dismissExistingAccountSheet() }) {
                    Text("Annuler")
                }
            },
        )
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Color.White),
    ) {
        AnimatedContent(
            targetState = step,
            modifier = Modifier.fillMaxSize(),
            transitionSpec = { fadeIn() togetherWith fadeOut() },
            label = "integratedOnboarding",
        ) { current ->
            when (current) {
                IntegratedOnboardingStep.Welcome -> AuthLaunchEntryScreen(
                    onCreateAccount = {
                        firstLaunch.rewindToMerchantPremisesSelectionForFreshCommercePick()
                        establishmentVm.resetForNewFlow()
                        flowVm.goToEstablishment()
                    },
                    onSignIn = onSignIn,
                )
                IntegratedOnboardingStep.EstablishmentSearch -> MerchantEstablishmentScreen(
                    viewModel = establishmentVm,
                    showTopBarBack = false,
                    onBack = null,
                    onContinue = { placeId, description, relax ->
                        firstLaunch.persistPendingEstablishment(placeId, description, relax)
                        firstLaunch.markMerchantPremisesOnboardingFinished()
                        flowVm.goToEmailCapture()
                    },
                    onAlreadyHaveAccount = {
                        firstLaunch.markRelaxPlaceRequirementForExistingAccountFlow()
                        firstLaunch.markMerchantPremisesOnboardingFinished()
                        onSignIn()
                    },
                )
                IntegratedOnboardingStep.EmailCapture -> Box(
                    Modifier
                        .fillMaxSize()
                        .padding(top = statusTop + 64.dp),
                ) {
                    OnboardingEmailCaptureContent(
                    email = flowVm.signupEmail,
                    onEmailChange = flowVm::onSignupEmailChange,
                    isChecking = flowVm.isCheckingEmail || flowVm.isSendingOtp,
                    errorMessage = flowVm.emailError,
                    commerceTitle = firstLaunch.pendingCommerceDisplayTitle(),
                    )
                }
                IntegratedOnboardingStep.OtpVerification -> Box(
                    Modifier
                        .fillMaxSize()
                        .padding(top = statusTop + 64.dp),
                ) {
                    AuthEmailOtpVerificationContent(
                    code = flowVm.otpCode,
                    onCodeChange = flowVm::onOtpChange,
                    email = flowVm.normalizedEmail,
                    commerceTitle = firstLaunch.pendingCommerceDisplayTitle(),
                    isVerifying = flowVm.isVerifyingOtp,
                    isSendingCode = flowVm.isSendingOtp,
                    showSuccessCelebration = flowVm.otpShowSuccess,
                    interactionLocked = flowVm.isVerifyingOtp || flowVm.otpShowSuccess,
                    errorMessage = flowVm.otpError,
                    onResend = flowVm::resendOtp,
                    onCodeComplete = { flowVm.verifyOtp(onSignupComplete) },
                    )
                }
                IntegratedOnboardingStep.SubscriptionPaywall -> MerchantPaywallScreen(
                    userEmail = container.sessionStore.userEmail,
                    sessionStore = container.sessionStore,
                    dashboardRepository = container.dashboardRepository,
                    authRepository = container.authRepository,
                    onLogout = {
                        container.sessionStore.finishSignupPaywallPhase(honorPaidThankYou = false)
                        onSignIn()
                    },
                    onAccessGranted = {
                        if (container.sessionStore.isCompletingSignupPaywallPhase) {
                            container.sessionStore.confirmSignupPaywallPaymentInThisSession()
                            flowVm.finishMandatoryPaywall(honorThankYou = true, onComplete = onSignupComplete)
                        } else {
                            onSignupComplete()
                        }
                    },
                    allowsClose = true,
                    onClose = {
                        flowVm.finishMandatoryPaywall(honorThankYou = false, onComplete = onSignupComplete)
                    },
                    closeRevealDelayMs = 0L,
                    isMandatorySignupPaywall = true,
                )
            }
        }

        if (showProcessHeader) {
            Column(
                Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = statusTop + 8.dp),
            ) {
                OnboardingProcessHeader(
                    filledSegments = flowVm.filledProgressSegments(),
                    totalSegments = ONBOARDING_PROGRESS_SEGMENTS,
                    onBack = { flowVm.goBack() },
                    backContent = {
                        GlassIconButton(
                            icon = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Retour",
                            onClick = { flowVm.goBack() },
                            tint = Color.Black.copy(0.88f),
                        )
                    },
                )
            }
        }

        if (showBottomContinue) {
            Column(
                Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .background(Color.White)
                    .padding(horizontal = 24.dp)
                    .padding(bottom = navBottom + 16.dp, top = 12.dp),
            ) {
                Button(
                    onClick = { flowVm.handleEmailContinue() },
                    enabled = flowVm.isSignupEmailValid && !flowVm.isCheckingEmail && !flowVm.isSendingOtp,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(52.dp),
                    shape = RoundedCornerShape(999.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color.Black,
                        contentColor = Color.White,
                        disabledContainerColor = Color.Black.copy(alpha = 0.22f),
                        disabledContentColor = Color.White.copy(alpha = 0.72f),
                    ),
                ) {
                    Text("CONTINUER", fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
                }
            }
        }
    }
}
