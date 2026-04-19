package fr.myfidpass.util

import android.net.Uri
import androidx.browser.customtabs.CustomTabColorSchemeParams
import androidx.browser.customtabs.CustomTabsIntent
import androidx.compose.ui.graphics.toArgb
import fr.myfidpass.ui.theme.Success

fun openInCustomTab(context: android.content.Context, url: String) {
    val uri = Uri.parse(url)
    val colors = CustomTabColorSchemeParams.Builder()
        .setToolbarColor(Success.toArgb())
        .build()
    CustomTabsIntent.Builder()
        .setDefaultColorSchemeParams(colors)
        .setShowTitle(true)
        .build()
        .launchUrl(context, uri)
}
