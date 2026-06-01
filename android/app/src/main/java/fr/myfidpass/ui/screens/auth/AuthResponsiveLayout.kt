package fr.myfidpass.ui.screens.auth

import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** Aligné iOS `AuthResponsiveLayout.swift`. */
object AuthResponsiveLayout {
    fun heroHeightFraction(screenWidthDp: Int): Float = when {
        screenWidthDp >= 600 -> 0.58f
        else -> 0.55f
    }

    fun heroImageWidthFraction(screenWidthDp: Int): Float = when {
        screenWidthDp >= 600 -> 0.68f
        else -> 1f
    }

    fun backButtonTopPadding(statusBarTopDp: Dp): Dp =
        maxOf(statusBarTopDp, 44.dp) + 8.dp
}
