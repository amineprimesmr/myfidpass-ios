package fr.myfidpass.di

import android.content.Context
import fr.myfidpass.BuildConfig
import fr.myfidpass.data.local.FirstLaunchPreferences
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.network.NetworkModule
import fr.myfidpass.data.repo.AuthRepository
import fr.myfidpass.data.repo.DashboardRepository

class AppContainer(context: Context) {
    private val appContext = context.applicationContext

    val sessionStore = SessionStore(appContext)
    val firstLaunchPreferences = FirstLaunchPreferences(appContext)

    private val network = NetworkModule(
        baseUrl = BuildConfig.API_BASE_URL,
        sessionStore = sessionStore,
    )

    val authRepository = AuthRepository(
        api = network.api,
        sessionStore = sessionStore,
        firstLaunch = firstLaunchPreferences,
    )

    val dashboardRepository = DashboardRepository(
        api = network.api,
        sessionStore = sessionStore,
    )
}
