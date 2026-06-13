package fr.myfidpass.domain.auth

import fr.myfidpass.core.auth.RefreshTokenCoordinator
import fr.myfidpass.core.auth.RefreshTokenOutcome

/** Use case minimal — refresh JWT avant appels API sensibles. */
class RefreshSessionUseCase(
    private val refreshCoordinator: RefreshTokenCoordinator,
) {
    operator fun invoke(force: Boolean = false): RefreshTokenOutcome =
        if (force) refreshCoordinator.refreshSync(force = true)
        else refreshCoordinator.ensureValidAccessTokenSync()
}
