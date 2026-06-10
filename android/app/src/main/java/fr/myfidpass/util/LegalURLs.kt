package fr.myfidpass.util

object LegalURLs {
    const val WEBSITE = "https://www.myfidpass.fr"
    const val TERMS = "https://www.myfidpass.fr/cgu"
    const val PRIVACY = "https://www.myfidpass.fr/politique-confidentialite"
    const val DELETE_ACCOUNT = "https://www.myfidpass.fr/supprimer-compte"
    const val SUBSCRIPTION = "https://www.myfidpass.fr/paiement"
    const val SUPPORT = "mailto:support@myfidpass.fr"
    const val STRIPE_PAYMENT_LINK = "https://buy.stripe.com/7sYcN53Z72N88et4Cr8Zq01"

    fun fidelityCardPage(slug: String): String {
        val s = slug.trim().lowercase()
        return if (s.isEmpty()) WEBSITE else "https://www.myfidpass.fr/fidelity/$s?qr=1"
    }

    /** Legacy Payment Link (sans promo préremplie). Préférer `merchantEmbeddedSaasPaymentPage`. */
    fun stripePaymentLinkWithEmail(email: String?): String {
        val e = email?.trim().orEmpty()
        return if (e.isEmpty()) STRIPE_PAYMENT_LINK else "$STRIPE_PAYMENT_LINK?prefilled_email=${java.net.URLEncoder.encode(e, Charsets.UTF_8.name())}"
    }

    /** Checkout intégré myfidpass.fr (`app_embed=1`) — aligné iOS `LegalURLs.merchantEmbeddedSaasPaymentPage`. */
    fun merchantEmbeddedSaasPaymentPage(
        prefilledEmail: String? = null,
        planAnnual: Boolean = false,
        commerceSlots: Int = 1,
        accessToken: String? = null,
        refreshToken: String? = null,
    ): String {
        val slots = commerceSlots.coerceIn(1, 5)
        val query = buildString {
            append("app_embed=1")
            append("&plan=").append(if (planAnnual) "annual" else "monthly")
            append("&commerce_slots=").append(slots)
            val e = prefilledEmail?.trim().orEmpty()
            if (e.isNotEmpty()) {
                append("&prefilled_email=").append(java.net.URLEncoder.encode(e, Charsets.UTF_8.name()))
            }
        }
        var url = "$WEBSITE/paiement?$query"
        val token = accessToken?.trim().orEmpty()
        if (token.isNotEmpty()) {
            val frag = buildString {
                append("fid_auth=").append(java.net.URLEncoder.encode(token, Charsets.UTF_8.name()))
                val rt = refreshToken?.trim().orEmpty()
                if (rt.isNotEmpty()) {
                    append("&fid_refresh=").append(java.net.URLEncoder.encode(rt, Charsets.UTF_8.name()))
                }
            }
            url = "$url#$frag"
        }
        return url
    }
}
