package fr.myfidpass.ui.viewmodel

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import fr.myfidpass.data.dto.BusinessStatsResponse
import fr.myfidpass.data.dto.NotificationCampaignInsightDto
import fr.myfidpass.data.local.NotificationSendLocalHistoryStore
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.repo.DashboardRepository
import android.content.Context
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
    var notificationCampaignsFromStatsEndpoint by mutableStateOf<List<NotificationCampaignInsightDto>>(emptyList())
        private set
    var loading by mutableStateOf(false)
        private set
    var error by mutableStateOf<String?>(null)

    private var scopedBusinessSlug: String? = null

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
        return CommerceStatsMonthNavigator.monthKeys(created)
    }

    fun resetForBusinessSwitch(slug: String?) {
        val clean = slug?.trim().orEmpty()
        if (clean.isEmpty()) {
            scopedBusinessSlug = null
            monthSnapshots = emptyMap()
            notificationCampaignsFromStatsEndpoint = emptyList()
            error = null
            return
        }
        if (scopedBusinessSlug == clean) return
        val switchingFromAnother = scopedBusinessSlug != null
        scopedBusinessSlug = clean
        if (!switchingFromAnother) return
        monthSnapshots = emptyMap()
        notificationCampaignsFromStatsEndpoint = emptyList()
        error = null
    }

    fun load(force: Boolean = false) {
        val slug = repository.currentSlug() ?: return
        val slugChanged = scopedBusinessSlug != slug
        if (slugChanged) resetForBusinessSwitch(slug)
        if (!force && !slugChanged && monthSnapshots.isNotEmpty() && notificationCampaignsFromStatsEndpoint.isNotEmpty()) return
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
                notificationCampaignsFromStatsEndpoint = repository.notificationCampaignsFromStats(slug)
                    .filter { !it.isDeliveryPending }
            }.onFailure { error = it.message }
            loading = false
        }
    }

    fun refreshNotificationStats(context: Context) {
        val slug = repository.currentSlug() ?: return
        viewModelScope.launch {
            runCatching {
                notificationCampaignsFromStatsEndpoint = repository.notificationCampaignsFromStats(slug)
                    .filter { !it.isDeliveryPending }
            }
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

    fun notificationCampaignsForMonth(
        monthKey: String,
        insightsUnlocked: Boolean,
        context: Context? = null,
    ): List<NotificationCampaignInsightDto> {
        if (!insightsUnlocked) {
            val index = monthKeys().indexOf(monthKey).coerceAtLeast(0)
            return if (index == 0) {
                CommerceStatisticsPreviewMock.paywallTeaserNotificationCampaigns
            } else {
                emptyList()
            }
        }
        val slug = repository.currentSlug().orEmpty()
        val byId = linkedMapOf<String, NotificationCampaignInsightDto>()
        monthSnapshots[monthKey]?.stats?.notificationCampaigns.orEmpty()
            .filter { !it.isDeliveryPending }
            .forEach { byId[it.batchId] = it }
        notificationCampaignsFromStatsEndpoint
            .filter { campaignMatchesMonthKey(it, monthKey) && !it.isDeliveryPending }
            .forEach { c ->
                val existing = byId[c.batchId]
                byId[c.batchId] = existing?.let { mergeCampaign(it, c) } ?: c
            }
        if (context != null && slug.isNotEmpty()) {
            NotificationSendLocalHistoryStore.asCampaignInsights(
                NotificationSendLocalHistoryStore.entries(context, slug),
            )
                .filter { campaignMatchesMonthKey(it, monthKey) }
                .forEach { local ->
                    if (byId.containsKey(local.batchId)) return@forEach
                    byId[local.batchId] = local
                }
        }
        return byId.values.sortedByDescending { it.createdAt.orEmpty() }
    }

    private fun campaignMatchesMonthKey(c: NotificationCampaignInsightDto, monthKey: String): Boolean {
        val created = c.createdAt?.trim().orEmpty()
        if (created.length >= 7) return created.substring(0, 7) == monthKey
        return false
    }

    private fun mergeCampaign(
        a: NotificationCampaignInsightDto,
        b: NotificationCampaignInsightDto,
    ): NotificationCampaignInsightDto = a.copy(
        triggerName = a.triggerName ?: b.triggerName,
        createdAt = a.createdAt ?: b.createdAt,
        sentTotal = maxOfNullable(a.sentTotal, b.sentTotal),
        recipientsDistinct = maxOfNullable(a.recipientsDistinct, b.recipientsDistinct),
        returnedWithin48h = maxOfNullable(a.returnedWithin48h, b.returnedWithin48h),
        notificationTitle = a.notificationTitle ?: b.notificationTitle ?: a.title ?: b.title,
        title = a.title ?: b.title,
        message = a.message ?: b.message,
        sentPasskit = maxOfNullable(a.sentPasskit, b.sentPasskit),
        sentWebPush = maxOfNullable(a.sentWebPush, b.sentWebPush),
        deliveryStatus = a.deliveryStatus ?: b.deliveryStatus,
        expectedDevices = maxOfNullable(a.expectedDevices, b.expectedDevices),
    )

    private fun maxOfNullable(a: Int?, b: Int?): Int? = when {
        a != null && b != null -> maxOf(a, b)
        a != null -> a
        else -> b
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

            val panierMoyen = real.panierMoyenEuro
            val panierRepere = real.panierRepereEuro
            val panierTrendEuro = if (panierMoyen != null && panierRepere != null && panierRepere > 0) {
                panierMoyen - panierRepere
            } else {
                null
            }

            CommerceStatsMonthPage(
                monthKey = key,
                membersCount = stats?.membersCount ?: mock.membersCount,
                newMembers = stats?.newMembersInPeriod ?: stats?.newMembersLast30Days ?: mock.newMembers,
                avgBasketEur = panierMoyen ?: mock.avgBasketEur,
                avgBasketTrendEuro = panierTrendEuro,
                visitFrequency = real.frequenceParActif ?: mock.visitFrequency,
                googleReviewsNewInPeriod = real.googleReviewsNewInPeriod.takeIf { it > 0 }
                    ?: mock.googleReviewsNewInPeriod,
                sparkline = real.membersWeeklySparkline.ifEmpty { realSpark }.ifEmpty { mock.sparkline },
                monthAxisDays = real.membersMonthAxisDays,
                panierSparkline = real.panierWeeklySparkline.ifEmpty { mock.panierSparkline },
                panierMonthAxisDays = real.panierMonthAxisDays.ifEmpty { mock.panierMonthAxisDays },
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
