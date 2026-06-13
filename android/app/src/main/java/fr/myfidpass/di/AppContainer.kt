package fr.myfidpass.di

import android.content.Context
import fr.myfidpass.data.local.FirstLaunchPreferences
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.network.MyfidpassApi
import fr.myfidpass.data.repo.AuthRepository
import fr.myfidpass.data.repo.BusinessCreationRepository
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.domain.auth.RefreshSessionUseCase
import fr.myfidpass.domain.sync.SyncDashboardUseCase
import fr.myfidpass.services.notifications.DeviceRegistrationCoordinator
import fr.myfidpass.services.sync.SyncService
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/** Facade DI injectée par Hilt — remplace l'ancien service locator manuel. */
@Singleton
class AppContainer @Inject constructor(
    @ApplicationContext val applicationContext: Context,
    val sessionStore: SessionStore,
    val firstLaunchPreferences: FirstLaunchPreferences,
    val api: MyfidpassApi,
    val authRepository: AuthRepository,
    val dashboardRepository: DashboardRepository,
    val businessCreationRepository: BusinessCreationRepository,
    val deviceRegistration: DeviceRegistrationCoordinator,
    val syncService: SyncService,
    val refreshSessionUseCase: RefreshSessionUseCase,
    val syncDashboardUseCase: SyncDashboardUseCase,
)
