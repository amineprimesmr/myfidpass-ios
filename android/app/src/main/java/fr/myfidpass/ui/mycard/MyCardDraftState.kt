package fr.myfidpass.ui.mycard

import fr.myfidpass.data.dto.BusinessSettingsResponse
import fr.myfidpass.data.local.CardPreviewSnapshot
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/** État brouillon Ma carte — aligné iOS `MyCardView` / `MyCardPersistedSnapshot`. */
data class MyCardDraftState(
    var displayName: String = "",
    var primaryHex: String = "#FFFFFF",
    var accentHex: String = "#2563EB",
    var labelHex: String = "#000000",
    var stripDisplayMode: String = "logo",
    var stripText: String = "",
    var logoUrl: String = "",
    var programType: String = "points",
    var pointsPerEuro: Int = 1,
    var pointsPerVisit: Int = 0,
    var pointsMinAmountEur: String = "",
    var requiredStamps: Int = 10,
    var stampEmoji: String = "☕",
    var stampRewardLabel: String = "",
    var stampMidRewardLabel: String = "",
    var startGameRewardLabel: String = "",
    var tierPoints: List<String> = List(MyCardRewardsSync.SLOT_COUNT) { "" },
    var tierLabels: List<String> = List(MyCardRewardsSync.SLOT_COUNT) { "" },
    var tierMinPurchases: List<String> = List(MyCardRewardsSync.SLOT_COUNT) { "" },
    var labelMember: String = "",
    var labelRestants: String = "",
    var backTerms: String = "",
    var backContact: String = "",
    var notificationTitleOverride: String = "",
    var notificationChangeMessage: String = "",
    var welcomeBonusEnabled: Boolean = true,
    var welcomeBonusAmount: Int = 10,
    var cardBackgroundRemoteUrl: String = "",
    var cardBackgroundWasRemoved: Boolean = false,
    var pendingLogoDataUrl: String? = null,
    var pendingBackgroundDataUrl: String? = null,
    var pendingStampIconDataUrl: String? = null,
    var stampIconWasRemoved: Boolean = false,
    var serverHasStampIcon: Boolean = false,
    var previewPoints: Int = 0,
    var previewStamps: Int = 0,
) {
    val isStampsMode: Boolean get() = programType.trim().lowercase() == "stamps"

    fun applyProgramTypeSideEffects(newType: String) {
        programType = newType
        welcomeBonusEnabled = true
        welcomeBonusAmount = if (newType == "points") 10 else 1
        if (newType == "stamps") {
            requiredStamps = 10
            if (previewStamps > 10) previewStamps = 10
        } else if (newType == "points") {
            val pts = tierPoints.toMutableList()
            val labs = tierLabels.toMutableList()
            MyCardRewardsSync.fillDefaultPointsTiersIfNeeded(pts, labs)
            tierPoints = pts
            tierLabels = labs
            if (startGameRewardLabel.isBlank()) {
                startGameRewardLabel = MyCardRewardsSync.ensureStartGameRewardLabel("")
            }
        }
    }

    fun loadFrom(settings: BusinessSettingsResponse?, snapshot: CardPreviewSnapshot?) {
        settings ?: return
        displayName = settings.organizationName.orEmpty().ifBlank { snapshot?.displayName.orEmpty() }
        primaryHex = settings.backgroundColor?.takeIf { it.isNotBlank() }
            ?: snapshot?.primaryHex?.takeIf { it.isNotBlank() } ?: primaryHex
        accentHex = settings.foregroundColor?.takeIf { it.isNotBlank() }
            ?: snapshot?.accentHex?.takeIf { it.isNotBlank() } ?: accentHex
        labelHex = settings.labelColor?.takeIf { it.isNotBlank() }
            ?: snapshot?.labelHex?.takeIf { it.isNotBlank() } ?: labelHex
        stripDisplayMode = "logo"
        stripText = ""
        logoUrl = settings.logoUrl.orEmpty()
        programType = settings.programType?.ifBlank { "points" } ?: snapshot?.programType ?: "points"
        pointsPerEuro = settings.pointsPerEuro ?: 1
        pointsPerVisit = settings.pointsPerVisit ?: 0
        pointsMinAmountEur = settings.pointsMinAmountEur?.toString().orEmpty()
        requiredStamps = settings.requiredStamps ?: snapshot?.requiredStamps ?: 10
        stampEmoji = settings.stampEmoji?.ifBlank { "☕" } ?: snapshot?.stampEmoji ?: "☕"
        stampRewardLabel = settings.stampRewardLabel.orEmpty()
        stampMidRewardLabel = settings.stampMidRewardLabel.orEmpty()
        startGameRewardLabel = settings.startGameRewardLabel.orEmpty()
        backTerms = settings.backTerms.orEmpty()
        backContact = settings.backContact.orEmpty()
        labelMember = settings.labelMember.orEmpty()
        labelRestants = settings.labelRestants.orEmpty()
        welcomeBonusEnabled = settings.welcomeBonusEnabled != 0
        val pt = settings.programType?.ifBlank { "points" } ?: "points"
        welcomeBonusAmount = settings.welcomeBonusAmount ?: if (pt == "stamps") 1 else 10
        cardBackgroundRemoteUrl = if (settings.hasCardBackground == true) "remote" else ""
        serverHasStampIcon = settings.hasStampIcon == true
        val split = MyCardRewardsSync.splitPointsTiersFromApi(
            settings.pointsRewardTiers,
            settings.startGameRewardLabel,
        )
        if (split.startGameRewardLabel.isNotBlank()) {
            startGameRewardLabel = split.startGameRewardLabel
        } else {
            startGameRewardLabel = MyCardRewardsSync.ensureStartGameRewardLabel(startGameRewardLabel)
        }
        tierLabels = split.tierLabels
        tierPoints = split.tierPoints
        tierMinPurchases = split.tierMinPurchases
        if (!isStampsMode) {
            val pts = tierPoints.toMutableList()
            val labs = tierLabels.toMutableList()
            MyCardRewardsSync.sanitizeEditableTierSlots(pts, labs)
            MyCardRewardsSync.fillEmptyPointsTierSlots(pts, labs)
            tierPoints = pts
            tierLabels = labs
            if (startGameRewardLabel.isBlank()) {
                startGameRewardLabel = MyCardRewardsSync.ensureStartGameRewardLabel("")
            }
        }
        snapshot?.let { snap ->
            if (startGameRewardLabel.isBlank() && snap.startGameRewardLabel.isNotBlank()) {
                startGameRewardLabel = snap.startGameRewardLabel
            }
            if (stampRewardLabel.isBlank() && snap.stampRewardLabel.isNotBlank()) {
                stampRewardLabel = snap.stampRewardLabel
            }
            if (stampMidRewardLabel.isBlank() && snap.stampMidRewardLabel.isNotBlank()) {
                stampMidRewardLabel = snap.stampMidRewardLabel
            }
            if (tierLabels.all { it.isBlank() } && snap.tierLabels.isNotEmpty()) {
                tierLabels = snap.tierLabels
            }
            if (tierPoints.all { it.isBlank() } && snap.tierPoints.isNotEmpty()) {
                tierPoints = snap.tierPoints
            }
        }
    }

    fun missingRequirements(): List<CardMissingRequirement> =
        MyCardCompletionRequirements.missingRequirements(normalizedForSave())

    /** Complète les paliers vides avant validation / enregistrement. */
    fun normalizedForSave(): MyCardDraftState {
        val start = MyCardRewardsSync.ensureStartGameRewardLabel(startGameRewardLabel)
        if (isStampsMode) return copy(startGameRewardLabel = start)
        val pts = tierPoints.toMutableList()
        val labs = tierLabels.toMutableList()
        MyCardRewardsSync.fillEmptyPointsTierSlots(pts, labs)
        return copy(tierPoints = pts, tierLabels = labs, startGameRewardLabel = start)
    }

    fun buildSavePatch(): JsonObject = normalizedForSave().let { n ->
        buildJsonObject {
        put("organization_name", n.displayName.trim())
        put("background_color", normalizeHex(n.primaryHex))
        put("foreground_color", normalizeHex(n.accentHex))
        put("label_color", normalizeHex(n.labelHex))
        put("program_type", n.programType.trim())
        put("strip_text", "")
        put("strip_display_mode", "logo")
        put("stamp_emoji", StampIconCatalog.normalizeKey(n.stampEmoji))
        put("stamp_reward_label", n.stampRewardLabel.trim())
        put("stamp_mid_reward_label", n.stampMidRewardLabel.trim())
        val startLabel = MyCardRewardsSync.ensureStartGameRewardLabel(n.startGameRewardLabel)
        put("start_game_reward_label", startLabel)
        put("points_per_euro", n.pointsPerEuro)
        put("required_stamps", n.requiredStamps)
        if (n.pointsPerVisit > 0) put("points_per_visit", n.pointsPerVisit)
        n.pointsMinAmountEur.replace(',', '.').toDoubleOrNull()?.let { put("points_min_amount_eur", it) }
        n.labelMember.trim().takeIf { it.isNotEmpty() }?.let { put("label_member", it) }
        n.labelRestants.trim().takeIf { it.isNotEmpty() }?.let { put("label_restants", it) }
        put("welcome_bonus_enabled", if (n.welcomeBonusEnabled) 1 else 0)
        put("welcome_bonus_amount", n.welcomeBonusAmount)
        n.backTerms.trim().takeIf { it.isNotEmpty() }?.let { put("back_terms", it) }
        n.backContact.trim().takeIf { it.isNotEmpty() }?.let { put("back_contact", it) }
        n.notificationTitleOverride.trim().takeIf { it.isNotEmpty() }?.let { put("notification_title_override", it) }
        n.notificationChangeMessage.trim().takeIf { it.isNotEmpty() }?.let { put("notification_change_message", it) }
        pendingLogoDataUrl?.let { put("logo_base64", it) }
        when {
            pendingBackgroundDataUrl != null -> put("card_background_base64", pendingBackgroundDataUrl!!)
            cardBackgroundWasRemoved -> put("card_background_base64", "")
        }
        when {
            stampIconWasRemoved -> put("stamp_icon_base64", "")
            pendingStampIconDataUrl != null -> put("stamp_icon_base64", pendingStampIconDataUrl!!)
        }
        if (stampIconWasRemoved) put("stamp_icon_remove", 1)
        val tiers = MyCardRewardsSync.buildPointsRewardTiersJson(
            startLabel,
            n.tierPoints,
            n.tierLabels,
            n.tierMinPurchases,
        )
        if (tiers.isNotEmpty()) put("points_reward_tiers", tiers)
        }
    }

    /** PATCH minimal depuis la feuille « Récompenses » — sans exiger une carte complète. */
    fun buildRewardsSavePatch(): JsonObject = normalizedForSave().let { n ->
        buildJsonObject {
        put("program_type", n.programType.trim())
        put("welcome_bonus_enabled", if (n.welcomeBonusEnabled) 1 else 0)
        put("welcome_bonus_amount", n.welcomeBonusAmount)
        put("stamp_reward_label", n.stampRewardLabel.trim())
        put("stamp_mid_reward_label", n.stampMidRewardLabel.trim())
        val startLabel = MyCardRewardsSync.ensureStartGameRewardLabel(n.startGameRewardLabel)
        put("start_game_reward_label", startLabel)
        put("required_stamps", n.requiredStamps)
        val tiers = MyCardRewardsSync.buildPointsRewardTiersJson(
            startLabel,
            n.tierPoints,
            n.tierLabels,
            n.tierMinPurchases,
        )
        if (n.programType == "points") {
            if (tiers.isNotEmpty()) put("points_reward_tiers", tiers)
            put("loyalty_mode", "points_cash")
        } else {
            put("points_reward_tiers", JsonNull)
            put("loyalty_mode", "points_cash")
        }
        }
    }

    fun toSnapshot(logoUrlAfterSave: String?): CardPreviewSnapshot = CardPreviewSnapshot(
        programType = programType,
        displayName = displayName,
        primaryHex = primaryHex,
        accentHex = accentHex,
        labelHex = labelHex,
        stripDisplayMode = stripDisplayMode,
        stripText = stripText,
        logoUrl = logoUrlAfterSave ?: logoUrl.takeIf { it.isNotBlank() },
        stampEmoji = stampEmoji,
        requiredStamps = requiredStamps,
        hasLocalBackground = pendingBackgroundDataUrl != null,
        hasRemoteBackground = cardBackgroundRemoteUrl.isNotBlank() && !cardBackgroundWasRemoved,
        stampRewardLabel = stampRewardLabel,
        stampMidRewardLabel = stampMidRewardLabel,
        startGameRewardLabel = startGameRewardLabel,
        tierPoints = tierPoints,
        tierLabels = tierLabels,
        hasServerStampIcon = serverHasStampIcon || !pendingStampIconDataUrl.isNullOrBlank(),
    )

    private fun normalizeHex(raw: String): String {
        val t = raw.trim().removePrefix("#")
        return if (t.length == 6) "#$t" else raw.trim()
    }
}

fun MyCardDraftState.snapshotForDirtyCompare(): MyCardDraftState = copy(
    pendingLogoDataUrl = null,
    pendingBackgroundDataUrl = null,
    pendingStampIconDataUrl = null,
)

fun MyCardDraftState.applySavedMediaFrom(settings: BusinessSettingsResponse?): MyCardDraftState = copy(
    logoUrl = settings?.logoUrl.orEmpty(),
    pendingLogoDataUrl = null,
    cardBackgroundRemoteUrl = if (settings?.hasCardBackground == true) "remote" else "",
    pendingBackgroundDataUrl = null,
    cardBackgroundWasRemoved = settings?.hasCardBackground != true,
)
