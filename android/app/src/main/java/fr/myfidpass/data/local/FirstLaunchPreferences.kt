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
            .apply()
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

        private const val PHASE_NEEDS = "needs"
        private const val PHASE_DONE = "done"
    }
}
