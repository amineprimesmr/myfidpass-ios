package fr.myfidpass.ui.screens.commerce.flyer

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Photo
import androidx.compose.material.icons.filled.Store
import androidx.compose.material.icons.outlined.AddPhotoAlternate
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import fr.myfidpass.flyer.AppVibrantColorPalette
import fr.myfidpass.flyer.FlyerBackgroundTemplates
import fr.myfidpass.ui.viewmodel.ProgramFlyerEditorViewModel
import fr.myfidpass.util.toComposeColorOr

object FlyerStudioTheme {
    val canvas = Color(0xFF0A0A0A)
    val accent = Color(0xFF7352F5)
    val promptSurface = Color(0xFF262729)
    val sourceCard = Color(0xFF13181D)
    val textPrimary = Color.White.copy(0.94f)
    val textSecondary = Color.White.copy(0.58f)
    val textTertiary = Color.White.copy(0.38f)
    val hairline = Color.White.copy(0.10f)
}

@Composable
fun FlyerLogoPickerCard(
    logoDataUrl: String?,
    onPickLogo: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(FlyerStudioTheme.promptSurface)
            .border(1.dp, FlyerStudioTheme.hairline, RoundedCornerShape(18.dp))
            .padding(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Default.Store, contentDescription = null, tint = FlyerStudioTheme.textSecondary, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(8.dp))
            Text("Logo", color = FlyerStudioTheme.textPrimary, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
        }
        Spacer(Modifier.height(10.dp))
        Box(
            Modifier
                .fillMaxWidth()
                .height(92.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(FlyerStudioTheme.sourceCard)
                .border(1.dp, FlyerStudioTheme.hairline, RoundedCornerShape(14.dp))
                .clickable(onClick = onPickLogo),
            contentAlignment = Alignment.Center,
        ) {
            if (logoDataUrl != null) {
                AsyncImage(
                    model = logoDataUrl,
                    contentDescription = "Logo",
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(92.dp)
                        .clip(RoundedCornerShape(14.dp)),
                    contentScale = ContentScale.Fit,
                )
            } else {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Outlined.AddPhotoAlternate, contentDescription = null, tint = FlyerStudioTheme.textTertiary, modifier = Modifier.size(28.dp))
                    Spacer(Modifier.height(6.dp))
                    Text("Importer le logo", color = FlyerStudioTheme.textTertiary, fontSize = 13.sp)
                }
            }
        }
    }
}

@Composable
fun FlyerAccentColorsCard(
    selectedHex6: String,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(FlyerStudioTheme.promptSurface)
            .border(1.dp, FlyerStudioTheme.hairline, RoundedCornerShape(18.dp))
            .padding(14.dp),
    ) {
        Text("Couleurs d'accent", color = FlyerStudioTheme.textSecondary, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
        Spacer(Modifier.height(10.dp))
        FlyerAccentPaletteRow(selectedHex6 = selectedHex6, onSelect = onSelect)
    }
}

@Composable
fun FlyerAccentPaletteRow(
    selectedHex6: String,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
    swatches: List<String> = AppVibrantColorPalette.flyerCarouselHex6,
) {
    val selectedNorm = selectedHex6.removePrefix("#").uppercase()
    Row(
        modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(32.dp)
                .clip(CircleShape)
                .background(Color.White.copy(0.07f))
                .border(1.dp, FlyerStudioTheme.hairline, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Default.Add, contentDescription = "Plus de couleurs", tint = FlyerStudioTheme.textSecondary, modifier = Modifier.size(16.dp))
        }
        swatches.forEach { hex ->
            FlyerPaletteSwatch(
                hex = hex,
                selected = hex.equals(selectedNorm, ignoreCase = true),
                onClick = { onSelect(hex) },
            )
        }
    }
}

@Composable
private fun FlyerPaletteSwatch(hex: String, selected: Boolean, onClick: () -> Unit) {
    val color = "#$hex".toComposeColorOr(Color.Gray)
    Box(
        Modifier
            .size(32.dp)
            .scale(if (selected) 1.05f else 1f)
            .clip(CircleShape)
            .background(color)
            .border(
                width = if (selected) 2.dp else 1.dp,
                color = if (selected) FlyerStudioTheme.accent else FlyerStudioTheme.hairline,
                shape = CircleShape,
            )
            .clickable(onClick = onClick),
    )
}

@Composable
fun FlyerCreatePrimaryButton(
    onClick: () -> Unit,
    enabled: Boolean,
    loading: Boolean,
    label: String = "Créer mon flyer",
    modifier: Modifier = Modifier,
) {
    Button(
        onClick = onClick,
        enabled = enabled && !loading,
        modifier = modifier
            .fillMaxWidth()
            .height(54.dp),
        shape = RoundedCornerShape(16.dp),
        colors = ButtonDefaults.buttonColors(containerColor = FlyerStudioTheme.accent, disabledContainerColor = FlyerStudioTheme.accent.copy(0.45f)),
    ) {
        if (loading) {
            CircularProgressIndicator(color = Color.White, modifier = Modifier.size(22.dp), strokeWidth = 2.dp)
        } else {
            Text(label, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
        }
    }
}

@Composable
fun FlyerViewModeHeader(
    onEdit: () -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        OutlinedButton(
            onClick = onEdit,
            shape = RoundedCornerShape(20.dp),
            border = androidx.compose.foundation.BorderStroke(1.dp, FlyerStudioTheme.hairline),
            colors = ButtonDefaults.outlinedButtonColors(contentColor = FlyerStudioTheme.textPrimary),
            contentPadding = ButtonDefaults.ContentPadding,
        ) {
            Text("Modifier", fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
        }
        Spacer(Modifier.weight(1f))
        Box(
            Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(FlyerStudioTheme.promptSurface)
                .border(1.dp, FlyerStudioTheme.hairline, CircleShape)
                .clickable(onClick = onClose),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Default.Check, contentDescription = "Fermer", tint = FlyerStudioTheme.textPrimary, modifier = Modifier.size(18.dp))
        }
    }
}

@Composable
fun FlyerViewModeUsageGuideCard(modifier: Modifier = Modifier) {
    val steps = listOf(
        Icons.Default.Download to "Téléchargez le visuel",
        Icons.Default.Photo to "Imprimez et affichez-le",
        Icons.Default.Store to "Vos clients scannent le QR",
    )
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(FlyerStudioTheme.sourceCard.copy(0.72f))
            .border(1.dp, FlyerStudioTheme.hairline.copy(0.5f), RoundedCornerShape(16.dp))
            .padding(16.dp),
    ) {
        Text("Votre flyer en boutique", color = FlyerStudioTheme.textSecondary, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
        Spacer(Modifier.height(14.dp))
        Row(verticalAlignment = Alignment.Top) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                steps.forEachIndexed { index, _ ->
                    Box(
                        Modifier
                            .size(28.dp)
                            .clip(CircleShape)
                            .background(FlyerStudioTheme.promptSurface)
                            .border(1.dp, FlyerStudioTheme.hairline, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text("${index + 1}", color = FlyerStudioTheme.textPrimary, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                    }
                    if (index < steps.lastIndex) {
                        Box(Modifier.width(2.dp).height(22.dp).background(FlyerStudioTheme.hairline.copy(0.5f)))
                    }
                }
            }
            Spacer(Modifier.width(12.dp))
            Column(verticalArrangement = Arrangement.spacedBy(18.dp), modifier = Modifier.padding(top = 4.dp)) {
                steps.forEach { (icon, title) ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(icon, contentDescription = null, tint = FlyerStudioTheme.textSecondary, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(10.dp))
                        Text(title, color = FlyerStudioTheme.textPrimary, fontWeight = FontWeight.Medium, fontSize = 14.sp)
                    }
                }
            }
        }
    }
}

@Composable
fun FlyerDownloadBar(onDownload: () -> Unit, modifier: Modifier = Modifier) {
    OutlinedButton(
        onClick = onDownload,
        modifier = modifier
            .fillMaxWidth()
            .height(48.dp),
        shape = RoundedCornerShape(14.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, FlyerStudioTheme.hairline),
        colors = ButtonDefaults.outlinedButtonColors(contentColor = FlyerStudioTheme.textPrimary),
    ) {
        Icon(Icons.Default.Download, contentDescription = null, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text("Télécharger le flyer", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
    }
}

@Composable
fun FlyerBackgroundCarousel(
    vm: ProgramFlyerEditorViewModel,
    templateKeys: List<String>,
    onPickCustomBg: () -> Unit,
    onGenerateAi: () -> Unit,
    onApplyTemplate: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            Modifier
                .width(84.dp)
                .height(126.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(FlyerStudioTheme.sourceCard)
                .border(1.dp, FlyerStudioTheme.hairline, RoundedCornerShape(12.dp))
                .clickable(onClick = onPickCustomBg),
            contentAlignment = Alignment.Center,
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Default.Add, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                Icon(Icons.Default.Photo, contentDescription = null, tint = FlyerStudioTheme.textSecondary, modifier = Modifier.size(14.dp))
            }
        }
        Box(
            Modifier
                .width(84.dp)
                .height(126.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(
                    Brush.linearGradient(
                        listOf(FlyerStudioTheme.accent.copy(0.92f), FlyerStudioTheme.accent.copy(0.58f)),
                    ),
                )
                .border(1.dp, FlyerStudioTheme.hairline, RoundedCornerShape(12.dp))
                .clickable(enabled = !vm.isGenerating, onClick = onGenerateAi),
            contentAlignment = Alignment.Center,
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Default.AutoAwesome, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                Text("IA", color = Color.White.copy(0.95f), fontWeight = FontWeight.Bold, fontSize = 12.sp)
            }
        }
        templateKeys.forEach { key ->
            val selected = vm.selectedBackgroundTemplateKey == key
            val drawableId = FlyerBackgroundTemplates.drawableIdForKey(key)
            Box(
                Modifier
                    .width(84.dp)
                    .height(126.dp)
                    .scale(if (selected) 1.03f else 1f)
                    .clip(RoundedCornerShape(12.dp))
                    .clickable { onApplyTemplate(key) },
            ) {
                if (drawableId != null) {
                    AsyncImage(
                        model = drawableId,
                        contentDescription = key,
                        modifier = Modifier
                            .fillMaxSize()
                            .clip(RoundedCornerShape(12.dp))
                            .border(
                                if (selected) 2.dp else 1.dp,
                                if (selected) FlyerStudioTheme.accent else FlyerStudioTheme.hairline,
                                RoundedCornerShape(12.dp),
                            ),
                        contentScale = ContentScale.Crop,
                    )
                }
                if (selected) {
                    Box(
                        Modifier
                            .align(Alignment.TopEnd)
                            .padding(6.dp)
                            .size(22.dp)
                            .clip(CircleShape)
                            .background(Color.Red)
                            .clickable { vm.clearBackground() },
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(Icons.Default.Close, contentDescription = "Retirer", tint = Color.White, modifier = Modifier.size(12.dp))
                    }
                }
            }
        }
    }
}

@Composable
fun FlyerInlineLogoSection(
    vm: ProgramFlyerEditorViewModel,
    onPickLogo: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(FlyerStudioTheme.sourceCard.copy(0.5f))
            .border(1.dp, FlyerStudioTheme.hairline.copy(0.45f), RoundedCornerShape(16.dp))
            .padding(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Default.Store, contentDescription = null, tint = FlyerStudioTheme.accent, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(8.dp))
            Text("Logo", color = FlyerStudioTheme.textPrimary, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.weight(1f))
            Switch(
                checked = vm.logoEnabled,
                onCheckedChange = { vm.setLogoEnabled(it) },
                colors = SwitchDefaults.colors(checkedTrackColor = FlyerStudioTheme.accent),
            )
        }
        if (vm.logoEnabled) {
            Spacer(Modifier.height(10.dp))
            FlyerLogoPickerCard(
                logoDataUrl = vm.logoPreviewDataUrl ?: vm.serverLogoDataUrl,
                onPickLogo = onPickLogo,
            )
        }
    }
}

@Composable
fun FlyerAiGenerationProgress(progress: Float, modifier: Modifier = Modifier) {
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(FlyerStudioTheme.sourceCard.copy(0.42f))
            .border(1.dp, FlyerStudioTheme.hairline.copy(0.55f), RoundedCornerShape(18.dp))
            .padding(16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Default.AutoAwesome, contentDescription = null, tint = FlyerStudioTheme.accent, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text("L'IA compose votre fond…", color = FlyerStudioTheme.textPrimary, fontWeight = FontWeight.SemiBold)
        }
        Spacer(Modifier.height(12.dp))
        LinearProgressIndicator(
            progress = { progress.coerceIn(0f, 1f) },
            modifier = Modifier.fillMaxWidth().height(8.dp).clip(CircleShape),
            color = FlyerStudioTheme.accent,
            trackColor = Color.White.copy(0.1f),
        )
        Spacer(Modifier.height(8.dp))
        Text(
            "Quelques instants — création d'image sur nos serveurs",
            color = FlyerStudioTheme.textTertiary,
            fontSize = 12.sp,
        )
    }
}
