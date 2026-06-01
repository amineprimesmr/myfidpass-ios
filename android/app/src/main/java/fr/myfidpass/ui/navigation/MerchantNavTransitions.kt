package fr.myfidpass.ui.navigation

import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavBackStackEntry

typealias NavTransitionScope = AnimatedContentTransitionScope<NavBackStackEntry>

/** Push horizontal léger + fondu — proche NavigationStack iOS. */
fun NavTransitionScope.merchantPushEnter(): EnterTransition =
    slideInHorizontally(
        animationSpec = tween(MerchantMotion.NavDurationMs, easing = MerchantMotion.navEasing),
        initialOffsetX = { fullWidth -> fullWidth / 4 },
    ) + fadeIn(tween(MerchantMotion.NavDurationMs, easing = MerchantMotion.navEasing))

fun NavTransitionScope.merchantPushExit(): ExitTransition =
    fadeOut(tween(MerchantMotion.NavDurationMs - 40, easing = MerchantMotion.navEasing))

fun NavTransitionScope.merchantPopEnter(): EnterTransition =
    fadeIn(tween(MerchantMotion.NavDurationMs - 40, easing = MerchantMotion.navEasing))

fun NavTransitionScope.merchantPopExit(): ExitTransition =
    slideOutHorizontally(
        animationSpec = tween(MerchantMotion.NavDurationMs, easing = MerchantMotion.navEasing),
        targetOffsetX = { fullWidth -> fullWidth / 4 },
    ) + fadeOut(tween(MerchantMotion.NavDurationMs - 40, easing = MerchantMotion.navEasing))

/** Présentation modale (scanner, Ma carte). */
fun NavTransitionScope.merchantModalEnter(): EnterTransition =
    slideInVertically(
        animationSpec = tween(MerchantMotion.ModalDurationMs, easing = MerchantMotion.navEasing),
        initialOffsetY = { fullHeight -> fullHeight / 10 },
    ) + fadeIn(tween(MerchantMotion.ModalDurationMs, easing = MerchantMotion.navEasing))

fun NavTransitionScope.merchantModalExit(): ExitTransition =
    slideOutVertically(
        animationSpec = tween(MerchantMotion.ModalDurationMs, easing = MerchantMotion.navEasing),
        targetOffsetY = { fullHeight -> fullHeight / 10 },
    ) + fadeOut(tween(MerchantMotion.ModalDurationMs - 60, easing = MerchantMotion.navEasing))

fun NavTransitionScope.merchantModalPopEnter(): EnterTransition =
    fadeIn(tween(MerchantMotion.ModalDurationMs - 60, easing = MerchantMotion.navEasing))

fun NavTransitionScope.merchantModalPopExit(): ExitTransition = merchantModalExit()

/** Crossfade entre onglets principaux. */
fun merchantTabTransitionSpec(): AnimatedContentTransitionScope<Int>.() -> androidx.compose.animation.ContentTransform =
    {
        fadeIn(tween(MerchantMotion.TabCrossfadeMs, easing = MerchantMotion.navEasing)) togetherWith
            fadeOut(tween(MerchantMotion.TabCrossfadeMs, easing = MerchantMotion.navEasing))
    }

/** Overlay plein écran (réglages, flyer, etc.). */
fun merchantOverlayEnter(): EnterTransition =
    slideInHorizontally(
        animationSpec = tween(MerchantMotion.OverlayDurationMs, easing = MerchantMotion.navEasing),
        initialOffsetX = { fullWidth -> fullWidth },
    ) + fadeIn(tween(MerchantMotion.OverlayDurationMs, easing = MerchantMotion.navEasing))

fun merchantOverlayExit(): ExitTransition =
    slideOutHorizontally(
        animationSpec = tween(MerchantMotion.OverlayDurationMs, easing = MerchantMotion.navEasing),
        targetOffsetX = { fullWidth -> fullWidth },
    ) + fadeOut(tween(MerchantMotion.OverlayDurationMs - 40, easing = MerchantMotion.navEasing))

fun merchantPaywallEnter(): EnterTransition =
    fadeIn(tween(MerchantMotion.OverlayDurationMs, easing = MerchantMotion.navEasing)) +
        scaleIn(
            initialScale = 0.94f,
            animationSpec = tween(MerchantMotion.OverlayDurationMs, easing = MerchantMotion.navEasing),
        )

fun merchantPaywallExit(): ExitTransition =
    fadeOut(tween(MerchantMotion.OverlayDurationMs - 40, easing = MerchantMotion.navEasing)) +
        scaleOut(
            targetScale = 0.94f,
            animationSpec = tween(MerchantMotion.OverlayDurationMs - 40, easing = MerchantMotion.navEasing),
        )

@Composable
fun MerchantAnimatedFullScreenOverlay(
    visible: Boolean,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    AnimatedVisibility(
        visible = visible,
        enter = merchantOverlayEnter(),
        exit = merchantOverlayExit(),
        modifier = modifier,
    ) {
        Box(Modifier.fillMaxSize()) {
            content()
        }
    }
}
