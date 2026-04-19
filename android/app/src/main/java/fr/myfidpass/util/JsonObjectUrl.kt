package fr.myfidpass.util

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
/** Extrait une URL HTTP depuis une réponse API type OAuth (`url`, `authorization_url`, …). */
fun JsonObject.optHttpUrl(): String? {
    val keys = listOf("url", "authorization_url", "auth_url", "redirect_url", "login_url")
    for (k in keys) {
        val prim = this[k] as? JsonPrimitive ?: continue
        val s = prim.content.trim()
        if (s.startsWith("http://") || s.startsWith("https://")) return s
    }
    return null
}
