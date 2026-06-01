package fr.myfidpass.ui.components

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.ui.stats.CommerceStatsMonthNavigator
import fr.myfidpass.ui.theme.CommerceStatsPalette
import fr.myfidpass.ui.theme.MerchantDesignSystem
import java.time.YearMonth
import java.time.format.TextStyle
import java.util.Locale

data class CommerceStatsMonthPage(
    val monthKey: String,
    val membersCount: Int?,
    val newMembers: Int?,
    val avgBasketEur: Double?,
    val visitFrequency: Double?,
    val sparkline: List<Float>,
    val freqSparkline: List<Float> = emptyList(),
)

/** Hauteur fixe du carrousel KPI — requis dans un `Column` scrollable (sinon crash Compose). */
private val kpiMembersBlockHeight = 212.dp
private val kpiPanierFreqBlockHeight = 118.dp
private val kpiCarouselBlockHeight = kpiMembersBlockHeight + 2.dp + kpiPanierFreqBlockHeight

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun CommerceStatsKpiCarousel(
    pages: List<CommerceStatsMonthPage>,
    palette: CommerceStatsPalette,
    modifier: Modifier = Modifier,
    panierFreqLocked: Boolean = false,
    onUnlockPro: () -> Unit = {},
    onMembersTap: (CommerceStatsMonthPage) -> Unit = {},
    onPanierTap: (CommerceStatsMonthPage) -> Unit = {},
    onMonthChanged: (String) -> Unit = {},
) {
    if (pages.isEmpty()) return
    val pagerState = rememberPagerState(pageCount = { pages.size })
    val page = pages[pagerState.currentPage.coerceIn(0, pages.lastIndex)]

    LaunchedEffect(pagerState.currentPage, pages) {
        pages.getOrNull(pagerState.currentPage)?.monthKey?.let(onMonthChanged)
    }
    val monthLabel = remember(page.monthKey) {
        CommerceStatsMonthNavigator.displayTitleInMonth(page.monthKey)
    }
    val kpiCarouselPeek = 22.dp
    val kpiCardContentLeading = 16.dp
    val monthTitleStart = kpiCarouselPeek + kpiCardContentLeading

    Column(modifier) {
        Text(
            monthLabel,
            color = palette.pageTitle,
            fontSize = 32.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(start = monthTitleStart, end = MerchantDesignSystem.spacingMd),
        )
        Spacer(Modifier.height(4.dp))
        HorizontalPager(
            state = pagerState,
            modifier = Modifier
                .fillMaxWidth()
                .height(kpiCarouselBlockHeight),
            pageSpacing = 10.dp,
            contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 22.dp),
        ) { index ->
            val p = pages[index]
            Column(Modifier.height(kpiCarouselBlockHeight)) {
                CommerceStatsMembersKpiCard(
                    membersCount = p.membersCount,
                    newMembers = p.newMembers,
                    sparkline = p.sparkline,
                    palette = palette,
                    blurred = false,
                    onClick = null,
                    modifier = Modifier.height(kpiMembersBlockHeight),
                )
                Spacer(Modifier.height(2.dp))
                CommerceStatsProUnlockOverlay(
                    locked = panierFreqLocked,
                    onUnlock = onUnlockPro,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(kpiPanierFreqBlockHeight),
                ) {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .height(kpiPanierFreqBlockHeight),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        CommerceStatsCompactKpiCard(
                            title = "Panier moyen",
                            value = p.avgBasketEur?.let { "%.0f €".format(it) } ?: "—",
                            palette = palette,
                            modifier = Modifier
                                .weight(1f)
                                .clickable(enabled = !panierFreqLocked) { onPanierTap(p) },
                        )
                        CommerceStatsCompactKpiCard(
                            title = "Fréquence d'achat",
                            value = p.visitFrequency?.let { "%.1f visites".format(it) } ?: "—",
                            valueSubline = if (p.visitFrequency != null) "/mois" else null,
                            palette = palette,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }
        }
        Spacer(Modifier.height(10.dp))
        Row(
            Modifier
                .fillMaxWidth()
                .padding(start = monthTitleStart),
            horizontalArrangement = Arrangement.Start,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            repeat(pages.size) { i ->
                val active = i == pagerState.currentPage
                Box(
                    Modifier
                        .padding(horizontal = 3.dp)
                        .height(6.dp)
                        .width(if (active) 24.dp else 6.dp)
                        .clip(RoundedCornerShape(999.dp))
                        .background(
                            if (active) palette.onTilePrimary.copy(0.92f)
                            else palette.secondaryLabel.copy(0.28f),
                        ),
                )
            }
        }
    }
}

@Composable
fun CommerceStatsMembersKpiCard(
    membersCount: Int?,
    newMembers: Int?,
    sparkline: List<Float>,
    palette: CommerceStatsPalette,
    modifier: Modifier = Modifier,
    blurred: Boolean = false,
    onClick: (() -> Unit)? = null,
) {
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(MerchantDesignSystem.radiusKpiTile))
            .background(palette.tileSurfaceLight)
            .border(1.dp, palette.onTilePrimary.copy(0.06f), RoundedCornerShape(MerchantDesignSystem.radiusKpiTile))
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        Text("Membres", color = palette.onTilePrimary.copy(0.84f), fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
        Spacer(Modifier.height(6.dp))
        Text(
            membersCount?.toString() ?: "—",
            color = palette.onTilePrimary,
            fontSize = 36.sp,
            fontWeight = FontWeight.Bold,
        )
        newMembers?.takeIf { it > 0 }?.let {
            Text("+$it nouveaux", color = palette.kpiTrendGreen, fontSize = 13.sp, fontWeight = FontWeight.Medium)
        }
        Spacer(Modifier.height(8.dp))
        if (sparkline.isNotEmpty()) {
            MiniSparklineChart(
                values = if (blurred) sparkline.map { it * 0.6f + 0.2f } else sparkline,
                lineColor = palette.chartLine,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
fun CommerceStatsCompactKpiCard(
    title: String,
    value: String,
    palette: CommerceStatsPalette,
    modifier: Modifier = Modifier,
    blurred: Boolean = false,
    valueSubline: String? = null,
    sparkline: List<Float> = emptyList(),
) {
    Column(
        modifier
            .clip(RoundedCornerShape(MerchantDesignSystem.radiusKpiTile))
            .background(palette.tileSurfaceLight)
            .border(1.dp, palette.onTilePrimary.copy(0.06f), RoundedCornerShape(MerchantDesignSystem.radiusKpiTile))
            .padding(horizontal = 14.dp, vertical = 12.dp)
            .then(if (blurred) Modifier.alpha(0.45f) else Modifier)
            .then(modifier),
    ) {
        Text(title, color = palette.onTilePrimary.copy(0.84f), fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
        Spacer(Modifier.height(8.dp))
        Text(
            if (blurred) "•••" else value,
            color = palette.onTilePrimary,
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
        )
        valueSubline?.let {
            Text(it, color = palette.onTilePrimary.copy(0.72f), fontSize = 14.sp)
        }
        if (sparkline.isNotEmpty()) {
            Spacer(Modifier.height(6.dp))
            MiniSparklineChart(
                values = sparkline,
                lineColor = palette.chartLine,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
