package fr.myfidpass.ui.viewmodel

import android.content.Context
import android.os.Build
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.repo.AuthRepository
import fr.myfidpass.services.notifications.NotificationPermissionHelper
import fr.myfidpass.services.sync.SyncService
import kotlinx.coroutines.launch

class AccountSettingsViewModel(
    private val authRepository: AuthRepository,
    private val sessionStore: SessionStore,
    private val syncService: SyncService,
) : ViewModel() {

    var loading by mutableStateOf(false)
    var loadError by mutableStateOf<String?>(null)
    var passwordResetNotice by mutableStateOf<String?>(null)
    var passwordResetError by mutableStateOf<String?>(null)
    var isSendingPasswordReset by mutableStateOf(false)
    var isDeletingAccount by mutableStateOf(false)
    var deleteAccountError by mutableStateOf<String?>(null)
    var pushAuthorized by mutableStateOf(true)

    val email: String get() = sessionStore.userEmail.orEmpty()
    val authProviderLabel: String get() = sessionStore.authProviderLabel()
    val passwordExternalLabel: String? get() = sessionStore.passwordExternalProviderLabel()
    val isEmailAuth: Boolean get() = sessionStore.authProvider?.lowercase() != "google" &&
        sessionStore.authProvider?.lowercase() != "apple" &&
        sessionStore.authProvider?.lowercase() != "phone"
    val businesses get() = sessionStore.businesses
    val currentSlug get() = sessionStore.currentBusinessSlug

    fun deviceLine(): String = "Android · ${Build.MODEL} · API ${Build.VERSION.SDK_INT}"

    fun refreshPushStatus(context: Context) {
        pushAuthorized = !NotificationPermissionHelper.needsRuntimePermission(context)
    }

    fun refreshAccount(force: Boolean = false) {
        viewModelScope.launch {
            if (!force && loadError == null && !loading) {
                // throttle handled by repository/session
            }
            loading = true
            loadError = null
            authRepository.refreshAccount()
                .onSuccess { loading = false }
                .onFailure {
                    loading = false
                    loadError = it.message ?: "Impossible de charger le compte."
                }
            sessionStore.currentBusinessSlug?.let { slug ->
                runCatching { syncService.syncIfNeeded(slug, force = false) }
            }
        }
    }

    fun sendPasswordReset(onDone: () -> Unit = {}) {
        val mail = email.trim()
        if (mail.isEmpty()) return
        viewModelScope.launch {
            isSendingPasswordReset = true
            passwordResetError = null
            runCatching { authRepository.forgotPassword(mail) }
                .onSuccess {
                    passwordResetNotice = "E-mail envoyé. Ouvrez le lien pour choisir un nouveau mot de passe."
                    onDone()
                }
                .onFailure {
                    passwordResetError = it.message ?: "Envoi impossible."
                }
            isSendingPasswordReset = false
        }
    }

    fun deleteAccount(onSuccess: () -> Unit) {
        viewModelScope.launch {
            isDeletingAccount = true
            deleteAccountError = null
            runCatching { authRepository.deleteAccount() }
                .onSuccess { onSuccess() }
                .onFailure { deleteAccountError = it.message ?: "Suppression impossible." }
            isDeletingAccount = false
        }
    }

    fun switchBusiness(slug: String) {
        sessionStore.switchBusiness(slug)
        viewModelScope.launch {
            sessionStore.currentBusinessSlug?.let { syncService.syncIfNeeded(it, force = true) }
        }
    }
}
