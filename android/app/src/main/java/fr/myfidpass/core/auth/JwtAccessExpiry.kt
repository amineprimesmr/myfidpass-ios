package fr.myfidpass.core.auth

import org.json.JSONObject
import java.util.Base64

object JwtAccessExpiry {
    fun expirationEpochSeconds(jwt: String): Long? {
        val parts = jwt.split('.')
        if (parts.size < 2) return null
        return runCatching {
            var payload = parts[1]
            val rem = payload.length % 4
            if (rem > 0) payload += "=".repeat(4 - rem)
            val decoded = Base64.getUrlDecoder().decode(payload)
            val json = JSONObject(String(decoded, Charsets.UTF_8))
            json.optLong("exp", 0L).takeIf { it > 0L }
        }.getOrNull()
    }

    fun stillWithinValidityWindow(token: String?, marginSeconds: Long = 30): Boolean {
        val jwt = token?.trim().orEmpty()
        if (jwt.isEmpty()) return false
        val exp = expirationEpochSeconds(jwt) ?: return false
        val now = System.currentTimeMillis() / 1000
        return exp - now > marginSeconds
    }

    fun shouldProactivelyRefresh(token: String?, withinSeconds: Long = 120): Boolean {
        val jwt = token?.trim().orEmpty()
        if (jwt.isEmpty()) return false
        val exp = expirationEpochSeconds(jwt) ?: return false
        val now = System.currentTimeMillis() / 1000
        return exp - now <= withinSeconds
    }
}
