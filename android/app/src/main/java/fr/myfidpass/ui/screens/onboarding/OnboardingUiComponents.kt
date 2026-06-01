package fr.myfidpass.ui.screens.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

@Composable
fun OnboardingSegmentedProgressBar(
    filledSegments: Int,
    totalSegments: Int,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        repeat(totalSegments.coerceAtLeast(1)) { index ->
            Box(
                Modifier
                    .weight(1f)
                    .height(8.dp)
                    .background(
                        if (index < filledSegments) Color.Black.copy(0.88f) else Color.Black.copy(0.12f),
                        RoundedCornerShape(999.dp),
                    ),
            )
        }
    }
}

@Composable
fun OnboardingProcessHeader(
    filledSegments: Int,
    totalSegments: Int,
    onBack: (() -> Unit)?,
    backContent: @Composable () -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (onBack != null) {
            backContent()
        } else {
            Spacer(Modifier.size(34.dp))
        }
        OnboardingSegmentedProgressBar(
            filledSegments = filledSegments,
            totalSegments = totalSegments,
            modifier = Modifier.weight(1f),
        )
        Spacer(Modifier.size(34.dp))
    }
}

@Composable
fun OnboardingEmailCaptureContent(
    email: String,
    onEmailChange: (String) -> Unit,
    isChecking: Boolean,
    errorMessage: String?,
    commerceTitle: String? = null,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.height(24.dp))
        Text(
            "Votre e-mail",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = Color(0xFF141518),
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(10.dp))
        Text(
            "Nous vous enverrons un code à 6 chiffres pour sécuriser votre compte.",
            fontSize = 15.sp,
            color = Color(0xFF73737A),
            textAlign = TextAlign.Center,
            lineHeight = 21.sp,
        )
        commerceTitle?.let {
            Spacer(Modifier.height(18.dp))
            SignUpCommerceBannerCompact(it)
        }
        Spacer(Modifier.height(28.dp))
        OutlinedTextField(
            value = email,
            onValueChange = onEmailChange,
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Adresse e-mail") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
            enabled = !isChecking,
        )
        if (isChecking) {
            Spacer(Modifier.height(16.dp))
            CircularProgressIndicator(Modifier.size(28.dp), strokeWidth = 2.dp)
        }
        errorMessage?.takeIf { it.isNotBlank() }?.let {
            Spacer(Modifier.height(12.dp))
            Text(it, color = Color(0xFFD93838), fontSize = 14.sp, textAlign = TextAlign.Center)
        }
    }
}

@Composable
private fun SignUpCommerceBannerCompact(title: String) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(Color.Black.copy(0.045f), RoundedCornerShape(16.dp))
            .border(1.dp, Color.Black.copy(0.07f), RoundedCornerShape(16.dp))
            .padding(horizontal = 16.dp, vertical = 14.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("VOTRE COMMERCE", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = Color.Black.copy(0.45f))
        Spacer(Modifier.height(6.dp))
        Text(title, fontWeight = FontWeight.Bold, fontSize = 17.sp, textAlign = TextAlign.Center)
    }
}

@Composable
fun AuthEmailOtpVerificationContent(
    code: String,
    onCodeChange: (String) -> Unit,
    email: String,
    commerceTitle: String? = null,
    isVerifying: Boolean,
    isSendingCode: Boolean,
    showSuccessCelebration: Boolean,
    interactionLocked: Boolean,
    errorMessage: String?,
    onResend: () -> Unit,
    onCodeComplete: () -> Unit,
) {
    val focusRequester = remember { FocusRequester() }
    var resendCountdown by remember { mutableIntStateOf(60) }

    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }

    LaunchedEffect(isVerifying, showSuccessCelebration) {
        if (!isVerifying && !showSuccessCelebration) {
            focusRequester.requestFocus()
        }
    }

    LaunchedEffect(isSendingCode) {
        if (!isSendingCode) {
            resendCountdown = 60
            while (resendCountdown > 0) {
                delay(1000)
                resendCountdown -= 1
            }
        }
    }

    LaunchedEffect(code) {
        val filtered = code.filter { it.isDigit() }.take(6)
        if (filtered != code) {
            onCodeChange(filtered)
            return@LaunchedEffect
        }
        if (filtered.length == 6 && !interactionLocked && !isVerifying && !showSuccessCelebration) {
            onCodeComplete()
        }
    }

    Box(Modifier.fillMaxWidth()) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .alpha(if (isVerifying || showSuccessCelebration) 0.35f else 1f),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(24.dp))
            Text(
                if (showSuccessCelebration) "Code validé" else "Entrez le code",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF141518),
            )
            if (!showSuccessCelebration) {
                Spacer(Modifier.height(10.dp))
                Text(
                    buildString {
                        append("Code envoyé à\n")
                        append(email)
                    },
                    fontSize = 15.sp,
                    color = Color(0xFF73737A),
                    textAlign = TextAlign.Center,
                    lineHeight = 21.sp,
                )
                commerceTitle?.let {
                    Spacer(Modifier.height(14.dp))
                    SignUpCommerceBannerCompact(it)
                }
            }
            Spacer(Modifier.height(28.dp))
            OtpBoxesRow(code = code, focusRequester = focusRequester, onCodeChange = onCodeChange)
            if (!showSuccessCelebration) {
                Spacer(Modifier.height(20.dp))
                if (resendCountdown > 0) {
                    Text(
                        "Renvoyer le code dans ${resendCountdown}s",
                        color = Color(0xFF73737A),
                        fontSize = 14.sp,
                    )
                } else {
                    TextButton(onClick = onResend, enabled = !isSendingCode) {
                        Text(if (isSendingCode) "Envoi…" else "Renvoyer le code")
                    }
                }
            }
            errorMessage?.takeIf { it.isNotBlank() && !showSuccessCelebration }?.let {
                Spacer(Modifier.height(12.dp))
                Text(it, color = Color(0xFFD93838), fontSize = 14.sp, textAlign = TextAlign.Center)
            }
        }

        if (showSuccessCelebration) {
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                OtpSuccessCelebration()
            }
        }
    }

    BasicTextField(
        value = code,
        onValueChange = onCodeChange,
        modifier = Modifier
            .size(1.dp)
            .alpha(0f)
            .focusRequester(focusRequester),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
    )
}

@Composable
private fun OtpBoxesRow(
    code: String,
    focusRequester: FocusRequester,
    onCodeChange: (String) -> Unit,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        repeat(6) { index ->
            val char = code.getOrNull(index)?.toString().orEmpty()
            val active = code.length == index
            Box(
                Modifier
                    .size(46.dp)
                    .background(Color.White, RoundedCornerShape(12.dp))
                    .border(
                        width = if (active) 2.dp else 1.dp,
                        color = if (active) Color.Black else Color.Black.copy(0.14f),
                        shape = RoundedCornerShape(12.dp),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Text(char, fontSize = 22.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun OtpSuccessCelebration() {
    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        visible = true
    }
    Box(
        Modifier
            .size(84.dp)
            .alpha(if (visible) 1f else 0.5f)
            .background(Color(0xFF1AC770).copy(0.16f), RoundedCornerShape(999.dp)),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier
                .size(64.dp)
                .background(Color(0xFF1AC770), RoundedCornerShape(999.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Text("✓", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
        }
    }
}
