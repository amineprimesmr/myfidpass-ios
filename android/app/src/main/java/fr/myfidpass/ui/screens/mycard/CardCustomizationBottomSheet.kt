package fr.myfidpass.ui.screens.mycard

import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.outlined.PhotoLibrary
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import fr.myfidpass.ui.mycard.MyCardRewardsSync
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.ui.components.CardColorPresets
import fr.myfidpass.ui.components.LogoRecentPhotosRow
import fr.myfidpass.ui.mycard.CardPreviewEditZone
import fr.myfidpass.ui.mycard.MyCardDraftState
import fr.myfidpass.ui.mycard.StampIconCatalog
import fr.myfidpass.util.toComposeColorOr

private val SheetBg = Color(0xFFF2F2F7)
private val CardBg = Color.White
private val BorderColor = Color.Black.copy(alpha = 0.12f)
private val LinkBlue = Color(0xFF007AFF)
private val Muted = Color.Black.copy(alpha = 0.55f)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CardCustomizationBottomSheet(
    zone: CardPreviewEditZone,
    draft: MyCardDraftState,
    onDraftChange: (MyCardDraftState) -> Unit,
    onDismiss: () -> Unit,
    onApplyExamples: () -> Unit = {},
    onSaveRewards: () -> Unit = {},
    canSaveRewards: Boolean = true,
    rewardsSaving: Boolean = false,
    onPickLogo: () -> Unit = {},
    onPickLogoUri: (Uri) -> Unit = {},
    onPickBackground: () -> Unit = {},
    onPickStampIcon: () -> Unit = {},
    onLogoNobg: () -> Unit = {},
    onRemoveLogo: () -> Unit = {},
    onRemoveBackground: () -> Unit = {},
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = SheetBg,
        dragHandle = null,
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(top = 8.dp, bottom = 28.dp),
        ) {
            Text(
                zone.title,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center,
                fontWeight = FontWeight.SemiBold,
                fontSize = 17.sp,
            )
            Spacer(Modifier.height(12.dp))
            when (zone) {
                CardPreviewEditZone.LOGO_BAND -> LogoBandSheet(
                    onPickLogo, onPickLogoUri, onLogoNobg, onRemoveLogo,
                )
                CardPreviewEditZone.HEADER_RIGHT -> RewardsSheet(
                    draft, onDraftChange, onApplyExamples, onSaveRewards, canSaveRewards, rewardsSaving,
                )
                CardPreviewEditZone.BACKGROUND_IMAGE -> ImagePickerSheet(
                    onPickBackground, onRemoveBackground, onPickLogoUri, isBackground = true,
                )
                CardPreviewEditZone.CARD_APPEARANCE -> ColorsSheet(draft, onDraftChange)
                CardPreviewEditZone.MAIN_METRICS -> MetricsSheet(
                    draft, onDraftChange, onPickBackground, onPickStampIcon, onPickLogoUri, onRemoveBackground,
                )
                CardPreviewEditZone.MEMBER_COLUMN -> MemberSheet(draft, onDraftChange)
                CardPreviewEditZone.QR_CODE -> Text(
                    "Le QR ouvre votre page fidélité publique.",
                    color = Muted,
                    modifier = Modifier.padding(vertical = 8.dp),
                )
                CardPreviewEditZone.WALLET_PASS_BACK -> PassBackSheet(draft, onDraftChange)
            }
            if (zone != CardPreviewEditZone.HEADER_RIGHT &&
                zone != CardPreviewEditZone.LOGO_BAND &&
                zone != CardPreviewEditZone.BACKGROUND_IMAGE &&
                zone != CardPreviewEditZone.MAIN_METRICS
            ) {
                Spacer(Modifier.height(16.dp))
                SheetPrimaryButton("Appliquer", enabled = true, onClick = onDismiss)
            }
        }
    }
}

@Composable
private fun LogoBandSheet(
    onPickLogo: () -> Unit,
    onPickLogoUri: (Uri) -> Unit,
    onLogoNobg: () -> Unit,
    onRemoveLogo: () -> Unit,
) {
    LogoRecentPhotosRow(onPhotoSelected = onPickLogoUri)
    Spacer(Modifier.height(10.dp))
    SheetActionCard {
        SheetActionRow(Icons.Outlined.PhotoLibrary, "Galerie", LinkBlue, onPickLogo)
        HorizontalDivider(modifier = Modifier.padding(start = 50.dp), color = BorderColor)
        SheetActionRow(null, "Retirer le fond du logo (IA)", LinkBlue, onLogoNobg)
        HorizontalDivider(modifier = Modifier.padding(start = 16.dp), color = BorderColor)
        SheetActionRow(null, "Supprimer le logo", Color.Red, onRemoveLogo)
    }
}

@Composable
private fun ImagePickerSheet(
    onPickGallery: () -> Unit,
    onRemove: () -> Unit,
    onPickUri: (Uri) -> Unit,
    isBackground: Boolean,
) {
    LogoRecentPhotosRow(onPhotoSelected = onPickUri)
    Spacer(Modifier.height(10.dp))
    SheetActionCard {
        SheetActionRow(Icons.Outlined.PhotoLibrary, "Galerie", LinkBlue, onPickGallery)
        if (isBackground) {
            HorizontalDivider(modifier = Modifier.padding(start = 50.dp), color = BorderColor)
            SheetActionRow(null, "Supprimer", Color.Red, onRemove)
        }
    }
}

@Composable
private fun RewardsSheet(
    draft: MyCardDraftState,
    onDraftChange: (MyCardDraftState) -> Unit,
    onApplyExamples: () -> Unit,
    onSaveRewards: () -> Unit,
    canSaveRewards: Boolean,
    rewardsSaving: Boolean,
) {
    var visibleTierRows by remember(draft.tierPoints, draft.tierLabels) {
        mutableStateOf(
            MyCardRewardsSync.resolvedVisibleTierRowCount(draft.tierPoints, draft.tierLabels),
        )
    }
    SheetPrimaryButton(
        label = "Enregistrer",
        enabled = canSaveRewards && !rewardsSaving,
        loading = rewardsSaving,
        onClick = onSaveRewards,
    )
    Spacer(Modifier.height(14.dp))
    if (draft.isStampsMode) {
        WelcomeStampCard()
    }
    Spacer(Modifier.height(12.dp))
    HorizontalDivider(color = BorderColor)
    Spacer(Modifier.height(12.dp))
    if (draft.isStampsMode) {
        StampRewardRow("Début du jeu", draft.startGameRewardLabel, "Boisson offerte") {
            onDraftChange(draft.copy(startGameRewardLabel = it))
        }
        StampRewardRow("5e", draft.stampMidRewardLabel, "-50 % sur l'addition") {
            onDraftChange(draft.copy(stampMidRewardLabel = it))
        }
        StampRewardRow("10e", draft.stampRewardLabel, "Une récompense offerte") {
            onDraftChange(draft.copy(stampRewardLabel = it))
        }
    } else {
        val examples = listOf("10", "50", "100", "150", "200", "250", "300", "350")
        val rewardExamples = listOf(
            "Boisson offerte", "Dessert offert", "Cheese offert", "Menu offert",
            "Formule du jour", "Réduction sur l'addition", "Cadeau surprise", "Offre spéciale",
        )
        for (i in 0 until visibleTierRows) {
            val lockedLeft = i == 0
            PointsRewardRow(
                left = if (lockedLeft) "10 pts" else draft.tierPoints.getOrElse(i) { "" },
                leftPlaceholder = examples.getOrElse(i) { "" },
                leftTint = if (lockedLeft) LinkBlue else Color.Black,
                value = if (lockedLeft) draft.startGameRewardLabel else draft.tierLabels.getOrElse(i) { "" },
                placeholder = rewardExamples.getOrElse(i) { "" },
                lockedLeft = lockedLeft,
                minPurchase = draft.tierMinPurchases.getOrElse(i) { "" },
                onMinPurchaseChange = { v ->
                    val mins = draft.tierMinPurchases.toMutableList()
                    while (mins.size <= i) mins.add("")
                    mins[i] = v.filter { it.isDigit() || it == ',' || it == '.' }
                    onDraftChange(draft.copy(tierMinPurchases = mins))
                },
                onLeftChange = if (lockedLeft) null else { v ->
                    val pts = draft.tierPoints.toMutableList()
                    while (pts.size <= i) pts.add("")
                    pts[i] = v.filter { it.isDigit() }
                    onDraftChange(draft.copy(tierPoints = pts))
                },
            ) { v ->
                if (lockedLeft) {
                    onDraftChange(draft.copy(startGameRewardLabel = v))
                } else {
                    val labs = draft.tierLabels.toMutableList()
                    while (labs.size <= i) labs.add("")
                    labs[i] = v
                    onDraftChange(draft.copy(tierLabels = labs))
                }
            }
        }
        if (visibleTierRows < MyCardRewardsSync.SLOT_COUNT) {
            AddRewardRow(onClick = { visibleTierRows += 1 })
        }
    }
    Spacer(Modifier.height(8.dp))
    SheetSecondaryGlassButton(label = "Appliquer les exemples", onClick = onApplyExamples)
}

@Composable
private fun AddRewardRow(onClick: () -> Unit) {
    Spacer(Modifier.height(10.dp))
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 2.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Box(
            Modifier
                .width(76.dp)
                .height(44.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(CardBg)
                .border(1.dp, BorderColor, RoundedCornerShape(12.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.Add, contentDescription = null, tint = LinkBlue, modifier = Modifier.size(18.dp))
        }
        Box(
            Modifier
                .weight(1f)
                .clip(RoundedCornerShape(12.dp))
                .background(CardBg)
                .border(1.dp, BorderColor, RoundedCornerShape(12.dp))
                .padding(horizontal = 12.dp, vertical = 12.dp),
        ) {
            Text("Ajouter une récompense", color = Muted, fontSize = 15.sp)
        }
    }
}

@Composable
private fun SheetSecondaryGlassButton(label: String, onClick: () -> Unit) {
    Box(
        Modifier
            .fillMaxWidth()
            .height(44.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.72f))
            .border(1.dp, Color.Black.copy(alpha = 0.06f), RoundedCornerShape(16.dp))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, fontWeight = FontWeight.Medium, color = Color.Black.copy(alpha = 0.72f), fontSize = 15.sp)
    }
}

@Composable
private fun WelcomeStampCard() {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(CardBg)
            .border(1.dp, BorderColor, RoundedCornerShape(14.dp))
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Text("🎁", fontSize = 20.sp)
        Spacer(Modifier.width(10.dp))
        Column {
            Text("Tampon de bienvenue", fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
            Text("1 tampon offert au 1er ajout Wallet", fontSize = 13.sp, color = Muted)
        }
    }
}

@Composable
private fun StampRewardRow(
    left: String,
    value: String,
    placeholder: String,
    onChange: (String) -> Unit,
) {
    Spacer(Modifier.height(10.dp))
    RewardFieldRow(
        leftContent = {
            Box(
                Modifier
                    .width(76.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(CardBg.copy(alpha = 0.6f))
                    .border(1.dp, BorderColor, RoundedCornerShape(12.dp))
                    .padding(vertical = 12.dp, horizontal = 6.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(left, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, textAlign = TextAlign.Center)
            }
        },
        value = value,
        placeholder = placeholder,
        onChange = onChange,
    )
}

@Composable
private fun PointsRewardRow(
    left: String,
    leftPlaceholder: String = left,
    leftTint: Color,
    value: String,
    placeholder: String,
    lockedLeft: Boolean,
    minPurchase: String = "",
    onMinPurchaseChange: ((String) -> Unit)? = null,
    onLeftChange: ((String) -> Unit)? = null,
    onChange: (String) -> Unit,
) {
    Spacer(Modifier.height(10.dp))
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        RewardFieldRow(
            leftContent = {
                if (lockedLeft) {
                    Box(
                        Modifier
                            .width(76.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(CardBg.copy(alpha = 0.6f))
                            .border(1.dp, BorderColor, RoundedCornerShape(12.dp))
                            .padding(vertical = 12.dp, horizontal = 6.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(left, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, color = leftTint, textAlign = TextAlign.Center)
                    }
                } else {
                    SheetTextField(
                        value = left,
                        placeholder = leftPlaceholder,
                        onValueChange = { onLeftChange?.invoke(it) },
                        modifier = Modifier.width(76.dp),
                        textAlign = TextAlign.Center,
                    )
                }
            },
            value = value,
            placeholder = placeholder,
            onChange = onChange,
        )
        if (onMinPurchaseChange != null) {
            Row(
                Modifier.padding(start = 86.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text("Min. achat", fontSize = 12.sp, color = Muted)
                SheetTextField(
                    value = minPurchase,
                    placeholder = "Optionnel",
                    onValueChange = onMinPurchaseChange,
                    modifier = Modifier.weight(1f),
                )
                Text("€", fontSize = 12.sp, color = Muted)
            }
        }
    }
}

@Composable
private fun RewardFieldRow(
    leftContent: @Composable () -> Unit,
    value: String,
    placeholder: String,
    onChange: (String) -> Unit,
) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.Top) {
        leftContent()
        SheetTextField(
            value = value,
            placeholder = placeholder,
            onValueChange = onChange,
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun SheetTextField(
    value: String,
    placeholder: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    textAlign: TextAlign = TextAlign.Start,
) {
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(CardBg)
            .border(1.dp, BorderColor, RoundedCornerShape(12.dp))
            .padding(horizontal = 12.dp, vertical = 12.dp),
        textStyle = TextStyle(fontSize = 15.sp, color = Color.Black, textAlign = textAlign),
        cursorBrush = SolidColor(LinkBlue),
        decorationBox = { inner ->
            Box {
                if (value.isEmpty()) {
                    Text(placeholder, color = Muted.copy(alpha = 0.85f), fontSize = 15.sp, textAlign = textAlign, modifier = Modifier.fillMaxWidth())
                }
                inner()
            }
        },
    )
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ColorsSheet(draft: MyCardDraftState, onDraftChange: (MyCardDraftState) -> Unit) {
    ColorPickerSection("Fond de la carte", draft.primaryHex) { onDraftChange(draft.copy(primaryHex = it)) }
    Spacer(Modifier.height(16.dp))
    ColorPickerSection("Titres", draft.labelHex) { onDraftChange(draft.copy(labelHex = it)) }
    Spacer(Modifier.height(16.dp))
    ColorPickerSection("Textes", draft.accentHex) { onDraftChange(draft.copy(accentHex = it)) }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ColorPickerSection(label: String, selectedHex: String, onSelect: (String) -> Unit) {
    Column {
        Text(label, fontWeight = FontWeight.Normal, fontSize = 16.sp)
        Spacer(Modifier.height(8.dp))
        Box(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(Color.Black.copy(alpha = 0.04f))
                .padding(horizontal = 10.dp, vertical = 10.dp),
        ) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                CardColorPresets.forEach { (hex, _) ->
                    val normalized = "#$hex"
                    val selected = selectedHex.removePrefix("#").equals(hex, ignoreCase = true)
                    Box(
                        Modifier
                            .size(40.dp)
                            .clip(CircleShape)
                            .background(normalized.toComposeColorOr(Color.Gray))
                            .border(
                                width = if (selected) 3.dp else 0.dp,
                                color = if (selected) LinkBlue.copy(alpha = 0.6f) else Color.Transparent,
                                shape = CircleShape,
                            )
                            .clickable { onSelect(normalized) },
                    )
                }
            }
        }
    }
}

@Composable
private fun MetricsSheet(
    draft: MyCardDraftState,
    onDraftChange: (MyCardDraftState) -> Unit,
    onPickBackground: () -> Unit,
    onPickStampIcon: () -> Unit,
    onPickUri: (Uri) -> Unit,
    onRemoveBackground: () -> Unit,
) {
    if (draft.isStampsMode) {
        Text("Système de carte", fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
        Text("Tampons", fontSize = 13.sp, color = Muted)
        Spacer(Modifier.height(6.dp))
        Text("Choisissez l'icône affichée sur les cases tampon.", fontSize = 13.sp, color = Muted)
        Spacer(Modifier.height(10.dp))
        LazyVerticalGrid(
            columns = GridCells.Fixed(6),
            modifier = Modifier.height(220.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            item {
                Box(
                    Modifier
                        .height(48.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(CardBg)
                        .border(1.dp, BorderColor, RoundedCornerShape(12.dp))
                        .clickable(onClick = onPickStampIcon),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Default.Add, contentDescription = "Importer", tint = Color.Black)
                }
            }
            items(StampIconCatalog.selectableKeys) { key ->
                val selected = StampIconCatalog.normalizeKey(draft.stampEmoji) == key
                Box(
                    Modifier
                        .height(48.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(if (selected) LinkBlue.copy(alpha = 0.12f) else CardBg)
                        .border(
                            1.dp,
                            if (selected) LinkBlue.copy(alpha = 0.35f) else BorderColor,
                            RoundedCornerShape(12.dp),
                        )
                        .clickable {
                            onDraftChange(
                                draft.copy(
                                    stampEmoji = key,
                                    pendingStampIconDataUrl = null,
                                    stampIconWasRemoved = true,
                                    serverHasStampIcon = false,
                                ),
                            )
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(StampIconCatalog.emojiFor(key), fontSize = 22.sp)
                }
            }
        }
    } else {
        Text("Image de fond", fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
        Spacer(Modifier.height(8.dp))
        ImagePickerSheet(onPickBackground, onRemoveBackground, onPickUri, isBackground = true)
    }
}

@Composable
private fun MemberSheet(draft: MyCardDraftState, onDraftChange: (MyCardDraftState) -> Unit) {
    SheetLabeledField("Libellé colonne membre", draft.labelMember) { onDraftChange(draft.copy(labelMember = it)) }
    SheetLabeledField("Libellé « restants »", draft.labelRestants) { onDraftChange(draft.copy(labelRestants = it)) }
}

@Composable
private fun PassBackSheet(draft: MyCardDraftState, onDraftChange: (MyCardDraftState) -> Unit) {
    SheetLabeledField("Conditions verso pass", draft.backTerms) { onDraftChange(draft.copy(backTerms = it)) }
    SheetLabeledField("Contact verso pass", draft.backContact) { onDraftChange(draft.copy(backContact = it)) }
    SheetLabeledField("Titre notification", draft.notificationTitleOverride) {
        onDraftChange(draft.copy(notificationTitleOverride = it))
    }
    SheetLabeledField("Message notification", draft.notificationChangeMessage) {
        onDraftChange(draft.copy(notificationChangeMessage = it))
    }
}

@Composable
private fun SheetLabeledField(label: String, value: String, onChange: (String) -> Unit) {
    Spacer(Modifier.height(10.dp))
    Text(label, fontSize = 13.sp, color = Muted)
    Spacer(Modifier.height(6.dp))
    SheetTextField(value = value, placeholder = label, onValueChange = onChange, modifier = Modifier.fillMaxWidth())
}

@Composable
private fun SheetActionCard(content: @Composable () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(CardBg)
            .border(1.dp, BorderColor, RoundedCornerShape(16.dp)),
    ) {
        content()
    }
}

@Composable
private fun SheetActionRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector?,
    label: String,
    tint: Color,
    onClick: () -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(24.dp))
            Spacer(Modifier.width(14.dp))
        }
        Text(label, color = tint, fontSize = 16.sp)
    }
}

@Composable
private fun SheetPrimaryButton(
    label: String,
    enabled: Boolean,
    loading: Boolean = false,
    onClick: () -> Unit,
) {
    Box(
        Modifier
            .fillMaxWidth()
            .height(50.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(if (enabled) Color(0xFFE5E5EA) else Color(0xFFF2F2F7))
            .clickable(enabled = enabled && !loading, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        if (loading) {
            CircularProgressIndicator(strokeWidth = 2.dp, modifier = Modifier.size(22.dp))
        } else {
            Text(
                label,
                fontWeight = FontWeight.SemiBold,
                color = if (enabled) Color.Black else Muted,
                fontSize = 16.sp,
            )
        }
    }
}
