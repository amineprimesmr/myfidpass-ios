package fr.myfidpass.util

import org.json.JSONObject

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

    fun dashboardAmountLine(
        type: String?,
        points: Int?,
        isPointsProgram: Boolean,
        rewardLabel: String? = null,
    ): String {
        val normalized = type?.trim()?.lowercase().orEmpty()
        if (normalized == "reward_redeem") {
            val label = rewardLabel?.trim().orEmpty()
            if (label.isNotEmpty()) return "− $label"
            val p = points
            if (p != null && p < 0) return "−${kotlin.math.abs(p)} pts"
            return "Récompense"
        }
        val p = points ?: return ""
        return if (isPointsProgram) {
            if (p >= 0) "+$p pts" else "$p pts"
        } else {
            if (p >= 0) "+$p" else "$p"
        }
    }
}
