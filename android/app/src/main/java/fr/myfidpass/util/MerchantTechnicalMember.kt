package fr.myfidpass.util

/** Comptes techniques hors listes / stats commerçant : invités QR et aperçu Wallet. */
object MerchantTechnicalMember {
    fun shouldExcludeFromMerchantActivity(email: String?): Boolean {
        val raw = email?.trim()?.lowercase().orEmpty()
        if (raw.isEmpty()) return false
        if (raw.endsWith("@guest.invalid")) return true
        return raw.startsWith("wallet-apercu.") && raw.endsWith("@example.com")
    }
}
