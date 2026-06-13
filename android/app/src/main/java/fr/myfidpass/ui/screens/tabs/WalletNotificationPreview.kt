package fr.myfidpass.ui.screens.tabs

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
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
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.PhotoLibrary
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import fr.myfidpass.R

enum class WalletNotificationPreviewSize {
    Standard,
    Carousel,
}

private data class WalletPreviewMetrics(
    val iconSide: androidx.compose.ui.unit.Dp,
    val iconCorner: androidx.compose.ui.unit.Dp,
    val rowSpacing: androidx.compose.ui.unit.Dp,
    val textStackSpacing: androidx.compose.ui.unit.Dp,
    val verticalPadding: androidx.compose.ui.unit.Dp,
    val horizontalPadding: androidx.compose.ui.unit.Dp,
    val cornerRadius: androidx.compose.ui.unit.Dp,
    val editIconSize: androidx.compose.ui.unit.Dp,
)

private fun WalletNotificationPreviewSize.metrics(): WalletPreviewMetrics = when (this) {
    WalletNotificationPreviewSize.Standard -> WalletPreviewMetrics(
        iconSide = 40.dp,
        iconCorner = 10.dp,
        rowSpacing = 12.dp,
        textStackSpacing = 3.dp,
        verticalPadding = 12.dp,
        horizontalPadding = 14.dp,
        cornerRadius = 22.dp,
        editIconSize = 20.dp,
    )
    WalletNotificationPreviewSize.Carousel -> WalletPreviewMetrics(
        iconSide = 52.dp,
        iconCorner = 12.dp,
        rowSpacing = 14.dp,
        textStackSpacing = 5.dp,
        verticalPadding = 16.dp,
        horizontalPadding = 16.dp,
        cornerRadius = 24.dp,
        editIconSize = 22.dp,
    )
}

/** Aperçu notification Wallet — aligné iOS `WalletNotificationPreviewBlock`. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun WalletNotificationPreviewBlock(
    notificationTitle: String,
    message: String,
    onMessageChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    logoUrl: String? = null,
    authToken: String? = null,
    messagePlaceholder: String = "Message sur le pass",
    maxLength: Int = 200,
    previewSize: WalletNotificationPreviewSize = WalletNotificationPreviewSize.Standard,
    lightGlassSurface: Boolean = false,
    onEditingChanged: (Boolean) -> Unit = {},
    footer: @Composable () -> Unit = {},
) {
    val bringIntoViewRequester = remember { BringIntoViewRequester() }
    val interactionSource = remember { MutableInteractionSource() }
    val isMessageFocused by interactionSource.collectIsFocusedAsState()
    val metrics = previewSize.metrics()
    val titleStyle = if (previewSize == WalletNotificationPreviewSize.Carousel) {
        MaterialTheme.typography.titleSmall
    } else {
        MaterialTheme.typography.labelLarge
    }
    val bodyStyle = if (previewSize == WalletNotificationPreviewSize.Carousel) {
        MaterialTheme.typography.bodyLarge
    } else {
        MaterialTheme.typography.bodyMedium
    }
    val titleColor = if (lightGlassSurface) Color.White else Color.Black
    val bodyColor = if (lightGlassSurface) Color.White.copy(alpha = 0.92f) else Color.Black.copy(alpha = 0.92f)
    val placeholderColor = if (lightGlassSurface) Color.White.copy(alpha = 0.42f) else Color.Black.copy(alpha = 0.38f)
    val cursorColor = if (lightGlassSurface) Color.White else Color(0xFF2563EB)

    LaunchedEffect(isMessageFocused) {
        onEditingChanged(isMessageFocused)
        if (isMessageFocused) {
            bringIntoViewRequester.bringIntoView()
        }
    }

    Column(
        modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .walletNotificationPreviewSurface(previewSize, lightGlassSurface)
                .padding(
                    horizontal = metrics.horizontalPadding,
                    vertical = metrics.verticalPadding,
                ),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(metrics.rowSpacing),
        ) {
            NotificationPreviewIcon(
                logoUrl = logoUrl,
                authToken = authToken,
                iconSide = metrics.iconSide,
                iconCorner = metrics.iconCorner,
            )
            Column(
                Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(metrics.textStackSpacing),
            ) {
                Text(
                    notificationTitle,
                    style = titleStyle,
                    fontWeight = FontWeight.SemiBold,
                    color = titleColor,
                    maxLines = 2,
                )
                TextField(
                    value = message,
                    onValueChange = { onMessageChange(it.take(maxLength)) },
                    placeholder = { Text(messagePlaceholder, style = bodyStyle, color = placeholderColor) },
                    textStyle = bodyStyle.copy(color = bodyColor),
                    modifier = Modifier
                        .fillMaxWidth()
                        .bringIntoViewRequester(bringIntoViewRequester),
                    minLines = 2,
                    interactionSource = interactionSource,
                    colors = TextFieldDefaults.colors(
                        focusedTextColor = bodyColor,
                        unfocusedTextColor = bodyColor,
                        focusedContainerColor = Color.Transparent,
                        unfocusedContainerColor = Color.Transparent,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent,
                        cursorColor = cursorColor,
                    ),
                )
            }
        }
        footer()
    }
}

/** Aperçu îlot lecture seule — aligné iOS `ManualRichNotificationReadOnlyPreview`. */
@Composable
fun ManualRichNotificationReadOnlyPreview(
    logoUrl: String?,
    authToken: String?,
    messageCopyOverride: String,
    modifier: Modifier = Modifier,
    hidesSenderTitleRow: Boolean = true,
    senderTitle: String = "",
) {
    Row(
        modifier
            .fillMaxWidth()
            .walletNotificationPreviewSurface(WalletNotificationPreviewSize.Carousel)
            .padding(horizontal = 14.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        NotificationPreviewIcon(
            logoUrl = logoUrl,
            authToken = authToken,
            iconSide = 52.dp,
            iconCorner = 12.dp,
        )
        Column(
            Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            if (!hidesSenderTitleRow && senderTitle.isNotBlank()) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        senderTitle,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.Black,
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        "maintenant",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Medium,
                        color = Color.Black.copy(alpha = 0.45f),
                    )
                }
            }
            Text(
                messageCopyOverride,
                style = MaterialTheme.typography.bodyMedium,
                color = Color.Black.copy(alpha = 0.88f),
            )
        }
    }
}

/** Pop-up logo notification — aligné iOS `NotificationManualLogoCommercePopupCard`. */
@Composable
fun NotificationLogoPopupCard(
    logoUrl: String?,
    authToken: String?,
    uploading: Boolean,
    onPickLogo: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .background(Color.White.copy(alpha = 0.94f))
            .border(1.dp, Color.Black.copy(alpha = 0.08f), RoundedCornerShape(24.dp))
            .clickable(
                indication = null,
                interactionSource = remember { MutableInteractionSource() },
                onClick = {},
            )
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        ManualRichNotificationReadOnlyPreview(
            logoUrl = logoUrl,
            authToken = authToken,
            messageCopyOverride = "👈 Votre logo apparaîtra ici dans la notification.",
        )

        if (uploading) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 4.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    strokeWidth = 2.dp,
                    color = Color.Black.copy(alpha = 0.7f),
                )
                Spacer(Modifier.width(10.dp))
                Text(
                    "Envoi en cours…",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    color = Color.Black.copy(alpha = 0.7f),
                )
            }
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(CircleShape)
                .background(Color.White)
                .border(1.dp, Color.Black.copy(alpha = 0.08f), CircleShape)
                .clickable(enabled = !uploading, onClick = onPickLogo)
                .padding(vertical = 14.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Outlined.PhotoLibrary,
                contentDescription = null,
                tint = Color.Black,
                modifier = Modifier.size(20.dp),
            )
            Spacer(Modifier.width(10.dp))
            Text(
                "Mettre mon logo",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = Color.Black,
            )
        }
    }
}

@Composable
private fun Modifier.walletNotificationPreviewSurface(
    previewSize: WalletNotificationPreviewSize,
    lightGlass: Boolean = false,
): Modifier {
    val metrics = previewSize.metrics()
    val shape = RoundedCornerShape(metrics.cornerRadius)
    return when (previewSize) {
        WalletNotificationPreviewSize.Carousel -> this
            .shadow(
                elevation = 4.dp,
                shape = shape,
                spotColor = Color.Black.copy(alpha = 0.10f),
                ambientColor = Color.Black.copy(alpha = 0.06f),
            )
            .clip(shape)
            .background(Color.White, shape)
            .border(1.dp, Color.Black.copy(alpha = 0.09f), shape)
        WalletNotificationPreviewSize.Standard -> if (lightGlass) {
            val darkGlass = Color(0xFF1C1C22)
            this
                .shadow(
                    elevation = 8.dp,
                    shape = shape,
                    spotColor = Color.Black.copy(alpha = 0.35f),
                    ambientColor = Color.Black.copy(alpha = 0.18f),
                )
                .clip(shape)
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.White.copy(alpha = 0.20f),
                            darkGlass.copy(alpha = 0.62f),
                        ),
                    ),
                    shape,
                )
                .border(1.dp, Color.White.copy(alpha = 0.28f), shape)
        } else {
            this
                .clip(shape)
                .background(Color.White.copy(alpha = 0.88f), shape)
                .border(1.dp, Color.White.copy(alpha = 0.55f), shape)
        }
    }
}

@Composable
private fun NotificationPreviewIcon(
    logoUrl: String?,
    authToken: String?,
    iconSide: androidx.compose.ui.unit.Dp,
    iconCorner: androidx.compose.ui.unit.Dp,
) {
    val context = LocalContext.current
    Box(
        Modifier
            .size(iconSide)
            .clip(RoundedCornerShape(iconCorner)),
        contentAlignment = Alignment.Center,
    ) {
        if (!logoUrl.isNullOrBlank()) {
            val req = ImageRequest.Builder(context)
                .data(logoUrl)
                .crossfade(true)
                .apply {
                    if (!authToken.isNullOrBlank() && logoUrl.contains("/api/")) {
                        addHeader("Authorization", "Bearer $authToken")
                    }
                }
                .build()
            AsyncImage(
                model = req,
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        } else {
            Image(
                painter = painterResource(R.drawable.logonotif),
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        }
    }
}
