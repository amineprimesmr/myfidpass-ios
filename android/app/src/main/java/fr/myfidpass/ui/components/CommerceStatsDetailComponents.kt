package fr.myfidpass.ui.components

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
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import android.os.Build
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
    onRowTap: ((String) -> Unit)? = null,
) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        rows.forEach { row ->
            when (row.id) {
                "audienceSplit" -> row.audienceSplit?.let { split ->
                    CommerceStatsAudienceCard(row, split, palette)
                }
                "pts" -> row.pointsAttributedDetail?.let { detail ->
                    CommerceStatsPointsCard(row, detail, palette)
                }
                "rewards" -> row.rewardsUsedDetail?.let { detail ->
                    CommerceStatsRewardsCard(row, detail, palette, onTap = { onRowTap?.invoke(row.id) })
                }
                "grev" -> CommerceStatsGoogleCard(row, palette)
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
        Text(row.subtitle, color = palette.secondaryLabel, fontSize = 13.sp)
        Spacer(Modifier.height(12.dp))
        Text(
            "${(split.activeFraction * 100).toInt()} %",
            fontSize = 36.sp,
            fontWeight = FontWeight.Bold,
        )
        Text("actifs", color = palette.secondaryLabel, fontSize = 13.sp)
        Spacer(Modifier.height(10.dp))
        Row(Modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(4.dp))) {
            val activeWeight = split.activeFraction.coerceIn(0.05f, 0.95f)
            Box(Modifier.weight(activeWeight).fillMaxWidth().height(8.dp).background(palette.kpiTrendGreen))
            Box(Modifier.weight(1f - activeWeight).fillMaxWidth().height(8.dp).background(Color(0xFFE5E7EB)))
        }
    }
}

@Composable
private fun CommerceStatsPointsCard(
    row: CommerceCategoryRowData,
    detail: fr.myfidpass.ui.stats.CommercePointsAttributedDetail,
    palette: CommerceStatsPalette,
) {
    StatsTileSurface {
        Text(row.title, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
        Text(row.subtitle, color = palette.secondaryLabel, fontSize = 13.sp)
        Spacer(Modifier.height(8.dp))
        Text(
            row.rightPrimary.removePrefix("+"),
            fontSize = 36.sp,
            fontWeight = FontWeight.Bold,
        )
        detail.trendPct?.let { t ->
            val sign = if (t >= 0) "+" else "−"
            Text("$sign${"%.0f".format(kotlin.math.abs(t))} %", color = palette.kpiTrendGreen, fontSize = 13.sp)
        }
        Spacer(Modifier.height(8.dp))
        MiniSparklineChart(detail.sparkline, lineColor = palette.accentBlue, modifier = Modifier.fillMaxWidth())
    }
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
        Text(row.subtitle, color = palette.secondaryLabel, fontSize = 13.sp)
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
private fun CommerceStatsGoogleCard(row: CommerceCategoryRowData, palette: CommerceStatsPalette) {
    StatsTileSurface {
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
    }
}

@Composable
private fun CommerceStatsSocialCard(
    row: CommerceCategoryRowData,
    detail: fr.myfidpass.ui.stats.CommerceSocialFollowsDetail,
    palette: CommerceStatsPalette,
) {
    StatsTileSurface {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(Color(0xFFF1F5F9)),
                contentAlignment = Alignment.Center,
            ) {
                Text(row.title.take(1), color = row.swatch, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(row.title, fontWeight = FontWeight.SemiBold)
                Text(row.subtitle, color = palette.secondaryLabel, fontSize = 13.sp)
            }
            Text(row.rightPrimary, fontWeight = FontWeight.Bold, fontSize = 28.sp)
        }
        Spacer(Modifier.height(12.dp))
        MiniSparklineChart(detail.sparkline, lineColor = row.swatch)
    }
}

@Composable
fun CommerceStatsNotificationImpactCard(
    campaigns: List<NotificationCampaignInsightDto>,
    palette: CommerceStatsPalette,
    modifier: Modifier = Modifier,
) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        campaigns.forEach { c ->
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
                    "Nombre d'ouvertures : ${c.returnedWithin48h ?: 0}",
                    fontSize = 13.sp,
                    color = palette.accentBlue,
                )
            }
        }
    }
}

@Composable
fun CommerceStatsConnectNetworksRow(
    subtitle: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(Color.White.copy(alpha = 0.94f))
            .border(1.dp, Color.Black.copy(alpha = 0.06f), RoundedCornerShape(18.dp))
            .clickable(onClick = onClick)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text("Connecter vos réseaux", fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
            Text(subtitle, color = Color.Black.copy(alpha = 0.55f), fontSize = 13.sp, maxLines = 2)
        }
        Icon(Icons.Outlined.ChevronRight, contentDescription = null, tint = Color.Black.copy(alpha = 0.35f))
    }
}

private fun Modifier.commerceStatsBlur(radius: androidx.compose.ui.unit.Dp): Modifier =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        blur(radius)
    } else {
        alpha(0.52f)
    }
