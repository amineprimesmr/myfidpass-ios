package fr.myfidpass.ui.viewmodel

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import fr.myfidpass.data.dto.BusinessSettingsResponse
import fr.myfidpass.data.dto.BusinessStatsResponse
import fr.myfidpass.data.repo.DashboardRepository
import kotlinx.coroutines.launch

class DashboardViewModel(
    private val dashboardRepository: DashboardRepository,
) : ViewModel() {

    var stats: BusinessStatsResponse? by mutableStateOf(null)
        private set
    var settings: BusinessSettingsResponse? by mutableStateOf(null)
        private set
    var loading by mutableStateOf(false)
        private set
    var error: String? by mutableStateOf(null)

    fun load() {
        val slug = dashboardRepository.currentSlug() ?: return
        viewModelScope.launch {
            loading = true
            error = null
            runCatching {
                dashboardRepository.refreshAll(slug)
                stats = dashboardRepository.businessStats(slug)
                settings = dashboardRepository.businessSettings(slug)
            }.onFailure {
                error = it.message
            }
            loading = false
        }
    }
}
