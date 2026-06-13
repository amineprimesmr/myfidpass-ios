package fr.myfidpass.di

import android.content.Context
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import fr.myfidpass.BuildConfig
import fr.myfidpass.core.auth.RefreshTokenCoordinator
import fr.myfidpass.data.local.FirstLaunchPreferences
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.network.MyfidpassApi
import fr.myfidpass.data.network.NetworkModule
import fr.myfidpass.data.repo.AuthRepository
import fr.myfidpass.data.repo.BusinessCreationRepository
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.domain.auth.RefreshSessionUseCase
import fr.myfidpass.domain.sync.SyncDashboardUseCase
import fr.myfidpass.services.notifications.DeviceRegistrationCoordinator
import fr.myfidpass.services.sync.SyncService
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

/** Module Hilt — bindings alignés sur AppContainer (migration progressive). */
@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideSessionStore(@ApplicationContext context: Context): SessionStore =
        SessionStore(context)

    @Provides
    @Singleton
    fun provideFirstLaunchPreferences(@ApplicationContext context: Context): FirstLaunchPreferences =
        FirstLaunchPreferences(context)

    @Provides
    @Singleton
    fun provideRefreshCoordinator(sessionStore: SessionStore): RefreshTokenCoordinator {
        val refreshClient = OkHttpClient.Builder()
            .connectTimeout(60, TimeUnit.SECONDS)
            .readTimeout(60, TimeUnit.SECONDS)
            .writeTimeout(60, TimeUnit.SECONDS)
            .build()
        return RefreshTokenCoordinator(
            sessionStore = sessionStore,
            refreshClient = refreshClient,
            refreshUrl = BuildConfig.API_BASE_URL.toHttpUrl().resolve("/api/auth/refresh")!!,
        )
    }

    @Provides
    @Singleton
    fun provideApi(sessionStore: SessionStore, refreshCoordinator: RefreshTokenCoordinator): MyfidpassApi =
        NetworkModule(
            baseUrl = BuildConfig.API_BASE_URL,
            sessionStore = sessionStore,
            refreshCoordinator = refreshCoordinator,
        ).api

    @Provides
    @Singleton
    fun provideAuthRepository(
        @ApplicationContext context: Context,
        api: MyfidpassApi,
        sessionStore: SessionStore,
        firstLaunch: FirstLaunchPreferences,
        refreshCoordinator: RefreshTokenCoordinator,
    ): AuthRepository = AuthRepository(context, api, sessionStore, firstLaunch, refreshCoordinator)

    @Provides
    @Singleton
    fun provideDashboardRepository(api: MyfidpassApi, sessionStore: SessionStore): DashboardRepository =
        DashboardRepository(api, sessionStore)

    @Provides
    @Singleton
    fun provideSyncService(
        @ApplicationContext context: Context,
        dashboardRepository: DashboardRepository,
    ): SyncService = SyncService(context, dashboardRepository)

    @Provides
    @Singleton
    fun provideBusinessCreationRepository(api: MyfidpassApi, sessionStore: SessionStore): BusinessCreationRepository =
        BusinessCreationRepository(api, sessionStore)

    @Provides
    @Singleton
    fun provideDeviceRegistration(
        @ApplicationContext context: Context,
        dashboardRepository: DashboardRepository,
    ): DeviceRegistrationCoordinator = DeviceRegistrationCoordinator(context, dashboardRepository)

    @Provides
    fun provideRefreshSessionUseCase(refreshCoordinator: RefreshTokenCoordinator): RefreshSessionUseCase =
        RefreshSessionUseCase(refreshCoordinator)

    @Provides
    fun provideSyncDashboardUseCase(syncService: SyncService): SyncDashboardUseCase =
        SyncDashboardUseCase(syncService)
}
