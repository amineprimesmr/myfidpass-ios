package fr.myfidpass.ui.mycard

import fr.myfidpass.data.dto.PointsRewardTierDto
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

object MyCardRewardsSync {
    const val SIGNUP_REWARD_POINTS = 10

    data class SplitPointsTiers(
        val startGameRewardLabel: String,
        val tierPoints: List<String>,
        val tierLabels: List<String>,
    )

    fun splitPointsTiersFromApi(
        tiers: List<PointsRewardTierDto>?,
        apiStartGameLabel: String?,
    ): SplitPointsTiers {
        val sorted = tiers.orEmpty().sortedBy { it.points ?: 0 }
        var startGame = apiStartGameLabel.orEmpty().trim()
        val ptsOut = MutableList(5) { "" }
        val labsOut = MutableList(5) { "" }
        var slot = 0
        for (t in sorted) {
            val pts = t.points ?: continue
            val lab = t.label.orEmpty().trim()
            if (lab.isEmpty()) continue
            if (pts == SIGNUP_REWARD_POINTS) {
                if (startGame.isEmpty()) startGame = lab
                continue
            }
            if (slot >= 5) continue
            ptsOut[slot] = pts.toString()
            labsOut[slot] = lab
            slot += 1
        }
        if (startGame.isEmpty()) {
            startGame = "Boisson offerte"
        }
        sanitizeEditableTierSlots(ptsOut, labsOut)
        return SplitPointsTiers(startGame, ptsOut, labsOut)
    }

    /** Retire tout palier 10 pts des cases éditables (réservé à « Début du jeu »). */
    fun sanitizeEditableTierSlots(tierPoints: MutableList<String>, tierLabels: MutableList<String>) {
        for (i in 0 until minOf(5, tierPoints.size)) {
            if (tierPoints[i].trim().toIntOrNull() == SIGNUP_REWARD_POINTS) {
                tierPoints[i] = ""
                if (i < tierLabels.size) tierLabels[i] = ""
            }
        }
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

    /** Remplit uniquement les cases vides (ex. après chargement API incomplet). */
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

    /** Si incomplet (ex. passage Tampons → Points), remplace par les exemples produit. */
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
    ): JsonArray {
        val startLab = ensureStartGameRewardLabel(startGameRewardLabel)
        val rows = mutableListOf<Pair<Int, String>>()
        rows += SIGNUP_REWARD_POINTS to startLab
        for (i in 0 until 5) {
            val lab = tierLabels.getOrElse(i) { "" }.trim()
            val pts = tierPoints.getOrElse(i) { "" }.trim().toIntOrNull() ?: continue
            if (lab.isEmpty() || pts < 0) continue
            if (pts == SIGNUP_REWARD_POINTS && startLab.isNotEmpty()) continue
            rows += pts to lab
        }
        return buildJsonArray {
            rows.sortedBy { it.first }.forEach { (pts, lab) ->
                add(buildJsonObject { put("points", pts); put("label", lab) })
            }
        }
    }
}
