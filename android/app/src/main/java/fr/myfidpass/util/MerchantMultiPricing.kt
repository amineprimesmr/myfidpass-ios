package fr.myfidpass.util

import java.util.Locale

/** Grille multi-commerces — alignée `fidelity/backend/src/lib/merchant-multi-pricing.js`. */
object MerchantMultiPricing {
    private const val MONTHLY_1_CENTS = 4_999
    private const val MONTHLY_2_TOTAL_CENTS = 8_999
    private const val MONTHLY_EXTRA_PER_SLOT_CENTS = 3_499
    private const val ANNUAL_1_REFERENCE_CENTS = 39_900

    fun monthlyTotalCents(slots: Int): Int {
        val n = slots.coerceIn(1, 5)
        if (n == 1) return MONTHLY_1_CENTS
        return MONTHLY_2_TOTAL_CENTS + maxOf(0, n - 2) * MONTHLY_EXTRA_PER_SLOT_CENTS
    }

    fun annualTotalCents(slots: Int): Int {
        val monthly = monthlyTotalCents(slots)
        return kotlin.math.round(monthly.toDouble() * ANNUAL_1_REFERENCE_CENTS / MONTHLY_1_CENTS).toInt()
    }

    data class Quote(
        val fromSlots: Int,
        val toSlots: Int,
        val fromMonthlyCents: Int,
        val toMonthlyCents: Int,
        val incrementalMonthlyCents: Int,
        val isUpgrade: Boolean,
    ) {
        val fromMonthlyLabel: String get() = formatEuro(fromMonthlyCents)
        val toMonthlyLabel: String get() = formatEuro(toMonthlyCents)
        val incrementalMonthlyLabel: String get() = formatEuro(incrementalMonthlyCents)
    }

    fun quote(fromSlots: Int, toSlots: Int): Quote {
        val from = fromSlots.coerceIn(1, 5)
        val to = toSlots.coerceIn(from, 5)
        val fromMonthly = monthlyTotalCents(from)
        val toMonthly = monthlyTotalCents(to)
        return Quote(
            fromSlots = from,
            toSlots = to,
            fromMonthlyCents = fromMonthly,
            toMonthlyCents = toMonthly,
            incrementalMonthlyCents = maxOf(0, toMonthly - fromMonthly),
            isUpgrade = to > from,
        )
    }

    fun formatEuro(cents: Int): String {
        val euros = String.format(Locale.FRANCE, "%.2f", maxOf(0, cents) / 100.0)
            .replace('.', ',')
        return "$euros €"
    }

    fun slotsToPurchase(
        usedBusinesses: Int,
        allowedBusinesses: Int,
        addingAnotherCommerce: Boolean,
    ): Int {
        val allowed = allowedBusinesses.coerceIn(1, 5)
        val used = maxOf(0, usedBusinesses)
        if (addingAnotherCommerce && used >= allowed) {
            return (allowed + 1).coerceAtMost(5)
        }
        return allowed.coerceAtLeast(1)
    }
}
