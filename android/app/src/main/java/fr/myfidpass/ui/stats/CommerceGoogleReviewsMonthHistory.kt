package fr.myfidpass.ui.stats

import android.content.Context
import org.json.JSONObject
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.util.Locale

object CommerceGoogleReviewsMonthHistory {
    private const val PREFS = "myfidpass_stats_google_reviews"
    private const val HISTORY_KEY = "monthly_history_v1"
    private val monthKeyFmt = DateTimeFormatter.ofPattern("yyyy-MM")

    fun normalizedMonthKey(raw: String?): String {
        val candidate = raw?.trim().orEmpty()
        return if (CommerceStatsMonthNavigator.isCalendarMonthPeriod(candidate)) {
            candidate
        } else {
            CommerceStatsMonthNavigator.calendarMonthKey()
        }
    }

    fun previousMonthKey(key: String): String {
        return runCatching {
            val ym = YearMonth.parse(key, monthKeyFmt)
            ym.minusMonths(1).format(monthKeyFmt)
        }.getOrDefault(key)
    }

    fun readHistory(context: Context): Map<String, Int> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(HISTORY_KEY, null)
            ?.trim()
            .orEmpty()
        if (raw.isEmpty() || raw == "{}") return emptyMap()
        return runCatching {
            val json = JSONObject(raw)
            buildMap {
                json.keys().forEach { k ->
                    put(k, json.optInt(k, 0).coerceAtLeast(0))
                }
            }
        }.getOrDefault(emptyMap())
    }

    private fun writeHistory(context: Context, history: Map<String, Int>) {
        val json = JSONObject()
        history.toSortedMap().forEach { (k, v) -> json.put(k, v) }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(HISTORY_KEY, json.toString())
            .apply()
    }

    fun persistIfNeeded(context: Context, monthKey: String?, newReviews: Int) {
        val key = normalizedMonthKey(monthKey)
        val cur = newReviews.coerceAtLeast(0)
        val hist = readHistory(context).toMutableMap()
        val existing = hist[key] ?: 0
        if (cur > existing) {
            hist[key] = cur
            writeHistory(context, hist)
        }
    }

    fun trendPct(context: Context, monthKey: String?, newReviews: Int): Double? {
        val key = normalizedMonthKey(monthKey)
        val prev = readHistory(context)[previousMonthKey(key)] ?: return null
        if (prev <= 0) return null
        val cur = newReviews.coerceAtLeast(0)
        return ((cur - prev).toDouble() / prev.toDouble()) * 100.0
    }

    fun trendLabel(context: Context, monthKey: String?, newReviews: Int): String? {
        val delta = trendPct(context, monthKey, newReviews) ?: return null
        if (delta <= 0) return null
        val formatted = "%.1f".format(Locale.FRANCE, delta)
            .replace('.', ',')
        return "+$formatted%"
    }
}
