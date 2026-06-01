package fr.myfidpass.data.repo

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import retrofit2.HttpException

private val errJson = Json { ignoreUnknownKeys = true }

data class ParsedHttpError(
    val message: String?,
    val code: String?,
)

fun parseHttpError(e: HttpException): ParsedHttpError {
    val body = e.response()?.errorBody()?.string() ?: return ParsedHttpError(null, null)
    return try {
        val o = errJson.parseToJsonElement(body).jsonObject
        ParsedHttpError(
            message = o["message"]?.jsonPrimitive?.content ?: o["error"]?.jsonPrimitive?.content,
            code = o["code"]?.jsonPrimitive?.content,
        )
    } catch (_: Exception) {
        ParsedHttpError(null, null)
    }
}

fun mapRegisterError(e: HttpException): String {
    val parsed = parseHttpError(e)
    return when (e.code()) {
        409 -> when (parsed.code) {
            "business_place_already_linked" ->
                parsed.message ?: "Ce commerce est déjà lié à un autre compte MyFidpass."
            else -> if (
                parsed.message?.contains("email", ignoreCase = true) == true ||
                parsed.message?.contains("compte existe", ignoreCase = true) == true
            ) {
                "Un compte existe déjà avec cet e-mail. Utilisez « Se connecter » ou choisissez un autre e-mail."
            } else {
                parsed.message ?: "Inscription impossible (conflit)."
            }
        }
        400 -> parsed.message ?: "Informations invalides."
        else -> parsed.message ?: "Erreur ${e.code()}"
    }
}

fun mapLoginError(e: HttpException): String {
    val parsed = parseHttpError(e)
    return when (e.code()) {
        401 -> parsed.message ?: "Identifiant ou mot de passe incorrect."
        else -> parsed.message ?: "Erreur ${e.code()}"
    }
}
