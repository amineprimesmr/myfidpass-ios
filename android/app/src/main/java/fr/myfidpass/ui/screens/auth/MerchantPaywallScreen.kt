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
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
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
import fr.myfidpass.util.MerchantMultiPricing
import fr.myfidpass.util.openInCustomTab
import kotlinx.coroutines.delay

private const val PAYWALL_TITLE = "Combien de commerces avez-vous ?"

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
    addingAnotherCommerce: Boolean = false,
    pendingCommerceName: String? = null,
) {
    val context = LocalContext.current
    var loading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var closeRevealed by remember { mutableStateOf(closeRevealDelayMs == 0L) }
    var legalMenuOpen by remember { mutableStateOf(false) }

    val paidSlotsBaseline = sessionStore.allowedBusinesses.coerceIn(1, 5)
    val initialTargetSlots = remember(addingAnotherCommerce, sessionStore.usedBusinesses, paidSlotsBaseline) {
        MerchantMultiPricing.slotsToPurchase(
            usedBusinesses = sessionStore.usedBusinesses,
            allowedBusinesses = paidSlotsBaseline,
            addingAnotherCommerce = addingAnotherCommerce,
        )
    }
    var selectedTargetSlots by remember { mutableIntStateOf(initialTargetSlots) }
    var isMonthlyPlanSelected by remember { mutableStateOf(false) }

    LaunchedEffect(initialTargetSlots, addingAnotherCommerce) {
        selectedTargetSlots = initialTargetSlots
    }

    val effectiveSlots = selectedTargetSlots.coerceIn(1, 5)
    val supportsAnnualPlanToggle = MerchantMultiPricing.supportsAnnualPlan(effectiveSlots)
    val selectedPlanIsAnnual = supportsAnnualPlanToggle && !isMonthlyPlanSelected

    LaunchedEffect(effectiveSlots, supportsAnnualPlanToggle) {
        if (!supportsAnnualPlanToggle) {
            isMonthlyPlanSelected = true
        }
    }

    val monthlyPlanCardPriceLine = remember(effectiveSlots) {
        "${MerchantMultiPricing.monthlyTotalLabel(effectiveSlots).replace(" €", "€")} /mois"
    }
    val annualPlanCardPriceLine = remember(effectiveSlots) {
        "${MerchantMultiPricing.annualMonthlyEquivalentLabel(effectiveSlots).replace(" €", "€")} /mois"
    }
    val monthlyPriceLine = remember(effectiveSlots) {
        "1 € puis ${MerchantMultiPricing.monthlyTotalLabel(effectiveSlots)} / mois"
    }
    val annualPriceLine = remember(effectiveSlots) {
        "1 € puis ${MerchantMultiPricing.annualTotalLabel(effectiveSlots)} / an"
    }
    val annualSavingsBadge = remember(effectiveSlots) {
        MerchantMultiPricing.annualSavingsPercent(effectiveSlots)?.let { "Économisez $it %" }
            ?: "Économisez 33 %"
    }
    val multiCommerceSavingsBadge = remember(effectiveSlots) {
        MerchantMultiPricing.multiCommerceSavingsPercent(effectiveSlots)?.let { "Économisez $it %" }
    }

    val showsCommerceQuotaSection = true

    val footerCommitmentText = remember(effectiveSlots, selectedPlanIsAnnual) {
        if (selectedPlanIsAnnual) {
            "Puis ${MerchantMultiPricing.annualTotalLabel(effectiveSlots)} / an sans engagement"
        } else {
            "Puis ${MerchantMultiPricing.monthlyTotalLabel(effectiveSlots)} / mois sans engagement"
        }
    }

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

                if (showsCommerceQuotaSection) {
                    PaywallCommerceQuotaSection(
                        businesses = sessionStore.businesses,
                        usedBusinesses = sessionStore.usedBusinesses,
                        allowedBusinesses = paidSlotsBaseline,
                        hasActiveSubscription = sessionStore.hasPaidMerchantSubscription(),
                        addingAnotherCommerce = addingAnotherCommerce,
                        pendingCommerceName = pendingCommerceName,
                        selectedTargetSlots = effectiveSlots,
                        onSelectedTargetSlotsChange = { selectedTargetSlots = it },
                        modifier = Modifier
                            .padding(horizontal = 22.dp)
                            .padding(bottom = 10.dp),
                    )
                }

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
                if (supportsAnnualPlanToggle) {
                    Row(
                        Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        PaywallBevelPlanCard(
                            title = "Mensuel",
                            priceLine = monthlyPlanCardPriceLine,
                            isSelected = isMonthlyPlanSelected,
                            onClick = { isMonthlyPlanSelected = true },
                            modifier = Modifier.weight(1f),
                        )
                        PaywallBevelPlanCard(
                            title = "Annuel",
                            priceLine = annualPlanCardPriceLine,
                            isSelected = !isMonthlyPlanSelected,
                            savingsBadge = annualSavingsBadge,
                            onClick = { isMonthlyPlanSelected = false },
                            modifier = Modifier.weight(1f),
                        )
                    }
                } else {
                    PaywallBevelPlanCard(
                        title = if (effectiveSlots == 1) "Mensuel" else "$effectiveSlots commerces",
                        priceLine = if (effectiveSlots == 1) monthlyPlanCardPriceLine else null,
                        isSelected = true,
                        savingsBadge = multiCommerceSavingsBadge,
                        onClick = {},
                        modifier = Modifier.fillMaxWidth(),
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
                    title = "Essayer pour 1€",
                    isLoading = loading,
                    isEnabled = !loading,
                    onClick = {
                        loading = true
                        errorMessage = null
                        runCatching {
                            val checkout = LegalURLs.merchantEmbeddedSaasPaymentPage(
                                prefilledEmail = userEmail,
                                planAnnual = selectedPlanIsAnnual,
                                commerceSlots = effectiveSlots,
                                accessToken = sessionStore.accessToken,
                                refreshToken = sessionStore.refreshToken,
                            )
                            if (checkout.isBlank()) error("URL de paiement indisponible")
                            openInCustomTab(context, checkout)
                        }.onFailure {
                            errorMessage = it.message ?: "Erreur checkout"
                        }
                        loading = false
                    },
                )

                Text(
                    footerCommitmentText,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(0xFF2E3038),
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}
