package fr.myfidpass.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Aligné iOS `GroupedSettingsComponents.swift`. */
object GroupedSettingsMetrics {
    val pageBackground = Color(0xFFF2F2F7)
    val cardCornerRadius = 28.dp
    val iconBoxSize = 29.dp
    val iconBoxCorner = 8.dp
    val horizontalPadding = 16.dp
    val rowVerticalPadding = 12.dp
    val interCardSpacing = 20.dp
    val dividerLeadingInset = horizontalPadding + iconBoxSize + 12.dp
}

@Composable
fun GroupedSettingsIconBox(
    icon: ImageVector,
    modifier: Modifier = Modifier,
    destructive: Boolean = false,
    tint: Color? = null,
) {
    val bg = if (destructive) Color(0xFFFF3B30).copy(0.15f) else Color(0xFFE5E5EA)
    val fg = tint ?: if (destructive) Color(0xFFFF3B30) else Color(0xFF1C1C1E)
    Box(
        modifier
            .size(GroupedSettingsMetrics.iconBoxSize)
            .clip(RoundedCornerShape(GroupedSettingsMetrics.iconBoxCorner))
            .background(bg),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = fg, modifier = Modifier.size(16.dp))
    }
}

@Composable
fun GroupedSettingsCard(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(GroupedSettingsMetrics.cardCornerRadius))
            .background(Color.White)
            .border(0.5.dp, Color.Black.copy(0.08f), RoundedCornerShape(GroupedSettingsMetrics.cardCornerRadius)),
    ) {
        content()
    }
}

@Composable
fun GroupedSettingsRowDivider() {
    Row(Modifier.fillMaxWidth()) {
        Spacer(Modifier.width(GroupedSettingsMetrics.dividerLeadingInset))
        HorizontalDivider(color = Color.Black.copy(0.08f))
    }
}

@Composable
fun GroupedSettingsNavigationRow(
    icon: ImageVector,
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    value: String? = null,
    showsChevron: Boolean = true,
    onClick: (() -> Unit)? = null,
) {
    val rowModifier = modifier
        .fillMaxWidth()
        .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
        .padding(horizontal = GroupedSettingsMetrics.horizontalPadding, vertical = GroupedSettingsMetrics.rowVerticalPadding)

    Row(rowModifier, verticalAlignment = if (subtitle == null) Alignment.CenterVertically else Alignment.Top) {
        GroupedSettingsIconBox(icon)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(title, fontWeight = FontWeight.Medium, fontSize = 16.sp, color = Color(0xFF1C1C1E))
            subtitle?.takeIf { it.isNotEmpty() }?.let {
                Text(it, fontSize = 14.sp, color = Color(0xFF8E8E93), modifier = Modifier.padding(top = 2.dp))
            }
        }
        value?.takeIf { it.isNotEmpty() }?.let {
            Text(
                it,
                fontSize = 16.sp,
                color = Color(0xFF8E8E93),
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.End,
                modifier = Modifier.padding(start = 8.dp),
            )
        }
        if (showsChevron) {
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = Color(0xFFC7C7CC),
                modifier = Modifier.size(20.dp),
            )
        }
    }
}

@Composable
fun GroupedSettingsInfoRow(
    icon: ImageVector,
    title: String,
    value: String,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier
            .fillMaxWidth()
            .padding(horizontal = GroupedSettingsMetrics.horizontalPadding, vertical = GroupedSettingsMetrics.rowVerticalPadding),
        verticalAlignment = Alignment.Top,
    ) {
        GroupedSettingsIconBox(icon)
        Spacer(Modifier.width(12.dp))
        Text(title, fontWeight = FontWeight.Medium, fontSize = 16.sp, color = Color(0xFF1C1C1E))
        Spacer(Modifier.weight(1f))
        Text(
            value,
            fontSize = 16.sp,
            color = Color(0xFF8E8E93),
            textAlign = TextAlign.End,
            maxLines = 3,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(start = 8.dp),
        )
    }
}

@Composable
fun GroupedSettingsLogoutRow(onClick: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = GroupedSettingsMetrics.horizontalPadding, vertical = GroupedSettingsMetrics.rowVerticalPadding),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(GroupedSettingsMetrics.iconBoxSize)
                .clip(RoundedCornerShape(GroupedSettingsMetrics.iconBoxCorner))
                .background(Color(0xFFFF9500).copy(0.15f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.AutoMirrored.Filled.Logout, contentDescription = null, tint = Color(0xFFFF9500), modifier = Modifier.size(16.dp))
        }
        Spacer(Modifier.width(12.dp))
        Text("Se déconnecter", fontWeight = FontWeight.Medium, fontSize = 16.sp, color = Color(0xFF1C1C1E))
    }
}

@Composable
fun GroupedSettingsSectionLabel(title: String, modifier: Modifier = Modifier) {
    Text(
        title.uppercase(),
        modifier = modifier.padding(horizontal = 4.dp, vertical = 4.dp),
        fontSize = 13.sp,
        fontWeight = FontWeight.SemiBold,
        color = Color(0xFF8E8E93),
        letterSpacing = 0.4.sp,
    )
}

@Composable
fun GroupedSettingsDestructiveRow(title: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = GroupedSettingsMetrics.horizontalPadding, vertical = GroupedSettingsMetrics.rowVerticalPadding),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        GroupedSettingsIconBox(Icons.Default.Delete, destructive = true)
        Spacer(Modifier.width(12.dp))
        Text(title, fontWeight = FontWeight.Medium, fontSize = 16.sp, color = Color(0xFFFF3B30))
    }
}
