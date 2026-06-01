package fr.myfidpass.ui.navigation

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween

/** Durées et ressorts alignés iOS `MerchantMotion.swift`. */
object MerchantMotion {
    const val NavDurationMs = 320
    const val TabCrossfadeMs = 220
    const val OverlayDurationMs = 340
    const val ModalDurationMs = 380
    const val ImmersiveCrossfadeMs = 260

    val navEasing = FastOutSlowInEasing

    val tabSpring = spring<Float>(
        dampingRatio = Spring.DampingRatioNoBouncy,
        stiffness = Spring.StiffnessMediumLow,
    )

    fun navTween(durationMs: Int = NavDurationMs) = tween<Float>(
        durationMillis = durationMs,
        easing = navEasing,
    )

    fun overlayTween(durationMs: Int = OverlayDurationMs) = tween<Float>(
        durationMillis = durationMs,
        easing = navEasing,
    )
}
