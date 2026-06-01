package fr.myfidpass.ui.screens.stats

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.data.dto.BusinessStatsResponse
import fr.myfidpass.data.dto.DashboardEvolutionResponse
import fr.myfidpass.ui.components.MiniBarChart
import fr.myfidpass.ui.components.MiniSparklineChart
import fr.myfidpass.ui.stats.CommerceStatisticDetailTopic
import fr.myfidpass.ui.stats.CommerceStatsMonthNavigator
import fr.myfidpass.ui.theme.CommerceStatsLightEmbedded

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MerchantStatisticDetailSheet(
    topic: CommerceStatisticDetailTopic,
    monthKey: String,
    stats: BusinessStatsResponse?,
    evolution: DashboardEvolutionResponse?,
    onDismiss: () -> Unit,
) {
    val palette = CommerceStatsLightEmbedded
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val chartValues = topic.chartValues(evolution?.evolution.orEmpty())
    val trend = weekOverWeekTrend(chartValues)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = palette.tileSurfaceLight,
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp),
        ) {
            Row(Modifier.fillMaxWidth()) {
                IconButton(onClick = onDismiss) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Fermer")
                }
                Text(
                    CommerceStatsMonthNavigator.displayTitle(monthKey),
                    modifier = Modifier.padding(top = 12.dp),
                    color = palette.secondaryLabel,
                    fontSize = 14.sp,
                )
            }
            Text(
                topic.screenTitle,
                fontWeight = FontWeight.SemiBold,
                fontSize = 22.sp,
                color = palette.pageTitle,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                topic.primaryMetric(stats),
                fontWeight = FontWeight.Bold,
                fontSize = 40.sp,
                color = palette.onTilePrimary,
            )
            trend?.let { (arrow, text, favorable) ->
                Spacer(Modifier.height(6.dp))
                Text(
                    "$arrow $text · ${CommerceStatsMonthNavigator.displayTitleMonthOnly(monthKey)}",
                    color = if (favorable) palette.kpiTrendGreen else palette.negative,
                    fontWeight = FontWeight.Medium,
                    fontSize = 15.sp,
                )
            }
            Spacer(Modifier.height(20.dp))
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(18.dp))
                    .background(palette.canvasEmbedded)
                    .padding(16.dp),
            ) {
                if (chartValues.size >= 4) {
                    MiniBarChart(values = chartValues, barColor = palette.chartLine)
                } else if (chartValues.isNotEmpty()) {
                    MiniSparklineChart(values = chartValues, lineColor = palette.chartLine)
                }
                Spacer(Modifier.height(10.dp))
                Text(topic.chartFootnote, fontSize = 13.sp, color = palette.secondaryLabel)
            }
        }
    }
}

private fun weekOverWeekTrend(values: List<Float>): Triple<String, String, Boolean>? {
    if (values.size < 2) return null
    val last = values.last()
    val prev = values[values.size - 2]
    if (prev <= 0f) return null
    val pct = ((last - prev) / prev) * 100f
    val favorable = last >= prev
    val arrow = if (favorable) "▲" else "▼"
    return Triple(arrow, "%.0f %%".format(kotlin.math.abs(pct)), favorable)
}
