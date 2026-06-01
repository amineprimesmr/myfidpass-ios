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

    /** Source de vérité serveur (`has_paid_merchant_subscription` sur login / GET /me). */
    var serverReportsPaidMerchantSubscription: Boolean?
        get() = when (prefs.contains(KEY_SUB_PAID)) {
            true -> prefs.getBoolean(KEY_SUB_PAID, false)
            false -> null
        }
        set(value) {
            if (value == null) {
                prefs.edit().remove(KEY_SUB_PAID).apply()
            } else {
                prefs.edit().putBoolean(KEY_SUB_PAID, value).apply()
            }
        }

    /** Compte admin plateforme (`is_admin` API). */
    var isAdminUser: Boolean
        get() = prefs.getBoolean(KEY_IS_ADMIN, false)
        set(value) = prefs.edit().putBoolean(KEY_IS_ADMIN, value).apply()

    /** Admin plateforme en mode pilotage commerçant (comme iOS `adminShowsMerchantWorkspace`). */
    var adminMerchantPilotMode: Boolean
        get() = prefs.getBoolean(KEY_ADMIN_PILOT, false)
        set(value) = prefs.edit().putBoolean(KEY_ADMIN_PILOT, value).apply()

    /** `owner` | `manager` | `staff` depuis GET /me ou login. */
    var workspaceRole: String?
        get() = prefs.getString(KEY_WORKSPACE_ROLE, null)
        set(value) {
            if (value.isNullOrEmpty()) prefs.edit().remove(KEY_WORKSPACE_ROLE).apply()
            else prefs.edit().putString(KEY_WORKSPACE_ROLE, value).apply()
        }

    /** Identifiant caisse employé (persistant même si l’API omet `workspace_role`). */
    var userStaffLogin: String?
        get() = prefs.getString(KEY_STAFF_LOGIN, null)
        set(value) {
            if (value.isNullOrEmpty()) prefs.edit().remove(KEY_STAFF_LOGIN).apply()
            else prefs.edit().putString(KEY_STAFF_LOGIN, value).apply()
        }

    fun isMerchantStaffUser(): Boolean {
        if (workspaceRole == "staff") return true
        return !userStaffLogin.isNullOrBlank()
    }

    /** Abonnement Stripe / App Store encaissé — aligné iOS `hasEncashedMerchantSubscription`. */
    fun hasPaidMerchantSubscription(): Boolean = serverReportsPaidMerchantSubscription == true

    /** Paywall obligatoire post-inscription (mémoire — aligné iOS `isCompletingSignupPaywallPhase`). */
    var isCompletingSignupPaywallPhase: Boolean = false

    /** Overlay « Merci » après paiement sur le paywall post-inscription. */
    var pendingSubscriptionThankYouAfterSignup: Boolean = false

    var signupPaywallPaymentConfirmedThisSession: Boolean = false

    fun bypassesMerchantSubscriptionGate(): Boolean {
        if (isMerchantStaffUser()) return true
        if (workspaceRole?.trim()?.lowercase() == "manager" && businesses.isEmpty()) return true
        return false
    }

    fun beginSignupPaywallPhaseIfNeeded() {
        signupPaywallPaymentConfirmedThisSession = false
        if (bypassesMerchantSubscriptionGate() || hasPaidMerchantSubscription()) {
            isCompletingSignupPaywallPhase = false
            return
        }
        isCompletingSignupPaywallPhase = true
    }

    fun confirmSignupPaywallPaymentInThisSession() {
        signupPaywallPaymentConfirmedThisSession = true
    }

    fun finishSignupPaywallPhase(honorPaidThankYou: Boolean = false) {
        isCompletingSignupPaywallPhase = false
        if (honorPaidThankYou &&
            signupPaywallPaymentConfirmedThisSession &&
            hasPaidMerchantSubscription()
        ) {
            pendingSubscriptionThankYouAfterSignup = true
        }
        signupPaywallPaymentConfirmedThisSession = false
    }

    fun consumePendingSubscriptionThankYouAfterSignup() {
        pendingSubscriptionThankYouAfterSignup = false
    }

    /**
     * Campagnes manuelles + stats détaillées (hors tuile Membres) : abo payant, admin ou équipe.
     * Abonnement payant uniquement — aligné iOS `merchantProInsightsUnlocked`.
     */
    fun merchantProInsightsUnlocked(): Boolean {
        if (isAdminUser) return true
        if (isMerchantStaffUser()) return true
        return hasPaidMerchantSubscription()
    }

    /** Onglets complets (Accueil + Notifs + Commerce) vs employé (Accueil + Compte). */
    fun usesFullMerchantTabLayout(): Boolean = !isMerchantStaffUser()

    /** `email` | `google` | `apple` — aligné iOS `AuthStorage.authProvider`. */
    var authProvider: String?
        get() = prefs.getString(KEY_AUTH_PROVIDER, null)
        set(value) {
            if (value.isNullOrEmpty()) prefs.edit().remove(KEY_AUTH_PROVIDER).apply()
            else prefs.edit().putString(KEY_AUTH_PROVIDER, value).apply()
        }

    fun canManageMerchantTeam(): Boolean {
        if (isMerchantStaffUser()) return false
        val role = workspaceRole?.trim()?.lowercase().orEmpty()
        if (role.isEmpty() || role == "owner") return true
        if (role == "manager") return true
        return false
    }

    fun authProviderLabel(): String = when (authProvider?.lowercase()) {
        "google" -> "Google"
        "apple" -> "Apple"
        "phone" -> "Téléphone (SMS)"
        else -> "E-mail"
    }

    fun passwordExternalProviderLabel(): String? = when (authProvider?.lowercase()) {
        "google" -> "Géré par Google"
        "apple" -> "Géré par Apple"
        "phone" -> "Connexion par SMS (sans mot de passe)"
        else -> null
    }

    var businesses: List<BusinessDto>
        get() {
            val raw = prefs.getString(KEY_BUSINESSES, null) ?: return emptyList()
            return try {
                prefsJson.decodeFromString<List<BusinessDto>>(raw)
            } catch (_: Exception) {
                emptyList()
            }
        }
        set(value) {
            prefs.edit().putString(KEY_BUSINESSES, prefsJson.encodeToString(value)).apply()
        }

    fun switchBusiness(slug: String) {
        val k = slug.trim()
        if (k.isEmpty()) return
        if (businesses.any { it.slug == k }) {
            currentBusinessSlug = k
        }
    }

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
        isCompletingSignupPaywallPhase = false
        pendingSubscriptionThankYouAfterSignup = false
        signupPaywallPaymentConfirmedThisSession = false
        prefs.edit().clear().apply()
    }

    fun applyLoginResponse(r: AuthLoginResponse, passwordLoginField: String? = null) {
        accessToken = r.token
        refreshToken = r.refreshToken
        businesses = r.businesses
        mergeDashboardTokens(r.businesses)
        applyUserSession(r.user, passwordLoginField)
        hasActiveSubscription = r.hasActiveSubscription
        serverReportsPaidMerchantSubscription = r.hasPaidMerchantSubscription
        if (r.businesses.isNotEmpty()) {
            if (currentBusinessSlug == null || r.businesses.none { it.slug == currentBusinessSlug }) {
                currentBusinessSlug = r.businesses.first().slug
            }
        }
        isLoggedIn = true
        if (authProvider.isNullOrBlank()) {
            authProvider = "email"
        }
    }

    private fun applyUserSession(user: fr.myfidpass.data.dto.AuthUser, passwordLoginField: String? = null) {
        userEmail = user.email?.trim().orEmpty().ifEmpty { null }
        isAdminUser = user.isAdmin == true
        workspaceRole = user.workspaceRole?.trim()?.takeIf { it.isNotEmpty() }
        val apiStaff = user.staffLogin?.trim()?.takeIf { it.isNotEmpty() }
        val field = passwordLoginField?.trim()?.takeIf { it.isNotEmpty() }
        when {
            apiStaff != null -> userStaffLogin = apiStaff
            field != null && !field.contains("@") -> userStaffLogin = field.lowercase()
            workspaceRole != "staff" -> userStaffLogin = null
        }
        if (isMerchantStaffUser() && userStaffLogin != null) {
            userEmail = userStaffLogin
        }
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
        if (r.hasPaidMerchantSubscription != null) {
            serverReportsPaidMerchantSubscription = r.hasPaidMerchantSubscription
        }
    }

    fun applyMeResponse(me: AuthMeResponse) {
        businesses = me.businesses
        mergeDashboardTokens(me.businesses)
        applyUserSession(me.user)
        hasActiveSubscription = me.hasActiveSubscription
        serverReportsPaidMerchantSubscription = me.hasPaidMerchantSubscription
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
        private const val KEY_SUB_PAID = "has_paid_merchant_subscription"
        private const val KEY_IS_ADMIN = "is_admin_user"
        private const val KEY_ADMIN_PILOT = "admin_merchant_pilot"
        private const val KEY_BUSINESSES = "businesses_json"
        private const val KEY_WORKSPACE_ROLE = "workspace_role"
        private const val KEY_STAFF_LOGIN = "user_staff_login"
        private const val KEY_AUTH_PROVIDER = "auth_provider"
    }
}
