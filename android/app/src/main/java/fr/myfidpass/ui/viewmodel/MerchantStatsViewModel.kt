package fr.myfidpass.ui.viewmodel

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import fr.myfidpass.data.dto.BusinessStatsResponse
import fr.myfidpass.data.dto.NotificationCampaignInsightDto
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.ui.components.CommerceStatsMonthPage
import fr.myfidpass.ui.stats.CommerceStatisticsDataBuilder
import fr.myfidpass.ui.stats.CommerceStatisticsPresentation
import fr.myfidpass.ui.stats.CommerceStatisticsPreviewMock
import fr.myfidpass.ui.stats.CommerceStatsMonthNavigator
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

data class StatsMonthSnapshot(
    val stats: BusinessStatsResponse,
    val evolution: fr.myfidpass.data.dto.DashboardEvolutionResponse,
)

class MerchantStatsViewModel(
    private val repository: DashboardRepository,
    private val sessionStore: SessionStore,
) : ViewModel() {

    var monthSnapshots by mutableStateOf<Map<String, StatsMonthSnapshot>>(emptyMap())
        private set
    var loading by mutableStateOf(false)
        private set
    var error by mutableStateOf<String?>(null)

    val baselinePanierRepereEuro: Double?
        get() {
            val keys = monthKeys()
            val key = keys.lastOrNull() ?: return null
            return monthSnapshots[key]?.stats?.baselineAvgBasketEur?.takeIf { it > 0.009 }
        }

    suspend fun savePanierRepere(value: Double?, clear: Boolean): Result<Unit> = runCatching {
        val slug = repository.currentSlug() ?: error("Commerce introuvable")
        val patch = buildJsonObject {
            if (clear) {
                put("baseline_avg_basket_eur", JsonNull)
            } else if (value != null) {
                put("baseline_avg_basket_eur", value)
            }
        }
        repository.patchDashboardSettings(slug, patch)
        load(force = true)
    }

    fun monthKeys(): List<String> {
        val slug = sessionStore.currentBusinessSlug
        val created = sessionStore.businesses.firstOrNull { it.slug == slug }?.createdAt
        return CommerceStatsMonthNavigator.monthKeys(created?.trim()?.take(7))
    }

    fun load(force: Boolean = false) {
        val slug = repository.currentSlug() ?: return
        if (!force && monthSnapshots.isNotEmpty()) return
        viewModelScope.launch {
            loading = true
            error = null
            runCatching {
                val keys = monthKeys()
                val loaded = coroutineScope {
                    keys.map { key ->
                        async {
                            key to runCatching {
                                val stats = repository.businessStats(slug, key)
                                val evolution = repository.businessEvolution(slug, weeks = 4, period = key)
                                StatsMonthSnapshot(stats, evolution)
                            }.getOrNull()
                        }
                    }.awaitAll().mapNotNull { (k, v) -> v?.let { k to it } }.toMap()
                }
                monthSnapshots = loaded
            }.onFailure { error = it.message }
            loading = false
        }
    }

    fun presentationForMonth(monthKey: String, insightsUnlocked: Boolean): CommerceStatisticsPresentation {
        val keys = monthKeys()
        val index = keys.indexOf(monthKey).coerceAtLeast(0)
        val snap = monthSnapshots[monthKey]
        val real = CommerceStatisticsDataBuilder.build(
            stats = snap?.stats,
            evolution = snap?.evolution?.evolution.orEmpty(),
            panierRepereEuro = snap?.stats?.baselineAvgBasketEur,
        )
        if (insightsUnlocked) return real
        val mockPayload = CommerceStatisticsPreviewMock.monthPayload(monthKey, index)
        val mock = CommerceStatisticsDataBuilder.build(
            stats = mockPayload.stats,
            evolution = mockPayload.evolution,
            panierRepereEuro = mockPayload.stats.baselineAvgBasketEur,
        )
        return CommerceStatisticsDataBuilder.paywallTeaserMerge(real, mock)
    }

    fun notificationCampaignsForMonth(monthKey: String, insightsUnlocked: Boolean): List<NotificationCampaignInsightDto> {
        if (insightsUnlocked) {
            return monthSnapshots[monthKey]?.stats?.notificationCampaigns.orEmpty()
        }
        val index = monthKeys().indexOf(monthKey).coerceAtLeast(0)
        return if (index == 0) {
            CommerceStatisticsPreviewMock.paywallTeaserNotificationCampaigns
        } else {
            emptyList()
        }
    }

    fun pages(): List<CommerceStatsMonthPage> {
        val keys = monthKeys()
        return keys.mapIndexed { index, key ->
            val snap = monthSnapshots[key]
            val stats = snap?.stats
            val realSpark = snap?.evolution?.evolution
                ?.map { (it.membersCount ?: it.operationsCount ?: 0).toFloat() }
                .orEmpty()
            val mock = CommerceStatisticsPreviewMock.mockPage(key, index)
            val real = CommerceStatisticsDataBuilder.build(
                stats = stats,
                evolution = snap?.evolution?.evolution.orEmpty(),
                panierRepereEuro = stats?.baselineAvgBasketEur,
            )

            CommerceStatsMonthPage(
                monthKey = key,
                membersCount = stats?.membersCount ?: mock.membersCount,
                newMembers = stats?.newMembersInPeriod ?: stats?.newMembersLast30Days ?: mock.newMembers,
                avgBasketEur = real.panierMoyenEuro ?: real.panierRepereEuro ?: mock.avgBasketEur,
                visitFrequency = real.frequenceParActif ?: mock.visitFrequency,
                sparkline = realSpark.ifEmpty { mock.sparkline },
                freqSparkline = snap?.evolution?.evolution
                    ?.map { (it.operationsCount ?: 0).toFloat() }
                    .orEmpty()
                    .let { raw ->
                        if (raw.isEmpty()) mock.sparkline else {
                            val maxV = raw.maxOrNull()?.coerceAtLeast(1f) ?: 1f
                            raw.map { (it / maxV).coerceIn(0f, 1f) }
                        }
                    },
            )
        }
    }
}
