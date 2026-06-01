package fr.myfidpass.util

object LegalURLs {
    const val WEBSITE = "https://www.myfidpass.fr"
    const val TERMS = "https://www.myfidpass.fr/cgu"
    const val PRIVACY = "https://www.myfidpass.fr/politique-confidentialite"
    const val DELETE_ACCOUNT = "https://www.myfidpass.fr/supprimer-compte"
    const val SUBSCRIPTION = "https://www.myfidpass.fr/abonnement"
    const val SUPPORT = "mailto:support@myfidpass.fr"
    const val STRIPE_PROMO =
        "https://buy.stripe.com/7sYcN53Z72N88et4Cr8Zq01?prefilled_promo_code=MYFID1EURO"

    fun fidelityCardPage(slug: String): String {
        val s = slug.trim().lowercase()
        return if (s.isEmpty()) WEBSITE else "https://www.myfidpass.fr/fidelity/$s?qr=1"
    }

    fun stripePromoWithEmail(email: String?): String {
        val e = email?.trim().orEmpty()
        return if (e.isEmpty()) STRIPE_PROMO else "$STRIPE_PROMO&prefilled_email=${java.net.URLEncoder.encode(e, Charsets.UTF_8.name())}"
    }
}
