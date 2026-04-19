package fr.myfidpass.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

private val LightColors = lightColorScheme(
    primary = Primary,
    onPrimary = ColorLightOnPrimary,
    primaryContainer = Primary.copy(alpha = 0.12f),
    secondary = Accent,
    secondaryContainer = Accent.copy(alpha = 0.15f),
    background = BackgroundLight,
    surface = Color.White,
    onBackground = TextPrimaryLight,
    onSurface = TextPrimaryLight,
    error = Error,
)

private val DarkColors = darkColorScheme(
    primary = Primary,
    onPrimary = ColorLightOnPrimary,
    secondary = Accent,
    background = BackgroundDark,
    surface = Color(0xFF1C1C1E),
    onBackground = Color(0xFFF1F5F9),
    onSurface = Color(0xFFF1F5F9),
    error = Error,
)

private val ColorLightOnPrimary = Color(0xFFFFFFFF)

@Composable
fun MyfidpassTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit,
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val ctx = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(ctx) else dynamicLightColorScheme(ctx)
        }
        darkTheme -> DarkColors
        else -> LightColors
    }
    MaterialTheme(
        colorScheme = colorScheme,
        typography = MyfidpassTypography,
        content = content,
    )
}
