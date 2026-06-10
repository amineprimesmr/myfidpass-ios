package fr.myfidpass.ui.stats

import androidx.compose.ui.graphics.Color
import fr.myfidpass.data.dto.BusinessStatsResponse
import fr.myfidpass.data.dto.EvolutionWeekDto
import fr.myfidpass.data.dto.RewardsRedeemedBreakdownRow
import fr.myfidpass.ui.theme.CommerceStatsLightEmbedded
import kotlin.math.abs
import kotlin.math.max

data class CommerceAudienceSplitData(
    val activeCount: Int,
    val inactiveCount: Int,
) {
    val total: Int get() = max(1, activeCount + inactiveCount)
    val activeFraction: Float get() = activeCount.toFloat() / total.toFloat()
    val inactiveFraction: Float get() = inactiveCount.toFloat() / total.toFloat()
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

data class CommerceVisitFrequencyDetail(
    val sparkline: List<Float>,
    val trendPct: Double?,
    val trendIsPositive: Boolean,
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
    val visitFrequencyDetail: CommerceVisitFrequencyDetail? = null,
    val googleReviewsCount: Int? = null,
)

data class CommerceStatisticsPresentation(
    val panierMoyenEuro: Double?,
    val panierRepereEuro: Double?,
    val frequenceParActif: Double?,
    val googleReviewsNewInPeriod: Int = 0,
    val categoryRows: List<CommerceCategoryRowData>,
    val engagementRows: List<CommerceCategoryRowData>,
    val membersWeeklySparkline: List<Float>,
    val membersMonthAxisDays: List<Int> = emptyList(),
    val panierWeeklySparkline: List<Float> = emptyList(),
    val panierMonthAxisDays: List<Int> = emptyList(),
    val membersTotal: Int?,
)

object CommerceStatisticsDataBuilder {
    private val colorPts = Color(0xFF0066D9)
    private val colorAct = CommerceStatsLightEmbedded.brandGreen
    private val colorRew = Color(0xFFFA6B6B)
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
        val freqSpark = normalizeSeries(opsSeries.map { it.toFloat() })
        val (_, freqTrend, freqTrendPos) = pointsRowSparklineAndTrend(opsSeries)

        val indicatorRows = listOf(
            CommerceCategoryRowData(
                id = "audienceSplit",
                title = "Activité client (+1 visite /mois)",
                subtitle = "",
                rightPrimary = "${formatInt(active30)} actifs",
                rightSecondary = "${formatInt(inactive30)} inactifs",
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
                subtitle = "",
                rightPrimary = formatInt(rewardsN),
                rightSecondary = "",
                swatch = colorRew,
                rewardsUsedDetail = rewardsUsedDetailFrom(rewardBreakdown, max(0, rewardsN)),
            ),
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
        val freq = resolvedPurchaseFrequency(
            stats = stats,
            activeMembers = active30,
            transactionsInPeriod = stats?.transactionsThisMonth ?: 0,
        )

        val freqValueText = freq?.takeIf { it >= 1 }?.let { f ->
            val formatted = if (kotlin.math.abs(f - f.toLong().toDouble()) < 0.05) {
                f.toLong().toString()
            } else {
                "%.1f".format(java.util.Locale.FRANCE, f)
            }
            "$formatted visites"
        } ?: "—"

        val frequencyRow = CommerceCategoryRowData(
            id = "freq",
            title = "Fréquence d'achat",
            subtitle = "/mois",
            rightPrimary = freqValueText,
            rightSecondary = "",
            swatch = colorPts,
            visitFrequencyDetail = CommerceVisitFrequencyDetail(
                sparkline = freqSpark,
                trendPct = freqTrend,
                trendIsPositive = freqTrendPos,
            ),
        )

        return CommerceStatisticsPresentation(
            panierMoyenEuro = panier,
            panierRepereEuro = repere,
            frequenceParActif = freq,
            googleReviewsNewInPeriod = max(0, googleRev),
            categoryRows = listOf(frequencyRow) + indicatorRows,
            engagementRows = socialRows,
            membersWeeklySparkline = normalizedMemberSparkline(evolution),
            membersMonthAxisDays = memberMonthAxisDays(evolution),
            panierWeeklySparkline = normalizedPanierSparkline(evolution),
            panierMonthAxisDays = memberMonthAxisDays(evolution),
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
        googleReviewsNewInPeriod = mock.googleReviewsNewInPeriod,
        categoryRows = mock.categoryRows,
        engagementRows = mock.engagementRows,
        panierWeeklySparkline = mock.panierWeeklySparkline,
        panierMonthAxisDays = mock.panierMonthAxisDays,
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

    /** Évite −100 % quand le dernier jalon du mois en cours n’a pas encore d’opérations. */
    private fun operationsTrendPair(opsSeries: List<Int>): Pair<Int, Int>? {
        if (opsSeries.size < 2) return null
        if (opsSeries.size >= 3 && opsSeries.last() == 0) {
            return opsSeries[opsSeries.size - 2] to opsSeries[opsSeries.size - 3]
        }
        return opsSeries.last() to opsSeries[opsSeries.size - 2]
    }

    private fun pointsRowSparklineAndTrend(opsSeries: List<Int>): Triple<List<Float>, Double?, Boolean> {
        val norm = normalizeSeries(opsSeries.map { it.toFloat() })
        val pair = operationsTrendPair(opsSeries)
        val trend = pair?.let { (last, prev) ->
            if (prev <= 0 || last <= 0) null else ((last - prev).toDouble() / prev) * 100.0
        }
        return Triple(norm, trend, (trend ?: 0.0) >= 0)
    }

    private val membersMonthMilestoneCount = 7
    private val membersMonthSparklineFloor = 0.06f

    private fun normalizedMemberSparkline(evolution: List<EvolutionWeekDto>): List<Float> {
        if (evolution.isEmpty()) return emptyList()

        val hasMonthSeries = evolution.any { it.newMembersInMonth != null && it.dayOfMonth != null }
        val raw = if (hasMonthSeries) {
            evolution.map { max(0, it.newMembersInMonth ?: 0).toFloat() }
        } else {
            val cumulative = evolution.map { (it.membersCount ?: it.operationsCount ?: 0).toFloat() }
            val baseline = cumulative.firstOrNull() ?: 0f
            cumulative.map { max(0f, it - baseline) }
        }
        return sparklineFromMonthGrowth(raw)
    }

    private fun memberMonthAxisDays(evolution: List<EvolutionWeekDto>): List<Int> {
        val days = evolution.mapNotNull { it.dayOfMonth }.filter { it > 0 }
        return days.ifEmpty { listOf(1, 5, 10, 15, 20, 25, 30) }
    }

    private fun normalizedPanierSparkline(evolution: List<EvolutionWeekDto>): List<Float> {
        if (evolution.isEmpty()) return emptyList()
        var cumulative = 0f
        val raw = evolution.map { point ->
            val total = point.basketTotalEurInMonth
            if (total != null && total > 0) return@map total.toFloat()
            val unit = point.avgBasketEurInInterval ?: point.avgBasketEurInMonth ?: 0.0
            val ops = max(0, point.operationsCount ?: 0)
            if (unit > 0 && ops > 0) {
                cumulative += unit.toFloat() * ops.toFloat()
            }
            cumulative
        }
        val maxTotal = raw.maxOrNull() ?: 0f
        if (maxTotal <= 0f) {
            return List(maxOf(evolution.size, membersMonthMilestoneCount)) { membersMonthSparklineFloor }
        }
        return raw.map { v ->
            if (v <= 0f) membersMonthSparklineFloor
            else (membersMonthSparklineFloor + 0.08f + (v / maxTotal) * 0.9f).coerceAtMost(1f)
        }
    }

    private fun sparklineFromMonthGrowth(raw: List<Float>): List<Float> {
        if (raw.isEmpty()) return emptyList()
        val monotonic = raw.toMutableList()
        for (i in 1 until monotonic.size) {
            if (monotonic[i] < monotonic[i - 1]) monotonic[i] = monotonic[i - 1]
        }
        val maxV = monotonic.maxOrNull()?.coerceAtLeast(0f) ?: 0f
        if (maxV < 1e-4f) {
            return List(maxOf(monotonic.size, membersMonthMilestoneCount)) { membersMonthSparklineFloor }
        }
        return monotonic.map { v ->
            (v / maxV).coerceIn(membersMonthSparklineFloor, 1f)
        }
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

    /** Moyenne de passages par membre acheteur — jamais &lt; 1 quand il y a des passages. */
    fun resolvedPurchaseFrequency(
        stats: fr.myfidpass.data.dto.BusinessStatsResponse?,
        activeMembers: Int,
        transactionsInPeriod: Int,
    ): Double? {
        stats?.avgVisitsPerActiveMember?.takeIf { it > 0 }?.let { return maxOf(1.0, it) }
        val visits = stats?.visitsInPeriod ?: transactionsInPeriod
        if (visits <= 0) return null
        val active = stats?.activeMembersInPeriod?.takeIf { it > 0 } ?: activeMembers.takeIf { it > 0 }
        return active?.let { maxOf(1.0, visits.toDouble() / it.toDouble()) }
    }
}
