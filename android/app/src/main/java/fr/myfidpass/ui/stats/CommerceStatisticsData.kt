package fr.myfidpass.ui.stats

import androidx.compose.ui.graphics.Color
import fr.myfidpass.data.dto.BusinessStatsResponse
import fr.myfidpass.data.dto.EvolutionWeekDto
import fr.myfidpass.data.dto.RewardsRedeemedBreakdownRow
import kotlin.math.abs
import kotlin.math.max

data class CommerceAudienceSplitData(
    val activeCount: Int,
    val inactiveCount: Int,
) {
    val total: Int get() = max(1, activeCount + inactiveCount)
    val activeFraction: Float get() = activeCount.toFloat() / total.toFloat()
}

data class CommercePointsAttributedDetail(
    val sparkline: List<Float>,
    val trendPct: Double?,
    val trendIsPositive: Boolean,
)

data class CommerceRewardUsedLineItem(
    val label: String,
    val count: Int,
    val shareRounded: Int,
    val trendPositive: Boolean,
)

data class CommerceRewardsUsedDetail(
    val items: List<CommerceRewardUsedLineItem>,
    val totalExchanges: Int,
)

data class CommerceSocialFollowsDetail(
    val networkId: String,
    val sparkline: List<Float>,
    val trendPct: Double? = null,
    val trendIsPositive: Boolean = true,
)

data class CommerceCategoryRowData(
    val id: String,
    val title: String,
    val subtitle: String,
    val rightPrimary: String,
    val rightSecondary: String = "",
    val swatch: Color,
    val audienceSplit: CommerceAudienceSplitData? = null,
    val pointsAttributedDetail: CommercePointsAttributedDetail? = null,
    val rewardsUsedDetail: CommerceRewardsUsedDetail? = null,
    val socialFollowsDetail: CommerceSocialFollowsDetail? = null,
    val googleReviewsCount: Int? = null,
)

data class CommerceStatisticsPresentation(
    val panierMoyenEuro: Double?,
    val panierRepereEuro: Double?,
    val frequenceParActif: Double?,
    val categoryRows: List<CommerceCategoryRowData>,
    val engagementRows: List<CommerceCategoryRowData>,
    val membersWeeklySparkline: List<Float>,
    val membersTotal: Int?,
)

object CommerceStatisticsDataBuilder {
    private val colorPts = Color(0xFF0066D9)
    private val colorAct = Color(0xFF30D158)
    private val colorRew = Color(0xFFFA6B6B)
    private val colorGoogle = Color(0xFF4285F4)

    fun build(
        stats: BusinessStatsResponse?,
        evolution: List<EvolutionWeekDto>,
        panierRepereEuro: Double? = null,
    ): CommerceStatisticsPresentation {
        val members = max(0, stats?.membersCount ?: 0)
        val inactive30Raw = max(0, stats?.inactiveMembers30Days ?: 0)
        val inactive30 = if (members > 0) minOf(members, inactive30Raw) else 0
        val active30 = if (members > 0) max(0, members - inactive30) else max(0, stats?.activeMembersInPeriod ?: 0)
        val ptsI = stats?.pointsThisMonth ?: 0
        val rewardsN = stats?.rewardsRedeemedCount ?: 0
        val rewardBreakdown = stats?.rewardsRedeemedBreakdown?.filter { it.count > 0 }.orEmpty()
        val googleRev = stats?.googleReviewsNewInPeriod ?: 0

        val opsSeries = evolution.map { it.operationsCount ?: 0 }
        val (ptsSpark, ptsTrend, ptsTrendPos) = pointsRowSparklineAndTrend(opsSeries)

        val indicatorRows = listOf(
            CommerceCategoryRowData(
                id = "audienceSplit",
                title = "Clients actifs / inactifs",
                subtitle = "Actif = au moins 1 passage · Inactif = 0",
                rightPrimary = "${formatPct(active30.toDouble() / max(1, members))} actifs",
                rightSecondary = "${formatPct(inactive30.toDouble() / max(1, members))} inactifs",
                swatch = colorAct,
                audienceSplit = CommerceAudienceSplitData(active30, inactive30),
            ),
            CommerceCategoryRowData(
                id = "pts",
                title = "Points attribués",
                subtitle = "Fidélité",
                rightPrimary = "+${formatInt(ptsI)}",
                rightSecondary = "",
                swatch = colorPts,
                pointsAttributedDetail = CommercePointsAttributedDetail(
                    sparkline = ptsSpark,
                    trendPct = ptsTrend,
                    trendIsPositive = ptsTrendPos,
                ),
            ),
            CommerceCategoryRowData(
                id = "rewards",
                title = "Récompenses utilisées",
                subtitle = "Sur la période",
                rightPrimary = formatInt(rewardsN),
                rightSecondary = "",
                swatch = colorRew,
                rewardsUsedDetail = rewardsUsedDetailFrom(rewardBreakdown, max(0, rewardsN)),
            ),
        )

        val googleRow = CommerceCategoryRowData(
            id = "grev",
            title = "Google",
            subtitle = "Clients ayant validé la mission avis",
            rightPrimary = "+${formatInt(googleRev)}",
            rightSecondary = "",
            swatch = colorGoogle,
            googleReviewsCount = max(0, googleRev),
        )

        val socialRows = stats?.socialFollowsClaimed?.let { sf ->
            listOf(
                socialNet("social-instagram", "Instagram", sf.instagram ?: 0, Color(0xFFE1306C)),
                socialNet("social-tiktok", "TikTok", sf.tiktok ?: 0, Color(0xFF25F4EE)),
                socialNet("social-facebook", "Facebook", sf.facebook ?: 0, Color(0xFF1877F2)),
                socialNet("social-twitter", "X", sf.twitter ?: 0, Color.Black),
            )
        }.orEmpty()

        val panier = stats?.avgBasketEur?.takeIf { it > 0 }
        val repere = (panierRepereEuro ?: stats?.baselineAvgBasketEur)?.takeIf { it > 0.009 }
        val freq = stats?.avgVisitsPerActiveMember?.takeIf { it > 0 }
            ?: if (active30 > 0 && (stats?.transactionsThisMonth ?: 0) > 0) {
                (stats?.transactionsThisMonth ?: 0).toDouble() / active30.toDouble()
            } else {
                null
            }

        return CommerceStatisticsPresentation(
            panierMoyenEuro = panier,
            panierRepereEuro = repere,
            frequenceParActif = freq,
            categoryRows = indicatorRows,
            engagementRows = listOf(googleRow) + socialRows,
            membersWeeklySparkline = normalizedMemberSparkline(evolution),
            membersTotal = members.takeIf { it > 0 },
        )
    }

    fun paywallTeaserMerge(
        real: CommerceStatisticsPresentation,
        mock: CommerceStatisticsPresentation,
    ): CommerceStatisticsPresentation = real.copy(
        panierMoyenEuro = mock.panierMoyenEuro,
        panierRepereEuro = mock.panierRepereEuro,
        frequenceParActif = mock.frequenceParActif,
        categoryRows = mock.categoryRows,
        engagementRows = mock.engagementRows,
    )

    private fun socialNet(id: String, label: String, count: Int, color: Color) =
        CommerceCategoryRowData(
            id = id,
            title = label,
            subtitle = "Nouveaux abonnés via mission",
            rightPrimary = "+${formatInt(count)}",
            swatch = color,
            socialFollowsDetail = CommerceSocialFollowsDetail(
                networkId = id,
                sparkline = syntheticSocialSparkline(count),
            ),
        )

    private fun rewardsUsedDetailFrom(
        breakdown: List<RewardsRedeemedBreakdownRow>,
        total: Int,
    ): CommerceRewardsUsedDetail {
        val items = breakdown.map { row ->
            val share = if (total > 0) ((row.count.toDouble() / total) * 100).toInt() else 0
            CommerceRewardUsedLineItem(
                label = row.label,
                count = row.count,
                shareRounded = share,
                trendPositive = share >= (100 / max(1, breakdown.size)),
            )
        }
        return CommerceRewardsUsedDetail(items, total)
    }

    private fun pointsRowSparklineAndTrend(opsSeries: List<Int>): Triple<List<Float>, Double?, Boolean> {
        if (opsSeries.size < 2) {
            val norm = normalizeSeries(opsSeries.map { it.toFloat() })
            return Triple(norm, null, true)
        }
        val norm = normalizeSeries(opsSeries.map { it.toFloat() })
        val a = opsSeries[opsSeries.size - 2].toDouble()
        val b = opsSeries.last().toDouble()
        val trend = if (a <= 0.0) null else ((b - a) / a) * 100.0
        return Triple(norm, trend, (trend ?: 0.0) >= 0)
    }

    private fun normalizedMemberSparkline(evolution: List<EvolutionWeekDto>): List<Float> {
        val raw = evolution.map { (it.membersCount ?: it.operationsCount ?: 0).toFloat() }
        return normalizeSeries(raw)
    }

    private fun syntheticSocialSparkline(total: Int): List<Float> {
        if (total <= 0) return List(8) { 0.12f }
        val base = total.coerceAtMost(20)
        return (0 until 8).map { i ->
            (base * (0.35f + i * 0.08f) / 20f).coerceIn(0.08f, 1f)
        }
    }

    private fun normalizeSeries(raw: List<Float>): List<Float> {
        if (raw.isEmpty()) return emptyList()
        val maxV = raw.maxOrNull()?.coerceAtLeast(1f) ?: 1f
        return raw.map { (it / maxV).coerceIn(0f, 1f) }
    }

    fun formatInt(n: Int): String = "%,d".format(java.util.Locale.FRANCE, n).replace('\u00A0', ' ')

    fun formatPct(ratio: Double): String = "${(ratio * 100).toInt()} %"

    fun formatEuro(v: Double): String = if (v % 1.0 < 0.05) v.toInt().toString() else "%.1f".format(v)
}
