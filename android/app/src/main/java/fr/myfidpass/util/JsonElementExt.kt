package fr.myfidpass.util

import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject

/** Évite le crash « JsonNull is not a JsonObject » quand l’API renvoie `null`. */
fun JsonElement?.jsonObjectOrNull(): JsonObject? =
    if (this == null || this is JsonNull) null else runCatching { jsonObject }.getOrNull()
