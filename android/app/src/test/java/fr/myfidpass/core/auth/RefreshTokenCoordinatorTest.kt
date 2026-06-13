package fr.myfidpass.core.auth

import fr.myfidpass.data.local.SessionStore
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import org.junit.Assert.assertEquals
import org.junit.Test

class RefreshTokenCoordinatorTest {

    @Test
    fun ensureValidAccessTokenSync_missingTokens_returnsMissingRefreshToken() {
        val session = mockk<SessionStore>(relaxed = true)
        every { session.accessToken } returns null
        every { session.refreshToken } returns null
        val coordinator = RefreshTokenCoordinator(
            sessionStore = session,
            refreshClient = OkHttpClient(),
            refreshUrl = "https://api.myfidpass.fr/api/auth/refresh".toHttpUrl(),
        )
        assertEquals(RefreshTokenOutcome.MissingRefreshToken, coordinator.ensureValidAccessTokenSync())
    }

    @Test
    fun forceTerminateSession_clearsSessionAndNotifies() {
        val session = mockk<SessionStore>(relaxed = true)
        val coordinator = RefreshTokenCoordinator(
            sessionStore = session,
            refreshClient = OkHttpClient(),
            refreshUrl = "https://api.myfidpass.fr/api/auth/refresh".toHttpUrl(),
        )
        coordinator.forceTerminateSession()
        verify { session.clearSession() }
    }
}
