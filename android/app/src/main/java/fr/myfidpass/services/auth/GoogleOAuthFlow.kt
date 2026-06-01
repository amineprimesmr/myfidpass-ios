package fr.myfidpass.services.auth

import android.net.Uri
import android.util.Base64
import fr.myfidpass.BuildConfig
import fr.myfidpass.data.dto.AuthConfigResponse
import fr.myfidpass.data.local.FirstLaunchPreferences
import org.json.JSONObject
import java.net.URLEncoder

object GoogleOAuthFlow {

    data class ParsedCallback(
        val accessToken: String,
        val refreshToken: String?,
    )

    class OAuthError(val code: String, override val message: String) : Exception(message)

    fun buildAuthorizationUrl(
        config: AuthConfigResponse,
        firstLaunch: FirstLaunchPreferences,
        mode: String = "sign_in",
    ): String {
        val clientId = config.googleClientId?.trim().orEmpty()
        require(clientId.isNotEmpty()) { "Connexion Google non configurée sur le serveur." }
        val base = BuildConfig.API_BASE_URL.trimEnd('/')
        val redirectUri = URLEncoder.encode("$base/api/auth/google-oauth-callback", Charsets.UTF_8.name())
        val pending = firstLaunch.readPendingEstablishment()
        val stateObj = JSONObject()
        stateObj.put("mode", mode)
        pending.placeId?.trim()?.takeIf { it.isNotEmpty() }?.let { stateObj.put("place_id", it) }
        pending.description?.trim()?.takeIf { it.isNotEmpty() }?.let { stateObj.put("establishment_name", it) }
        val stateB64 = Base64.encodeToString(
            stateObj.toString().toByteArray(Charsets.UTF_8),
            Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
        )
        return buildString {
            append("https://accounts.google.com/o/oauth2/v2/auth?")
            append("client_id=").append(URLEncoder.encode(clientId, Charsets.UTF_8.name()))
            append("&redirect_uri=").append(redirectUri)
            append("&response_type=code")
            append("&scope=").append(URLEncoder.encode("openid email profile", Charsets.UTF_8.name()))
            append("&prompt=select_account")
            append("&state=").append(URLEncoder.encode(stateB64, Charsets.UTF_8.name()))
        }
    }

    fun parseCallbackUri(uri: Uri): ParsedCallback {
        val params = uri.queryParameterNames.associateWith { uri.getQueryParameter(it).orEmpty() }
        params["error"]?.takeIf { it.isNotEmpty() }?.let { err ->
            throw OAuthError(err, mapOAuthError(err))
        }
        val token = params["token"]?.trim().orEmpty()
        if (token.isEmpty()) throw OAuthError("no_token", "Réponse Google invalide.")
        val refresh = params["refreshToken"]?.trim()?.takeIf { it.isNotEmpty() }
        return ParsedCallback(token, refresh)
    }

    private fun mapOAuthError(code: String): String = when (code) {
        "no_account" -> "Aucun compte trouvé. Créez un compte ou utilisez l'e-mail."
        "invalid" -> "Échange Google refusé (redirect_uri ou secrets serveur)."
        "config" -> "Connexion Google non configurée sur le serveur."
        "no_email" -> "Google n'a pas partagé votre e-mail."
        "missing_establishment" -> "Inscription Google : choisissez d'abord un établissement."
        "account_exists" -> "Un compte existe déjà avec cet e-mail Google. Utilisez « Se connecter »."
        "business_place_already_linked" -> "Ce commerce est déjà lié à un autre compte."
        else -> "Connexion Google impossible ($code)."
    }
}
