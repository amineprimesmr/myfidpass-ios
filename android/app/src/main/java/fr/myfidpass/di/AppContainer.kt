package fr.myfidpass.di

import android.content.Context
import fr.myfidpass.BuildConfig
import fr.myfidpass.core.auth.RefreshTokenCoordinator
import fr.myfidpass.data.local.FirstLaunchPreferences
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.network.NetworkModule
import fr.myfidpass.data.repo.AuthRepository
import fr.myfidpass.data.repo.BusinessCreationRepository
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.services.notifications.DeviceRegistrationCoordinator
import fr.myfidpass.services.sync.SyncService
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit

class AppContainer(context: Context) {
    val applicationContext = context.applicationContext
    private val appContext = applicationContext

    val sessionStore = SessionStore(appContext)
    val firstLaunchPreferences = FirstLaunchPreferences(appContext)

    private val refreshClient: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(60, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .build()

    val refreshCoordinator = RefreshTokenCoordinator(
        sessionStore = sessionStore,
        refreshClient = refreshClient,
        refreshUrl = BuildConfig.API_BASE_URL.toHttpUrl().resolve("/api/auth/refresh")!!,
    )

    private val network = NetworkModule(
        baseUrl = BuildConfig.API_BASE_URL,
        sessionStore = sessionStore,
        refreshCoordinator = refreshCoordinator,
    )

    val authRepository = AuthRepository(
        api = network.api,
        sessionStore = sessionStore,
        firstLaunch = firstLaunchPreferences,
        refreshCoordinator = refreshCoordinator,
    )

    val dashboardRepository = DashboardRepository(
        api = network.api,
        sessionStore = sessionStore,
    )

    val businessCreationRepository = BusinessCreationRepository(
        api = network.api,
        sessionStore = sessionStore,
    )

    val deviceRegistration = DeviceRegistrationCoordinator(
        context = appContext,
        repository = dashboardRepository,
    )

    val syncService = SyncService(
        context = appContext,
        repository = dashboardRepository,
    )
}
