package fr.myfidpass.ui.screens.auth

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
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import fr.myfidpass.di.AppContainer
import fr.myfidpass.ui.components.GlassIconButton
import fr.myfidpass.ui.screens.onboarding.AuthEmailOtpVerificationContent
import fr.myfidpass.ui.screens.onboarding.OnboardingProcessHeader
import fr.myfidpass.ui.viewModelFactory
import fr.myfidpass.ui.viewmodel.AuthSignInOtpViewModel
import fr.myfidpass.ui.viewmodel.AuthSignInStep
import androidx.compose.foundation.text.KeyboardOptions

private const val SIGN_IN_PROGRESS_SEGMENTS = 2

/** Connexion e-mail → OTP — aligné iOS `AuthSignInEmailFlowView`. */
@Composable
fun AuthSignInOtpScreen(
    container: AppContainer,
    initialIdentifier: String? = null,
    skipExistenceCheck: Boolean = false,
    onBack: () -> Unit,
    onSuccess: () -> Unit,
) {
    val factory = remember(container) { viewModelFactory(container) }
    val vm: AuthSignInOtpViewModel = viewModel(factory = factory)
    val statusTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val navBottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val step = AuthSignInStep.entries[vm.currentStep]

    LaunchedEffect(initialIdentifier, skipExistenceCheck) {
        vm.bootstrap(initialIdentifier, skipExistenceCheck)
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Color(0xFFF7F7F8)),
    ) {
        Column(Modifier.fillMaxSize()) {
            Spacer(Modifier.height(statusTop + 8.dp))
            OnboardingProcessHeader(
                filledSegments = vm.filledProgressSegments(),
                totalSegments = SIGN_IN_PROGRESS_SEGMENTS,
                onBack = {
                    if (step == AuthSignInStep.Otp) vm.goBack() else onBack()
                },
                backContent = {
                    GlassIconButton(
                        icon = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Retour",
                        onClick = {
                            if (step == AuthSignInStep.Otp) vm.goBack() else onBack()
                        },
                        tint = Color.Black.copy(0.88f),
                    )
                },
            )

            when (step) {
                AuthSignInStep.Identifier -> Column(
                    Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .padding(horizontal = 28.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Spacer(Modifier.height(32.dp))
                    Text(
                        "Connexion",
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF141518),
                    )
                    Spacer(Modifier.height(10.dp))
                    Text(
                        "Entrez l'e-mail de votre compte commerçant.",
                        fontSize = 15.sp,
                        color = Color(0xFF73737A),
                    )
                    Spacer(Modifier.height(28.dp))
                    OutlinedTextField(
                        value = vm.identifier,
                        onValueChange = vm::onIdentifierChange,
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("Adresse e-mail") },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                        enabled = !vm.isCheckingIdentifier && !vm.isSendingCode,
                    )
                    vm.identifierError?.let {
                        Spacer(Modifier.height(12.dp))
                        Text(it, color = Color(0xFFD93838), fontSize = 14.sp)
                    }
                }
                AuthSignInStep.Otp -> AuthEmailOtpVerificationContent(
                    code = vm.otpCode,
                    onCodeChange = vm::onOtpChange,
                    email = vm.normalizedIdentifier,
                    isVerifying = vm.isVerifying,
                    isSendingCode = vm.isSendingCode,
                    showSuccessCelebration = vm.otpShowSuccess,
                    interactionLocked = vm.otpSubmitInFlight,
                    errorMessage = vm.otpError,
                    onResend = vm::resendCode,
                    onCodeComplete = { vm.verifyOtp(onSuccess) },
                )
            }
        }

        if (step == AuthSignInStep.Identifier) {
            Column(
                Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .background(Color(0xFFF7F7F8))
                    .padding(horizontal = 24.dp)
                    .padding(bottom = navBottom + 16.dp, top = 12.dp),
            ) {
                Button(
                    onClick = vm::handleIdentifierContinue,
                    enabled = vm.isIdentifierValid && !vm.isCheckingIdentifier && !vm.isSendingCode,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(52.dp),
                    shape = RoundedCornerShape(999.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Black),
                ) {
                    Text("CONTINUER", fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
                }
            }
        }
    }
}
