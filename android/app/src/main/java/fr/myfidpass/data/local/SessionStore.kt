package fr.myfidpass.data.local

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import fr.myfidpass.data.dto.AuthLoginResponse
import fr.myfidpass.data.dto.AuthMeResponse
import fr.myfidpass.data.dto.AuthRefreshResponse
import fr.myfidpass.data.dto.BusinessDto
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.Instant

private val prefsJson = Json { ignoreUnknownKeys = true }

class SessionStore(context: Context) {

    private val prefs: SharedPreferences

    init {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        prefs = EncryptedSharedPreferences.create(
            context,
            "myfidpass_session",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    var isLoggedIn: Boolean
        get() = prefs.getBoolean(KEY_LOGGED_IN, false)
        set(value) = prefs.edit().putBoolean(KEY_LOGGED_IN, value).apply()

    var accessToken: String?
        get() = prefs.getString(KEY_ACCESS, null)
        set(value) {
            if (value.isNullOrEmpty()) prefs.edit().remove(KEY_ACCESS).apply()
            else prefs.edit().putString(KEY_ACCESS, value).apply()
        }

    var refreshToken: String?
        get() = prefs.getString(KEY_REFRESH, null)
        set(value) {
            if (value.isNullOrEmpty()) prefs.edit().remove(KEY_REFRESH).apply()
            else prefs.edit().putString(KEY_REFRESH, value).apply()
        }

    var userEmail: String?
        get() = prefs.getString(KEY_EMAIL, null)
        set(value) {
            if (value.isNullOrEmpty()) prefs.edit().remove(KEY_EMAIL).apply()
            else prefs.edit().putString(KEY_EMAIL, value).apply()
        }

    var currentBusinessSlug: String?
        get() = prefs.getString(KEY_SLUG, null)
        set(value) {
            if (value.isNullOrEmpty()) prefs.edit().remove(KEY_SLUG).apply()
            else prefs.edit().putString(KEY_SLUG, value).apply()
        }

    /** Aligné `has_active_subscription` (réponse login / me). */
    var hasActiveSubscription: Boolean?
        get() = when (prefs.contains(KEY_SUB_ACTIVE)) {
            true -> prefs.getBoolean(KEY_SUB_ACTIVE, false)
            false -> null
        }
        set(value) {
            if (value == null) {
                prefs.edit().remove(KEY_SUB_ACTIVE).apply()
            } else {
                prefs.edit().putBoolean(KEY_SUB_ACTIVE, value).apply()
            }
        }

    @Suppress("unused")
    var merchantTrialEndsAt: String?
        get() = prefs.getString(KEY_TRIAL_ENDS, null)
        set(value) {
            if (value.isNullOrEmpty()) prefs.edit().remove(KEY_TRIAL_ENDS).apply()
            else prefs.edit().putString(KEY_TRIAL_ENDS, value).apply()
        }

    /**
     * Accès à l’app commerçant (comme `MerchantSubscriptionPaywallBlockingView` iOS) :
     * abonnement actif, ou essai non expiré ; si l’API n’envoie rien, on n’empêche pas l’usage.
     */
    fun isMerchantAccessGranted(): Boolean {
        if (hasActiveSubscription == true) return true
        if (hasActiveSubscription == null && merchantTrialEndsAt.isNullOrBlank()) return true
        val end = merchantTrialEndsAt?.trim()?.takeIf { it.isNotEmpty() } ?: return false
        return try {
            Instant.parse(end).isAfter(Instant.now())
        } catch (_: Exception) {
            false
        }
    }

    /** Compte admin plateforme (`is_admin` API). */
    var isAdminUser: Boolean
        get() = prefs.getBoolean(KEY_IS_ADMIN, false)
        set(value) = prefs.edit().putBoolean(KEY_IS_ADMIN, value).apply()

    fun mergeDashboardTokens(businesses: List<BusinessDto>) {
        val map = dashboardTokensMap.toMutableMap()
        for (b in businesses) {
            val slug = b.slug.trim()
            if (slug.isEmpty()) continue
            val t = b.dashboardToken?.trim().orEmpty()
            if (t.isNotEmpty()) map[slug] = t
        }
        prefs.edit().putString(KEY_DASH_MAP, prefsJson.encodeToString(map)).apply()
    }

    private val dashboardTokensMap: Map<String, String>
        get() {
            val raw = prefs.getString(KEY_DASH_MAP, null) ?: return emptyMap()
            return try {
                prefsJson.decodeFromString<Map<String, String>>(raw)
            } catch (_: Exception) {
                emptyMap()
            }
        }

    fun dashboardTokenForSlug(slug: String): String? {
        val k = slug.trim()
        if (k.isEmpty()) return null
        return dashboardTokensMap[k]
    }

    fun clearSession() {
        prefs.edit().clear().apply()
    }

    fun applyLoginResponse(r: AuthLoginResponse) {
        accessToken = r.token
        refreshToken = r.refreshToken
        mergeDashboardTokens(r.businesses)
        userEmail = r.user.email?.trim().orEmpty().ifEmpty { null }
        hasActiveSubscription = r.hasActiveSubscription
        merchantTrialEndsAt = r.merchantTrialEndsAt?.trim()?.takeIf { it.isNotEmpty() }
        isAdminUser = r.user.isAdmin == true
        if (r.businesses.isNotEmpty()) {
            if (currentBusinessSlug == null || r.businesses.none { it.slug == currentBusinessSlug }) {
                currentBusinessSlug = r.businesses.first().slug
            }
        }
        isLoggedIn = true
    }

    fun applyRefreshResponse(r: AuthRefreshResponse) {
        accessToken = r.token
        if (!r.refreshToken.isNullOrEmpty()) {
            refreshToken = r.refreshToken
        }
        // Ne pas effacer l’état d’abonnement si le refresh ne renvoie pas ces champs.
        if (r.hasActiveSubscription != null) {
            hasActiveSubscription = r.hasActiveSubscription
        }
        val trial = r.merchantTrialEndsAt?.trim()?.takeIf { it.isNotEmpty() }
        if (trial != null) {
            merchantTrialEndsAt = trial
        }
    }

    fun applyMeResponse(me: AuthMeResponse) {
        mergeDashboardTokens(me.businesses)
        me.user.email?.trim()?.takeIf { it.isNotEmpty() }?.let { userEmail = it }
        hasActiveSubscription = me.hasActiveSubscription
        merchantTrialEndsAt = me.merchantTrialEndsAt?.trim()?.takeIf { it.isNotEmpty() }
        isAdminUser = me.user.isAdmin == true
        if (me.businesses.isNotEmpty()) {
            if (currentBusinessSlug == null || me.businesses.none { it.slug == currentBusinessSlug }) {
                currentBusinessSlug = me.businesses.first().slug
            }
        }
    }

    companion object {
        private const val KEY_LOGGED_IN = "is_logged_in"
        private const val KEY_ACCESS = "access_token"
        private const val KEY_REFRESH = "refresh_token"
        private const val KEY_EMAIL = "user_email"
        private const val KEY_SLUG = "current_slug"
        private const val KEY_DASH_MAP = "dashboard_tokens_json"
        private const val KEY_SUB_ACTIVE = "has_active_subscription"
        private const val KEY_TRIAL_ENDS = "merchant_trial_ends_at"
        private const val KEY_IS_ADMIN = "is_admin_user"
    }
}
