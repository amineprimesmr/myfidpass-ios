package fr.myfidpass.ui.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.HorizontalDivider
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.res.painterResource
import fr.myfidpass.R
import fr.myfidpass.ui.mycard.CardPreviewEditZone
import fr.myfidpass.ui.mycard.StampIconCatalog
import fr.myfidpass.util.qrCodeImageBitmap
import fr.myfidpass.util.toComposeColorOr

private const val CARD_ASPECT = 375f / 478f
private const val BANNER_ASPECT = 750f / 246f
private const val HEADER_H_DP = 100f

@Composable
fun WalletCardPreviewAndroid(
    businessName: String,
    organizationLabel: String?,
    qrPayload: String,
    logoUrl: String?,
    backgroundHex: String?,
    labelHex: String?,
    accentHex: String?,
    modifier: Modifier = Modifier,
    compact: Boolean = false,
    samplePoints: Int = 120,
    sampleMemberLabel: String = "Prévisualisation",
    programType: String? = null,
    requiredStamps: Int = 10,
    previewStampsCount: Int = 0,
    stampEmoji: String? = null,
    stripDisplayMode: String? = "logo",
    stripText: String? = null,
    backgroundImageUrl: String? = null,
    pendingBackgroundDataUrl: String? = null,
    pendingLogoDataUrl: String? = null,
    memberColumnTitle: String = "MEMBRE",
    headerRightText: String = "Récompenses ↗",
    stampMidRewardLabel: String = "",
    stampRewardLabel: String = "",
    authToken: String? = null,
    completionHighlightZones: Set<CardPreviewEditZone> = emptySet(),
    onZoneTap: ((CardPreviewEditZone) -> Unit)? = null,
) {
    val isStamps = programType?.trim()?.lowercase() == "stamps"
    if (isStamps) {
        StampCardPreviewAndroid(
            businessName = businessName,
            qrPayload = qrPayload,
            logoUrl = logoUrl,
            backgroundHex = backgroundHex,
            labelHex = labelHex,
            accentHex = accentHex,
            modifier = modifier,
            compact = compact,
            requiredStamps = requiredStamps,
            previewStampsCount = previewStampsCount,
            stampEmoji = stampEmoji,
            stripDisplayMode = stripDisplayMode,
            stripText = stripText,
            pendingLogoDataUrl = pendingLogoDataUrl,
            sampleMemberLabel = sampleMemberLabel,
            memberColumnTitle = memberColumnTitle,
            headerRightText = headerRightText,
            stampMidRewardLabel = stampMidRewardLabel,
            stampRewardLabel = stampRewardLabel,
            authToken = authToken,
            completionHighlightZones = completionHighlightZones,
            onZoneTap = onZoneTap,
        )
        return
    }

    val primary = backgroundHex.toComposeColorOr(Color(0xFF0F766E))
    val labelC = labelHex.toComposeColorOr(Color.Black.copy(alpha = 0.78f))
    val accentC = accentHex.toComposeColorOr(Color(0xFF2563EB))
    val corner = if (compact) 9.dp else 14.dp
    val headH = if (compact) 70.dp else HEADER_H_DP.dp
    val context = LocalContext.current
    val bgModel = pendingBackgroundDataUrl ?: backgroundImageUrl
    val logoModel = pendingLogoDataUrl ?: logoUrl
    val hasBackground = !bgModel.isNullOrBlank()
    val headerBarColor = if (hasBackground) primary else primary

    WalletCardFrame(
        modifier = modifier,
        corner = corner,
        compact = compact,
        completionHighlightZones = completionHighlightZones,
        onZoneTap = onZoneTap,
        layoutStyle = CardPreviewPillsLayoutStyle.WALLET_POINTS,
    ) { cardWidth, cardHeight ->
        Column(Modifier.fillMaxSize()) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(headH)
                    .background(headerBarColor)
                    .then(zoneClick(onZoneTap, CardPreviewEditZone.LOGO_BAND)),
            ) {
                Row(
                    Modifier
                        .fillMaxSize()
                        .padding(horizontal = if (compact) 12.dp else 16.dp, vertical = if (compact) 7.dp else 12.dp),
                    verticalAlignment = Alignment.Top,
                ) {
                    Box(Modifier.weight(1f), contentAlignment = Alignment.TopStart) {
                        StripContent(
                            logoModel = logoModel,
                            stripDisplayMode = stripDisplayMode,
                            stripText = stripText,
                            businessName = businessName,
                            authToken = authToken,
                            context = context,
                            accentC = accentC,
                            onPrimaryBackground = true,
                        )
                    }
                    Text(
                        headerRightText,
                        color = accentC,
                        fontSize = if (compact) 10.sp else 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        textAlign = TextAlign.End,
                        modifier = Modifier
                            .weight(0.55f)
                            .then(zoneClick(onZoneTap, CardPreviewEditZone.HEADER_RIGHT)),
                    )
                }
            }

            Box(
                Modifier
                    .fillMaxWidth()
                    .height(cardWidth / BANNER_ASPECT)
                    .then(zoneClick(onZoneTap, CardPreviewEditZone.BACKGROUND_IMAGE)),
            ) {
                if (!bgModel.isNullOrBlank()) {
                    WalletPreviewImage(bgModel, authToken, context, Modifier.fillMaxSize(), ContentScale.Crop)
                } else {
                    DefaultWalletStripBanner(Modifier.fillMaxSize())
                }
            }

            Column(
                Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .background(primary),
            ) {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = if (compact) 14.dp else 20.dp),
                    verticalAlignment = Alignment.Top,
                ) {
                    Column(
                        Modifier
                            .weight(1f)
                            .then(zoneClick(onZoneTap, CardPreviewEditZone.MAIN_METRICS)),
                    ) {
                        FieldBlock("POINTS", samplePoints.toString(), labelC, accentC, Alignment.Start)
                    }
                    Column(
                        Modifier
                            .weight(1f)
                            .then(zoneClick(onZoneTap, CardPreviewEditZone.MEMBER_COLUMN)),
                        horizontalAlignment = Alignment.End,
                    ) {
                        FieldBlock(
                            memberColumnTitle.uppercase(),
                            sampleMemberLabel,
                            labelC,
                            accentC,
                            Alignment.End,
                        )
                    }
                }

                Box(
                    Modifier
                        .fillMaxWidth()
                        .weight(1f)
                        .then(zoneClick(onZoneTap, CardPreviewEditZone.CARD_APPEARANCE)),
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        Modifier
                            .fillMaxWidth(0.62f)
                            .aspectRatio(1f)
                            .then(zoneClick(onZoneTap, CardPreviewEditZone.QR_CODE)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Image(
                            bitmap = qrCodeImageBitmap(qrPayload, 320),
                            contentDescription = null,
                            modifier = Modifier
                                .fillMaxWidth(0.92f)
                                .aspectRatio(1f)
                                .background(Color.White, RoundedCornerShape(4.dp))
                                .padding(4.dp),
                        )
                    }
                }
                Spacer(Modifier.height(if (compact) 8.dp else 10.dp))
            }
        }
    }
}

@Composable
fun StampCardPreviewAndroid(
    businessName: String,
    qrPayload: String,
    logoUrl: String?,
    backgroundHex: String?,
    labelHex: String?,
    accentHex: String?,
    modifier: Modifier = Modifier,
    compact: Boolean = false,
    requiredStamps: Int = 10,
    previewStampsCount: Int = 0,
    stampEmoji: String? = "☕",
    stripDisplayMode: String? = "logo",
    stripText: String? = null,
    pendingLogoDataUrl: String? = null,
    sampleMemberLabel: String = "Prévisualisation",
    memberColumnTitle: String = "MEMBRE",
    headerRightText: String = "Récompenses ↗",
    stampMidRewardLabel: String = "",
    stampRewardLabel: String = "",
    authToken: String? = null,
    completionHighlightZones: Set<CardPreviewEditZone> = emptySet(),
    onZoneTap: ((CardPreviewEditZone) -> Unit)? = null,
) {
    val primary = backgroundHex.toComposeColorOr(Color(0xFF0F766E))
    val labelC = labelHex.toComposeColorOr(Color.Black.copy(alpha = 0.78f))
    val accentC = accentHex.toComposeColorOr(Color(0xFF2563EB))
    val corner = if (compact) 9.dp else 14.dp
    val headH = if (compact) 70.dp else HEADER_H_DP.dp
    val context = LocalContext.current
    val logoModel = pendingLogoDataUrl ?: logoUrl
    val total = maxOf(1, requiredStamps)
    val filled = previewStampsCount.coerceIn(0, total)
    val iconKey = StampIconCatalog.normalizeKey(stampEmoji)
    val cols = 5
    val rewardLabel = when {
        filled >= total -> stampRewardLabel.ifBlank { "—" }
        total <= 5 -> stampRewardLabel.ifBlank { "Récompense" }
        filled < 5 -> stampMidRewardLabel.ifBlank { "Récompense au 5ᵉ passage" }
        else -> stampRewardLabel.ifBlank { "Récompense à la carte complète" }
    }
    val dansLabel = when {
        filled >= total -> "OBJECTIF ATTEINT"
        total <= 5 -> if (total - filled == 1) "DANS 1 PASSAGE" else "DANS ${total - filled} PASSAGES"
        filled < 5 -> if (5 - filled == 1) "DANS 1 PASSAGE" else "DANS ${5 - filled} PASSAGES"
        else -> if (total - filled == 1) "DANS 1 PASSAGE" else "DANS ${total - filled} PASSAGES"
    }

    WalletCardFrame(
        modifier = modifier,
        corner = corner,
        compact = compact,
        completionHighlightZones = completionHighlightZones,
        onZoneTap = onZoneTap,
        layoutStyle = CardPreviewPillsLayoutStyle.STAMP_GRID_IN_BANNER,
    ) { cardWidth, _ ->
        Column(Modifier.fillMaxSize()) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(headH)
                    .background(primary)
                    .then(zoneClick(onZoneTap, CardPreviewEditZone.LOGO_BAND)),
            ) {
                Row(
                    Modifier
                        .fillMaxSize()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.Top,
                ) {
                    Box(Modifier.weight(1f)) {
                        StripContent(
                            logoModel, stripDisplayMode, stripText, businessName, authToken, context, accentC, true,
                        )
                    }
                    Text(
                        headerRightText,
                        color = accentC,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.then(zoneClick(onZoneTap, CardPreviewEditZone.HEADER_RIGHT)),
                    )
                }
            }

            Box(
                Modifier
                    .fillMaxWidth()
                    .height(cardWidth / BANNER_ASPECT)
                    .background(Color.White)
                    .padding(horizontal = 18.dp, vertical = 12.dp)
                    .then(zoneClick(onZoneTap, CardPreviewEditZone.MAIN_METRICS)),
            ) {
                Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    for (rowStart in 0 until total step cols) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                            for (col in 0 until cols) {
                                val i = rowStart + col
                                if (i >= total) break
                                StampCell(
                                    index = i,
                                    total = total,
                                    filled = filled,
                                    iconKey = iconKey,
                                    modifier = Modifier.weight(1f),
                                )
                            }
                        }
                    }
                }
            }

            Column(
                Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .background(primary)
                    .padding(horizontal = 16.dp, vertical = 14.dp),
            ) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
                    Column(
                        Modifier
                            .weight(1f)
                            .then(zoneClick(onZoneTap, CardPreviewEditZone.MEMBER_COLUMN)),
                    ) {
                        FieldBlock("TAMPONS", filled.toString(), labelC, accentC, Alignment.Start)
                    }
                    Column(Modifier.weight(1f), horizontalAlignment = Alignment.End) {
                        Text(
                            dansLabel,
                            fontSize = 10.sp,
                            color = labelC,
                            textAlign = TextAlign.End,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                        )
                        Text(
                            rewardLabel,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = accentC,
                            textAlign = TextAlign.End,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
                Spacer(Modifier.weight(1f))
                Box(
                    Modifier
                        .fillMaxWidth()
                        .then(zoneClick(onZoneTap, CardPreviewEditZone.QR_CODE)),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        bitmap = qrCodeImageBitmap(qrPayload, 280),
                        contentDescription = null,
                        modifier = Modifier
                            .fillMaxWidth(0.55f)
                            .aspectRatio(1f)
                            .background(Color.White, RoundedCornerShape(4.dp))
                            .padding(4.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun WalletCardFrame(
    modifier: Modifier,
    corner: androidx.compose.ui.unit.Dp,
    compact: Boolean,
    completionHighlightZones: Set<CardPreviewEditZone>,
    onZoneTap: ((CardPreviewEditZone) -> Unit)?,
    layoutStyle: CardPreviewPillsLayoutStyle,
    content: @Composable (cardWidth: androidx.compose.ui.unit.Dp, cardHeight: androidx.compose.ui.unit.Dp) -> Unit,
) {
    BoxWithConstraints(
        modifier = modifier
            .fillMaxWidth()
            .aspectRatio(CARD_ASPECT)
            .shadow(if (compact) 12.dp else 20.dp, RoundedCornerShape(corner), clip = false)
            .clip(RoundedCornerShape(corner))
            .border(1.dp, Color.White.copy(alpha = 0.35f), RoundedCornerShape(corner)),
    ) {
        content(maxWidth, maxHeight)
        if (completionHighlightZones.isNotEmpty() && onZoneTap != null) {
            val density = LocalDensity.current
            CardPreviewCompletionPillsOverlay(
                cardWidth = with(density) { maxWidth.toPx() },
                totalHeight = with(density) { maxHeight.toPx() },
                zones = completionHighlightZones,
                layoutStyle = layoutStyle,
                onTapZone = onZoneTap,
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}

@Composable
private fun StampCell(
    index: Int,
    total: Int,
    filled: Int,
    iconKey: String,
    modifier: Modifier = Modifier,
    customStampIconUrl: String? = null,
    authToken: String? = null,
    context: android.content.Context? = null,
) {
    val slotFilled = index < filled
    val giftKey = rewardIconKey(index, total)
    val emoji = giftKey?.let { StampIconCatalog.emojiFor(it) } ?: StampIconCatalog.emojiFor(iconKey)
    val alpha = if (slotFilled || isNextGiftTeaser(index, total, filled)) 1f else 0.44f
    Box(
        modifier
            .aspectRatio(1f)
            .clip(RoundedCornerShape(8.dp))
            .background(Color(0xFFF1F5F9))
            .border(1.dp, Color(0xFFE2E8F0), RoundedCornerShape(8.dp)),
        contentAlignment = Alignment.Center,
    ) {
        when {
            giftKey != null -> Text(emoji, fontSize = 20.sp, modifier = Modifier.alpha(alpha))
            !customStampIconUrl.isNullOrBlank() && context != null -> {
                WalletPreviewImage(
                    customStampIconUrl,
                    authToken,
                    context,
                    Modifier
                        .fillMaxSize(0.72f)
                        .alpha(alpha),
                    ContentScale.Fit,
                )
            }
            else -> Text(emoji, fontSize = 20.sp, modifier = Modifier.alpha(alpha))
        }
    }
}

@Composable
private fun WalletStampGridNative(
    requiredStamps: Int,
    previewStampsCount: Int,
    stampEmoji: String?,
    modifier: Modifier = Modifier,
    backgroundColor: Color = Color.White,
    customStampIconUrl: String? = null,
    authToken: String? = null,
) {
    val context = LocalContext.current
    val total = maxOf(1, requiredStamps)
    val filled = previewStampsCount.coerceIn(0, total)
    val iconKey = StampIconCatalog.normalizeKey(stampEmoji)
    val cols = 5
    Box(
        modifier
            .background(backgroundColor)
            .padding(horizontal = 14.dp, vertical = 10.dp),
    ) {
        Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            for (rowStart in 0 until total step cols) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    for (col in 0 until cols) {
                        val i = rowStart + col
                        if (i >= total) break
                        StampCell(
                            index = i,
                            total = total,
                            filled = filled,
                            iconKey = iconKey,
                            modifier = Modifier.weight(1f),
                            customStampIconUrl = customStampIconUrl,
                            authToken = authToken,
                            context = context,
                        )
                    }
                }
            }
        }
    }
}

private fun rewardIconKey(index: Int, total: Int): String? {
    if (total < 5) return null
    val lastIndex = total - 1
    val midIndex = 4
    if (index == midIndex && midIndex == lastIndex) return "giftgold"
    if (index == midIndex) return "giftsilver"
    if (index == lastIndex) return "giftgold"
    return null
}

private fun isNextGiftTeaser(index: Int, total: Int, filled: Int): Boolean {
    if (total < 5) return false
    val lastIndex = total - 1
    val midIndex = 4
    if (filled < 5 && index == midIndex) return true
    if (midIndex != lastIndex && filled >= 5 && filled < total && index == lastIndex) return true
    return false
}

@Composable
private fun DefaultWalletStripBanner(modifier: Modifier = Modifier) {
    Box(modifier) {
        Row(Modifier.fillMaxSize()) {
            repeat(10) { i ->
                Box(
                    Modifier
                        .weight(1f)
                        .fillMaxHeight()
                        .background(Color(0xFFCBD5E1).copy(alpha = 0.35f + (i % 3) * 0.12f)),
                )
            }
        }
        Box(
            Modifier
                .fillMaxSize()
                .background(
                    Brush.horizontalGradient(
                        listOf(Color.Black.copy(alpha = 0.35f), Color.Black.copy(alpha = 0.08f)),
                    ),
                ),
        )
    }
}

@Composable
private fun FieldBlock(
    label: String,
    value: String,
    labelColor: Color,
    valueColor: Color,
    align: Alignment.Horizontal,
) {
    Column(
        horizontalAlignment = align,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(label, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = labelColor, maxLines = 2)
        Text(value, fontSize = 17.sp, fontWeight = FontWeight.Normal, color = valueColor, maxLines = 3)
    }
}

@Composable
private fun StripContent(
    logoModel: String?,
    stripDisplayMode: String?,
    stripText: String?,
    businessName: String,
    authToken: String?,
    context: android.content.Context,
    accentC: Color,
    onPrimaryBackground: Boolean,
) {
        if (!logoModel.isNullOrBlank()) {
            WalletPreviewImage(
                logoModel,
                authToken,
                context,
                Modifier.fillMaxWidth(0.40f).height(46.dp),
                ContentScale.Fit,
            )
        } else {
            Image(
                painter = painterResource(R.drawable.votrelogo),
                contentDescription = "Logo du commerce, à personnaliser",
                modifier = Modifier
                    .fillMaxWidth(0.36f)
                    .height(40.dp),
                contentScale = ContentScale.Fit,
            )
        }
}

private fun zoneClick(onZoneTap: ((CardPreviewEditZone) -> Unit)?, zone: CardPreviewEditZone): Modifier =
    if (onZoneTap != null) Modifier.clickable { onZoneTap(zone) } else Modifier

private fun Color.onPrimaryMainText(labelFallback: Color): Color =
    if (luminance() > 0.55f) labelFallback else Color.White

private fun Color.onPrimaryMutedText(): Color =
    if (luminance() > 0.55f) Color.Black.copy(alpha = 0.55f) else Color.White.copy(alpha = 0.78f)

private const val GOOGLE_WALLET_OPEN_HEIGHT_RATIO = 1.46f
private const val GOOGLE_WALLET_COMPACT_HEIGHT_RATIO = 1.10f
private const val GOOGLE_WALLET_BODY_FRACTION = 0.74f
private const val GOOGLE_WALLET_HERO_FRACTION = 0.26f
private const val GOOGLE_WALLET_CORNER_FRACTION = 0.078f

private fun googleWalletRewardsHint(
    isStamps: Boolean,
    startGameRewardLabel: String,
    stampRewardLabel: String,
    tierLabels: List<String>,
): String {
    if (isStamps) {
        return stampRewardLabel.trim().ifBlank { "Configurer" }
    }
    return startGameRewardLabel.trim().ifBlank { tierLabels.firstOrNull()?.trim().orEmpty().ifBlank { "Configurer" } }
}

fun buildGoogleWalletPassBackRows(
    businessName: String,
    isStamps: Boolean,
    startGameRewardLabel: String,
    stampMidRewardLabel: String,
    stampRewardLabel: String,
    requiredStamps: Int,
    tierPoints: List<String>,
    tierLabels: List<String>,
    backTerms: String,
    backContact: String,
    memberSample: String = "Prévisualisation",
    memberEmailSample: String = "client@exemple.fr",
): List<Pair<String, String>> {
    val rewardsBody = buildString {
        val start = startGameRewardLabel.trim().ifBlank { "Boisson offerte" }
        if (isStamps) {
            append("10 tampons : ").append(start)
            if (requiredStamps > 5) {
                val mid = stampMidRewardLabel.trim()
                if (mid.isNotEmpty()) append("\n5 tampons : ").append(mid)
            }
            val finalReward = stampRewardLabel.trim()
            if (finalReward.isNotEmpty()) {
                append("\n").append(requiredStamps).append(" tampons : ").append(finalReward)
            }
        } else {
            append("10 pts : ").append(start)
            for (i in 0 until 5) {
                val pts = tierPoints.getOrElse(i) { "" }.trim()
                val label = tierLabels.getOrElse(i) { "" }.trim()
                if (pts.isNotEmpty() && label.isNotEmpty()) {
                    append("\n").append(pts).append(" pts : ").append(label)
                }
            }
        }
    }
    return buildList {
        add("Client" to memberSample)
        add("Carte" to memberEmailSample)
        add("Récompenses" to rewardsBody)
        add("Commerce" to businessName.ifBlank { "Ma boutique" })
        add("Scan" to "Présentez le QR code en caisse pour créditer votre fidélité.")
        backTerms.trim().takeIf { it.isNotEmpty() }?.let { add("Conditions" to it) }
        backContact.trim().takeIf { it.isNotEmpty() }?.let { add("Contact" to it) }
    }
}

private fun googleWalletScanIdLine(qrPayload: String): String {
    val trimmed = qrPayload.trim()
    if (trimmed.length <= 40) return trimmed
    return trimmed.take(36) + "…"
}

private fun googleWalletLogoSlotSize(cardWidth: Dp, compact: Boolean): Pair<Dp, Dp> {
    val ref = 375.dp
    val scale = maxOf(0.55f, cardWidth / ref)
    val slotW = 160.dp * scale
    val slotH = 50.dp * scale
    return if (compact) {
        minOf(slotW * 0.82f, cardWidth * 0.38f) to minOf(slotH * 0.88f, 36.dp)
    } else {
        minOf(slotW * 0.92f, cardWidth * 0.40f) to minOf(slotH * 0.96f, 46.dp)
    }
}

@Composable
private fun GoogleWalletHeaderLogo(
    logoModel: String?,
    authToken: String?,
    context: android.content.Context,
    compact: Boolean,
    slotWidth: Dp,
    slotHeight: Dp,
) {
    Box(
        Modifier
            .width(slotWidth)
            .height(slotHeight),
        contentAlignment = Alignment.TopStart,
    ) {
        if (!logoModel.isNullOrBlank()) {
            WalletPreviewImage(
                logoModel,
                authToken,
                context,
                Modifier.fillMaxSize(),
                ContentScale.Fit,
            )
        } else {
            Image(
                painter = painterResource(R.drawable.votrelogo),
                contentDescription = "Logo du commerce, à personnaliser",
                modifier = Modifier
                    .fillMaxHeight()
                    .fillMaxWidth(0.88f),
                contentScale = ContentScale.Fit,
            )
        }
    }
}

/**
 * Aperçu fidèle au pass Google Wallet ouvert (loyalty) :
 * bandeau rouge + QR centré + identifiant + bannière hero en bas.
 */
@Composable
fun GoogleWalletLoyaltyPreviewAndroid(
    businessName: String,
    qrPayload: String,
    logoUrl: String?,
    backgroundHex: String?,
    labelHex: String?,
    accentHex: String?,
    modifier: Modifier = Modifier,
    compact: Boolean = false,
    samplePoints: Int = 0,
    sampleMemberLabel: String = "Prévisualisation",
    programType: String? = null,
    requiredStamps: Int = 10,
    previewStampsCount: Int = 0,
    stampEmoji: String? = null,
    stripDisplayMode: String? = "logo",
    stripText: String? = null,
    backgroundImageUrl: String? = null,
    stampHeroImageUrl: String? = null,
    pendingBackgroundDataUrl: String? = null,
    pendingLogoDataUrl: String? = null,
    pendingStampIconDataUrl: String? = null,
    stampIconRemoteUrl: String? = null,
    stampMidRewardLabel: String = "",
    stampRewardLabel: String = "",
    startGameRewardLabel: String = "",
    tierPoints: List<String> = emptyList(),
    tierLabels: List<String> = emptyList(),
    authToken: String? = null,
    headerRightText: String = "Récompenses ↗",
    completionHighlightZones: Set<CardPreviewEditZone> = emptySet(),
    onZoneTap: ((CardPreviewEditZone) -> Unit)? = null,
    onCompletionPillTap: ((CardPreviewEditZone) -> Unit)? = null,
) {
    val isStamps = programType?.trim()?.lowercase() == "stamps"
    val primary = backgroundHex.toComposeColorOr(Color(0xFF2563EB))
    val accentC = accentHex.toComposeColorOr(Color(0xFF2563EB))
    val labelC = labelHex.toComposeColorOr(Color.Black.copy(alpha = 0.78f))
    val onPrimaryMain = primary.onPrimaryMainText(labelC)
    val onPrimaryMuted = primary.onPrimaryMutedText()
    val context = LocalContext.current
    val density = LocalDensity.current
    val logoModel = pendingLogoDataUrl ?: logoUrl
    val hasCustomHeroImage = !isStamps && (
        !pendingBackgroundDataUrl.isNullOrBlank() ||
            !backgroundImageUrl.isNullOrBlank()
    )
    val heroModel = when {
        isStamps -> null
        !pendingBackgroundDataUrl.isNullOrBlank() -> pendingBackgroundDataUrl
        !backgroundImageUrl.isNullOrBlank() -> backgroundImageUrl
        else -> null
    }
    val customStampIconModel = pendingStampIconDataUrl?.takeIf { it.isNotBlank() }
        ?: stampIconRemoteUrl?.takeIf { !StampIconCatalog.isCatalogKey(stampEmoji) && !it.isBlank() }
    val displayName = businessName.ifBlank { "Ma Carte Fidélité" }
    val scanIdLine = googleWalletScanIdLine(qrPayload)
    val heroTapZone = if (isStamps) CardPreviewEditZone.MAIN_METRICS else CardPreviewEditZone.BACKGROUND_IMAGE
    val logoNeedsSetup = CardPreviewEditZone.LOGO_BAND in completionHighlightZones
    val rewardsHeaderNeedsSetup = CardPreviewEditZone.HEADER_RIGHT in completionHighlightZones
    val pillTapHandler = onCompletionPillTap ?: onZoneTap

    BoxWithConstraints(
        modifier = modifier.fillMaxWidth(),
    ) {
        val cardWidth = maxWidth
        val corner = maxOf(
            if (compact) 22.dp else 28.dp,
            cardWidth * GOOGLE_WALLET_CORNER_FRACTION,
        )
        val heightRatio = if (compact) GOOGLE_WALLET_COMPACT_HEIGHT_RATIO else GOOGLE_WALLET_OPEN_HEIGHT_RATIO
        val totalHeight = cardWidth * heightRatio
        val bodyHeight = totalHeight * GOOGLE_WALLET_BODY_FRACTION
        val heroHeight = totalHeight * GOOGLE_WALLET_HERO_FRACTION
        val qrSize = cardWidth * if (compact) 0.40f else 0.52f
        val cardWidthPx = with(density) { cardWidth.toPx() }
        val totalHeightPx = with(density) { totalHeight.toPx() }
        val (logoSlotW, logoSlotH) = googleWalletLogoSlotSize(cardWidth, compact)

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(totalHeight)
                .shadow(if (compact) 12.dp else 18.dp, RoundedCornerShape(corner), clip = false)
                .clip(RoundedCornerShape(corner))
                .background(Color.White)
                .border(1.dp, Color.Black.copy(alpha = 0.06f), RoundedCornerShape(corner)),
        ) {
            Column(Modifier.fillMaxSize()) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(bodyHeight)
                    .background(primary),
            ) {
                if (onZoneTap != null) {
                    Box(
                        Modifier
                            .matchParentSize()
                            .then(zoneClick(onZoneTap, CardPreviewEditZone.CARD_APPEARANCE)),
                    )
                }
                Column(
                    Modifier
                        .matchParentSize()
                        .padding(horizontal = if (compact) 18.dp else 20.dp)
                        .padding(top = if (compact) 16.dp else 18.dp, bottom = if (compact) 14.dp else 16.dp),
                ) {
                Row(
                    Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.Top,
                ) {
                    Row(
                        Modifier
                            .weight(1f)
                            .then(zoneClick(onZoneTap, CardPreviewEditZone.LOGO_BAND)),
                        verticalAlignment = Alignment.Top,
                    ) {
                        Box(
                            Modifier.then(
                                if (logoNeedsSetup) {
                                    Modifier
                                        .clip(RoundedCornerShape(8.dp))
                                        .background(Color.White.copy(alpha = 0.1f))
                                        .padding(4.dp)
                                } else {
                                    Modifier
                                },
                            ),
                        ) {
                            GoogleWalletHeaderLogo(
                                logoModel,
                                authToken,
                                context,
                                compact,
                                logoSlotW,
                                logoSlotH,
                            )
                        }
                    }
                    Box(
                        Modifier
                            .weight(0.95f)
                            .then(zoneClick(onZoneTap, CardPreviewEditZone.HEADER_RIGHT)),
                        contentAlignment = Alignment.TopEnd,
                    ) {
                        Text(
                            headerRightText,
                            color = accentC,
                            fontSize = if (compact) 11.sp else 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                            textAlign = TextAlign.End,
                            modifier = if (rewardsHeaderNeedsSetup) {
                                Modifier
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(accentC.copy(alpha = 0.12f))
                                    .padding(horizontal = 8.dp, vertical = 4.dp)
                            } else {
                                Modifier
                            },
                        )
                    }
                }

                Spacer(Modifier.height(if (compact) 10.dp else 12.dp))
                HorizontalDivider(
                    color = onPrimaryMuted.copy(alpha = 0.35f),
                    thickness = 1.dp,
                )
                Spacer(Modifier.height(if (compact) 12.dp else 14.dp))

                Text(
                    displayName,
                    color = onPrimaryMain,
                    fontWeight = FontWeight.Bold,
                    fontSize = if (compact) 24.sp else 28.sp,
                    lineHeight = if (compact) 28.sp else 32.sp,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )

                Spacer(Modifier.weight(1f))

                Box(
                    Modifier
                        .fillMaxWidth()
                        .then(zoneClick(onZoneTap, CardPreviewEditZone.QR_CODE)),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        bitmap = qrCodeImageBitmap(qrPayload, if (compact) 280 else 340),
                        contentDescription = null,
                        modifier = Modifier
                            .size(qrSize)
                            .clip(RoundedCornerShape(if (compact) 12.dp else 14.dp))
                            .background(Color.White)
                            .padding(if (compact) 8.dp else 10.dp),
                    )
                }

                Spacer(Modifier.height(if (compact) 10.dp else 12.dp))

                Text(
                    scanIdLine,
                    modifier = Modifier.fillMaxWidth(),
                    color = onPrimaryMuted,
                    fontSize = if (compact) 10.sp else 11.sp,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                }
            }

            Box(
                Modifier
                    .fillMaxWidth()
                    .height(heroHeight)
                    .then(zoneClick(onZoneTap, heroTapZone)),
            ) {
                when {
                    isStamps -> {
                        WalletStampGridNative(
                            requiredStamps = requiredStamps,
                            previewStampsCount = previewStampsCount,
                            stampEmoji = stampEmoji,
                            modifier = Modifier.fillMaxSize(),
                            customStampIconUrl = customStampIconModel,
                            authToken = authToken,
                        )
                    }
                    hasCustomHeroImage && !heroModel.isNullOrBlank() -> {
                        WalletPreviewImage(
                            heroModel,
                            authToken,
                            context,
                            Modifier.fillMaxSize(),
                            ContentScale.Crop,
                        )
                    }
                    !stampHeroImageUrl.isNullOrBlank() -> {
                        WalletPreviewImage(
                            stampHeroImageUrl,
                            authToken,
                            context,
                            Modifier.fillMaxSize(),
                            ContentScale.Crop,
                        )
                    }
                    else -> DefaultWalletStripBanner(Modifier.fillMaxSize())
                }
            }
            }

            if (completionHighlightZones.isNotEmpty() && pillTapHandler != null) {
                CardPreviewCompletionPillsOverlay(
                    cardWidth = cardWidthPx,
                    totalHeight = totalHeightPx,
                    zones = completionHighlightZones,
                    layoutStyle = CardPreviewPillsLayoutStyle.GOOGLE_WALLET,
                    onTapZone = pillTapHandler,
                    modifier = Modifier.fillMaxSize(),
                )
            }
        }
    }
}

@Composable
fun GoogleWalletPassBackPreviewAndroid(
    rows: List<Pair<String, String>>,
    modifier: Modifier = Modifier,
    onTap: (() -> Unit)? = null,
) {
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Color(0xFFF2F2F2))
            .then(if (onTap != null) Modifier.clickable(onClick = onTap) else Modifier)
            .padding(horizontal = 18.dp, vertical = 14.dp),
    ) {
        Text(
            "Verso Google Wallet",
            fontWeight = FontWeight.SemiBold,
            fontSize = 13.sp,
            color = Color.Black.copy(alpha = 0.55f),
        )
        Spacer(Modifier.height(10.dp))
        rows.forEachIndexed { index, (header, body) ->
            if (index > 0) Spacer(Modifier.height(12.dp))
            Text(
                header,
                fontWeight = FontWeight.Bold,
                fontSize = 14.sp,
                color = Color.Black.copy(alpha = 0.88f),
            )
            Spacer(Modifier.height(4.dp))
            Text(
                body,
                fontSize = 13.sp,
                lineHeight = 18.sp,
                color = Color.Black.copy(alpha = 0.72f),
            )
        }
    }
}
