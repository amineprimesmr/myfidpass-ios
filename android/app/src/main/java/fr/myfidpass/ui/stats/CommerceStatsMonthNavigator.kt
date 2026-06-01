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
        return (0 until 6).map { now.minusMonths(it.toLong()).toString() }.reversed()
    }

    fun monthKeys(fromCreation: String?): List<String> {
        val all = sixMonthKeysEndingCurrentMonth()
        val creation = fromCreation?.trim()?.takeIf { it.length >= 7 && isCalendarMonthPeriod(it.take(7)) }
            ?.take(7)
        if (creation == null) return all
        val filtered = all.filter { it >= creation }
        return filtered.ifEmpty { listOf(calendarMonthKey()) }
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
