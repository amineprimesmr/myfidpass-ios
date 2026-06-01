package fr.myfidpass.data.local

import android.content.Context
import android.content.SharedPreferences
import fr.myfidpass.BuildConfig

/**
 * Aligné sur `FirstLaunchOnboarding` (iOS) : phase « commerce » avant auth au premier lancement ;
 * après déconnexion la phase ne se rejoue pas.
 */
class FirstLaunchPreferences(context: Context) {

    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun bootstrapInstallAndMigrateIfNeeded(sessionStore: SessionStore) {
        if (prefs.contains(KEY_MERCHANT_PHASE)) {
            recordLastLaunchedVersion()
            return
        }
        val previousVersion = prefs.getString(KEY_LAST_VERSION, null)
        when {
            prefs.getBoolean(KEY_LEGACY_COMPLETED, false) -> setPhaseDone()
            previousVersion != null -> setPhaseDone()
            hasLegacyActivity(sessionStore) -> setPhaseDone()
            else -> prefs.edit().putString(KEY_MERCHANT_PHASE, PHASE_NEEDS).apply()
        }
        recordLastLaunchedVersion()
    }

    private fun hasLegacyActivity(sessionStore: SessionStore): Boolean {
        if (sessionStore.isLoggedIn) return true
        if (!sessionStore.userEmail.isNullOrBlank()) return true
        if (!sessionStore.accessToken.isNullOrBlank()) return true
        val pid = prefs.getString(KEY_OB_PLACE_ID, null)?.trim().orEmpty()
        if (pid.isNotEmpty()) return true
        return false
    }

    private fun recordLastLaunchedVersion() {
        prefs.edit().putString(KEY_LAST_VERSION, BuildConfig.VERSION_NAME).apply()
    }

    val shouldShowMerchantPremisesBeforeAuth: Boolean
        get() = prefs.getString(KEY_MERCHANT_PHASE, PHASE_DONE) != PHASE_DONE

    fun markMerchantPremisesOnboardingFinished() {
        prefs.edit().putString(KEY_MERCHANT_PHASE, PHASE_DONE).apply()
    }

    fun persistPendingEstablishment(placeId: String?, description: String?, relax: Boolean) {
        val e = prefs.edit()
        if (placeId.isNullOrBlank()) e.remove(KEY_OB_PLACE_ID) else e.putString(KEY_OB_PLACE_ID, placeId.trim())
        if (description.isNullOrBlank()) e.remove(KEY_OB_PLACE_DESC) else e.putString(KEY_OB_PLACE_DESC, description.trim())
        e.putBoolean(KEY_OB_RELAX, relax)
        e.apply()
        if (!placeId.isNullOrBlank() && !description.isNullOrBlank()) {
            persistSignupCommerceDraftBackup(placeId, description)
        }
    }

    fun readPendingEstablishment(): PendingEstablishment {
        val rawId = prefs.getString(KEY_OB_PLACE_ID, null)?.trim().orEmpty()
        return PendingEstablishment(
            placeId = rawId.takeIf { it.isNotEmpty() },
            description = prefs.getString(KEY_OB_PLACE_DESC, null),
            relax = prefs.getBoolean(KEY_OB_RELAX, false),
        )
    }

    fun clearPendingEstablishmentFromOnboarding() {
        prefs.edit()
            .remove(KEY_OB_PLACE_ID)
            .remove(KEY_OB_PLACE_DESC)
            .remove(KEY_OB_RELAX)
            .remove(KEY_SIGNUP_DRAFT)
            .apply()
    }

    fun markRelaxPlaceRequirementForExistingAccountFlow() {
        prefs.edit().putBoolean(KEY_OB_RELAX, true).apply()
    }

    fun rewindToMerchantPremisesSelectionForFreshCommercePick() {
        prefs.edit().putString(KEY_MERCHANT_PHASE, PHASE_NEEDS).apply()
        clearPendingEstablishmentFromOnboarding()
    }

    fun resetAfterAccountDeletion() {
        prefs.edit()
            .putString(KEY_MERCHANT_PHASE, PHASE_NEEDS)
            .remove(KEY_LEGACY_COMPLETED)
            .remove(KEY_OB_PLACE_ID)
            .remove(KEY_OB_PLACE_DESC)
            .remove(KEY_OB_RELAX)
            .remove(KEY_SIGNUP_DRAFT)
            .remove(KEY_SIGNUP_EMAIL)
            .apply()
        restartEpoch += 1
    }

    var restartEpoch: Int
        get() = prefs.getInt(KEY_RESTART_EPOCH, 0)
        private set(value) {
            prefs.edit().putInt(KEY_RESTART_EPOCH, value).apply()
        }

    fun persistSignupCommerceDraftBackup(placeId: String, establishmentName: String) {
        val pid = placeId.trim()
        val name = establishmentName.trim()
        if (pid.isEmpty() || name.isEmpty()) {
            prefs.edit().remove(KEY_SIGNUP_DRAFT).apply()
            return
        }
        prefs.edit().putString(KEY_SIGNUP_DRAFT, """{"place_id":"$pid","establishment_name":"${name.replace("\"", "\\\"")}"}""").apply()
    }

    fun pendingCommerceDisplayTitle(): String? {
        val p = readPendingEstablishment()
        p.description?.trim()?.takeIf { it.isNotEmpty() }?.let { return it }
        val draft = prefs.getString(KEY_SIGNUP_DRAFT, null) ?: return null
        return runCatching {
            val regex = """"establishment_name"\s*:\s*"([^"]+)"""".toRegex()
            regex.find(draft)?.groupValues?.getOrNull(1)
        }.getOrNull()
    }

    fun hasCompletePendingEstablishmentForRegistration(): Boolean {
        val p = readPendingEstablishment()
        val place = p.placeId?.trim().orEmpty()
        val name = p.description?.trim().orEmpty()
        return place.isNotEmpty() && name.isNotEmpty()
    }

    /** Restaure le commerce depuis le brouillon JSON si les clés principales sont vides. */
    fun rehydratePendingEstablishmentFromAllSourcesIfNeeded() {
        if (hasCompletePendingEstablishmentForRegistration()) return
        val draft = prefs.getString(KEY_SIGNUP_DRAFT, null) ?: return
        val placeId = """"place_id"\s*:\s*"([^"]+)"""".toRegex().find(draft)?.groupValues?.getOrNull(1)?.trim().orEmpty()
        val name = """"establishment_name"\s*:\s*"([^"]+)"""".toRegex().find(draft)?.groupValues?.getOrNull(1)?.trim().orEmpty()
        if (placeId.isNotEmpty() && name.isNotEmpty()) {
            persistPendingEstablishment(placeId, name, relax = false)
        }
    }

    fun persistSignupEmail(email: String) {
        val norm = email.trim().lowercase()
        if (norm.isEmpty()) {
            prefs.edit().remove(KEY_SIGNUP_EMAIL).apply()
            return
        }
        prefs.edit().putString(KEY_SIGNUP_EMAIL, norm).apply()
    }

    fun readSignupEmail(): String? =
        prefs.getString(KEY_SIGNUP_EMAIL, null)?.trim()?.lowercase()?.takeIf { it.isNotEmpty() }

    fun clearSignupEmail() {
        prefs.edit().remove(KEY_SIGNUP_EMAIL).apply()
    }

    private fun setPhaseDone() {
        prefs.edit().putString(KEY_MERCHANT_PHASE, PHASE_DONE).apply()
    }

    data class PendingEstablishment(
        val placeId: String?,
        val description: String?,
        val relax: Boolean,
    )

    companion object {
        private const val PREFS_NAME = "myfidpass_first_launch"
        private const val KEY_MERCHANT_PHASE = "myfidpass.merchantPremises.phase"
        private const val KEY_LEGACY_COMPLETED = "myfidpass.hasCompletedFirstLaunchOnboarding"
        private const val KEY_LAST_VERSION = "myfidpass.lastLaunchedShortVersion"
        private const val KEY_OB_PLACE_ID = "myfidpass.ob.placeId"
        private const val KEY_OB_PLACE_DESC = "myfidpass.ob.placeDescription"
        private const val KEY_OB_RELAX = "myfidpass.ob.relaxPlaceRequirement"
        private const val KEY_SIGNUP_DRAFT = "myfidpass.ob.signupCommerceDraftBackup.v1"
        private const val KEY_RESTART_EPOCH = "myfidpass.firstLaunchOnboardingRestartEpoch"
        private const val KEY_SIGNUP_EMAIL = "myfidpass.ob.signupEmail"

        private const val PHASE_NEEDS = "needs"
        private const val PHASE_DONE = "done"
    }
}
