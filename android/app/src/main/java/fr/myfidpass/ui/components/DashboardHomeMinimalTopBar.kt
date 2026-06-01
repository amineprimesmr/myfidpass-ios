package fr.myfidpass.ui.components

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.height
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.ui.theme.MerchantDesignSystem
import fr.myfidpass.util.MerchantFlyerReadiness

/** Barre noire partagée — alignée iOS `DashboardHomeMinimalTopBar`. */
@Composable
fun DashboardHomeMinimalTopBar(
    title: String,
    sessionStore: SessionStore?,
    onSettingsClick: () -> Unit,
    onBusinessSwitched: () -> Unit = {},
    businessLabel: String? = null,
    showBusinessSwitcher: Boolean = true,
    onOpenSideMenu: (() -> Unit)? = null,
    onAddCommerce: (() -> Unit)? = null,
    showSettingsAttentionDot: Boolean = false,
    showSettingsButton: Boolean = false,
    dashboardRepository: DashboardRepository? = null,
    refreshAttentionDotKey: Any? = null,
    modifier: Modifier = Modifier,
) {
    val businesses = sessionStore?.businesses.orEmpty()
    val currentSlug = sessionStore?.currentBusinessSlug
    val current = businesses.firstOrNull { it.slug == currentSlug } ?: businesses.firstOrNull()
    var switcherOpen by remember { mutableStateOf(false) }
    var search by remember { mutableStateOf("") }
    var autoAttentionDot by remember { mutableStateOf(false) }
    val avatarInitial = (current?.name?.firstOrNull() ?: title.firstOrNull())?.uppercaseChar()?.toString() ?: "M"
    val slug = currentSlug?.trim().orEmpty()
    val effectiveAttentionDot = showSettingsAttentionDot || autoAttentionDot

    LaunchedEffect(slug, dashboardRepository, refreshAttentionDotKey) {
        if (dashboardRepository == null) {
            autoAttentionDot = slug.isEmpty()
            return@LaunchedEffect
        }
        autoAttentionDot = !MerchantFlyerReadiness.isFlyerReady(slug, dashboardRepository)
    }

    Row(
        modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .background(Color.Black)
            .padding(horizontal = 14.dp)
            .padding(top = MerchantDesignSystem.topBarPaddingTop, bottom = MerchantDesignSystem.topBarPaddingBottom)
            .height(MerchantDesignSystem.topBarContentHeight),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (onOpenSideMenu != null) {
            TopBarPlainMenuButton(
                onClick = onOpenSideMenu,
                showAttentionDot = effectiveAttentionDot,
            )
        }
        Text(
            title,
            color = Color.White,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        if (showSettingsButton && onOpenSideMenu == null) {
            GlassIconButton(
                icon = Icons.Default.Person,
                contentDescription = "Compte",
                onClick = onSettingsClick,
                circular = false,
                diameter = 40.dp,
                showAttentionDot = effectiveAttentionDot,
            )
        }
        if (showBusinessSwitcher && sessionStore != null && businesses.isNotEmpty()) {
            Box(
                Modifier
                    .size(36.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(
                        Brush.linearGradient(
                            listOf(Color(0xFF0D2A73), Color(0xFF691E8C)),
                        ),
                    )
                    .clickable { switcherOpen = true },
                contentAlignment = Alignment.Center,
            ) {
                Text(avatarInitial, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }
        }
    }

    if (switcherOpen && sessionStore != null) {
        val filtered = businesses.filter {
            search.isBlank() || it.name.contains(search, ignoreCase = true) || it.slug.contains(search, ignoreCase = true)
        }
        Dialog(onDismissRequest = { switcherOpen = false }) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(26.dp))
                    .background(Color(0xFF1C1C1E))
                    .padding(16.dp),
            ) {
                Text("Commerces", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Text(
                    businessLabel ?: current?.name ?: title,
                    color = Color.White.copy(0.65f),
                    fontSize = 13.sp,
                    modifier = Modifier.padding(top = 4.dp, bottom = 12.dp),
                )
                OutlinedTextField(
                    value = search,
                    onValueChange = { search = it },
                    placeholder = { Text("Rechercher") },
                    leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                LazyColumn(Modifier.padding(top = 8.dp)) {
                    items(filtered, key = { it.slug }) { b ->
                        val selected = b.slug == currentSlug
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(12.dp))
                                .background(if (selected) Color.White.copy(0.12f) else Color.Transparent)
                                .clickable {
                                    sessionStore.switchBusiness(b.slug)
                                    switcherOpen = false
                                    search = ""
                                    onBusinessSwitched()
                                }
                                .padding(horizontal = 12.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Box(
                                Modifier
                                    .size(36.dp)
                                    .clip(CircleShape)
                                    .background(Color.White.copy(0.15f)),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    b.name.firstOrNull()?.uppercaseChar()?.toString() ?: "?",
                                    color = Color.White,
                                    fontWeight = FontWeight.SemiBold,
                                )
                            }
                            Text(
                                b.name.ifBlank { b.slug },
                                color = Color.White,
                                modifier = Modifier
                                    .weight(1f)
                                    .padding(horizontal = 12.dp),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                }
                if (onAddCommerce != null) {
                    HorizontalDivider(Modifier.padding(vertical = 8.dp), color = Color.White.copy(0.12f))
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .clickable {
                                switcherOpen = false
                                onAddCommerce()
                            }
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Icon(Icons.Default.Add, contentDescription = null, tint = Color(0xFF2563EB))
                        Text("Ajouter un commerce", color = Color.White)
                    }
                }
            }
        }
    }
}

@Composable
fun DashboardHomeStaffTopBar(
    title: String,
    onSettingsClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .background(Color.Black)
            .padding(horizontal = 14.dp)
            .padding(top = MerchantDesignSystem.topBarPaddingTop, bottom = MerchantDesignSystem.topBarPaddingBottom)
            .height(MerchantDesignSystem.topBarContentHeight),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
        GlassIconButton(
            icon = Icons.Default.Person,
            contentDescription = "Compte",
            onClick = onSettingsClick,
            circular = false,
            diameter = 40.dp,
        )
    }
}

@Composable
private fun TopBarPlainMenuButton(
    onClick: () -> Unit,
    showAttentionDot: Boolean,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier
            .size(44.dp)
            .clickable(
                indication = null,
                interactionSource = remember { MutableInteractionSource() },
                onClick = onClick,
            ),
        contentAlignment = Alignment.CenterStart,
    ) {
        Icon(
            Icons.Default.Menu,
            contentDescription = "Menu",
            tint = Color.White,
            modifier = Modifier.size(22.dp),
        )
        if (showAttentionDot) {
            Box(
                Modifier
                    .align(Alignment.TopEnd)
                    .padding(top = 6.dp, end = 4.dp)
                    .size(9.dp)
                    .clip(CircleShape)
                    .background(Color(0xFFEF4444)),
            )
        }
    }
}

@Composable
fun MerchantSubscribeFloatingPill(
    onSubscribe: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val blinkTransition = rememberInfiniteTransition(label = "subscribe_pill_blink")
    val dotAlpha by blinkTransition.animateFloat(
        initialValue = 0.42f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 850, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "subscribe_pill_dot_alpha",
    )
    val dotRingScale by blinkTransition.animateFloat(
        initialValue = 0.85f,
        targetValue = 1.35f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 850, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "subscribe_pill_dot_ring",
    )

    Row(
        modifier = modifier
            .fillMaxWidth(0.88f)
            .widthIn(min = 280.dp)
            .clip(RoundedCornerShape(999.dp))
            .background(Color.Black)
            .clickable(onClick = onSubscribe)
            .padding(horizontal = 22.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(9.dp, Alignment.CenterHorizontally),
    ) {
        Box(contentAlignment = Alignment.Center) {
            Box(
                Modifier
                    .size((9 * dotRingScale).dp)
                    .clip(CircleShape)
                    .background(Color(0xFF38D46A).copy(alpha = if (dotAlpha > 0.7f) 0.22f else 0.08f)),
            )
            Box(
                Modifier
                    .size(9.dp)
                    .clip(CircleShape)
                    .background(Color(0xFF38D46A).copy(alpha = dotAlpha)),
            )
        }
        Text(
            "Essayer 1 mois à 1€",
            color = Color.White,
            fontWeight = FontWeight.Medium,
            fontSize = 14.sp,
        )
    }
}
