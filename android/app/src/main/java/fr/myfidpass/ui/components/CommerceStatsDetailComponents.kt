package fr.myfidpass.ui.components

import androidx.compose.foundation.Image
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import android.os.Build
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.R
import fr.myfidpass.data.dto.NotificationCampaignInsightDto
import fr.myfidpass.ui.stats.CommerceCategoryRowData
import fr.myfidpass.ui.stats.CommerceStatisticsDataBuilder
import fr.myfidpass.ui.theme.CommerceStatsPalette
import fr.myfidpass.ui.theme.MerchantDesignSystem

@Composable
fun CommerceStatsProUnlockOverlay(
    locked: Boolean,
    onUnlock: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Box(modifier) {
        Box(
            Modifier
                .then(
                    if (locked) {
                        Modifier
                            .commerceStatsBlur(5.dp)
                    } else {
                        Modifier
                    },
                ),
        ) {
            content()
        }
        if (locked) {
            Box(
                Modifier
                    .matchParentSize()
                    .background(Color.Black.copy(alpha = 0.04f)),
            )
            CommerceStatsProUnlockButton(
                onClick = onUnlock,
                modifier = Modifier.align(Alignment.Center),
            )
        }
    }
}

@Composable
fun CommerceStatsProUnlockButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier
            .clip(RoundedCornerShape(50))
            .background(Color.White)
            .border(1.dp, Color.Black.copy(alpha = 0.08f), RoundedCornerShape(50))
            .clickable(onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Default.Lock, contentDescription = null, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(8.dp))
        Text("Déverrouiller avec Pro", fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
    }
}

@Composable
fun CommerceStatsSectionHeader(title: String, modifier: Modifier = Modifier) {
    Text(
        title,
        modifier = modifier,
        fontSize = 18.sp,
        fontWeight = FontWeight.Bold,
        color = Color.Black,
    )
}

@Composable
fun CommerceStatsCategoryListCard(
    rows: List<CommerceCategoryRowData>,
    palette: CommerceStatsPalette,
    modifier: Modifier = Modifier,
    onViewGoogleReviews: (() -> Unit)? = null,
    onRowTap: ((String) -> Unit)? = null,
) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        rows.forEach { row ->
            when (row.id) {
                "audienceSplit" -> row.audienceSplit?.let { split ->
                    CommerceStatsAudienceCard(row, split, palette)
                }
                "freq" -> row.visitFrequencyDetail?.let { detail ->
                    CommerceStatsFrequencyCard(row, detail, palette)
                }
                "pts" -> row.pointsAttributedDetail?.let { detail ->
                    CommerceStatsPointsCard(row, detail, palette)
                }
                "rewards" -> row.rewardsUsedDetail?.let { detail ->
                    CommerceStatsRewardsCard(row, detail, palette, onTap = { onRowTap?.invoke(row.id) })
                }
                "grev" -> CommerceStatsGoogleCard(row, palette, onViewReviews = onViewGoogleReviews)
                else -> if (row.id.startsWith("social-")) {
                    row.socialFollowsDetail?.let { CommerceStatsSocialCard(row, it, palette) }
                }
            }
        }
    }
}

@Composable
private fun StatsTileSurface(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Column(
        modifier
            .fillMaxWidth()
            .height(200.dp)
            .clip(RoundedCornerShape(MerchantDesignSystem.radiusKpiTile))
            .background(Color.White.copy(alpha = 0.94f))
            .border(1.dp, Color.Black.copy(alpha = 0.06f), RoundedCornerShape(MerchantDesignSystem.radiusKpiTile))
            .padding(16.dp),
    ) {
        content()
    }
}

@Composable
private fun CommerceStatsAudienceCard(
    row: CommerceCategoryRowData,
    split: fr.myfidpass.ui.stats.CommerceAudienceSplitData,
    palette: CommerceStatsPalette,
) {
    StatsTileSurface {
        Text(row.title, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
        Spacer(Modifier.height(14.dp))
        audienceMetricLine("Clients actifs", split.activeCount, split.activeFraction, palette.kpiTrendGreen)
        Spacer(Modifier.height(10.dp))
        audienceMetricLine("Clients inactifs", split.inactiveCount, split.inactiveFraction, Color(0xFFFA6B6B))
    }
}

@Composable
private fun audienceMetricLine(
    label: String,
    count: Int,
    fraction: Float,
    tint: Color,
) {
    Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(label, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color.Black.copy(alpha = 0.55f))
            Spacer(Modifier.weight(1f))
            Text(
                CommerceStatisticsDataBuilder.formatInt(count),
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                " ${(fraction * 100).toInt()} %",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = tint,
            )
        }
        Box(
            Modifier
                .fillMaxWidth()
                .height(8.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(Color.Black.copy(alpha = 0.06f)),
        ) {
            Box(
                Modifier
                    .fillMaxWidth(fraction.coerceIn(0.05f, 1f))
                    .height(8.dp)
                    .background(tint),
            )
        }
    }
}

@Composable
private fun CommerceStatsLargeMetricTile(
    title: String,
    subtitle: String,
    value: String,
    sparkline: List<Float>,
    palette: CommerceStatsPalette,
    chartLineColor: Color = palette.accentBlue,
    headerIconRes: Int? = null,
    trendPct: Double? = null,
) {
    val shape = RoundedCornerShape(MerchantDesignSystem.radiusKpiTile)
    val hasSparkline = sparkline.isNotEmpty()
    Column(
        Modifier
            .fillMaxWidth()
            .height(200.dp)
            .clip(shape)
            .background(Color.White.copy(alpha = 0.94f))
            .border(1.dp, Color.Black.copy(alpha = 0.06f), shape),
    ) {
        Column(
            Modifier.padding(
                start = 18.dp,
                end = 16.dp,
                top = 16.dp,
                bottom = if (hasSparkline) 0.dp else 14.dp,
            ),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                headerIconRes?.let { iconRes ->
                    Image(
                        painter = painterResource(iconRes),
                        contentDescription = null,
                        modifier = Modifier
                            .size(30.dp)
                            .clip(RoundedCornerShape(7.dp)),
                    )
                    Spacer(Modifier.width(10.dp))
                }
                Text(title, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
            }
            Text(
                value.removePrefix("+"),
                fontSize = 30.sp,
                fontWeight = FontWeight.Bold,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                if (subtitle.isNotEmpty()) {
                    Text(
                        subtitle,
                        color = chartLineColor,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
                trendPct?.let { t ->
                    val sign = if (t >= 0) "+" else "−"
                    Text(
                        "$sign${"%.1f".format(java.util.Locale.FRANCE, kotlin.math.abs(t))} %",
                        color = chartLineColor,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }
        if (hasSparkline) {
            Spacer(Modifier.weight(1f))
            MiniSparklineChart(
                values = sparkline,
                lineColor = chartLineColor,
                fillColor = chartLineColor.copy(alpha = 0.22f),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(104.dp)
                    .clip(RoundedCornerShape(bottomStart = 22.dp, bottomEnd = 22.dp)),
            )
        }
    }
}

@Composable
private fun CommerceStatsFrequencyCard(
    row: CommerceCategoryRowData,
    detail: fr.myfidpass.ui.stats.CommerceVisitFrequencyDetail,
    palette: CommerceStatsPalette,
) {
    val value = row.rightPrimary.removeSuffix(" visites")
    CommerceStatsLargeMetricTile(
        title = row.title,
        subtitle = row.subtitle,
        value = value,
        sparkline = detail.sparkline,
        palette = palette,
        chartLineColor = palette.accentBlue,
        trendPct = detail.trendPct,
    )
}

@Composable
private fun CommerceStatsPointsCard(
    row: CommerceCategoryRowData,
    detail: fr.myfidpass.ui.stats.CommercePointsAttributedDetail,
    palette: CommerceStatsPalette,
) {
    CommerceStatsLargeMetricTile(
        title = row.title,
        subtitle = row.subtitle,
        value = row.rightPrimary,
        sparkline = detail.sparkline,
        palette = palette,
        chartLineColor = palette.accentBlue,
        trendPct = detail.trendPct,
    )
}

@Composable
private fun CommerceStatsRewardsCard(
    row: CommerceCategoryRowData,
    detail: fr.myfidpass.ui.stats.CommerceRewardsUsedDetail,
    palette: CommerceStatsPalette,
    onTap: () -> Unit,
) {
    StatsTileSurface(Modifier.clickable(onClick = onTap)) {
        Text(row.title, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
        if (row.subtitle.isNotEmpty()) {
            Text(row.subtitle, color = palette.secondaryLabel, fontSize = 13.sp)
        }
        Spacer(Modifier.height(10.dp))
        detail.items.take(3).forEach { item ->
            Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    CommerceStatisticsDataBuilder.formatInt(item.count),
                    fontWeight = FontWeight.Bold,
                    fontSize = 22.sp,
                    modifier = Modifier.width(36.dp),
                )
                Text(item.label, fontSize = 14.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

@Composable
private fun CommerceStatsGoogleCard(
    row: CommerceCategoryRowData,
    palette: CommerceStatsPalette,
    onViewReviews: (() -> Unit)? = null,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(MerchantDesignSystem.radiusKpiTile))
            .background(Color.White.copy(alpha = 0.94f))
            .border(1.dp, Color.Black.copy(alpha = 0.06f), RoundedCornerShape(MerchantDesignSystem.radiusKpiTile))
            .padding(16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(Color(0xFFF1F5F9)),
                contentAlignment = Alignment.Center,
            ) {
                Text("G", color = row.swatch, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(row.title, fontWeight = FontWeight.SemiBold)
                Text(row.subtitle, color = palette.secondaryLabel, fontSize = 13.sp)
            }
            Text(row.rightPrimary, fontWeight = FontWeight.Bold, fontSize = 28.sp)
        }
        Spacer(Modifier.height(12.dp))
        MiniSparklineChart(
            listOf(0.2f, 0.35f, 0.42f, 0.55f, 0.62f, 0.7f),
            lineColor = row.swatch,
        )
        if (onViewReviews != null) {
            Spacer(Modifier.height(12.dp))
            Button(
                onClick = onViewReviews,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.Black,
                    contentColor = Color.White,
                ),
            ) {
                Text("Voir les avis", fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun CommerceStatsSocialCard(
    row: CommerceCategoryRowData,
    detail: fr.myfidpass.ui.stats.CommerceSocialFollowsDetail,
    palette: CommerceStatsPalette,
) {
    CommerceStatsLargeMetricTile(
        title = row.title,
        subtitle = row.subtitle,
        value = row.rightPrimary,
        sparkline = detail.sparkline,
        palette = palette,
        chartLineColor = row.swatch,
        headerIconRes = commerceStatsSocialIconRes(detail.networkId),
        trendPct = detail.trendPct,
    )
}

private fun commerceStatsSocialIconRes(networkId: String): Int? = when (networkId) {
    "social-instagram" -> R.drawable.social_instagram
    "social-tiktok" -> R.drawable.social_tiktok
    "social-facebook" -> R.drawable.social_facebook
    "social-twitter" -> R.drawable.social_x
    else -> null
}

@Composable
fun CommerceStatsNotificationImpactCard(
    campaigns: List<NotificationCampaignInsightDto>,
    palette: CommerceStatsPalette,
    modifier: Modifier = Modifier,
) {
    var showsAll by remember { mutableStateOf(false) }
    val collapsedCount = 2
    val visible = if (showsAll || campaigns.size <= collapsedCount) {
        campaigns
    } else {
        campaigns.take(collapsedCount)
    }
    val hiddenCount = (campaigns.size - collapsedCount).coerceAtLeast(0)

    Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        visible.forEach { c ->
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(18.dp))
                    .background(Color.White.copy(alpha = 0.94f))
                    .border(1.dp, Color.Black.copy(alpha = 0.06f), RoundedCornerShape(18.dp))
                    .padding(16.dp),
            ) {
                Text(
                    c.notificationTitle ?: c.title ?: c.triggerName ?: "Notification",
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 16.sp,
                )
                c.message?.let {
                    Text(it, color = palette.secondaryLabel, fontSize = 13.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
                }
                Spacer(Modifier.height(8.dp))
                Text(
                    "Membres touchés : ${c.confirmedRecipientsCount}",
                    fontSize = 13.sp,
                    color = palette.accentBlue,
                )
            }
        }
        if (!showsAll && hiddenCount > 0) {
            TextButton(onClick = { showsAll = true }) {
                Text("Voir plus ($hiddenCount)", color = palette.secondaryLabel, fontSize = 13.sp)
            }
        } else if (showsAll && campaigns.size > collapsedCount) {
            TextButton(onClick = { showsAll = false }) {
                Text("Voir moins", color = palette.secondaryLabel, fontSize = 13.sp)
            }
        }
    }
}

private data class CommerceStatsSocialIcon(
    val id: String,
    val drawable: Int,
    val cornerRadiusDp: Float,
)

private val commerceStatsAllSocialIcons = listOf(
    CommerceStatsSocialIcon("instagram", R.drawable.social_instagram, 0f),
    CommerceStatsSocialIcon("tiktok", R.drawable.social_tiktok, 0f),
    CommerceStatsSocialIcon("facebook", R.drawable.social_facebook, 0f),
    CommerceStatsSocialIcon("twitter", R.drawable.social_x, 7f),
)

@Composable
fun CommerceStatsConnectNetworksRow(
    subtitle: String,
    connectedNetworkIds: Set<String> = emptySet(),
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val pendingIcons = commerceStatsAllSocialIcons.filter { it.id !in connectedNetworkIds }
    Column(
        modifier
            .fillMaxWidth()
            .shadow(10.dp, RoundedCornerShape(26.dp), spotColor = Color.Black.copy(0.07f))
            .clip(RoundedCornerShape(26.dp))
            .background(Color.White)
            .clickable(onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        if (pendingIcons.isNotEmpty()) {
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                pendingIcons.forEach { icon ->
                    Image(
                        painter = painterResource(icon.drawable),
                        contentDescription = null,
                        modifier = Modifier
                            .size(30.dp)
                            .clip(RoundedCornerShape(icon.cornerRadiusDp.dp)),
                        contentScale = ContentScale.Fit,
                    )
                }
            }
        }
        Text(subtitle, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, color = Color(0xFF141518))
        Text(
            "Connecter mes réseaux",
            fontWeight = FontWeight.Bold,
            fontSize = 16.sp,
            color = Color.White,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(Color.Black)
                .padding(vertical = 15.dp),
            textAlign = TextAlign.Center,
        )
    }
}

private fun Modifier.commerceStatsBlur(radius: androidx.compose.ui.unit.Dp): Modifier =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        blur(radius)
    } else {
        alpha(0.52f)
    }
