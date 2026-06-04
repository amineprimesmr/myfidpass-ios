package fr.myfidpass.data.local

/**
 * Combinaison plafonds scan (passages / points) → accès commerçant équivalent abonnement payant (app uniquement).
 */
object MerchantScanBenchAccess {
    const val BENCH_MAX_PASSES_PER_DAY = 2
    const val BENCH_MAX_POINTS_PER_OPERATION = 2

    fun matchesBenchCombo(passes: Int, points: Int): Boolean =
        passes == BENCH_MAX_PASSES_PER_DAY && points == BENCH_MAX_POINTS_PER_OPERATION

    fun isActive(store: SessionStore): Boolean = store.merchantScanBenchAccessActive

    fun sync(store: SessionStore, passes: Int, points: Int): Boolean {
        val active = matchesBenchCombo(passes, points)
        store.merchantScanBenchAccessActive = active
        return active
    }
}
