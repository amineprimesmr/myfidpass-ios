package fr.myfidpass.core.auth

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Base64

class JwtAccessExpiryTest {

    private fun jwtWithExp(exp: Long): String {
        val payloadJson = """{"exp":$exp}"""
        val payload = Base64.getUrlEncoder().withoutPadding()
            .encodeToString(payloadJson.toByteArray(Charsets.UTF_8))
        return "header.$payload.sig"
    }

    @Test
    fun stillWithinValidityWindow_returnsTrueForFarFutureExp() {
        val token = jwtWithExp(4_102_444_800L)
        assertEquals(true, JwtAccessExpiry.stillWithinValidityWindow(token))
    }

    @Test
    fun shouldProactivelyRefresh_returnsFalseForFarFutureExp() {
        val token = jwtWithExp(4_102_444_800L)
        assertEquals(false, JwtAccessExpiry.shouldProactivelyRefresh(token))
    }

    @Test
    fun expirationEpochSeconds_parsesPayload() {
        val token = jwtWithExp(1_700_000_000L)
        assertEquals(1_700_000_000L, JwtAccessExpiry.expirationEpochSeconds(token))
    }

    @Test
    fun stillWithinValidityWindow_returnsFalseForBlank() {
        assertEquals(false, JwtAccessExpiry.stillWithinValidityWindow(null))
        assertEquals(false, JwtAccessExpiry.stillWithinValidityWindow(""))
    }
}
