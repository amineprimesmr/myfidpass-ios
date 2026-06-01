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
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

class DashboardViewModel(
    private val dashboardRepository: DashboardRepository,
    private val syncService: SyncService,
    private val appContext: Context,
) : ViewModel() {

    var stats: BusinessStatsResponse? by mutableStateOf(null)
        private set
    var settings: BusinessSettingsResponse? by mutableStateOf(null)
        private set
    var recentTransactions: List<TransactionDto> by mutableStateOf(emptyList())
        private set
    var loading by mutableStateOf(false)
        private set
    var refreshing by mutableStateOf(false)
        private set
    var error: String? by mutableStateOf(null)

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

    private suspend fun reload(slug: String, forceSync: Boolean) {
        loadCachedTransactions(slug)?.let { recentTransactions = it }
        syncService.syncIfNeeded(slug, force = forceSync)
        dashboardRepository.refreshAll(slug)
        stats = dashboardRepository.businessStats(slug)
        val freshSettings = dashboardRepository.businessSettings(slug)
        settings = freshSettings
        freshSettings?.let { CardPreviewSnapshotSync.syncFromSettings(appContext, slug, it) }
        recentTransactions = runCatching {
            dashboardRepository.businessTransactions(slug, limit = 12, sort = "desc").transactions
        }.getOrElse {
            loadCachedTransactions(slug).orEmpty()
        }
    }

    private suspend fun loadCachedTransactions(slug: String): List<TransactionDto>? {
        val rows = runCatching {
            syncService.transactionDao.observeRecent(slug, 12).first()
        }.getOrNull().orEmpty()
        if (rows.isEmpty()) return null
        return rows.map {
            TransactionDto(
                id = it.id,
                memberId = it.memberId,
                memberName = it.memberName,
                memberEmail = it.memberEmail,
                type = it.type,
                points = it.points,
                metadata = it.detail,
                createdAt = it.createdAt,
            )
        }
    }
}
