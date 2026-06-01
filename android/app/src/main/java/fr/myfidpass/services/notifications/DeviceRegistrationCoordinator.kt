package fr.myfidpass.services.notifications

import android.content.Context
import android.provider.Settings
import android.util.Log
import com.google.firebase.messaging.FirebaseMessaging
import fr.myfidpass.data.repo.DashboardRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.tasks.await
import kotlin.math.pow

/**
 * Enregistrement FCM → `POST /api/device/register` avec retry/backoff (aligné iOS NotificationsService).
 */
class DeviceRegistrationCoordinator(
    private val context: Context,
    private val repository: DashboardRepository,
) {
    private val scope = CoroutineScope(Dispatchers.IO)
    private val mutex = Mutex()
    private val pendingStore = PendingDeviceTokenStore(context)

    fun registerAfterLogin() {
        scope.launch {
            mutex.withLock {
                runCatching { registerWithRetry(fcmOrFallbackToken()) }
                    .onFailure { Log.w(TAG, "device register failed: ${it.message}") }
            }
        }
    }

    suspend fun registerTokenNow(token: String) {
        mutex.withLock {
            registerWithRetry(token)
        }
    }

    private suspend fun registerWithRetry(token: String) {
        val trimmed = token.trim()
        if (trimmed.isEmpty() || trimmed.startsWith("android-local-")) return
        pendingStore.save(trimmed)

        var lastError: Throwable? = null
        repeat(MAX_ATTEMPTS) { attempt ->
            val result = runCatching { repository.deviceRegister(trimmed) }
            if (result.isSuccess) {
                pendingStore.clear()
                return
            }
            lastError = result.exceptionOrNull()
            if (attempt < MAX_ATTEMPTS - 1) {
                val delaySeconds = 2.0.pow(attempt + 1.0)
                delay((delaySeconds * 1000).toLong())
            }
        }
        Log.w(TAG, "deviceRegister failed after $MAX_ATTEMPTS attempts: ${lastError?.message}")
    }

    fun retryPendingIfNeeded() {
        val pending = pendingStore.read() ?: return
        scope.launch {
            mutex.withLock {
                runCatching { registerWithRetry(pending) }
            }
        }
    }

    private suspend fun fcmOrFallbackToken(): String {
        return runCatching {
            FirebaseMessaging.getInstance().token.await().trim()
        }.getOrNull()?.takeIf { it.isNotEmpty() }
            ?: fallbackLocalToken()
    }

    private fun fallbackLocalToken(): String {
        val androidId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
        return "android-local-$androidId"
    }

    companion object {
        private const val TAG = "DeviceRegistration"
        private const val MAX_ATTEMPTS = 3
    }
}

private class PendingDeviceTokenStore(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun save(token: String) {
        prefs.edit().putString(KEY, token).apply()
    }

    fun read(): String? = prefs.getString(KEY, null)?.trim()?.takeIf { it.isNotEmpty() }

    fun clear() {
        prefs.edit().remove(KEY).apply()
    }

    companion object {
        private const val PREFS = "myfidpass_pending_device_token"
        private const val KEY = "token"
    }
}
