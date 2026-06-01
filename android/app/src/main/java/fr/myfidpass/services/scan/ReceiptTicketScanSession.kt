package fr.myfidpass.services.scan

/** Session plein écran scan ticket — aligné iOS `ReceiptTicketScanSession`. */
data class ReceiptTicketScanSession(
    val slug: String,
    val amountEur: Double,
    val qrPayload: String,
    val expiresAt: String? = null,
)
