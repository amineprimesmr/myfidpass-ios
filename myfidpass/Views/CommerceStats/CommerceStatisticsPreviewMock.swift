//
//  CommerceStatisticsPreviewMock.swift
//  myfidpass
//
//  Données factices par mois civil (bouton « Démo 6 mois » + glissement mois par mois).
//

import Foundation

struct CommerceStatisticsPreviewMonthPayload {
    let stats: BusinessStatsResponse
    let evolution: [EvolutionWeekDTO]
}

enum CommerceStatisticsPreviewMock {
    static func payloadsByMonthKeys(_ keys: [String]) -> [String: CommerceStatisticsPreviewMonthPayload] {
        Dictionary(uniqueKeysWithValues: keys.enumerated().map { idx, key in
            (key, monthPayload(monthKey: key, indexFromNewest: idx))
        })
    }

    private static func monthPayload(monthKey: String, indexFromNewest: Int) -> CommerceStatisticsPreviewMonthPayload {
        let title = CommerceStatsMonthNavigator.displayTitle(forMonthKey: monthKey)
        let seed = max(1, 6 - indexFromNewest)
        let opsBase = 14 + indexFromNewest * 5
        let milestones = Array(1...8)
        let newInMonthCumulative = [2, 5, 9, 14, 18, 24, 31, 38].map { $0 + seed * 2 - indexFromNewest }
        let opsIntervals = [
            opsBase + seed,
            opsBase + seed + 2,
            opsBase + seed + 4,
            opsBase + seed + 3,
            opsBase + seed + 6,
            opsBase + seed * 2,
            opsBase + seed * 2 + 3,
            opsBase + seed + 7,
        ]
        let membersBase = 3_650 + (5 - indexFromNewest) * 48
        let basketBase = 18.2 + Double(indexFromNewest) * 0.6
        let basketTotals = [120.0, 248.0, 395.0, 510.0, 688.0, 842.0, 1015.0, 1188.0]
            .map { $0 + Double(indexFromNewest) * 42 }
        let evolution: [EvolutionWeekDTO] = milestones.enumerated().map { i, day in
            EvolutionWeekDTO(
                weekIndex: i,
                dayOfMonth: day,
                operationsCount: opsIntervals[i],
                membersCount: membersBase + max(0, newInMonthCumulative[i]),
                newMembersInMonth: max(0, newInMonthCumulative[i]),
                avgBasketEurInMonth: basketBase + Double(i) * 0.45,
                avgBasketEurInInterval: nil,
                basketTotalEurInMonth: basketTotals[i]
            )
        }

        let members = 3_920 - indexFromNewest * 62
        let newInMonth = 38 + seed * 4 - indexFromNewest * 3
        let active = 210 + seed * 12 - indexFromNewest * 8

        let rewardsBreakdown: [RewardRedeemedBreakdownRowDTO] = [
            RewardRedeemedBreakdownRowDTO(label: "Boisson offerte", count: 2 + seed / 2),
            RewardRedeemedBreakdownRowDTO(label: "Dessert au choix", count: 3 + seed / 3),
            RewardRedeemedBreakdownRowDTO(label: "Récompense tampons", count: 1),
        ]
        let socialFollows = SocialFollowsClaimedDTO(
            instagram: max(0, 7 - indexFromNewest * 1),
            tiktok: max(0, 4 - indexFromNewest),
            facebook: max(0, 3 - indexFromNewest),
            twitter: max(0, 2 - indexFromNewest / 2)
        )
        let campaigns: [NotificationCampaignInsightDTO] = indexFromNewest == 0 ? Self.paywallTeaserNotificationCampaigns : []
        let pointsAvg: Double = 95 + Double(seed) * 2.2
        let retention: Double = min(78, 52 + Double(seed) * 2.1)
        let avgVisits: Double = 2.1 + Double(seed) * 0.08
        let avgBasket: Double = 22.5 + Double(indexFromNewest) * 0.85
        let stats = BusinessStatsResponse(
            period: title,
            periodKey: monthKey,
            membersCount: members,
            pointsThisMonth: 2_200 + indexFromNewest * 160,
            transactionsThisMonth: 480 + indexFromNewest * 35,
            newMembersLast7Days: min(28, 8 + seed),
            newMembersLast30Days: min(120, 28 + seed * 5),
            newMembersInPeriod: max(0, newInMonth),
            inactiveMembers30Days: 88 + indexFromNewest * 5,
            inactiveMembers90Days: 260 + indexFromNewest * 12,
            pointsAveragePerMember: pointsAvg,
            activeMembersInPeriod: active,
            retentionPct: retention,
            recurrentMembersInPeriod: 42 + seed * 3,
            visitsInPeriod: 620 + indexFromNewest * 40,
            avgVisitsPerActiveMember: avgVisits,
            avgBasketEur: avgBasket,
            baselineAvgBasketEur: 20.0,
            rewardsRedeemedCount: 6 + seed,
            rewardsRedeemedBreakdown: rewardsBreakdown,
            pointsRedeemedInPeriod: 720 + indexFromNewest * 55,
            googleReviewsNewInPeriod: max(0, 4 - indexFromNewest / 2),
            socialFollowsClaimed: socialFollows,
            notificationCampaigns: campaigns,
            businessName: "Boutique démo"
        )

        return CommerceStatisticsPreviewMonthPayload(stats: stats, evolution: evolution)
    }

    /// Campagnes factices (aperçu impact + teaser avant abonnement payant).
    static let paywallTeaserNotificationCampaigns: [NotificationCampaignInsightDTO] = {
        [
            NotificationCampaignInsightDTO(
                batchId: "demo-batch-1",
                triggerName: "Réactivation week-end",
                createdAt: "2026-03-15T10:00:00.000Z",
                sentTotal: 480,
                recipientsDistinct: 480,
                returnedWithin48h: 62,
                notificationTitle: "C’est le week-end",
                message: "Venez retirer un café offert dès 15 € d’achat, ce samedi seulement.",
                sentPasskit: 300,
                sentWebPush: 180
            ),
            NotificationCampaignInsightDTO(
                batchId: "demo-batch-2",
                triggerName: "Happy hour café",
                createdAt: "2026-04-02T14:30:00.000Z",
                sentTotal: 320,
                recipientsDistinct: 320,
                returnedWithin48h: 41,
                notificationTitle: "Happy hour 17h",
                message: "−10 % sur les pâtisseries aujourd’hui après 17 h."
            ),
        ]
    }()
}
