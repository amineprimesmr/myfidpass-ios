package fr.myfidpass.ui.screens.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.data.dto.BusinessDto

@Composable
fun PaywallCommerceQuotaSection(
    businesses: List<BusinessDto>,
    usedBusinesses: Int,
    allowedBusinesses: Int,
    hasActiveSubscription: Boolean,
    addingAnotherCommerce: Boolean,
    pendingCommerceName: String?,
    selectedTargetSlots: Int,
    onSelectedTargetSlotsChange: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val paidSlotsBaseline = allowedBusinesses.coerceIn(1, 5)
    val minSelectableSlots = when {
        !hasActiveSubscription -> 1
        addingAnotherCommerce || usedBusinesses >= paidSlotsBaseline ->
            minOf(5, maxOf(paidSlotsBaseline + 1, usedBusinesses + 1))
        else -> paidSlotsBaseline
    }
    val maxSelectableSlots = 5
    val clampedSlots = selectedTargetSlots.coerceIn(minSelectableSlots, maxSelectableSlots)

    LaunchedEffect(paidSlotsBaseline, usedBusinesses, minSelectableSlots, selectedTargetSlots) {
        if (selectedTargetSlots < minSelectableSlots) {
            onSelectedTargetSlotsChange(minSelectableSlots)
        } else if (selectedTargetSlots > maxSelectableSlots) {
            onSelectedTargetSlotsChange(maxSelectableSlots)
        }
    }

    Row(
        modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        PaywallGlassStepperButton(
            icon = Icons.Default.Remove,
            enabled = clampedSlots > minSelectableSlots,
            onClick = { onSelectedTargetSlotsChange((clampedSlots - 1).coerceAtLeast(minSelectableSlots)) },
        )
        Text(
            "$clampedSlots",
            fontSize = 30.sp,
            fontWeight = FontWeight.ExtraBold,
            color = Color(0xFF14171C),
            modifier = Modifier.padding(horizontal = 20.dp),
        )
        PaywallGlassStepperButton(
            icon = Icons.Default.Add,
            enabled = clampedSlots < maxSelectableSlots,
            onClick = { onSelectedTargetSlotsChange((clampedSlots + 1).coerceAtMost(maxSelectableSlots)) },
        )
    }
}

@Composable
private fun PaywallGlassStepperButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(26.dp)
    val tint = Color(0xFF14171C).copy(alpha = if (enabled) 0.88f else 0.28f)
    Icon(
        icon,
        contentDescription = null,
        tint = tint,
        modifier = Modifier
            .size(52.dp)
            .clip(shape)
            .background(Color.White.copy(alpha = if (enabled) 0.42f else 0.18f))
            .border(1.dp, Color.White.copy(alpha = if (enabled) 0.72f else 0.35f), shape)
            .clickable(
                enabled = enabled,
                indication = null,
                interactionSource = remember { MutableInteractionSource() },
                onClick = onClick,
            )
            .padding(14.dp),
    )
}
