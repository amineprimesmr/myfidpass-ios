package fr.myfidpass.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import fr.myfidpass.di.AppContainer
import fr.myfidpass.ui.viewmodel.AccountSettingsViewModel
import fr.myfidpass.ui.viewmodel.DashboardViewModel
import fr.myfidpass.ui.viewmodel.EmailAuthViewModel
import fr.myfidpass.ui.viewmodel.AuthSignInOtpViewModel
import fr.myfidpass.ui.viewmodel.MerchantIntegratedOnboardingViewModel
import fr.myfidpass.ui.viewmodel.MerchantOnboardingViewModel
import fr.myfidpass.ui.viewmodel.MerchantStatsViewModel
import fr.myfidpass.ui.viewmodel.RootViewModel

fun viewModelFactory(container: AppContainer): ViewModelProvider.Factory =
    object : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            return when {
                modelClass.isAssignableFrom(RootViewModel::class.java) ->
                    RootViewModel(
                        container.authRepository,
                        container.sessionStore,
                        container.firstLaunchPreferences,
                    ) as T
                modelClass.isAssignableFrom(MerchantOnboardingViewModel::class.java) ->
                    MerchantOnboardingViewModel(container.authRepository) as T
                modelClass.isAssignableFrom(MerchantIntegratedOnboardingViewModel::class.java) ->
                    MerchantIntegratedOnboardingViewModel(
                        container.authRepository,
                        container.firstLaunchPreferences,
                        container.sessionStore,
                    ) as T
                modelClass.isAssignableFrom(AuthSignInOtpViewModel::class.java) ->
                    AuthSignInOtpViewModel(
                        container.authRepository,
                        container.firstLaunchPreferences,
                    ) as T
                modelClass.isAssignableFrom(EmailAuthViewModel::class.java) ->
                    EmailAuthViewModel(container.authRepository, container.firstLaunchPreferences) as T
                modelClass.isAssignableFrom(DashboardViewModel::class.java) ->
                    DashboardViewModel(
                        container.dashboardRepository,
                        container.syncService,
                        container.applicationContext,
                    ) as T
                modelClass.isAssignableFrom(MerchantStatsViewModel::class.java) ->
                    MerchantStatsViewModel(container.dashboardRepository, container.sessionStore) as T
                modelClass.isAssignableFrom(AccountSettingsViewModel::class.java) ->
                    AccountSettingsViewModel(
                        container.authRepository,
                        container.sessionStore,
                        container.syncService,
                    ) as T
                else -> throw IllegalArgumentException("Unknown VM ${modelClass.simpleName}")
            }
        }
    }
