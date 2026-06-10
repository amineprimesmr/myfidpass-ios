package fr.myfidpass.ui.screens.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import fr.myfidpass.BuildConfig
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.ui.components.FintechLoadMoreTransactionsButton
import fr.myfidpass.ui.components.FintechTransactionPill
import fr.myfidpass.ui.components.FintechTransactionsEmptyState
import fr.myfidpass.ui.components.FintechTransactionsHeader
import fr.myfidpass.ui.components.HomeCardTouchHintPill
import fr.myfidpass.ui.components.DashboardSetupHeroCarousel
import fr.myfidpass.ui.components.GoogleWalletLoyaltyPreviewAndroid
import fr.myfidpass.ui.mycard.MyCardCompletionRequirements
import fr.myfidpass.ui.mycard.MyCardMediaUrls
import fr.myfidpass.data.local.CardPreviewSnapshotStore
import fr.myfidpass.ui.theme.FintechLightPalette
import fr.myfidpass.ui.theme.MerchantDesignSystem
import fr.myfidpass.ui.viewmodel.DashboardViewModel

private const val HOME_CARD_PREVIEW_WIDTH_FRACTION = 0.68f

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeDashboardScreen(
    modifier: Modifier = Modifier,
    viewModel: DashboardViewModel,
    sessionStore: SessionStore,
    isStaff: Boolean = false,
    onMembers: () -> Unit,
    onScan: () -> Unit,
    onMyCard: () -> Unit,
    onActivityFull: () -> Unit = {},
    onMerchantStats: () -> Unit = {},
    onSubscribe: () -> Unit = {},
    repository: DashboardRepository? = null,
    onUnlockPro: () -> Unit = {},
) {
    val palette = FintechLightPalette
    val slug = sessionStore.currentBusinessSlug?.trim()?.lowercase().orEmpty()
    val publicCardUrl = if (slug.isEmpty()) "" else "https://myfidpass.fr/fidelity/$slug?qr=1"
    val settings = viewModel.settings
    val businessName =
        viewModel.stats?.businessName?.takeIf { !it.isNullOrBlank() }
            ?: settings?.organizationName?.takeIf { !it.isNullOrBlank() }
            ?: sessionStore.businesses.firstOrNull { it.slug == slug }?.name
            ?: "Ma boutique"
    val orgLabel = settings?.organizationName
    val isPointsProgram = settings?.programType?.lowercase() != "stamps"
    val previewPoints = if (isPointsProgram) viewModel.stats?.pointsThisMonth ?: 0 else 0
    val previewStampsCount = if (isPointsProgram) 0 else (viewModel.stats?.membersCount?.coerceAtMost(settings?.requiredStamps ?: 10) ?: 0)
    val memberColumn = settings?.labelMember?.ifBlank { null } ?: "Client"

    val context = LocalContext.current
    val snapshot = slug.takeIf { it.isNotEmpty() }?.let { CardPreviewSnapshotStore.load(context, it) }
    val cardConfigured = MyCardCompletionRequirements.isConfigured(settings, snapshot)
    val scrollState = rememberScrollState()

    DisposableEffect(slug) {
        if (slug.isNotEmpty()) {
            viewModel.bindHomeActivityLiveUpdates(slug)
        }
        onDispose { viewModel.unbindHomeActivityLiveUpdates() }
    }

    PullToRefreshBox(
        isRefreshing = viewModel.refreshing,
        onRefresh = { viewModel.refresh() },
        modifier = modifier.fillMaxSize(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 10.dp)
                .padding(bottom = 100.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (viewModel.loading && !viewModel.refreshing) {
                CircularProgressIndicator()
                Spacer(Modifier.height(12.dp))
            }
            viewModel.error?.let {
                Text(it, color = MaterialTheme.colorScheme.error)
                Spacer(Modifier.height(8.dp))
            }

            if (!isStaff && slug.isNotEmpty() && publicCardUrl.isNotEmpty()) {
                HomeCardPreviewTapBlock(
                    showTouchHint = !cardConfigured,
                    onClick = onMyCard,
                ) {
                    GoogleWalletLoyaltyPreviewAndroid(
                        businessName = businessName,
                        qrPayload = publicCardUrl,
                        logoUrl = settings?.logoUrl?.let {
                            MyCardMediaUrls.versionedApiUrl(it, settings.logoUpdatedAt)
                        },
                        backgroundHex = settings?.backgroundColor,
                        labelHex = settings?.labelColor,
                        accentHex = settings?.foregroundColor,
                        compact = true,
                        samplePoints = previewPoints,
                        sampleMemberLabel = memberColumn,
                        programType = settings?.programType,
                        requiredStamps = settings?.requiredStamps ?: 10,
                        previewStampsCount = previewStampsCount,
                        stampEmoji = settings?.stampEmoji,
                        stripDisplayMode = settings?.stripDisplayMode,
                        stripText = settings?.stripText,
                        backgroundImageUrl = if (isPointsProgram && settings?.hasCardBackground == true) {
                            MyCardMediaUrls.cardBackgroundUrl(
                                BuildConfig.API_BASE_URL,
                                slug,
                                settings.cardBackgroundUpdatedAt,
                            )
                        } else null,
                        stampHeroImageUrl = if (
                            settings?.programType?.lowercase() == "stamps" &&
                            settings.hasCardBackground != true &&
                            slug.isNotEmpty()
                        ) {
                            "${BuildConfig.API_BASE_URL.trimEnd('/')}/api/businesses/$slug/public/wallet-stamp-hero?filled=$previewStampsCount"
                        } else null,
                        stampMidRewardLabel = settings?.stampMidRewardLabel.orEmpty(),
                        stampRewardLabel = settings?.stampRewardLabel.orEmpty(),
                        startGameRewardLabel = settings?.startGameRewardLabel.orEmpty(),
                        tierLabels = settings?.pointsRewardTiers?.map { it.label.orEmpty() }.orEmpty(),
                        authToken = sessionStore.accessToken,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                Spacer(Modifier.height(16.dp))
            } else if (!isStaff) {
                Column(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(24.dp))
                        .background(
                            Brush.verticalGradient(
                                listOf(Color(0xFF0D1F3C), Color(0xFF152847)),
                            ),
                        )
                        .clickable(onClick = onMyCard)
                        .padding(22.dp),
                ) {
                    Row(
                        Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(
                                "Finalisez votre lancement",
                                style = MaterialTheme.typography.headlineSmall,
                                fontWeight = FontWeight.Bold,
                                color = Color.White,
                            )
                            Spacer(Modifier.height(8.dp))
                            Text(
                                "Logo, couleurs et récompenses — deux minutes pour être prêt.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = Color.White.copy(0.72f),
                            )
                            Spacer(Modifier.height(12.dp))
                            Text(
                                "Commencer →",
                                style = MaterialTheme.typography.labelLarge,
                                fontWeight = FontWeight.Bold,
                                color = palette.accentBlue.copy(0.95f),
                            )
                        }
                        DashboardSetupHeroCarousel(Modifier.width(120.dp))
                    }
                }
                Spacer(Modifier.height(16.dp))
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth(0.92f)
                    .weight(1f, fill = false)
                    .verticalScroll(scrollState),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                FintechTransactionsHeader(
                    palette = palette,
                    onSeeAll = if (viewModel.recentTransactions.isNotEmpty()) {
                        if (isStaff) onActivityFull else onMerchantStats
                    } else null,
                    onScan = onScan,
                )

                if (viewModel.recentTransactions.isEmpty()) {
                    FintechTransactionsEmptyState(palette = palette)
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        viewModel.recentTransactions
                            .take(viewModel.transactionsVisibleCount)
                            .forEach { t ->
                                FintechTransactionPill(
                                    transaction = t,
                                    palette = palette,
                                    isPointsProgram = isPointsProgram,
                                    pointsPerEuro = settings?.pointsPerEuro?.takeIf { it > 0 },
                                )
                            }
                        if (viewModel.hasMoreTransactions) {
                            FintechLoadMoreTransactionsButton(
                                palette = palette,
                                isLoading = viewModel.loadingMoreTransactions,
                                onClick = { viewModel.loadMoreTransactions() },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun HomeCardPreviewTapBlock(
    showTouchHint: Boolean,
    onClick: () -> Unit,
    content: @Composable () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp),
        contentAlignment = Alignment.TopCenter,
    ) {
        Box(Modifier.fillMaxWidth(HOME_CARD_PREVIEW_WIDTH_FRACTION)) {
            content()
            if (showTouchHint) {
                HomeCardTouchHintPill(
                    modifier = Modifier.align(Alignment.Center),
                )
            }
            Box(
                Modifier
                    .matchParentSize()
                    .zIndex(1f)
                    .clickable(
                        interactionSource = interactionSource,
                        indication = null,
                        onClick = onClick,
                    ),
            )
        }
    }
}
