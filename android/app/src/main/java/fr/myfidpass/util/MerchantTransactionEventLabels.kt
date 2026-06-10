package fr.myfidpass.util

import org.json.JSONObject
import java.util.Locale
import kotlin.math.abs

object MerchantTransactionEventLabels {

    fun rewardLabelFromMetadata(metadata: String?): String? {
        val raw = metadata?.trim().orEmpty()
        if (raw.isEmpty()) return null
        return try {
            val label = JSONObject(raw).optString("reward_label").trim()
            label.ifEmpty { null }
        } catch (_: Exception) {
            null
        }
    }

    fun amountEurFromMetadata(metadata: String?): Double? {
        val raw = metadata?.trim().orEmpty()
        if (raw.isEmpty()) return null
        return try {
            val obj = JSONObject(raw)
            when {
                obj.has("amount_eur") && !obj.isNull("amount_eur") -> {
                    val v = obj.optDouble("amount_eur", Double.NaN)
                    if (v.isFinite() && v > 0) v else null
                }
                else -> null
            }
        } catch (_: Exception) {
            null
        }
    }

    fun dashboardAmountLine(
        type: String?,
        points: Int?,
        isPointsProgram: Boolean,
        rewardLabel: String? = null,
        metadata: String? = null,
        isVisit: Boolean = false,
        pointsPerEuro: Int? = null,
    ): String {
        val normalized = type?.trim()?.lowercase().orEmpty()
        if (normalized == "reward_redeem") {
            val label = rewardLabel?.trim().orEmpty()
            if (label.isNotEmpty()) return "− $label"
            val p = points
            if (p != null && p < 0) return "−${abs(p)} pts"
            return "Récompense"
        }
        if (normalized == "welcome_bonus") return "Nouveau"
        if (normalized == "points_correction") {
            resolvedDashboardAmountEur(amountEurFromMetadata(metadata), points, pointsPerEuro)?.let {
                return formatDashboardEuro(it, sign = "−")
            }
            val p = points
            if (p != null && p < 0) return "−${abs(p)} pts"
            return "Correction"
        }
        if (isPointsProgram) {
            if (isVisit && resolvedDashboardAmountEur(amountEurFromMetadata(metadata), points, pointsPerEuro) == null) {
                return "+ Visite"
            }
            resolvedDashboardAmountEur(amountEurFromMetadata(metadata), points, pointsPerEuro)?.let {
                return formatDashboardEuro(it, sign = "+")
            }
            val p = points
            if (p != null) {
                if (p > 0) return "+$p pts"
                if (p < 0) return "−${abs(p)} pts"
            }
            return "+ Visite"
        }
        val p = points ?: return ""
        return if (p >= 0) "+$p" else "$p"
    }

    private fun resolvedDashboardAmountEur(
        amountEur: Double?,
        points: Int?,
        pointsPerEuro: Int?,
    ): Double? {
        if (amountEur != null && amountEur > 0) return amountEur
        val p = points ?: return null
        val ppe = pointsPerEuro ?: return null
        if (p <= 0 || ppe <= 0) return null
        return p.toDouble() / ppe.toDouble()
    }

    private fun formatDashboardEuro(amount: Double, sign: String): String {
        val formatted = String.format(Locale.FRANCE, "%.2f", abs(amount))
        return "$sign$formatted €"
    }
}
