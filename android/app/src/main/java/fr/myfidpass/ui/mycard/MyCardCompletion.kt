package fr.myfidpass.ui.mycard

import fr.myfidpass.data.dto.BusinessSettingsResponse
import fr.myfidpass.data.local.CardPreviewSnapshot

enum class CardMissingRequirement(val title: String, val detail: String) {
    LogoOrBandeau(
        "Logo ou texte du bandeau",
        "Ajoutez un logo ou un texte de bandeau visible sur la carte.",
    ),
    Couleurs(
        "Couleurs de la carte",
        "Personnalisez les couleurs principales de votre carte.",
    ),
    Recompenses(
        "Récompenses du programme",
        "Définissez tous les paliers ou récompenses prévus.",
    ),
    FondPoints(
        "Image de fond (mode points)",
        "Choisissez une image pour la zone sous l'en-tête.",
    ),
    IconeTampons(
        "Icône des tampons",
        "Choisissez un emoji ou importez une icône pour les tampons.",
    ),
    ;

    val suggestedEditZone: CardPreviewEditZone
        get() = when (this) {
            LogoOrBandeau -> CardPreviewEditZone.LOGO_BAND
            Couleurs -> CardPreviewEditZone.CARD_APPEARANCE
            Recompenses -> CardPreviewEditZone.HEADER_RIGHT
            FondPoints -> CardPreviewEditZone.BACKGROUND_IMAGE
            IconeTampons -> CardPreviewEditZone.MAIN_METRICS
        }
}

object MyCardCompletionRequirements {
    private val hexRegex = Regex("^#?[0-9A-Fa-f]{6}$")

    fun missingRequirements(state: MyCardDraftState): List<CardMissingRequirement> {
        val missing = mutableListOf<CardMissingRequirement>()
        if (!hasBandeauComplet(state)) missing += CardMissingRequirement.LogoOrBandeau
        if (!hasCouleursCarte(state.primaryHex, state.accentHex, state.labelHex)) {
            missing += CardMissingRequirement.Couleurs
        }
        if (!hasRecompensesCompletes(state)) missing += CardMissingRequirement.Recompenses
        if (!hasCardBackgroundPoints(state)) missing += CardMissingRequirement.FondPoints
        if (!hasStampVisual(state)) missing += CardMissingRequirement.IconeTampons
        return missing
    }

    fun missingRequirements(
        settings: BusinessSettingsResponse?,
        snapshot: CardPreviewSnapshot?,
    ): List<CardMissingRequirement> {
        val draft = MyCardDraftState().apply { loadFrom(settings, snapshot) }
        return missingRequirements(draft)
    }

    fun isConfigured(settings: BusinessSettingsResponse?, snapshot: CardPreviewSnapshot?): Boolean =
        missingRequirements(settings, snapshot).isEmpty()

    private fun hasBandeauComplet(state: MyCardDraftState): Boolean = true

    private fun hasCouleursCarte(primary: String, accent: String, label: String): Boolean =
        isValidHex(primary) && isValidHex(accent) && isValidHex(label)

    private fun hasRecompensesCompletes(state: MyCardDraftState): Boolean {
        val startLabel = MyCardRewardsSync.ensureStartGameRewardLabel(state.startGameRewardLabel)
        if (startLabel.isBlank()) return false
        if (state.isStampsMode) {
            if (state.stampRewardLabel.trim().isEmpty()) return false
            if (state.requiredStamps > 5 && state.stampMidRewardLabel.trim().isEmpty()) return false
            return true
        }
        return MyCardRewardsSync.isPointsTiersComplete(state.tierPoints, state.tierLabels)
    }

    private fun hasCardBackgroundPoints(state: MyCardDraftState): Boolean {
        if (state.isStampsMode) return true
        if (state.pendingBackgroundDataUrl != null) return true
        if (state.cardBackgroundRemoteUrl.isNotBlank() && !state.cardBackgroundWasRemoved) return true
        return false
    }

    private fun hasStampVisual(state: MyCardDraftState): Boolean {
        if (!state.isStampsMode) return true
        if (state.stampEmoji.trim().isNotEmpty()) return true
        if (!state.pendingStampIconDataUrl.isNullOrBlank()) return true
        if (state.stampIconWasRemoved) return false
        return state.serverHasStampIcon
    }

    private fun isValidHex(value: String): Boolean {
        val v = value.trim()
        if (v.isEmpty()) return false
        return hexRegex.matches(v)
    }
}
