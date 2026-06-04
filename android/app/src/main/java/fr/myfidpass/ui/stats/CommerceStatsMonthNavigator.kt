package fr.myfidpass.ui.stats

import java.time.YearMonth
import java.time.format.TextStyle
import java.util.Locale

/** Aligné `CommerceStatsMonthNavigator` iOS — clés calendaires `YYYY-MM`. */
object CommerceStatsMonthNavigator {
    private val monthKeyRegex = Regex("^\\d{4}-\\d{2}$")

    fun isCalendarMonthPeriod(value: String): Boolean = monthKeyRegex.matches(value.trim())

    fun calendarMonthKey(date: YearMonth = YearMonth.now()): String = date.toString()

    fun sixMonthKeysEndingCurrentMonth(): List<String> {
        val now = YearMonth.now()
        return (0 until 6).map { now.minusMonths(it.toLong()).toString() }
    }

    fun creationMonthKey(fromCreatedAt: String?): String? {
        val raw = fromCreatedAt?.trim().orEmpty()
        if (raw.isEmpty()) return null
        if (raw.length >= 7) {
            val prefix = raw.take(7)
            if (isCalendarMonthPeriod(prefix)) return prefix
        }
        return runCatching {
            val instant = java.time.Instant.parse(raw)
            calendarMonthKey(YearMonth.from(instant.atZone(java.time.ZoneId.systemDefault())))
        }.getOrNull()
            ?: runCatching { calendarMonthKey(YearMonth.parse(raw.take(10))) }.getOrNull()
    }

    fun monthKeys(fromCreation: String?): List<String> {
        val current = calendarMonthKey()
        val creation = creationMonthKey(fromCreation)
        if (creation == null) return sixMonthKeysEndingCurrentMonth()
        if (creation > current) return listOf(current)
        val keys = mutableListOf<String>()
        var cursor = current
        while (cursor >= creation && keys.size < 6) {
            keys.add(cursor)
            val prev = runCatching { YearMonth.parse(cursor).minusMonths(1).toString() }.getOrNull() ?: break
            cursor = prev
        }
        return keys.ifEmpty { listOf(current) }
    }

    fun displayTitleInMonth(monthKey: String): String = runCatching {
        val month = displayTitleMonthOnly(monthKey)
        "En ${month.lowercase(Locale.FRENCH)}"
    }.getOrElse { monthKey }

    fun displayTitleMonthOnly(monthKey: String): String = runCatching {
        val ym = YearMonth.parse(monthKey)
        ym.month.getDisplayName(TextStyle.FULL_STANDALONE, Locale.FRENCH)
            .replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.FRENCH) else it.toString() }
    }.getOrElse { monthKey }

    fun displayTitle(monthKey: String): String = runCatching {
        val ym = YearMonth.parse(monthKey)
        val month = ym.month.getDisplayName(TextStyle.FULL_STANDALONE, Locale.FRENCH)
        "$month ${ym.year}"
    }.getOrElse { monthKey }
}
