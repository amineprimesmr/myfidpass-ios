package fr.myfidpass.ui.components

import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import fr.myfidpass.ui.theme.MerchantDesignSystem

/** Insets système (edge-to-edge) — aligné safe area iOS. */
object SafeArea {
    @Composable
    fun statusBarTop(): Dp =
        WindowInsets.statusBars.asPaddingValues().calculateTopPadding()

    @Composable
    fun navigationBarBottom(): Dp =
        WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

    /** Status bar + hauteur contenu `DashboardHomeMinimalTopBar`. */
    @Composable
    fun merchantTopBarTotalInset(): Dp =
        statusBarTop() + MerchantDesignSystem.topBarScrollInset
}

fun Modifier.safeStatusBarPadding(): Modifier = statusBarsPadding()

fun Modifier.safeNavigationBarPadding(): Modifier = navigationBarsPadding()
