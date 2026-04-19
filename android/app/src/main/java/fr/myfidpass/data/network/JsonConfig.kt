package fr.myfidpass.data.network

import kotlinx.serialization.json.Json

/** JSON API (snake_case) — champs annotés `@SerialName` dans les DTOs. */
val jsonNet: Json = Json {
    ignoreUnknownKeys = true
    isLenient = true
    encodeDefaults = true
}
