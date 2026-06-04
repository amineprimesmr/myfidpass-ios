package fr.myfidpass.services.version

import android.content.Context

/** Règles de prompting et cadence des lookups store — aligné iOS `AppVersionUpdatePolicy`. */
object AppVersionUpdatePolicy {
    private const val PREFS = "myfidpass_app_update"
    private const val KEY_LAST_LOOKUP_AT = "last_lookup_at_ms"
    const val MINIMUM_LOOKUP_INTERVAL_MS = 30L * 60L * 1000L

    fun shouldRunStoreLookup(context: Context, nowMs: Long = System.currentTimeMillis()): Boolean {
        val last = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getLong(KEY_LAST_LOOKUP_AT, 0L)
        if (last <= 0L) return true
        return nowMs - last >= MINIMUM_LOOKUP_INTERVAL_MS
    }

    fun recordStoreLookupAttempt(context: Context, atMs: Long = System.currentTimeMillis()) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putLong(KEY_LAST_LOOKUP_AT, atMs)
            .apply()
    }

    /**
     * Marqueurs Play Console (notes de version) :
     * `[force]`, `[myfidpass_force]`, `UPDATE_REQUIRED`, ou première ligne commençant par `!`.
     */
    fun isMandatoryUpdate(releaseNotes: String?): Boolean {
        val trimmed = releaseNotes?.trim().orEmpty()
        if (trimmed.isEmpty()) return false
        val lower = trimmed.lowercase()
        if (lower.contains("[force]") || lower.contains("[myfidpass_force]")) return true
        if (lower.contains("update_required")) return true
        if (trimmed.first() == '!') return true
        return false
    }
}
