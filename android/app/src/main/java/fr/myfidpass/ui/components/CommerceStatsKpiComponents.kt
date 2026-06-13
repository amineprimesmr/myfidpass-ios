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
import androidx.compose.foundation.Image
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Map
import androidx.compose.material3.Icon
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import fr.myfidpass.R
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.ui.stats.CommerceGoogleReviewsMonthHistory
import fr.myfidpass.ui.stats.CommerceStatisticsDataBuilder
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
    val avgBasketTrendEuro: Double? = null,
    val visitFrequency: Double?,
    val googleReviewsNewInPeriod: Int = 0,
    val sparkline: List<Float>,
    val monthAxisDays: List<Int> = emptyList(),
    val panierSparkline: List<Float> = emptyList(),
    val panierMonthAxisDays: List<Int> = emptyList(),
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
    onGoogleReviewsTap: () -> Unit = {},
    onMonthChanged: (String) -> Unit = {},
) {
    if (pages.isEmpty()) return
    val context = LocalContext.current
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
            val googleReviewsTrendLabel = remember(p.monthKey, p.googleReviewsNewInPeriod) {
                CommerceGoogleReviewsMonthHistory.trendLabel(context, p.monthKey, p.googleReviewsNewInPeriod)
            }
            LaunchedEffect(p.monthKey, p.googleReviewsNewInPeriod) {
                CommerceGoogleReviewsMonthHistory.persistIfNeeded(context, p.monthKey, p.googleReviewsNewInPeriod)
            }
            Column(Modifier.height(kpiCarouselBlockHeight)) {
                CommerceStatsMembersKpiCard(
                    membersCount = p.membersCount,
                    newMembers = p.newMembers,
                    sparkline = p.sparkline,
                    monthAxisDays = p.monthAxisDays,
                    palette = palette,
                    blurred = false,
                    onClick = { onMembersTap(p) },
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
                            value = p.avgBasketEur?.takeIf { it > 0 }?.let {
                                "%.2f €".format(java.util.Locale.FRANCE, it)
                            } ?: "—",
                            trendEuro = p.avgBasketTrendEuro,
                            palette = palette,
                            sparkline = p.panierSparkline,
                            sparklineDayLabels = p.panierMonthAxisDays,
                            edgeToEdgeSparkline = true,
                            panierEvolutionStyle = true,
                            modifier = Modifier
                                .weight(1f)
                                .clickable(enabled = !panierFreqLocked) { onPanierTap(p) },
                        )
                        CommerceStatsCompactKpiCard(
                            title = "Avis Google",
                            value = formatGoogleReviewsKpi(p.googleReviewsNewInPeriod),
                            trendLabel = googleReviewsTrendLabel,
                            trendLabelColor = palette.kpiTrendGreen,
                            palette = palette,
                            leadingIconRes = R.drawable.googleicon,
                            googleReviewsFooter = true,
                            modifier = Modifier
                                .weight(1f)
                                .clickable(enabled = !panierFreqLocked) { onGoogleReviewsTap() },
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
    monthAxisDays: List<Int> = emptyList(),
    palette: CommerceStatsPalette,
    modifier: Modifier = Modifier,
    blurred: Boolean = false,
    onClick: (() -> Unit)? = null,
) {
    val shape = RoundedCornerShape(MerchantDesignSystem.radiusKpiTile)
    val chartValues = if (blurred) sparkline.map { it * 0.6f + 0.2f } else sparkline
    Column(
        modifier
            .fillMaxWidth()
            .clip(shape)
            .background(palette.tileSurfaceLight)
            .border(1.dp, palette.onTilePrimary.copy(0.06f), shape)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier),
    ) {
        Column(Modifier.padding(start = 18.dp, end = 16.dp, top = 16.dp)) {
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
        }
        if (chartValues.isNotEmpty()) {
            MembersMonthSparklineChart(
                values = chartValues,
                monthAxisDays = monthAxisDays,
                lineColor = palette.chartLine,
                axisLabelColor = palette.secondaryLabel.copy(alpha = 0.88f),
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(bottomStart = 22.dp, bottomEnd = 22.dp)),
            )
        } else {
            Spacer(Modifier.height(14.dp))
        }
    }
}

@Composable
private fun CommerceStatsMonthDayAxisRow(
    days: List<Int>,
    palette: CommerceStatsPalette,
    modifier: Modifier = Modifier,
) {
    val labels = days.filter { it > 0 }.ifEmpty { listOf(1, 5, 10, 15, 20, 25, 30) }
    Row(
        modifier
            .fillMaxWidth()
            .padding(top = 4.dp, start = 2.dp, end = 2.dp),
    ) {
        labels.forEach { day ->
            Text(
                "$day",
                modifier = Modifier.weight(1f),
                fontSize = 10.sp,
                fontWeight = FontWeight.Medium,
                color = palette.secondaryLabel.copy(alpha = 0.72f),
                textAlign = TextAlign.Center,
                maxLines = 1,
            )
        }
    }
}

private fun formatGoogleReviewsKpi(count: Int): String =
    if (count > 0) "+${"%,d".format(java.util.Locale.FRANCE, count).replace('\u00A0', ' ')}" else "—"

@Composable
fun CommerceStatsCompactKpiCard(
    title: String,
    value: String,
    palette: CommerceStatsPalette,
    modifier: Modifier = Modifier,
    blurred: Boolean = false,
    valueSubline: String? = null,
    trendEuro: Double? = null,
    trendLabel: String? = null,
    trendLabelColor: Color? = null,
    leadingIconRes: Int? = null,
    trailingIconRes: Int? = null,
    sparkline: List<Float> = emptyList(),
    sparklineDayLabels: List<Int> = emptyList(),
    edgeToEdgeSparkline: Boolean = false,
    panierEvolutionStyle: Boolean = false,
    googleReviewsFooter: Boolean = false,
) {
    val shape = RoundedCornerShape(MerchantDesignSystem.radiusKpiTile)
    Column(
        modifier
            .clip(shape)
            .background(palette.tileSurfaceLight)
            .border(1.dp, palette.onTilePrimary.copy(0.06f), shape)
            .then(if (blurred) Modifier.alpha(0.45f) else Modifier)
            .then(modifier),
    ) {
        Column(
            Modifier.padding(
                start = 14.dp,
                end = 14.dp,
                top = 12.dp,
                bottom = if ((edgeToEdgeSparkline && sparkline.isNotEmpty()) || googleReviewsFooter) 0.dp else 12.dp,
            ),
        ) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Row(
                    Modifier.weight(1f),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    leadingIconRes?.let { res ->
                        Image(
                            painter = painterResource(res),
                            contentDescription = null,
                            modifier = Modifier
                                .size(30.dp)
                                .shadow(4.dp, RoundedCornerShape(8.dp), spotColor = Color.Black.copy(0.10f))
                                .clip(RoundedCornerShape(8.dp)),
                            contentScale = ContentScale.Fit,
                        )
                    }
                    Text(
                        title,
                        color = palette.onTilePrimary.copy(0.84f),
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp,
                    )
                }
                trailingIconRes?.let { res ->
                    Image(
                        painter = painterResource(res),
                        contentDescription = null,
                        modifier = Modifier
                            .size(42.dp)
                            .shadow(6.dp, RoundedCornerShape(10.dp), spotColor = Color.Black.copy(0.12f))
                            .clip(RoundedCornerShape(10.dp)),
                        contentScale = ContentScale.Fit,
                    )
                }
            }
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
            trendEuro?.let { raw ->
                CommerceStatisticsDataBuilder.displayableTrendEuro(raw)?.let { delta ->
                    Text(
                        "+${"%.2f".format(java.util.Locale.FRANCE, delta)} €",
                        color = palette.kpiTrendGreen,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
            if (trendEuro == null) {
                trendLabel?.let { label ->
                    Text(
                        label,
                        color = trendLabelColor ?: palette.kpiTrendGreen,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
            if (!edgeToEdgeSparkline && sparkline.isNotEmpty()) {
                Spacer(Modifier.height(6.dp))
                MiniSparklineChart(
                    values = sparkline,
                    lineColor = palette.chartLine,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
        if (edgeToEdgeSparkline && sparkline.isNotEmpty()) {
            if (panierEvolutionStyle) {
                PanierEvolutionSparklineChart(
                    values = sparkline,
                    dayLabels = sparklineDayLabels,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(52.dp)
                        .clip(RoundedCornerShape(bottomStart = 22.dp, bottomEnd = 22.dp)),
                )
            } else {
                MiniSparklineChart(
                    values = sparkline,
                    lineColor = palette.chartLine,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(52.dp)
                        .clip(RoundedCornerShape(bottomStart = 22.dp, bottomEnd = 22.dp)),
                )
            }
        }
        if (googleReviewsFooter) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .height(34.dp)
                    .background(Color.Black)
                    .clip(RoundedCornerShape(bottomStart = 22.dp, bottomEnd = 22.dp))
                    .padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(Icons.Filled.Map, contentDescription = null, tint = Color.White, modifier = Modifier.size(14.dp))
                Text(
                    "Voir les avis",
                    color = Color.White,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f),
                )
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(16.dp),
                )
            }
        }
    }
}
