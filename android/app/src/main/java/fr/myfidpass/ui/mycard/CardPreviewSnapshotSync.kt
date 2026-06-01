package fr.myfidpass.ui.mycard

import android.content.Context
import fr.myfidpass.data.dto.BusinessSettingsResponse
import fr.myfidpass.data.local.CardPreviewSnapshot
import fr.myfidpass.data.local.CardPreviewSnapshotStore

/** Aligne le snapshot local (accueil / complétion carte) sur GET settings — changements faits sur un autre appareil. */
object CardPreviewSnapshotSync {
    fun syncFromSettings(context: Context, slug: String, settings: BusinessSettingsResponse) {
        if (slug.isBlank()) return
        val merged = snapshotFromSettings(settings, CardPreviewSnapshotStore.load(context, slug))
        CardPreviewSnapshotStore.save(context, slug, merged)
    }

    fun snapshotFromSettings(
        settings: BusinessSettingsResponse,
        existing: CardPreviewSnapshot? = null,
    ): CardPreviewSnapshot {
        val programType = settings.programType?.ifBlank { "points" } ?: "points"
        val split = MyCardRewardsSync.splitPointsTiersFromApi(
            settings.pointsRewardTiers,
            settings.startGameRewardLabel,
        )
        val logoStrip = settings.logoUrl.orEmpty()
        val logoIcon = settings.logoIconUrl.orEmpty()
        val logoCombined = logoStrip.ifBlank { logoIcon }
        val stripMode = settings.stripDisplayMode?.trim()?.lowercase()?.takeIf { it == "text" } ?: "logo"
        return CardPreviewSnapshot(
            programType = programType,
            displayName = settings.organizationName.orEmpty().ifBlank { existing?.displayName.orEmpty() },
            primaryHex = settings.backgroundColor.orEmpty().ifBlank { existing?.primaryHex.orEmpty() },
            accentHex = settings.foregroundColor.orEmpty().ifBlank { existing?.accentHex.orEmpty() },
            labelHex = settings.labelColor.orEmpty().ifBlank { existing?.labelHex.orEmpty() },
            stripDisplayMode = stripMode,
            stripText = settings.stripText.orEmpty(),
            logoUrl = logoCombined.takeIf { it.isNotBlank() },
            stampEmoji = settings.stampEmoji.orEmpty().ifBlank { "☕" },
            requiredStamps = settings.requiredStamps ?: 10,
            hasLocalBackground = existing?.hasLocalBackground == true,
            hasRemoteBackground = settings.hasCardBackground == true,
            stampRewardLabel = settings.stampRewardLabel.orEmpty(),
            stampMidRewardLabel = settings.stampMidRewardLabel.orEmpty(),
            startGameRewardLabel = split.startGameRewardLabel,
            tierPoints = split.tierPoints,
            tierLabels = split.tierLabels,
            hasServerStampIcon = settings.hasStampIcon == true,
        )
    }
}
