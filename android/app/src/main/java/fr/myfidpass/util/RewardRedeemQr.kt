package fr.myfidpass.util

private const val PREFIX = "MYFIDPASS_REDEEM:"

data class ParsedRewardRedeemQr(
    val memberId: String,
    val tierIndex: Int,
    val points: Int,
)

/** Aligné backend `reward-redeem-qr.js` — points encodés = source de vérité pour le coût. */
fun parseRewardRedeemQrPayload(raw: String): ParsedRewardRedeemQr? {
    val s = raw.trim()
    if (!s.uppercase().startsWith(PREFIX)) return null
    val parts = s.drop(PREFIX.length).split(":")
    if (parts.size < 5 || parts[0].toIntOrNull() != 1) return null
    if (parts[2].lowercase() != "p") return null
    val memberId = parts[1].trim()
    if (memberId.isEmpty()) return null
    val tierIndex = parts[3].toIntOrNull() ?: return null
    val points = parts[4].toIntOrNull() ?: return null
    if (tierIndex < 0 || points <= 0) return null
    return ParsedRewardRedeemQr(memberId = memberId, tierIndex = tierIndex, points = points)
}

fun effectiveRewardRedeemPoints(apiPoints: Int?, barcode: String): Int {
    val fromApi = apiPoints ?: 0
    if (fromApi > 0) return fromApi
    return parseRewardRedeemQrPayload(barcode)?.points ?: 0
}

fun effectiveRewardRedeemEligible(apiPoints: Int?, pointsBalance: Int?, barcode: String): Boolean {
    val cost = effectiveRewardRedeemPoints(apiPoints, barcode)
    val balance = pointsBalance ?: 0
    return cost > 0 && balance >= cost
}
