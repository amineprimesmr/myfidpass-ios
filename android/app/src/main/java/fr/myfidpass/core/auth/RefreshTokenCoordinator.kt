package fr.myfidpass.core.auth

import fr.myfidpass.data.dto.AuthRefreshResponse
import fr.myfidpass.data.dto.RefreshRequest
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.network.jsonNet
import kotlinx.serialization.encodeToString
import okhttp3.HttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.net.SocketTimeoutException

class RefreshTokenCoordinator(
    private val sessionStore: SessionStore,
    private val refreshClient: OkHttpClient,
    private val refreshUrl: HttpUrl,
) {
    private val lock = Any()

    @Volatile
    private var lastRefreshSuccessAt: Long = 0

    private val minRefreshIntervalMs = 2_500L

    fun ensureValidAccessTokenSync(): RefreshTokenOutcome {
        val token = sessionStore.accessToken
        if (token.isNullOrBlank()) {
            return if (sessionStore.refreshToken.isNullOrBlank()) {
                RefreshTokenOutcome.MissingRefreshToken
            } else {
                refreshSync(force = false)
            }
        }
        if (!JwtAccessExpiry.shouldProactivelyRefresh(token)) {
            return RefreshTokenOutcome.Success
        }
        return refreshSync(force = false)
    }

    fun refreshSync(force: Boolean = false): RefreshTokenOutcome {
        synchronized(lock) {
            val now = System.currentTimeMillis()
            val current = sessionStore.accessToken
            if (!force && current != null && JwtAccessExpiry.stillWithinValidityWindow(current)) {
                if (now - lastRefreshSuccessAt < minRefreshIntervalMs) {
                    return RefreshTokenOutcome.Success
                }
                if (!JwtAccessExpiry.shouldProactivelyRefresh(current)) {
                    return RefreshTokenOutcome.Success
                }
            }

            val rt = sessionStore.refreshToken?.trim().orEmpty()
            if (rt.isEmpty()) return RefreshTokenOutcome.MissingRefreshToken

            if (!force && now - lastRefreshSuccessAt < minRefreshIntervalMs) {
                return if (JwtAccessExpiry.stillWithinValidityWindow(sessionStore.accessToken)) {
                    RefreshTokenOutcome.Success
                } else {
                    performRefresh(rt)
                }
            }
            return performRefresh(rt)
        }
    }

    private fun performRefresh(refreshToken: String): RefreshTokenOutcome {
        return try {
            val bodyStr = jsonNet.encodeToString(RefreshRequest(refreshToken = refreshToken))
            val refreshReq = okhttp3.Request.Builder()
                .url(refreshUrl)
                .post(bodyStr.toRequestBody("application/json".toMediaType()))
                .header("Content-Type", "application/json")
                .header("Accept", "application/json")
                .build()
            refreshClient.newCall(refreshReq).execute().use { r ->
                if (r.code == 401) return RefreshTokenOutcome.InvalidToken
                if (!r.isSuccessful) return RefreshTokenOutcome.TransientFailure
                val respBody = r.body?.string()
                if (respBody.isNullOrEmpty()) return RefreshTokenOutcome.TransientFailure
                val refreshed = try {
                    jsonNet.decodeFromString<AuthRefreshResponse>(respBody)
                } catch (_: Exception) {
                    return RefreshTokenOutcome.TransientFailure
                }
                sessionStore.applyRefreshResponse(refreshed)
                if (sessionStore.accessToken.isNullOrBlank()) {
                    RefreshTokenOutcome.TransientFailure
                } else {
                    lastRefreshSuccessAt = System.currentTimeMillis()
                    RefreshTokenOutcome.Success
                }
            }
        } catch (_: SocketTimeoutException) {
            RefreshTokenOutcome.TransientFailure
        } catch (_: IOException) {
            RefreshTokenOutcome.TransientFailure
        } catch (_: Exception) {
            RefreshTokenOutcome.TransientFailure
        }
    }

    fun shouldTerminateSession(outcome: RefreshTokenOutcome): Boolean {
        if (JwtAccessExpiry.stillWithinValidityWindow(sessionStore.accessToken)) return false
        if (outcome == RefreshTokenOutcome.TransientFailure) return false
        return outcome == RefreshTokenOutcome.InvalidToken ||
            outcome == RefreshTokenOutcome.MissingRefreshToken
    }

    fun terminateSessionIfAppropriate(outcome: RefreshTokenOutcome) {
        if (!shouldTerminateSession(outcome)) return
        sessionStore.clearSession()
        SessionEvents.notifyInvalidated()
    }
}
