package fr.myfidpass.util

private const val PREFIX = "MYFIDPASS_REDEEM:"

data class ParsedRewardRedeemQr(
    val memberId: String,
    val tierIndex: Int = 0,
    val points: Int = 0,
    val stampThreshold: Int? = null,
)

/** Aligné backend `reward-redeem-qr.js` — points encodés = source de vérité pour le coût. */
fun parseRewardRedeemQrPayload(raw: String): ParsedRewardRedeemQr? {
    val s = raw.trim()
    if (!s.uppercase().startsWith(PREFIX)) return null
    val parts = s.drop(PREFIX.length).split(":")
    if (parts.size < 3 || parts[0].toIntOrNull() != 1) return null
    val memberId = parts[1].trim()
    if (memberId.isEmpty()) return null
    when (parts[2].lowercase()) {
        "s" -> {
            val th = if (parts.size >= 4) parts[3].toIntOrNull() else null
            return ParsedRewardRedeemQr(memberId = memberId, stampThreshold = th?.takeIf { it > 0 })
        }
        "p" -> {
            if (parts.size < 5) return null
            val tierIndex = parts[3].toIntOrNull() ?: return null
            val points = parts[4].toIntOrNull() ?: return null
            if (tierIndex < 0 || points <= 0) return null
            return ParsedRewardRedeemQr(memberId = memberId, tierIndex = tierIndex, points = points)
        }
        else -> return null
    }
}

fun effectiveRewardRedeemPoints(apiPoints: Int?, barcode: String): Int {
    val fromApi = apiPoints ?: 0
    if (fromApi > 0) return fromApi
    val parsed = parseRewardRedeemQrPayload(barcode) ?: return 0
    if (parsed.stampThreshold != null) return parsed.stampThreshold
    return parsed.points
}

fun effectiveRewardRedeemEligible(
    apiEligible: Boolean?,
    apiPoints: Int?,
    pointsBalance: Int?,
    barcode: String,
): Boolean {
    if (apiEligible == true) return true
    if (apiEligible == false) return false
    val cost = effectiveRewardRedeemPoints(apiPoints, barcode)
    val balance = pointsBalance ?: 0
    return cost > 0 && balance >= cost
}
