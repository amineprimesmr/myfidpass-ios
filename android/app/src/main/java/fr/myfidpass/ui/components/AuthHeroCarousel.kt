package fr.myfidpass.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import fr.myfidpass.R
import fr.myfidpass.ui.screens.auth.AuthResponsiveLayout
import kotlinx.coroutines.delay

val authHeroDrawableIds = listOf(
    R.drawable.auth_hero_5,
    R.drawable.auth_hero_6,
    R.drawable.auth_hero_7,
    R.drawable.auth_hero_8,
)

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun AuthHeroCarousel(
    modifier: Modifier = Modifier,
    screenWidthDp: Int,
    availableHeightDp: Float,
) {
    val pagerState = rememberPagerState(pageCount = { authHeroDrawableIds.size })
    val alpha by animateFloatAsState(1f, tween(720), label = "heroAlpha")
    val heroHeight = availableHeightDp * AuthResponsiveLayout.heroHeightFraction(screenWidthDp)
    val imageWidthFraction = AuthResponsiveLayout.heroImageWidthFraction(screenWidthDp)

    LaunchedEffect(Unit) {
        while (true) {
            delay(4200)
            val next = (pagerState.currentPage + 1) % authHeroDrawableIds.size
            pagerState.animateScrollToPage(next)
        }
    }

    Box(
        modifier
            .fillMaxWidth()
            .height(heroHeight.dp)
            .alpha(alpha),
        contentAlignment = Alignment.TopCenter,
    ) {
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.fillMaxSize(),
            userScrollEnabled = false,
            verticalAlignment = Alignment.Top,
        ) { page ->
            Box(
                Modifier.fillMaxSize(),
                contentAlignment = Alignment.TopCenter,
            ) {
                Image(
                    painter = painterResource(authHeroDrawableIds[page]),
                    contentDescription = null,
                    modifier = Modifier
                        .fillMaxWidth(imageWidthFraction)
                        .fillMaxHeight(),
                    contentScale = ContentScale.FillWidth,
                    alignment = Alignment.TopCenter,
                )
            }
        }
    }
}

/** Visuel welcome — aligné iOS `AuthWelcomeImageView` (pleine largeur, ancré en haut). */
@Composable
fun AuthLaunchHeroImage(
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier,
        contentAlignment = Alignment.TopCenter,
    ) {
        Image(
            painter = painterResource(R.drawable.auth_hero_5),
            contentDescription = null,
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxSize()
                .padding(top = 12.dp),
            contentScale = ContentScale.FillWidth,
            alignment = Alignment.TopCenter,
        )
    }
}
