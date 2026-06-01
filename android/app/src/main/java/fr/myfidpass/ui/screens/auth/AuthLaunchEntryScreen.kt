package fr.myfidpass.ui.screens.auth

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.ui.components.AuthLaunchHeroImage

private val PrimaryCtaBottomInset = 50.dp
private val GlassPillBackground = Color(0xFFF2F2F7)
private val GlassPillBorder = Color.Black.copy(alpha = 0.10f)

/** Aligné iOS `AuthLaunchEntryView` — visuel plein écran + COMMENCER / Se connecter. */
@Composable
fun AuthLaunchEntryScreen(
    onCreateAccount: () -> Unit,
    onSignIn: () -> Unit,
) {
    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { visible = true }
    val ctaAlpha by animateFloatAsState(if (visible) 1f else 0f, tween(520), label = "cta")
    val ctaOffset by animateFloatAsState(if (visible) 0f else 18f, tween(520), label = "off")
    val navBottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

    Column(Modifier.fillMaxSize().background(Color.White)) {
        Box(
            Modifier
                .weight(1f)
                .fillMaxWidth(),
        ) {
            AuthLaunchHeroImage(Modifier.fillMaxSize())
            // Fondu bas léger (iOS welcome gradient ~44pt)
            Box(
                Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .height(56.dp)
                    .background(
                        Brush.verticalGradient(
                            0f to Color.Transparent,
                            1f to Color.White,
                        ),
                    ),
            )
        }

        Column(
            Modifier
                .fillMaxWidth()
                .background(Color.White)
                .padding(horizontal = 40.dp)
                .padding(top = 8.dp)
                .padding(bottom = maxOf(PrimaryCtaBottomInset, navBottom + 8.dp))
                .alpha(ctaAlpha)
                .offset(y = ctaOffset.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Button(
                onClick = onCreateAccount,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                shape = RoundedCornerShape(50.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = GlassPillBackground,
                    contentColor = Color.Black,
                ),
                border = BorderStroke(1.dp, GlassPillBorder),
                elevation = ButtonDefaults.buttonElevation(
                    defaultElevation = 2.dp,
                    pressedElevation = 1.dp,
                ),
            ) {
                Text("COMMENCER", fontWeight = FontWeight.Black, fontSize = 20.sp)
            }

            Spacer(Modifier.height(8.dp))

            TextButton(onClick = onSignIn) {
                Text(
                    "Se connecter",
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 16.sp,
                    color = Color.Black.copy(0.78f),
                    textDecoration = TextDecoration.Underline,
                )
            }
        }
    }
}
