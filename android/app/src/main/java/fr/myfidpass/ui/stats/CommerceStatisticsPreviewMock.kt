package fr.myfidpass.ui.stats

import fr.myfidpass.data.dto.BusinessStatsResponse
import fr.myfidpass.data.dto.EvolutionWeekDto
import fr.myfidpass.data.dto.NotificationCampaignInsightDto
import fr.myfidpass.data.dto.RewardsRedeemedBreakdownRow
import fr.myfidpass.data.dto.SocialFollowsClaimedDto
import fr.myfidpass.ui.components.CommerceStatsMonthPage

data class CommerceStatisticsPreviewMonthPayload(
    val stats: BusinessStatsResponse,
    val evolution: List<EvolutionWeekDto>,
)

/** Données démo par mois — aligné iOS `CommerceStatisticsPreviewMock`. */
object CommerceStatisticsPreviewMock {
    private val demoSparklines = listOf(
        listOf(0.12f, 0.18f, 0.22f, 0.28f, 0.35f, 0.42f, 0.48f, 0.55f),
        listOf(0.20f, 0.24f, 0.30f, 0.38f, 0.44f, 0.50f, 0.58f, 0.65f),
        listOf(0.15f, 0.22f, 0.28f, 0.32f, 0.40f, 0.46f, 0.52f, 0.60f),
        listOf(0.18f, 0.26f, 0.34f, 0.42f, 0.48f, 0.54f, 0.62f, 0.70f),
        listOf(0.10f, 0.16f, 0.24f, 0.30f, 0.36f, 0.44f, 0.50f, 0.58f),
        listOf(0.22f, 0.28f, 0.36f, 0.44f, 0.52f, 0.58f, 0.66f, 0.74f),
    )

    fun payloadsByMonthKeys(keys: List<String>): Map<String, CommerceStatisticsPreviewMonthPayload> =
        keys.mapIndexed { index, key -> key to monthPayload(key, index) }.toMap()

    fun monthPayload(monthKey: String, indexFromNewest: Int): CommerceStatisticsPreviewMonthPayload {
        val seed = maxOf(1, 6 - indexFromNewest)
        val opsBase = 14 + indexFromNewest * 5
        val milestones = listOf(1, 2, 3, 5, 6, 7, 8)
        val newInMonthCumulative = listOf(2, 7, 12, 18, 24, 31, 38).map { it + seed * 2 - indexFromNewest }
        val opsIntervals = listOf(
            opsBase + seed,
            opsBase + seed + 3,
            opsBase + seed + 5,
            opsBase + seed * 2,
            opsBase + seed + 4,
            opsBase + seed * 2 + 2,
            opsBase + seed + 6,
        )
        val membersBase = 3650 + (5 - indexFromNewest) * 48
        val basketBase = 18.2 + indexFromNewest * 0.6
        val basketTotals = listOf(120.0, 248.0, 395.0, 510.0, 688.0, 842.0, 1015.0, 1188.0)
            .map { it + indexFromNewest * 42.0 }
        val evolution = milestones.mapIndexed { i, day ->
            val newInMonth = maxOf(0, newInMonthCumulative[i])
            EvolutionWeekDto(
                weekIndex = i,
                dayOfMonth = day,
                operationsCount = opsIntervals[i],
                membersCount = membersBase + newInMonth,
                newMembersInMonth = newInMonth,
                avgBasketEurInMonth = basketBase + i * 0.45,
                basketTotalEurInMonth = basketTotals[i],
            )
        }
        val members = 3920 - indexFromNewest * 62
        val newInMonth = 38 + seed * 4 - indexFromNewest * 3
        val active = 210 + seed * 12 - indexFromNewest * 8
        val stats = BusinessStatsResponse(
            periodKey = monthKey,
            membersCount = members,
            pointsThisMonth = 2200 + indexFromNewest * 160,
            transactionsThisMonth = 480 + indexFromNewest * 35,
            newMembersLast7Days = minOf(28, 8 + seed),
            newMembersLast30Days = minOf(120, 28 + seed * 5),
            newMembersInPeriod = maxOf(0, newInMonth),
            inactiveMembers30Days = 88 + indexFromNewest * 5,
            activeMembersInPeriod = active,
            retentionPct = minOf(78.0, 52.0 + seed * 2.1),
            avgVisitsPerActiveMember = 2.1 + seed * 0.08,
            avgBasketEur = 22.5 + indexFromNewest * 0.85,
            baselineAvgBasketEur = 20.0,
            rewardsRedeemedCount = 6 + seed,
            rewardsRedeemedBreakdown = listOf(
                RewardsRedeemedBreakdownRow("Boisson offerte", 2 + seed / 2),
                RewardsRedeemedBreakdownRow("Dessert au choix", 3 + seed / 3),
                RewardsRedeemedBreakdownRow("Récompense tampons", 1),
            ),
            googleReviewsNewInPeriod = maxOf(0, 4 - indexFromNewest / 2),
            socialFollowsClaimed = SocialFollowsClaimedDto(
                instagram = maxOf(0, 7 - indexFromNewest),
                tiktok = maxOf(0, 4 - indexFromNewest),
                facebook = maxOf(0, 3 - indexFromNewest),
                twitter = maxOf(0, 2 - indexFromNewest / 2),
            ),
            notificationCampaigns = if (indexFromNewest == 0) paywallTeaserNotificationCampaigns else emptyList(),
        )
        return CommerceStatisticsPreviewMonthPayload(stats, evolution)
    }

    val paywallTeaserNotificationCampaigns: List<NotificationCampaignInsightDto> = listOf(
        NotificationCampaignInsightDto(
            batchId = "demo-batch-1",
            triggerName = "Réactivation week-end",
            createdAt = "2026-03-15T10:00:00.000Z",
            sentTotal = 480,
            recipientsDistinct = 480,
            returnedWithin48h = 62,
            notificationTitle = "C'est le week-end",
            message = "Venez retirer un café offert dès 15 € d'achat, ce samedi seulement.",
            sentPasskit = 300,
            sentWebPush = 180,
        ),
        NotificationCampaignInsightDto(
            batchId = "demo-batch-2",
            triggerName = "Happy hour café",
            createdAt = "2026-04-02T14:30:00.000Z",
            sentTotal = 320,
            recipientsDistinct = 320,
            returnedWithin48h = 41,
            notificationTitle = "Happy hour 17h",
            message = "−10 % sur les pâtisseries aujourd'hui après 17 h.",
        ),
    )

    fun mockPage(monthKey: String, index: Int): CommerceStatsMonthPage {
        val payload = monthPayload(monthKey, index)
        val s = payload.stats
        val pres = CommerceStatisticsDataBuilder.build(
            stats = s,
            evolution = payload.evolution,
        )
        return CommerceStatsMonthPage(
            monthKey = monthKey,
            membersCount = s.membersCount,
            newMembers = s.newMembersInPeriod ?: s.newMembersLast30Days,
            avgBasketEur = s.avgBasketEur,
            visitFrequency = s.avgVisitsPerActiveMember,
            googleReviewsNewInPeriod = s.googleReviewsNewInPeriod ?: 0,
            sparkline = pres.membersWeeklySparkline.ifEmpty { demoSparklines[index % demoSparklines.size] },
            monthAxisDays = pres.membersMonthAxisDays,
            panierSparkline = pres.panierWeeklySparkline,
            panierMonthAxisDays = pres.panierMonthAxisDays,
        )
    }
}
