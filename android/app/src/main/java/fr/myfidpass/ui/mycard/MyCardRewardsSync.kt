package fr.myfidpass.ui.mycard

import fr.myfidpass.data.dto.PointsRewardTierDto
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

object MyCardRewardsSync {
    const val SIGNUP_REWARD_POINTS = 10
    const val SLOT_COUNT = 8

    data class SplitPointsTiers(
        val startGameRewardLabel: String,
        val tierPoints: List<String>,
        val tierLabels: List<String>,
        val tierMinPurchases: List<String> = List(SLOT_COUNT) { "" },
    )

    fun splitPointsTiersFromApi(
        tiers: List<PointsRewardTierDto>?,
        apiStartGameLabel: String?,
    ): SplitPointsTiers {
        val sorted = tiers.orEmpty().sortedBy { it.points ?: 0 }
        var startGame = apiStartGameLabel.orEmpty().trim()
        val ptsOut = MutableList(SLOT_COUNT) { "" }
        val labsOut = MutableList(SLOT_COUNT) { "" }
        val minOut = MutableList(SLOT_COUNT) { "" }
        var slot = 0
        for (t in sorted) {
            val pts = t.points ?: continue
            val lab = t.label.orEmpty().trim()
            if (lab.isEmpty()) continue
            val minStr = t.minPurchaseEur?.takeIf { it > 0 }?.let(::formatMinPurchase).orEmpty()
            if (pts == SIGNUP_REWARD_POINTS) {
                if (startGame.isEmpty()) startGame = lab
                ptsOut[0] = SIGNUP_REWARD_POINTS.toString()
                labsOut[0] = lab
                minOut[0] = minStr
                continue
            }
            if (slot == 0 && ptsOut[0].isNotBlank()) slot = 1
            while (slot < SLOT_COUNT && ptsOut[slot].isNotBlank()) slot++
            if (slot >= SLOT_COUNT) continue
            ptsOut[slot] = pts.toString()
            labsOut[slot] = lab
            minOut[slot] = minStr
            slot++
        }
        if (startGame.isEmpty()) startGame = "Boisson offerte"
        if (ptsOut[0].isBlank()) ptsOut[0] = SIGNUP_REWARD_POINTS.toString()
        sanitizeEditableTierSlots(ptsOut, labsOut)
        return SplitPointsTiers(startGame, ptsOut, labsOut, minOut)
    }

    fun sanitizeEditableTierSlots(tierPoints: MutableList<String>, tierLabels: MutableList<String>) {
        for (i in 1 until minOf(SLOT_COUNT, tierPoints.size)) {
            if (tierPoints[i].trim().toIntOrNull() == SIGNUP_REWARD_POINTS) {
                tierPoints[i] = ""
                if (i < tierLabels.size) tierLabels[i] = ""
            }
        }
    }

    fun resolvedVisibleTierRowCount(tierPoints: List<String>, tierLabels: List<String>): Int {
        var lastFilled = -1
        for (i in 0 until SLOT_COUNT) {
            val p = tierPoints.getOrElse(i) { "" }.trim()
            val l = tierLabels.getOrElse(i) { "" }.trim()
            if (p.isNotEmpty() || l.isNotEmpty()) lastFilled = i
        }
        return minOf(maxOf(1, lastFilled + 1), SLOT_COUNT)
    }

    fun ensureStartGameRewardLabel(label: String): String =
        label.trim().ifEmpty { "Boisson offerte" }

    fun isPointsTiersComplete(tierPoints: List<String>, tierLabels: List<String>): Boolean {
        for (i in 0 until 5) {
            val pts = tierPoints.getOrElse(i) { "" }.trim().toIntOrNull() ?: return false
            val lab = tierLabels.getOrElse(i) { "" }.trim()
            if (lab.isEmpty() || pts < 0) return false
        }
        return true
    }

    fun fillEmptyPointsTierSlots(tierPoints: MutableList<String>, tierLabels: MutableList<String>) {
        val examplePts = listOf("50", "100", "150", "200", "250")
        val exampleLabs = listOf(
            "Dessert offert",
            "Cheese offert",
            "Menu offert",
            "Formule du jour",
            "Réduction sur l'addition",
        )
        for (i in 0 until 5) {
            while (tierPoints.size <= i) tierPoints.add("")
            while (tierLabels.size <= i) tierLabels.add("")
            if (tierPoints[i].trim().isEmpty()) tierPoints[i] = examplePts[i]
            if (tierLabels[i].trim().isEmpty()) tierLabels[i] = exampleLabs[i]
        }
    }

    fun fillDefaultPointsTiersIfNeeded(tierPoints: MutableList<String>, tierLabels: MutableList<String>) {
        fillEmptyPointsTierSlots(tierPoints, tierLabels)
        if (isPointsTiersComplete(tierPoints, tierLabels)) return
        tierPoints.clear()
        tierLabels.clear()
        tierPoints.addAll(listOf("50", "100", "150", "200", "250"))
        tierLabels.addAll(
            listOf(
                "Un café offert",
                "Un dessert offert",
                "10 % de réduction",
                "15 % de réduction",
                "Un repas offert",
            ),
        )
    }

    fun buildPointsRewardTiersJson(
        startGameRewardLabel: String,
        tierPoints: List<String>,
        tierLabels: List<String>,
        tierMinPurchases: List<String> = emptyList(),
    ): JsonArray {
        val startLab = ensureStartGameRewardLabel(startGameRewardLabel)
        val rows = mutableListOf<Triple<Int, String, Double?>>()
        val signupMin = parseMinPurchase(tierMinPurchases.getOrElse(0) { "" })
        rows += Triple(SIGNUP_REWARD_POINTS, startLab, signupMin)
        for (i in 0 until SLOT_COUNT) {
            val lab = tierLabels.getOrElse(i) { "" }.trim()
            val pts = tierPoints.getOrElse(i) { "" }.trim().toIntOrNull() ?: continue
            if (lab.isEmpty() || pts < 0) continue
            if (pts == SIGNUP_REWARD_POINTS && i > 0) continue
            if (pts == SIGNUP_REWARD_POINTS && i == 0) continue
            val min = parseMinPurchase(tierMinPurchases.getOrElse(i) { "" })
            rows += Triple(pts, lab, min)
        }
        return buildJsonArray {
            rows.sortedBy { it.first }.forEach { (pts, lab, min) ->
                add(
                    buildJsonObject {
                        put("points", pts)
                        put("label", lab)
                        if (min != null) put("min_purchase_eur", min)
                    },
                )
            }
        }
    }

    private fun parseMinPurchase(raw: String): Double? {
        val t = raw.trim().replace(",", ".")
        if (t.isEmpty()) return null
        val d = t.toDoubleOrNull() ?: return null
        if (d <= 0) return null
        return (d * 100).toInt() / 100.0
    }

    private fun formatMinPurchase(value: Double): String {
        val rounded = (value * 100).toInt() / 100.0
        return if (rounded % 1.0 == 0.0) rounded.toInt().toString() else rounded.toString().replace('.', ',')
    }
}
