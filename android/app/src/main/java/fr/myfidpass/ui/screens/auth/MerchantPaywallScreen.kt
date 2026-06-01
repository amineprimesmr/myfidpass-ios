package fr.myfidpass.ui.screens.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.repo.AuthRepository
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.util.LegalURLs
import fr.myfidpass.util.openInCustomTab
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private const val PAYWALL_TITLE = "Prenez le contrôle de votre fidélité avec MyFidpass"
private const val MONTHLY_PRICE = "49,99 € / mois"
private const val ANNUAL_PRICE = "399,99 € / an"

/** Paywall PRO Bevel + Stripe — aligné iOS `CustomMerchantProPaywallView`. */
@Composable
fun MerchantPaywallScreen(
    userEmail: String?,
    sessionStore: SessionStore,
    dashboardRepository: DashboardRepository,
    authRepository: AuthRepository,
    onLogout: () -> Unit,
    onAccessGranted: () -> Unit = {},
    allowsClose: Boolean = false,
    onClose: () -> Unit = {},
    closeRevealDelayMs: Long = if (allowsClose) 5000L else 0L,
    isMandatorySignupPaywall: Boolean = false,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var isMonthlySelected by remember { mutableStateOf(true) }
    var loading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var closeRevealed by remember { mutableStateOf(closeRevealDelayMs == 0L) }
    var legalMenuOpen by remember { mutableStateOf(false) }

    LaunchedEffect(closeRevealDelayMs) {
        if (closeRevealDelayMs > 0) {
            delay(closeRevealDelayMs)
            closeRevealed = true
        }
    }

    Box(Modifier.fillMaxSize()) {
        PaywallBevelBackdrop()
        Column(
            Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding(),
        ) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 18.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (allowsClose && closeRevealed) {
                    IconButton(onClick = onClose) {
                        Icon(Icons.Default.Close, contentDescription = "Fermer", tint = Color.Black.copy(0.35f))
                    }
                } else {
                    Spacer(Modifier.size(48.dp))
                }
                Box {
                    IconButton(
                        onClick = { legalMenuOpen = true },
                        modifier = Modifier
                            .size(36.dp)
                            .shadow(8.dp, CircleShape, spotColor = Color.Black.copy(0.08f))
                            .background(Color.White, CircleShape),
                    ) {
                        Icon(Icons.Default.MoreHoriz, contentDescription = "Informations légales", tint = Color.Black.copy(0.72f))
                    }
                    DropdownMenu(expanded = legalMenuOpen, onDismissRequest = { legalMenuOpen = false }) {
                        DropdownMenuItem(
                            text = { Text("Politique de confidentialité") },
                            onClick = {
                                legalMenuOpen = false
                                openInCustomTab(context, LegalURLs.PRIVACY)
                            },
                        )
                        DropdownMenuItem(
                            text = { Text("Conditions (CGU)") },
                            onClick = {
                                legalMenuOpen = false
                                openInCustomTab(context, LegalURLs.TERMS)
                            },
                        )
                    }
                }
            }

            Column(
                Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState()),
            ) {
                Text(
                    PAYWALL_TITLE,
                    fontSize = 27.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = Color(0xFF0F1117),
                    textAlign = TextAlign.Center,
                    lineHeight = 32.sp,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 28.dp)
                        .padding(top = 10.dp, bottom = 22.dp),
                )

                PaywallBevelFeaturesBlock(
                    primary = PaywallBevelFeatureCatalog.primary,
                    alsoIncluded = PaywallBevelFeatureCatalog.alsoIncluded,
                    modifier = Modifier.padding(top = 4.dp, bottom = 12.dp),
                )
            }

            Column(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 22.dp)
                    .padding(top = 14.dp, bottom = 28.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    PaywallBevelPlanCard(
                        title = "Mensuel",
                        priceLine = MONTHLY_PRICE,
                        isSelected = isMonthlySelected,
                        onClick = { isMonthlySelected = true },
                        modifier = Modifier.weight(1f),
                    )
                    PaywallBevelPlanCard(
                        title = "Annuel",
                        priceLine = ANNUAL_PRICE,
                        isSelected = !isMonthlySelected,
                        savingsBadge = "Économisez 33 %",
                        onClick = { isMonthlySelected = false },
                        modifier = Modifier.weight(1f),
                    )
                }

                errorMessage?.let {
                    Text(
                        it,
                        fontSize = 12.sp,
                        color = Color(0xFFD32F2F),
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }

                PaywallBevelContinueButton(
                    title = "Continuer",
                    isLoading = loading,
                    isEnabled = !loading,
                    onClick = {
                        scope.launch {
                            loading = true
                            errorMessage = null
                            runCatching {
                                val slug = sessionStore.currentBusinessSlug
                                val url = if (!slug.isNullOrBlank()) {
                                    dashboardRepository.paymentBusinessCheckout(
                                        slug,
                                        if (isMonthlySelected) "month" else "year",
                                    ).url
                                } else {
                                    dashboardRepository.paymentCheckout(null).url
                                }
                                val checkout = url?.trim().orEmpty()
                                if (checkout.isEmpty()) error("URL de paiement indisponible")
                                openInCustomTab(context, checkout)
                            }.onFailure {
                                errorMessage = it.message ?: "Erreur checkout"
                            }
                            loading = false
                        }
                    },
                )

                Text(
                    "Sans engagement",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(0xFF2E3038),
                )
            }
        }
    }
}
