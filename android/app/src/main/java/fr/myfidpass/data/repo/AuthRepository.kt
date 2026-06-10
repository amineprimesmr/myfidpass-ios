package fr.myfidpass.data.repo

import android.content.Context
import fr.myfidpass.core.auth.JwtAccessExpiry
import fr.myfidpass.core.auth.RefreshTokenCoordinator
import fr.myfidpass.data.dto.AppleAuthRequest
import fr.myfidpass.data.dto.CheckIdentifierRequest
import fr.myfidpass.data.dto.AuthConfigResponse
import fr.myfidpass.data.dto.CheckIdentifierResponse
import fr.myfidpass.data.dto.EmailSendCodeRequest
import fr.myfidpass.data.dto.EmailVerifyRequest
import fr.myfidpass.data.dto.ForgotPasswordRequest
import fr.myfidpass.data.dto.GoogleAuthRequest
import fr.myfidpass.data.dto.LoginRequest
import fr.myfidpass.data.dto.LogoutRequest
import fr.myfidpass.data.dto.PlaceAutocompletePrediction
import fr.myfidpass.data.dto.PlacesPlaceDetailsResponse
import fr.myfidpass.data.dto.RegisterRequest
import fr.myfidpass.data.local.CardPreviewSnapshotStore
import fr.myfidpass.data.local.CommerceFlyerStore
import fr.myfidpass.data.local.NotificationSendLocalHistoryStore
import fr.myfidpass.data.local.FirstLaunchPreferences
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.network.MyfidpassApi
import fr.myfidpass.services.auth.GoogleOAuthFlow
import retrofit2.HttpException
import java.io.IOException
import java.net.SocketTimeoutException

sealed class EmailLoginResult {
    data object Success : EmailLoginResult()
    data object NoAccount : EmailLoginResult()
    data class Error(val message: String) : EmailLoginResult()
}

class AuthRepository(
    private val appContext: Context,
    private val api: MyfidpassApi,
    private val sessionStore: SessionStore,
    private val firstLaunch: FirstLaunchPreferences,
    private val refreshCoordinator: RefreshTokenCoordinator,
) {

    suspend fun login(email: String, password: String): Result<Unit> = runCatching {
        val raw = email.trim()
        val login = if (raw.contains("@")) raw.lowercase() else raw.lowercase()
        val r = api.login(LoginRequest(login, password))
        sessionStore.applyLoginResponse(r, passwordLoginField = raw)
    }

    suspend fun loginEmailReturningOutcome(email: String, password: String): EmailLoginResult {
        return try {
            val raw = email.trim()
            val login = if (raw.contains("@")) raw.lowercase() else raw.lowercase()
            val r = api.login(LoginRequest(login, password))
            sessionStore.applyLoginResponse(r, passwordLoginField = raw)
            EmailLoginResult.Success
        } catch (e: HttpException) {
            if (e.code() == 404) {
                EmailLoginResult.NoAccount
            } else {
                EmailLoginResult.Error(mapLoginError(e))
            }
        } catch (e: Exception) {
            EmailLoginResult.Error(e.message ?: "Erreur réseau")
        }
    }

    suspend fun checkIdentifier(identifier: String): CheckIdentifierResponse =
        api.checkIdentifier(CheckIdentifierRequest(identifier.trim()))

    suspend fun sendEmailOtp(email: String): Result<Unit> = runCatching {
        api.emailSendCode(EmailSendCodeRequest(email.trim().lowercase()))
        Unit
    }.recoverCatching { e ->
        if (e is HttpException) error(mapOtpSendError(e))
        else throw e
    }

    suspend fun verifyEmailOtpAndSignIn(
        email: String,
        code: String,
        isSignup: Boolean,
        name: String? = null,
    ): Result<Unit> = runCatching {
        firstLaunch.rehydratePendingEstablishmentFromAllSourcesIfNeeded()
        val pending = firstLaunch.readPendingEstablishment()
        val placeId = if (isSignup) pending.placeId?.trim()?.takeIf { it.isNotEmpty() } else null
        val estName = if (isSignup) {
            pending.description?.trim()?.takeIf { it.isNotEmpty() }?.let { if (it.length > 100) it.take(100) else it }
        } else {
            null
        }
        val r = api.emailVerify(
            EmailVerifyRequest(
                email = email.trim().lowercase(),
                code = code.filter { it.isDigit() },
                name = name?.trim()?.takeIf { it.isNotEmpty() },
                googlePlaceId = placeId,
                establishmentName = estName,
            ),
        )
        finalizeEmailOtpSignIn(r, isSignup = isSignup)
    }.recoverCatching { e ->
        if (e is HttpException) error(mapOtpVerifyError(e))
        else throw e
    }

    fun finalizeEmailOtpSignIn(r: fr.myfidpass.data.dto.AuthLoginResponse, isSignup: Boolean) {
        sessionStore.applyLoginResponse(r)
        sessionStore.authProvider = "email"
        r.user.email?.trim()?.lowercase()?.takeIf { it.isNotEmpty() }?.let {
            firstLaunch.persistSignupEmail(it)
        }
        if (isSignup) {
            val pending = firstLaunch.readPendingEstablishment()
            if (pending.placeId != null || !pending.description.isNullOrBlank()) {
                firstLaunch.clearPendingEstablishmentFromOnboarding()
            }
            firstLaunch.markMerchantPremisesOnboardingFinished()
        }
    }

    suspend fun register(
        email: String,
        password: String,
        name: String?,
    ): Result<Unit> = runCatching {
        firstLaunch.rehydratePendingEstablishmentFromAllSourcesIfNeeded()
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
            error(mapRegisterError(e))
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

    suspend fun applyGoogleOAuthCallback(parsed: GoogleOAuthFlow.ParsedCallback): Result<Unit> = runCatching {
        firstLaunch.rehydratePendingEstablishmentFromAllSourcesIfNeeded()
        sessionStore.accessToken = parsed.accessToken
        parsed.refreshToken?.let { sessionStore.refreshToken = it }
        sessionStore.authProvider = "google"
        sessionStore.isLoggedIn = true
        firstLaunch.clearPendingEstablishmentFromOnboarding()
        val me = api.me()
        sessionStore.applyMeResponse(me)
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
        refreshCoordinator.refreshSync(force = false)
        val me = api.me()
        sessionStore.applyMeResponse(me)
    }

    /** Au retour au premier plan — aligné iOS `ContentView.onChange(scenePhase)`. */
    suspend fun refreshSessionOnForeground() {
        if (!sessionStore.isLoggedIn) return
        refreshCoordinator.ensureValidAccessTokenSync()
        runCatching {
            val me = api.me()
            sessionStore.applyMeResponse(me)
        }
    }

    /** Bootstrap : true si la session locale reste utilisable malgré une erreur réseau. */
    fun canKeepLocalSessionAfterBootstrapFailure(): Boolean {
        return sessionStore.isLoggedIn &&
            !sessionStore.accessToken.isNullOrEmpty() &&
            JwtAccessExpiry.stillWithinValidityWindow(sessionStore.accessToken)
    }

    fun isTransientBootstrapError(error: Throwable?): Boolean {
        return error is IOException ||
            error is SocketTimeoutException ||
            (error is HttpException && error.code() >= 500)
    }

    suspend fun authConfig(): AuthConfigResponse = api.authConfig()

    suspend fun performLogout() {
        runCatching {
            api.logout(LogoutRequest(refreshToken = sessionStore.refreshToken))
        }
        clearLocalMerchantCachesForSessionEnd()
        sessionStore.clearSession()
    }

    suspend fun forgotPassword(email: String) {
        api.forgotPassword(ForgotPasswordRequest(email.trim().lowercase()))
    }

    suspend fun deleteAccount() {
        api.deleteAccount()
        clearLocalMerchantCachesForSessionEnd()
        sessionStore.clearSession()
        firstLaunch.resetAfterAccountDeletion()
    }

    private fun clearLocalMerchantCachesForSessionEnd() {
        CardPreviewSnapshotStore.clearAll(appContext)
        CommerceFlyerStore.clearAll(appContext)
        NotificationSendLocalHistoryStore.clearAll(appContext)
        appContext.getSharedPreferences("myfidpass.post_card_flyer_promo", Context.MODE_PRIVATE).edit().clear().apply()
    }

    private fun mapLoginError(e: HttpException): String = when (e.code()) {
        401 -> "Identifiants incorrects."
        404 -> "Aucun compte trouvé."
        else -> apiErrorMessage(e) ?: "Erreur serveur"
    }

    private fun mapRegisterError(e: HttpException): String =
        apiErrorMessage(e) ?: "Inscription impossible"

    private fun mapOtpSendError(e: HttpException): String =
        apiErrorMessage(e) ?: "Impossible d'envoyer le code. Réessayez."

    private fun mapOtpVerifyError(e: HttpException): String = when (e.code()) {
        401 -> "Code incorrect ou expiré."
        404 -> "Aucun compte trouvé pour cet e-mail."
        else -> apiErrorMessage(e) ?: "Vérification impossible"
    }

    private fun apiErrorMessage(e: HttpException): String? {
        return runCatching {
            e.response()?.errorBody()?.string()?.let { body ->
                """"error"\s*:\s*"([^"]+)"""".toRegex().find(body)?.groupValues?.getOrNull(1)
            }
        }.getOrNull()?.takeIf { it.isNotBlank() }
    }
}
