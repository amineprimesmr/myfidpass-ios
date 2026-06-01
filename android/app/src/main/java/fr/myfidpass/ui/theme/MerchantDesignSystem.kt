package fr.myfidpass.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.unit.dp

/** Espacements / rayons alignés `AppTheme` + layouts iOS commerçant. */
object MerchantDesignSystem {
    val spacingXs = 4.dp
    val spacingSm = 8.dp
    val spacingMd = 16.dp
    val spacingLg = 24.dp
    val spacingXl = 32.dp

    val radiusSm = 8.dp
    val radiusMd = 12.dp
    val radiusLg = 16.dp
    val radiusXl = 24.dp
    val radiusPanelTop = 24.dp
    val radiusKpiTile = 26.dp
    val radiusTransactionPill = 32.dp

    /** Rangée titre + actions (hors status bar). */
    val topBarContentHeight = 38.dp
    val topBarPaddingTop = 0.dp
    val topBarPaddingBottom = 4.dp
    val topBarBlockHeight = topBarPaddingTop + topBarContentHeight + topBarPaddingBottom
    /** Espace noir avant le panneau arrondi (coins 24dp visibles). */
    val topBarCornerRevealGap = 4.dp
    val topBarScrollInset = topBarBlockHeight + topBarCornerRevealGap

    val topRoundedPanelShape = RoundedCornerShape(topStart = radiusPanelTop, topEnd = radiusPanelTop)
}
