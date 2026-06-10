package fr.myfidpass.core.auth

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/** Codes JSON 401 indiquant une session invalidée côté serveur (suppression compte admin, reset BDD). */
object AuthApiErrorCodes {
    private val json = Json { ignoreUnknownKeys = true }

    @Serializable
    private data class Body(@SerialName("code") val code: String? = null)

    fun isSessionRevoked(body: String?): Boolean {
        val raw = body?.trim().orEmpty()
        if (raw.isEmpty()) return false
        val code = try {
            json.decodeFromString<Body>(raw).code?.trim().orEmpty()
        } catch (_: Exception) {
            return false
        }
        return code == "session_revoked" || code == "user_not_found" || code == "account_deleted"
    }
}
