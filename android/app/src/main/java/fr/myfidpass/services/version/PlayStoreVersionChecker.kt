package fr.myfidpass.services.version

import android.content.Context
import fr.myfidpass.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.regex.Pattern

/** Vérifie une version Play Store plus récente — équivalent Android de iOS `VersionCheckManager`. */
object PlayStoreVersionChecker {

    private val client = OkHttpClient.Builder().build()
    private const val PREFS = "myfidpass_app_update"
    private const val KEY_DISMISSED = "dismissed_store_version"

    data class UpdateInfo(
        val currentVersion: String,
        val storeVersion: String,
        val playStoreUrl: String,
        val isMandatoryUpdate: Boolean = false,
    )

    suspend fun check(
        context: Context,
        packageName: String = context.packageName.removeSuffix(".debug"),
        ignoreThrottle: Boolean = false,
    ): UpdateInfo? =
        withContext(Dispatchers.IO) {
            if (!ignoreThrottle && !AppVersionUpdatePolicy.shouldRunStoreLookup(context)) {
                return@withContext null
            }
            AppVersionUpdatePolicy.recordStoreLookupAttempt(context)

            val installed = BuildConfig.VERSION_NAME.trim()
            val page = fetchPlayStorePage(packageName) ?: return@withContext null
            val storeVersion = parseStoreVersion(page) ?: return@withContext null
            if (!isStoreVersionStrictlyNewer(storeVersion, installed)) return@withContext null
            val dismissed = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_DISMISSED, null)
            if (dismissed == storeVersion) return@withContext null
            val releaseNotes = parseReleaseNotes(page)
            UpdateInfo(
                currentVersion = installed,
                storeVersion = storeVersion,
                playStoreUrl = "https://play.google.com/store/apps/details?id=$packageName",
                isMandatoryUpdate = AppVersionUpdatePolicy.isMandatoryUpdate(releaseNotes),
            )
        }

    fun dismiss(context: Context, storeVersion: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_DISMISSED, storeVersion.trim())
            .apply()
    }

    private fun fetchPlayStorePage(packageName: String): String? {
        val url = "https://play.google.com/store/apps/details?id=$packageName&hl=fr"
        val request = Request.Builder().url(url).header("User-Agent", "Mozilla/5.0").build()
        return runCatching { client.newCall(request).execute().body?.string() }.getOrNull()
    }

    private fun parseStoreVersion(html: String): String? {
        val patterns = listOf(
            Pattern.compile("\\[\\[\\[\"([0-9.]+?)\"\\]\\],"),
            Pattern.compile("Current Version</div><span[^>]*><div[^>]*><span[^>]*>([0-9.]+?)<"),
            Pattern.compile("versionString\":\"([0-9.]+?)\"")
        )
        for (p in patterns) {
            val m = p.matcher(html)
            if (m.find()) return m.group(1)?.trim()?.takeIf { it.isNotEmpty() }
        }
        return null
    }

    private fun parseReleaseNotes(html: String): String? {
        val patterns = listOf(
            Pattern.compile("\"releaseNotes\"\\s*:\\s*\"((?:\\\\.|[^\"\\\\])*)\"", Pattern.DOTALL),
            Pattern.compile("\\\\\"releaseNotes\\\\\"\\s*:\\s*\\\\\"((?:\\\\.|[^\"\\\\])*)\\\\\"", Pattern.DOTALL),
        )
        for (p in patterns) {
            val m = p.matcher(html)
            if (m.find()) {
                return m.group(1)
                    ?.replace("\\\\n", "\n")
                    ?.replace("\\n", "\n")
                    ?.trim()
                    ?.takeIf { it.isNotEmpty() }
            }
        }
        return null
    }

    private fun isStoreVersionStrictlyNewer(store: String, installed: String): Boolean {
        val a = normalizedSegments(installed)
        val b = normalizedSegments(store)
        if (a.isEmpty() || b.isEmpty()) return installed.compareTo(store) < 0
        val n = maxOf(a.size, b.size)
        for (i in 0 until n) {
            val x = a.getOrElse(i) { 0 }
            val y = b.getOrElse(i) { 0 }
            if (x < y) return true
            if (x > y) return false
        }
        return false
    }

    private fun normalizedSegments(version: String): List<Int> {
        val parts = version.trim().split(".")
        if (parts.size == 2 && parts[1].length == 2 && parts[1].startsWith("0")) {
            val major = parts[0].toIntOrNull() ?: return emptyList()
            val patch = parts[1].drop(1).toIntOrNull() ?: return emptyList()
            return listOf(major, 0, patch)
        }
        return parts.mapNotNull { it.toIntOrNull() }
    }
}
