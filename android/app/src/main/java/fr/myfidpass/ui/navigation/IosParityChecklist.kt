package fr.myfidpass.ui.navigation

/**
 * Registre de parité avec les écrans Swift (référence pour itérations).
 */
@Suppress("unused")
object IosParityChecklist {
    val auth = listOf(
        "AuthLanding + onboarding ✓",
        "Login staff + check-identifier ✓",
        "Paywall PRO Stripe checkout + reconcile ✓",
        "Session refresh iOS-parity (coalesce, transient 5xx, /me refresh) ✓",
    )
    val tabs = listOf(
        "MainTabView → DashboardView ✓ (top bar noire + staff variant)",
        "MainTabView → CampaignNotificationsView ✓ (top bar + test Passkit UI)",
        "MainTabView → Stats commerce ✓ (onglet 3 = stats, pas hub)",
        "Staff 2 onglets ✓",
        "Deep link myfidpass://scan ✓",
    )
    val dashboard = listOf(
        "Scan complet ✓", "Members import/export ✓", "Room sync illimitée ✓",
        "StatsTransactionsScreen ✓",
        "Notification rapide accueil ✓",
        "PostCardFlyerPromo sheet ✓",
    )
    val myCard = listOf(
        "MyCardEditView ✓ (5 paliers, bonus, nobg, strip mode)",
        "Test Google Wallet ✓", "WalletCardPreviewAndroid ✓",
        "Recadrage logo + photos récentes ✓",
    )
    val profile = listOf(
        "Google Business hub complet ✓",
        "Programme, flyer (hub éditeur complet), social, jeux, pronostics ✓",
        "Stats, compta, traçabilité ✓",
        "Catégories membres (réglages) ✓",
    )
    val misc = listOf(
        "AppUpdate Play Store ✓",
        "FCM + permission POST_NOTIFICATIONS ✓ (google-services.json requis)",
        "Signing release + ProGuard ✓ (keystore.properties)",
        "IAP natif Play — Stripe prod sur Android (iOS = StoreKit)",
        "Sign in with Apple — web SaaS (pas natif Android)",
    )
}
