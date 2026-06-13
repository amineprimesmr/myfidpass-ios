package fr.myfidpass.ui.components

import android.content.Context
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.data.local.CardPreviewSnapshotStore
import fr.myfidpass.data.local.CommerceFlyerStore
import fr.myfidpass.ui.components.MerchantProUnlockTeaserButton

private const val FLYER_PRO_UNLOCK_CTA = "Débloquer le flyer de jeu avec Pro"
private const val PAYWALL_CONTINUE_CTA = "Essayer pour 1€"

/** Aligné iOS `PostCardFlyerPromoEligibility`. */
object PostCardFlyerPromoEligibility {
    private const val PREFS = "myfidpass.post_card_flyer_promo"
    private const val KEY_PENDING = "pending_merchant_home"
    private const val KEY_SLUG = "pending_slug"

    private var suppressedUntilNextAppOpen = false

    fun resetSessionSuppressionForAppOpen() {
        suppressedUntilNextAppOpen = false
    }

    fun markDismissedWithoutCompletingFlyer() {
        suppressedUntilNextAppOpen = true
    }

    fun stillNeedsFlyerPromo(context: Context, slugRaw: String): Boolean {
        val slug = slugRaw.trim().lowercase()
        if (slug.isEmpty()) return false
        if (!CardPreviewSnapshotStore.isMerchantCardConfigured(context, slug)) return false
        if (CommerceFlyerStore.isFlyerReady(context, slug)) return false
        return true
    }

    fun shouldOffer(context: Context, slugRaw: String): Boolean {
        if (suppressedUntilNextAppOpen) return false
        return stillNeedsFlyerPromo(context, slugRaw)
    }

    fun queuePresentationOnMerchantHome(context: Context, slugRaw: String) {
        if (!stillNeedsFlyerPromo(context, slugRaw)) return
        val slug = slugRaw.trim().lowercase()
        if (slug.isEmpty()) return
        suppressedUntilNextAppOpen = false
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_PENDING, true)
            .putString(KEY_SLUG, slug)
            .apply()
    }

    fun dequeuePendingSlugIfEligible(context: Context): String? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_PENDING, false)) return null
        val slug = prefs.getString(KEY_SLUG, "").orEmpty().trim().lowercase()
        prefs.edit().remove(KEY_PENDING).remove(KEY_SLUG).apply()
        if (slug.isEmpty() || !shouldOffer(context, slug)) return null
        return slug
    }

    fun showsCreationAttentionBadge(context: Context, slugRaw: String?): Boolean {
        slugRaw ?: return false
        return stillNeedsFlyerPromo(context, slugRaw)
    }

    fun clearPendingForLogout(context: Context) {
        suppressedUntilNextAppOpen = false
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }
}

@Composable
fun FlyerProUnlockOverlay(
    locked: Boolean,
    onUnlock: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Box(modifier) {
        Box(
            Modifier.then(
                if (locked) {
                    Modifier
                        .blur(8.dp)
                        .alpha(0.38f)
                } else {
                    Modifier
                },
            ),
        ) {
            content()
        }
        if (locked) {
            Box(
                Modifier
                    .matchParentSize()
                    .background(Color.Black.copy(alpha = 0.42f)),
            )
            FlyerProUnlockButton(
                onClick = onUnlock,
                modifier = Modifier
                    .align(Alignment.Center)
                    .padding(horizontal = 24.dp),
            )
        }
    }
}

@Composable
fun FlyerProUnlockButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    MerchantProUnlockTeaserButton(
        onUnlock = onClick,
        modifier = modifier,
        unlockTitle = FLYER_PRO_UNLOCK_CTA,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PostCardFlyerPromoSheet(
    slug: String,
    visible: Boolean,
    hasProAccess: Boolean,
    onDismiss: () -> Unit,
    onUnlockPro: () -> Unit,
    onCreateFlyer: () -> Unit,
) {
    if (!visible) return
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = {
            PostCardFlyerPromoEligibility.markDismissedWithoutCompletingFlyer()
            onDismiss()
        },
        sheetState = sheetState,
        containerColor = Color(0xFF0A0A0A),
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 22.dp)
                .padding(bottom = 32.dp),
        ) {
            Text(
                "Créez et affichez votre flyer de jeu",
                fontSize = 26.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                "Votre carte est prête — ajoutez un flyer pour attirer vos clients en magasin.",
                fontSize = 15.sp,
                color = Color.White.copy(0.72f),
                lineHeight = 22.sp,
            )
            Spacer(Modifier.height(24.dp))
            Button(
                onClick = {
                    onDismiss()
                    if (hasProAccess) {
                        onCreateFlyer()
                    } else {
                        onUnlockPro()
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color(0xFF007AFF),
                    contentColor = Color.White,
                ),
            ) {
                Text(
                    if (hasProAccess) "Créer mon flyer" else PAYWALL_CONTINUE_CTA,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 17.sp,
                    modifier = Modifier.padding(vertical = 6.dp),
                )
            }
        }
    }
}
