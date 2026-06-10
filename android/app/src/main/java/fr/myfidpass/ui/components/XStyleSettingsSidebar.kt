package fr.myfidpass.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Article
import androidx.compose.material.icons.filled.NorthEast
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SportsSoccer
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.data.local.SessionStore

/** Contenu du panneau latéral — aligné iOS `XStyleSettingsSideBar`. */
@Composable
fun XStyleSettingsSidebar(
    sessionStore: SessionStore,
    onOpenFlyer: () -> Unit,
    onOpenFootballGame: () -> Unit,
    onOpenLiveGame: () -> Unit,
    onOpenSettings: () -> Unit,
    showFlyerAttentionDot: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val businesses = sessionStore.businesses
    val currentSlug = sessionStore.currentBusinessSlug
    val current = businesses.firstOrNull { it.slug == currentSlug } ?: businesses.firstOrNull()
    val displayName = current?.name?.takeIf { it.isNotBlank() }
        ?: sessionStore.userEmail?.substringBefore("@")?.takeIf { it.isNotBlank() }
        ?: "Mon commerce"
    val avatarInitial = displayName.firstOrNull()?.uppercaseChar()?.toString() ?: "M"

    Column(
        modifier
            .fillMaxHeight()
            .background(Color.Black)
            .padding(horizontal = 15.dp, vertical = 15.dp),
    ) {
        Box(
            Modifier
                .size(60.dp)
                .clip(RoundedCornerShape(17.dp))
                .background(
                    Brush.linearGradient(listOf(Color(0xFF0D2A73), Color(0xFF691E8C))),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Text(avatarInitial, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 24.sp)
        }
        Spacer(Modifier.height(10.dp))
        Text(
            displayName,
            color = Color.White,
            fontWeight = FontWeight.SemiBold,
            fontSize = 20.sp,
            lineHeight = 24.sp,
        )
        Row(Modifier.padding(top = 5.dp)) {
            Text(
                "${businesses.size}",
                color = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = 15.sp,
            )
            Text(
                if (businesses.size == 1) " commerce" else " commerces",
                color = Color.White.copy(0.62f),
                fontSize = 15.sp,
            )
        }
        HorizontalDivider(
            Modifier.padding(top = 15.dp),
            color = Color.White.copy(0.22f),
        )
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(top = 20.dp),
            verticalArrangement = Arrangement.spacedBy(30.dp),
        ) {
            SidebarMenuButton(
                icon = { Icon(Icons.AutoMirrored.Filled.Article, contentDescription = null, tint = Color.White) },
                title = "Flyer de jeu",
                showAttentionDot = showFlyerAttentionDot,
                onClick = onOpenFlyer,
            )
            SidebarMenuButton(
                icon = { Icon(Icons.Default.SportsSoccer, contentDescription = null, tint = Color.White) },
                title = "Jeu de foot",
                onClick = onOpenFootballGame,
            )
            SidebarMenuButton(
                title = "Jeu en direct",
                showInlineExternalArrow = true,
                onClick = onOpenLiveGame,
            )
            SidebarMenuButton(
                icon = { Icon(Icons.Default.Settings, contentDescription = null, tint = Color.White) },
                title = "Paramètres",
                onClick = onOpenSettings,
            )
        }
    }
}

@Composable
private fun SidebarMenuButton(
    title: String,
    onClick: () -> Unit,
    icon: (@Composable () -> Unit)? = null,
    showAttentionDot: Boolean = false,
    showInlineExternalArrow: Boolean = false,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        if (icon != null) {
            Box(Modifier.size(24.dp), contentAlignment = Alignment.Center) {
                icon()
            }
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(if (showInlineExternalArrow) 5.dp else 8.dp),
        ) {
            Text(
                title,
                color = Color.White,
                fontWeight = FontWeight.Medium,
                fontSize = 17.sp,
            )
            if (showInlineExternalArrow) {
                Icon(
                    Icons.Default.NorthEast,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(16.dp),
                )
            }
            if (showAttentionDot) {
                Box(
                    Modifier
                        .size(8.dp)
                        .clip(RoundedCornerShape(999.dp))
                        .background(Color(0xFFEF4444)),
                )
            }
        }
    }
}
