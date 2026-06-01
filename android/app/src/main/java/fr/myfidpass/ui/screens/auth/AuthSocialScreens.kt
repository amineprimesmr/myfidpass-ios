package fr.myfidpass.ui.screens.auth

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.ui.components.AuthHeroCarousel
import fr.myfidpass.ui.components.AuthLegalFooter
import fr.myfidpass.ui.components.GlassIconButton
import fr.myfidpass.util.openInCustomTab

@Composable
fun AuthSignInScreen(
    onBack: () -> Unit,
    onEmail: () -> Unit,
    onGoogle: () -> Unit = {},
    onApple: () -> Unit = {},
) {
    AuthEmailEntryShell(
        onBack = onBack,
        onEmail = onEmail,
        onGoogle = onGoogle,
        onApple = onApple,
        emailLabel = "Connexion avec l'e-mail",
    )
}

@Composable
fun AuthSignUpScreen(
    commerceTitle: String?,
    onBack: () -> Unit,
    onEmail: () -> Unit,
    onGoogle: () -> Unit = {},
    onApple: () -> Unit = {},
) {
    AuthEmailEntryShell(
        onBack = onBack,
        onEmail = onEmail,
        onGoogle = onGoogle,
        onApple = onApple,
        emailLabel = "Choisir mon mot de passe",
        commerceTitle = commerceTitle,
    )
}

@Composable
private fun AuthEmailEntryShell(
    onBack: () -> Unit,
    onEmail: () -> Unit,
    onGoogle: () -> Unit,
    onApple: () -> Unit = {},
    emailLabel: String,
    commerceTitle: String? = null,
) {
    val context = LocalContext.current
    val contentAlpha by animateFloatAsState(1f, tween(520), label = "content")
    val statusTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val navBottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val config = LocalConfiguration.current
    val density = LocalDensity.current
    val screenHeightDp = config.screenHeightDp.toFloat()

    Box(
        Modifier
            .fillMaxSize()
            .background(Color.White),
    ) {
        Column(Modifier.fillMaxSize()) {
            Spacer(Modifier.height(AuthResponsiveLayout.backButtonTopPadding(statusTop)))
            AuthHeroCarousel(
                screenWidthDp = config.screenWidthDp,
                availableHeightDp = screenHeightDp - with(density) { statusTop.toPx() / density.density } - 120f,
                modifier = Modifier.fillMaxWidth(),
            )
            Column(
                Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .background(
                        Brush.verticalGradient(
                            0f to Color.White.copy(0.85f),
                            0.15f to Color.White,
                            1f to Color.White,
                        ),
                    )
                    .padding(horizontal = 24.dp)
                    .padding(top = 8.dp, bottom = navBottom + 16.dp)
                    .alpha(contentAlpha),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                commerceTitle?.let {
                    SignUpCommerceBanner(it)
                    Spacer(Modifier.height(12.dp))
                }
                Button(
                    onClick = onEmail,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(52.dp),
                    shape = RoundedCornerShape(999.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color.White, contentColor = Color.Black),
                    elevation = ButtonDefaults.buttonElevation(defaultElevation = 0.dp),
                ) {
                    Text(emailLabel, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                }
                Spacer(Modifier.height(10.dp))
                OutlinedGoogleSignInButton(onClick = onGoogle)
                Spacer(Modifier.height(10.dp))
                OutlinedButton(
                    onClick = {
                        onApple()
                        openInCustomTab(context, "https://www.myfidpass.fr/login")
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(52.dp),
                    shape = RoundedCornerShape(999.dp),
                ) {
                    Text("Continuer avec Apple", fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                }
                Spacer(Modifier.height(8.dp))
                AuthLegalFooter()
            }
        }
        GlassIconButton(
            icon = Icons.AutoMirrored.Filled.ArrowBack,
            contentDescription = "Retour",
            onClick = onBack,
            modifier = Modifier
                .padding(start = 16.dp, top = statusTop + 8.dp)
                .align(Alignment.TopStart),
            tint = Color.Black.copy(0.88f),
        )
    }
}

@Composable
private fun OutlinedGoogleSignInButton(onClick: () -> Unit) {
    OutlinedButton(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp),
        shape = RoundedCornerShape(999.dp),
    ) {
        Text("Continuer avec Google", fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
    }
}

@Composable
fun SignUpCommerceBanner(title: String) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Color.Black.copy(0.045f))
            .border(1.dp, Color.Black.copy(0.07f), RoundedCornerShape(16.dp))
            .padding(horizontal = 16.dp, vertical = 14.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            "VOTRE COMMERCE",
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color.Black.copy(0.45f),
            letterSpacing = 0.6.sp,
        )
        Spacer(Modifier.height(6.dp))
        Text(
            title,
            fontWeight = FontWeight.Bold,
            fontSize = 17.sp,
            color = Color.Black.copy(0.9f),
            textAlign = TextAlign.Center,
            lineHeight = 22.sp,
        )
    }
}
