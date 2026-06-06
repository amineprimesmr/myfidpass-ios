package fr.myfidpass.util

import java.time.Instant
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale

/** Sous-titre date des pastilles « Dernières transactions » (accueil commerçant). */
object MerchantActivityDateFormat {
    private val timeFormatter = DateTimeFormatter.ofPattern("HH:mm", Locale.FRENCH)
    private val shortDateFormatter = DateTimeFormatter.ofPattern("d MMM", Locale.FRENCH)

    fun activitySubtitle(iso: String?): String? {
        val raw = iso?.trim().orEmpty()
        if (raw.isEmpty()) return null
        val instant = parseInstant(raw) ?: return raw.take(16).replace('T', ' ')
        val zdt = instant.atZone(ZoneId.systemDefault())
        val date = zdt.toLocalDate()
        val today = LocalDate.now(ZoneId.systemDefault())
        val time = timeFormatter.format(zdt)
        return when {
            date == today -> time
            date == today.minusDays(1) -> "Hier · $time"
            else -> {
                val days = ChronoUnit.DAYS.between(date, today)
                if (days in 2..6) "Il y a $days j" else shortDateFormatter.format(zdt)
            }
        }
    }

    private fun parseInstant(raw: String): Instant? =
        runCatching { Instant.parse(raw) }.getOrNull()
            ?: runCatching { OffsetDateTime.parse(raw).toInstant() }.getOrNull()
}
