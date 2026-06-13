package fr.myfidpass.domain.sync

import fr.myfidpass.services.sync.SyncService

/** Use case minimal — point d’entrée domaine pour la sync dashboard (membres + transactions). */
class SyncDashboardUseCase(
    private val syncService: SyncService,
) {
    suspend operator fun invoke(slug: String, force: Boolean = false): Result<Unit> =
        runCatching { syncService.syncIfNeeded(slug, force) }
}
