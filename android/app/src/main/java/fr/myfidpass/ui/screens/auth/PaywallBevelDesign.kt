package fr.myfidpass.ui.screens.auth

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CardGiftcard
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Redeem
import androidx.compose.material.icons.filled.ShowChart
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.R

data class PaywallFeatureItem(
    val title: String,
    val subtitle: String,
    val icon: ImageVector,
    val tint: Color,
    val iconDrawableRes: Int? = null,
    val iconCornerRadiusDp: Float = 0f,
    val iconSizeDp: Float = 28f,
)

object PaywallBevelFeatureCatalog {
    val primary = listOf(
        PaywallFeatureItem(
            "Carte Apple & Google Wallet",
            "Distribuez une carte fidélité sur iPhone et Android.",
            Icons.Default.CardGiftcard,
            Color(0xFFFA7268),
            iconDrawableRes = R.drawable.paywall_apple_wallet_icon,
            iconCornerRadiusDp = 8f,
            iconSizeDp = 32f,
        ),
        PaywallFeatureItem(
            "Notifications push illimitées",
            "Relancez vos clients au bon moment, sans limite.",
            Icons.Default.Notifications,
            Color(0xFFFA576B),
        ),
        PaywallFeatureItem(
            "Statistiques détaillées",
            "Suivez l'activité et la croissance de votre commerce.",
            Icons.Default.ShowChart,
            Color(0xFF4798FA),
        ),
        PaywallFeatureItem(
            "Base clients centralisée",
            "Retrouvez l'historique et les préférences de chaque membre.",
            Icons.Default.People,
            Color(0xFF6B78FA),
        ),
        PaywallFeatureItem(
            "Avis Google boosté",
            "Encouragez les avis Google Business après chaque visite.",
            Icons.Default.Star,
            Color(0xFFF28C2E),
            iconDrawableRes = R.drawable.paywall_google_icon,
        ),
        PaywallFeatureItem(
            "Engagement X boosté",
            "Récompensez un follow sur votre compte X.",
            Icons.Default.Star,
            Color(0xFF101010),
            iconDrawableRes = R.drawable.paywall_x_icon,
            iconCornerRadiusDp = 8f,
            iconSizeDp = 32f,
        ),
        PaywallFeatureItem(
            "Récompenses illimitées",
            "Fidélisez sans plafond sur vos offres.",
            Icons.Default.Redeem,
            Color(0xFFE8A32E),
        ),
    )

    val alsoIncluded = emptyList<PaywallFeatureItem>()
}

@Composable
fun PaywallBevelBackdrop(modifier: Modifier = Modifier) {
    Box(
        modifier
            .fillMaxSize()
            .background(Color(0xFFFCFCFF))
            .background(
                Brush.radialGradient(
                    colors = listOf(
                        Color(0xFFE6F2FF).copy(alpha = 0.42f),
                        Color(0xFFF5F9FF).copy(alpha = 0.22f),
                        Color.Transparent,
                    ),
                    radius = 900f,
                ),
            ),
    )
}

@Composable
fun PaywallBevelFeatureRow(item: PaywallFeatureItem, modifier: Modifier = Modifier) {
    Row(
        modifier.padding(vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(
            Modifier.size(48.dp),
            contentAlignment = Alignment.Center,
        ) {
            if (item.iconDrawableRes != null) {
                val iconShape = if (item.iconCornerRadiusDp > 0f) {
                    RoundedCornerShape(item.iconCornerRadiusDp.dp)
                } else {
                    RoundedCornerShape(0.dp)
                }
                Image(
                    painter = painterResource(item.iconDrawableRes),
                    contentDescription = null,
                    modifier = Modifier
                        .size(item.iconSizeDp.dp)
                        .clip(iconShape),
                    contentScale = ContentScale.Fit,
                )
            } else {
                Icon(item.icon, contentDescription = null, tint = item.tint, modifier = Modifier.size(26.dp))
            }
        }
        Column(Modifier.weight(1f)) {
            Text(item.title, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, color = Color(0xFF141518))
            Text(item.subtitle, fontSize = 13.sp, color = Color(0xFF737578), lineHeight = 18.sp)
        }
    }
}

@Composable
fun PaywallBevelAlsoIncludesDivider(modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(Modifier.weight(1f).height(1.dp).background(Color.Black.copy(0.08f)))
        Text(
            "inclut également",
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            color = Color(0xFF8C8E99),
        )
        Box(Modifier.weight(1f).height(1.dp).background(Color.Black.copy(0.08f)))
    }
}

@Composable
fun PaywallBevelFeaturesBlock(
    primary: List<PaywallFeatureItem>,
    alsoIncluded: List<PaywallFeatureItem>,
    modifier: Modifier = Modifier,
) {
    Column(modifier.padding(horizontal = 22.dp)) {
        primary.forEach { PaywallBevelFeatureRow(it) }
        if (alsoIncluded.isNotEmpty()) {
            PaywallBevelAlsoIncludesDivider()
            alsoIncluded.forEach { PaywallBevelFeatureRow(it) }
        }
    }
}

@Composable
fun PaywallBevelContinueButton(
    title: String,
    isLoading: Boolean,
    isEnabled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Button(
        onClick = onClick,
        enabled = isEnabled && !isLoading,
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp),
        shape = RoundedCornerShape(999.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.Black.copy(alpha = if (isEnabled) 1f else 0.35f),
            contentColor = Color.White,
        ),
        elevation = ButtonDefaults.buttonElevation(defaultElevation = 0.dp),
    ) {
        if (isLoading) {
            CircularProgressIndicator(color = Color.White, modifier = Modifier.size(22.dp), strokeWidth = 2.dp)
        } else {
            Text(title, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
        }
    }
}

@Composable
fun PaywallBevelPlanCard(
    title: String,
    priceLine: String? = null,
    isSelected: Boolean,
    savingsBadge: String? = null,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(modifier) {
        Column(
            Modifier
                .fillMaxWidth()
                .shadow(if (isSelected) 14.dp else 8.dp, RoundedCornerShape(18.dp), spotColor = Color.Black.copy(0.08f))
                .clip(RoundedCornerShape(18.dp))
                .background(Color.White)
                .border(
                    width = if (isSelected) 2.dp else 1.dp,
                    color = if (isSelected) Color.Black else Color.Black.copy(0.10f),
                    shape = RoundedCornerShape(18.dp),
                )
                .clickable(
                    indication = null,
                    interactionSource = remember { MutableInteractionSource() },
                    onClick = onClick,
                )
                .padding(horizontal = 16.dp, vertical = 18.dp),
        ) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(title, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, color = Color(0xFF141518))
                Box(
                    Modifier
                        .size(22.dp)
                        .then(
                            if (isSelected) {
                                Modifier.background(Color.Black, CircleShape)
                            } else {
                                Modifier.border(1.5.dp, Color.Black.copy(0.18f), CircleShape)
                            },
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    if (isSelected) {
                        Icon(Icons.Default.Check, contentDescription = null, tint = Color.White, modifier = Modifier.size(14.dp))
                    }
                }
            }
            priceLine?.let {
                Spacer(Modifier.height(6.dp))
                Text(it, fontSize = 14.sp, color = Color(0xFF737578))
            }
        }
        if (savingsBadge != null) {
            Text(
                savingsBadge,
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White,
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .offset(y = (-11).dp)
                    .background(Color.Black, RoundedCornerShape(999.dp))
                    .padding(horizontal = 10.dp, vertical = 5.dp),
            )
        }
    }
}
