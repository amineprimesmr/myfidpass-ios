package fr.myfidpass.data.local

/**
 * Combinaison plafonds scan (passages / points) → accès commerçant équivalent abonnement payant (app uniquement).
 */
object MerchantScanBenchAccess {
    const val BENCH_MAX_PASSES_PER_DAY = 102
    const val BENCH_MAX_POINTS_PER_OPERATION = 102
    const val BENCH_MAX_ALLOWED_BUSINESSES = 5

    fun matchesBenchCombo(passes: Int, points: Int): Boolean =
        passes == BENCH_MAX_PASSES_PER_DAY && points == BENCH_MAX_POINTS_PER_OPERATION

    fun isActive(store: SessionStore): Boolean = store.merchantScanBenchAccessActive

    fun sync(store: SessionStore, passes: Int, points: Int): Boolean {
        val active = matchesBenchCombo(passes, points)
        store.merchantScanBenchAccessActive = active
        if (active) {
            applyFullEntitlements(store)
        }
        return active
    }

    /** Forfait max test (5 commerces) — aligné iOS `applyBenchFullEntitlementsIfActive`. */
    fun applyFullEntitlements(store: SessionStore) {
        if (!store.merchantScanBenchAccessActive) return
        if (store.bypassesMerchantSubscriptionGate()) return
        val used = maxOf(store.usedBusinesses, store.businesses.size)
        store.allowedBusinesses = BENCH_MAX_ALLOWED_BUSINESSES
        store.usedBusinesses = used
        store.canCreateBusiness = used < BENCH_MAX_ALLOWED_BUSINESSES
    }
}
