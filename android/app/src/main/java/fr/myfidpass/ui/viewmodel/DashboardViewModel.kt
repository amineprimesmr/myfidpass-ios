package fr.myfidpass.ui.viewmodel

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import fr.myfidpass.data.dto.BusinessSettingsResponse
import fr.myfidpass.data.dto.BusinessStatsResponse
import fr.myfidpass.data.dto.TransactionDto
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.services.sync.SyncService
import fr.myfidpass.ui.mycard.CardPreviewSnapshotSync
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class DashboardViewModel @Inject constructor(
    private val dashboardRepository: DashboardRepository,
    private val syncService: SyncService,
    @ApplicationContext private val appContext: Context,
) : ViewModel() {

    var stats: BusinessStatsResponse? by mutableStateOf(null)
        private set
    var settings: BusinessSettingsResponse? by mutableStateOf(null)
        private set
    var recentTransactions: List<TransactionDto> by mutableStateOf(emptyList())
        private set
    var transactionsVisibleCount by mutableStateOf(TRANSACTIONS_PAGE_SIZE)
        private set
    var loadingMoreTransactions by mutableStateOf(false)
        private set
    var loading by mutableStateOf(false)
        private set
    var refreshing by mutableStateOf(false)
        private set
    var error: String? by mutableStateOf(null)

    val hasMoreTransactions: Boolean
        get() {
            if (transactionsVisibleCount < recentTransactions.size) return true
            val total = transactionsTotal ?: return false
            return recentTransactions.size < total
        }

    private var transactionsTotal: Int? = null
    private var homeTransactionsExpanded = false
    private var transactionsFetchSize = INITIAL_TRANSACTIONS_FETCH
    private var homeLiveSyncJob: Job? = null

    fun load() {
        val slug = dashboardRepository.currentSlug() ?: return
        viewModelScope.launch {
            loading = true
            error = null
            runCatching { reload(slug, forceSync = false) }.onFailure {
                error = it.message
            }
            loading = false
        }
    }

    fun refresh() {
        val slug = dashboardRepository.currentSlug() ?: return
        viewModelScope.launch {
            refreshing = true
            error = null
            runCatching { reload(slug, forceSync = true) }.onFailure {
                error = it.message
            }
            refreshing = false
        }
    }

    /** Attend la fin du rechargement (après PATCH settings) pour éviter d’écraser le brouillon avec des données périmées. */
    suspend fun refreshAndWait() {
        val slug = dashboardRepository.currentSlug() ?: return
        refreshing = true
        error = null
        runCatching { reload(slug, forceSync = true) }.onFailure {
            error = it.message
        }
        refreshing = false
    }

    /**
     * Accueil : observe Room + poll léger (aligné iOS push `dashboard_sync` + polling 25 s).
     * Les transactions web / QR apparaissent sans pull-to-refresh manuel.
     */
    fun loadMoreTransactions() {
        val slug = dashboardRepository.currentSlug() ?: return
        if (loadingMoreTransactions || !hasMoreTransactions) return
        viewModelScope.launch {
            loadingMoreTransactions = true
            homeTransactionsExpanded = true
            val nextVisible = transactionsVisibleCount + TRANSACTIONS_PAGE_SIZE
            if (nextVisible > recentTransactions.size) {
                runCatching {
                    val offset = recentTransactions.size
                    val response = dashboardRepository.businessTransactions(
                        slug = slug,
                        limit = TRANSACTIONS_PAGE_SIZE,
                        offset = offset,
                        sort = "desc",
                    )
                    transactionsTotal = response.total
                    recentTransactions = recentTransactions + response.transactions
                    transactionsFetchSize = recentTransactions.size
                }.onFailure { error = it.message }
            }
            transactionsVisibleCount = nextVisible
            loadingMoreTransactions = false
        }
    }

    private fun resetTransactionsPagination() {
        transactionsVisibleCount = TRANSACTIONS_PAGE_SIZE
        loadingMoreTransactions = false
        homeTransactionsExpanded = false
        transactionsFetchSize = INITIAL_TRANSACTIONS_FETCH
        transactionsTotal = null
    }

    fun bindHomeActivityLiveUpdates(slug: String) {
        val trimmed = slug.trim()
        if (trimmed.isEmpty()) return
        resetTransactionsPagination()
        homeLiveSyncJob?.cancel()
        homeLiveSyncJob = viewModelScope.launch {
            launch {
                syncService.transactionDao.observeRecent(trimmed, INITIAL_TRANSACTIONS_FETCH).collect { rows ->
                    if (!homeTransactionsExpanded) {
                        recentTransactions = rows.map { entityToDto(it) }
                    }
                }
            }
            launch {
                runCatching { syncService.syncIfNeeded(trimmed, force = true) }
                while (isActive) {
                    delay(HOME_ACTIVITY_POLL_MS)
                    runCatching { syncService.syncIfNeeded(trimmed, force = true) }
                }
            }
        }
    }

    fun unbindHomeActivityLiveUpdates() {
        homeLiveSyncJob?.cancel()
        homeLiveSyncJob = null
    }

    private fun entityToDto(entity: fr.myfidpass.data.local.db.entities.TransactionEntity): TransactionDto =
        TransactionDto(
            id = entity.id,
            memberId = entity.memberId,
            memberName = entity.memberName,
            memberEmail = entity.memberEmail,
            type = entity.type,
            points = entity.points,
            metadata = entity.detail,
            createdAt = entity.createdAt,
        )

    private suspend fun reload(slug: String, forceSync: Boolean) {
        loadCachedTransactions(slug)?.let { recentTransactions = it }
        syncService.syncIfNeeded(slug, force = forceSync)
        dashboardRepository.refreshAll(slug)
        stats = dashboardRepository.businessStats(slug)
        val freshSettings = dashboardRepository.businessSettings(slug)
        settings = freshSettings
        freshSettings?.let { CardPreviewSnapshotSync.syncFromSettings(appContext, slug, it) }
        val fetchLimit = maxOf(
            INITIAL_TRANSACTIONS_FETCH,
            transactionsFetchSize,
            transactionsVisibleCount + 1,
        )
        recentTransactions = runCatching {
            val response = dashboardRepository.businessTransactions(
                slug = slug,
                limit = fetchLimit,
                sort = "desc",
            )
            transactionsTotal = response.total
            transactionsFetchSize = response.transactions.size
            response.transactions
        }.getOrElse {
            loadCachedTransactions(slug).orEmpty()
        }
    }

    private suspend fun loadCachedTransactions(slug: String): List<TransactionDto>? {
        val rows = runCatching {
            syncService.transactionDao.observeRecent(slug, 12).first()
        }.getOrNull().orEmpty()
        if (rows.isEmpty()) return null
        return rows.map { entityToDto(it) }
    }

    companion object {
        private const val HOME_ACTIVITY_POLL_MS = 25_000L
        const val TRANSACTIONS_PAGE_SIZE = 8
        private const val INITIAL_TRANSACTIONS_FETCH = 16
    }
}
