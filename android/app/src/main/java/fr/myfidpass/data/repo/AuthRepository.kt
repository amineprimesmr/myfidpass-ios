package fr.myfidpass.data.repo

import fr.myfidpass.data.dto.AppleAuthRequest
import fr.myfidpass.data.dto.AuthConfigResponse
import fr.myfidpass.data.dto.ForgotPasswordRequest
import fr.myfidpass.data.dto.GoogleAuthRequest
import fr.myfidpass.data.dto.LoginRequest
import fr.myfidpass.data.dto.LogoutRequest
import fr.myfidpass.data.dto.PlaceAutocompletePrediction
import fr.myfidpass.data.dto.PlacesPlaceDetailsResponse
import fr.myfidpass.data.dto.RegisterRequest
import fr.myfidpass.data.local.FirstLaunchPreferences
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.network.MyfidpassApi
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import retrofit2.HttpException

private val errJson = Json { ignoreUnknownKeys = true }

sealed class EmailLoginResult {
    data object Success : EmailLoginResult()
    data object NoAccount : EmailLoginResult()
    data class Error(val message: String) : EmailLoginResult()
}

class AuthRepository(
    private val api: MyfidpassApi,
    private val sessionStore: SessionStore,
    private val firstLaunch: FirstLaunchPreferences,
) {

    suspend fun login(email: String, password: String): Result<Unit> = runCatching {
        val r = api.login(LoginRequest(email.trim().lowercase(), password))
        sessionStore.applyLoginResponse(r)
    }

    suspend fun loginEmailReturningOutcome(email: String, password: String): EmailLoginResult {
        return try {
            val r = api.login(LoginRequest(email.trim().lowercase(), password))
            sessionStore.applyLoginResponse(r)
            EmailLoginResult.Success
        } catch (e: HttpException) {
            if (e.code() == 404) {
                EmailLoginResult.NoAccount
            } else {
                EmailLoginResult.Error(httpErrorMessage(e) ?: "Erreur ${e.code()}")
            }
        } catch (e: Exception) {
            EmailLoginResult.Error(e.message ?: "Erreur réseau")
        }
    }

    suspend fun register(
        email: String,
        password: String,
        name: String?,
    ): Result<Unit> = runCatching {
        try {
            val pending = firstLaunch.readPendingEstablishment()
            val placeId = pending.placeId?.trim()?.takeIf { it.isNotEmpty() }
            val estFromPending = pending.description?.trim()?.takeIf { it.isNotEmpty() }
            val establishmentName = estFromPending?.let { if (it.length > 100) it.take(100) else it }
            val r = api.register(
                RegisterRequest(
                    email = email.trim().lowercase(),
                    password = password,
                    name = name?.trim()?.takeIf { it.isNotEmpty() },
                    googlePlaceId = placeId,
                    establishmentName = establishmentName,
                ),
            )
            sessionStore.applyLoginResponse(r)
            firstLaunch.clearPendingEstablishmentFromOnboarding()
        } catch (e: HttpException) {
            if (e.code() == 409) error("Cet e-mail est déjà utilisé.")
            error(httpErrorMessage(e) ?: "Erreur ${e.code()}")
        }
    }

    suspend fun loginWithGoogle(idToken: String): Result<Unit> = runCatching {
        val p = firstLaunch.readPendingEstablishment()
        val estName = p.description?.trim()?.takeIf { it.isNotEmpty() }
        val r = api.authGoogle(
            GoogleAuthRequest(
                idToken = idToken,
                googlePlaceId = p.placeId,
                establishmentName = estName,
            ),
        )
        sessionStore.applyLoginResponse(r)
        if (p.placeId != null || estName != null) {
            firstLaunch.clearPendingEstablishmentFromOnboarding()
        }
    }

    suspend fun placesAutocomplete(input: String): Result<List<PlaceAutocompletePrediction>> = runCatching {
        api.placesAutocomplete(input.trim()).predictions
    }

    suspend fun placesPlaceDetails(placeId: String): PlacesPlaceDetailsResponse =
        api.placesPlaceDetails(placeId.trim())

    suspend fun loginWithApple(idToken: String, name: String?, email: String?): Result<Unit> = runCatching {
        val p = firstLaunch.readPendingEstablishment()
        val estName = p.description?.trim()?.takeIf { it.isNotEmpty() }
        val r = api.authApple(
            AppleAuthRequest(
                idToken = idToken,
                name = name?.trim()?.takeIf { it.isNotEmpty() },
                email = email?.trim()?.lowercase()?.takeIf { it.isNotEmpty() },
                googlePlaceId = p.placeId,
                establishmentName = estName,
            ),
        )
        sessionStore.applyLoginResponse(r)
        if (p.placeId != null || estName != null) {
            firstLaunch.clearPendingEstablishmentFromOnboarding()
        }
    }

    suspend fun refreshAccount(): Result<Unit> = runCatching {
        if (!sessionStore.isLoggedIn || sessionStore.accessToken.isNullOrEmpty()) {
            error("Session invalide")
        }
        val me = api.me()
        sessionStore.applyMeResponse(me)
    }

    suspend fun authConfig(): AuthConfigResponse = api.authConfig()

    suspend fun performLogout() {
        runCatching {
            api.logout(LogoutRequest(refreshToken = sessionStore.refreshToken))
        }
        sessionStore.clearSession()
    }

    suspend fun forgotPassword(email: String) {
        api.forgotPassword(ForgotPasswordRequest(email.trim().lowercase()))
    }

    suspend fun deleteAccount() {
        api.deleteAccount()
        sessionStore.clearSession()
    }

    private fun httpErrorMessage(e: HttpException): String? {
        val body = e.response()?.errorBody()?.string() ?: return null
        return try {
            val o = errJson.parseToJsonElement(body).jsonObject
            o["message"]?.jsonPrimitive?.content
                ?: o["error"]?.jsonPrimitive?.content
        } catch (_: Exception) {
            null
        }
    }
}
