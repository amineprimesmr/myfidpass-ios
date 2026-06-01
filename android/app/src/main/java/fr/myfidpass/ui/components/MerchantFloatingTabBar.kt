package fr.myfidpass.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Person
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import fr.myfidpass.ui.navigation.MerchantMotion
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp

object MerchantFloatingTabBarMetrics {
    val pillHeight = 56.dp
    val tabTouchSize = 46.dp
    val bottomPadding = 10.dp
    /** Espace réservé sous le contenu scroll (tab bar + marge nav approx.). */
    val contentBottomInset = 88.dp
    /** Espace entre la pastille abo et le haut de la tab bar. */
    val subscribePillGapAboveTabBar = 12.dp
    val subscribePillBottomInset = contentBottomInset + subscribePillGapAboveTabBar
}

@Composable
fun MerchantFloatingTabBar(
    selectedTab: Int,
    onTabSelected: (Int) -> Unit,
    fullLayout: Boolean,
    modifier: Modifier = Modifier,
) {
    val tabs = if (fullLayout) {
        listOf(
            TabSpec(0, Icons.Filled.Home, Icons.Outlined.Home, "Accueil"),
            TabSpec(1, Icons.Filled.Notifications, Icons.Outlined.Notifications, "Notifications"),
            TabSpec(2, Icons.Filled.BarChart, Icons.Outlined.BarChart, "Statistiques"),
        )
    } else {
        listOf(
            TabSpec(0, Icons.Filled.Home, Icons.Outlined.Home, "Accueil"),
            TabSpec(1, Icons.Filled.Person, Icons.Outlined.Person, "Compte"),
        )
    }

    Box(
        modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(bottom = MerchantFloatingTabBarMetrics.bottomPadding),
        contentAlignment = Alignment.Center,
    ) {
        Row(
            Modifier
                .fillMaxWidth(0.82f)
                .widthIn(min = 272.dp)
                .shadow(12.dp, RoundedCornerShape(999.dp), spotColor = Color.Black.copy(0.10f))
                .clip(RoundedCornerShape(999.dp))
                .background(Color.White)
                .padding(horizontal = 14.dp, vertical = 5.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            tabs.forEach { tab ->
                FloatingTabItem(
                    selected = selectedTab == tab.index,
                    selectedIcon = tab.selectedIcon,
                    unselectedIcon = tab.unselectedIcon,
                    contentDescription = tab.label,
                    onClick = { onTabSelected(tab.index) },
                )
            }
        }
    }
}

private data class TabSpec(
    val index: Int,
    val selectedIcon: ImageVector,
    val unselectedIcon: ImageVector,
    val label: String,
)

@Composable
private fun FloatingTabItem(
    selected: Boolean,
    selectedIcon: ImageVector,
    unselectedIcon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
) {
    val iconTint by animateColorAsState(
        targetValue = if (selected) Color(0xFF111111) else Color(0xFF8E8E93),
        animationSpec = tween(MerchantMotion.TabCrossfadeMs, easing = MerchantMotion.navEasing),
        label = "tabIconTint",
    )
    val pillAlpha by animateColorAsState(
        targetValue = if (selected) Color(0xFFE9E9ED) else Color.Transparent,
        animationSpec = tween(MerchantMotion.TabCrossfadeMs, easing = MerchantMotion.navEasing),
        label = "tabPillBg",
    )
    Box(
        Modifier
            .size(MerchantFloatingTabBarMetrics.tabTouchSize)
            .clip(CircleShape)
            .clickable(
                indication = null,
                interactionSource = remember { MutableInteractionSource() },
                onClick = onClick,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(pillAlpha),
        )
        Icon(
            imageVector = if (selected) selectedIcon else unselectedIcon,
            contentDescription = contentDescription,
            tint = iconTint,
            modifier = Modifier.size(23.dp),
        )
    }
}
