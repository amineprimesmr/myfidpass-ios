package fr.myfidpass.ui.screens.auth

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import fr.myfidpass.di.AppContainer
import fr.myfidpass.ui.screens.onboarding.MerchantOnboardingRootScreen

private enum class WelcomeStage { Onboarding, SignInFlow }

/**
 * Parcours welcome aligné iOS `WelcomeFlow` dans RootView.swift :
 * onboarding intégré (welcome → établissement → e-mail → OTP → paywall) | connexion OTP.
 */
@Composable
fun WelcomeFlowScreen(
    container: AppContainer,
    onLoggedIn: () -> Unit,
    onGoogleSignIn: (signUp: Boolean) -> Unit = {},
    onAuthError: (String) -> Unit = {},
) {
    val firstLaunch = container.firstLaunchPreferences
    var restartKey by remember { mutableIntStateOf(firstLaunch.restartEpoch) }
    var stage by remember { mutableStateOf(WelcomeStage.Onboarding) }
    var signInPrefill by remember { mutableStateOf<String?>(null) }
    var signInAccountVerified by remember { mutableStateOf(false) }

    LaunchedEffect(firstLaunch.restartEpoch) {
        if (firstLaunch.restartEpoch != restartKey) {
            restartKey = firstLaunch.restartEpoch
            stage = WelcomeStage.Onboarding
            signInPrefill = null
            signInAccountVerified = false
        }
    }

    LaunchedEffect(container.sessionStore.isCompletingSignupPaywallPhase) {
        if (container.sessionStore.isLoggedIn && container.sessionStore.isCompletingSignupPaywallPhase) {
            stage = WelcomeStage.Onboarding
        }
    }

    AnimatedContent(
        targetState = stage,
        modifier = Modifier.fillMaxSize(),
        transitionSpec = { fadeIn() togetherWith fadeOut() },
        label = "welcomeStage",
    ) { current ->
        when (current) {
            WelcomeStage.Onboarding -> MerchantOnboardingRootScreen(
                container = container,
                onSignupComplete = onLoggedIn,
                onSignIn = {
                    firstLaunch.markRelaxPlaceRequirementForExistingAccountFlow()
                    signInPrefill = firstLaunch.readSignupEmail()
                    signInAccountVerified = false
                    stage = WelcomeStage.SignInFlow
                },
                onExistingAccountEmail = { email ->
                    firstLaunch.persistSignupEmail(email)
                    signInPrefill = email
                    signInAccountVerified = true
                    stage = WelcomeStage.SignInFlow
                },
                onGoogleSignIn = onGoogleSignIn,
            )
            WelcomeStage.SignInFlow -> AuthSignInOtpScreen(
                container = container,
                initialIdentifier = signInPrefill,
                skipExistenceCheck = signInAccountVerified,
                onBack = {
                    signInPrefill = null
                    signInAccountVerified = false
                    stage = WelcomeStage.Onboarding
                },
                onSuccess = onLoggedIn,
            )
        }
    }
}
