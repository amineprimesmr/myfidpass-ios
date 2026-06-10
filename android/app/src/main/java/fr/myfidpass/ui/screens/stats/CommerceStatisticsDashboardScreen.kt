package fr.myfidpass.ui.screens.stats

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.data.local.FirstLaunchPreferences
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.ui.stats.CommerceStatsGoogleMapsOpener
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import fr.myfidpass.ui.components.CommerceStatsCategoryListCard
import fr.myfidpass.ui.components.CommerceStatsConnectNetworksRow
import fr.myfidpass.ui.components.CommerceStatsKpiCarousel
import fr.myfidpass.ui.components.CommerceStatsNotificationImpactCard
import fr.myfidpass.ui.components.CommerceStatsProUnlockOverlay
import fr.myfidpass.ui.components.CommerceStatsSectionHeader
import fr.myfidpass.ui.stats.CommerceStatsMonthNavigator
import fr.myfidpass.ui.theme.CommerceStatsLightEmbedded
import fr.myfidpass.ui.theme.FintechLightPalette
import fr.myfidpass.ui.theme.MerchantDesignSystem
import fr.myfidpass.ui.viewmodel.MerchantStatsViewModel
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CommerceStatisticsDashboardScreen(
    repository: DashboardRepository,
    onBack: () -> Unit,
    hasProInsights: Boolean = true,
    onUnlockPro: () -> Unit = {},
    embeddedRoot: Boolean = false,
    onAccounting: () -> Unit = {},
    onTraceability: () -> Unit = {},
    onStatsTransactions: () -> Unit = {},
    onOpenSocial: () -> Unit = {},
    onOpenMembers: () -> Unit = {},
    statsViewModel: MerchantStatsViewModel,
) {
    val palette = CommerceStatsLightEmbedded
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var showPanierRepereSheet by remember { mutableStateOf(false) }
    var selectedMonthKey by remember {
        mutableStateOf(CommerceStatsMonthNavigator.calendarMonthKey())
    }
    val vm = statsViewModel
    val slug = repository.currentSlug()
    var connectedSocialNetworkIds by remember { mutableStateOf(setOf<String>()) }
    var socialConnectSubtitle by remember {
        mutableStateOf("Instagram · TikTok · Facebook · X — missions & points")
    }

    var cachedSettingsPlaceId by remember { mutableStateOf<String?>(null) }
    var cachedOrganizationName by remember { mutableStateOf<String?>(null) }
    var cachedLocationAddress by remember { mutableStateOf<String?>(null) }

    fun openGoogleMapsReviews() {
        val businessSlug = slug?.trim().orEmpty()
        if (businessSlug.isEmpty()) {
            Toast.makeText(context, "Commerce introuvable", Toast.LENGTH_SHORT).show()
            return
        }
        val firstLaunch = FirstLaunchPreferences(context)
        val instant = CommerceStatsGoogleMapsOpener.resolveInstantUri(
            context = context,
            slug = businessSlug,
            firstLaunch = firstLaunch,
            organizationName = cachedOrganizationName,
            locationAddress = cachedLocationAddress,
            cachedSettingsPlaceId = cachedSettingsPlaceId,
        )
        if (CommerceStatsGoogleMapsOpener.openUri(context, instant)) {
            scope.launch {
                CommerceStatsGoogleMapsOpener.prefetchOpenUri(
                    repository = repository,
                    slug = businessSlug,
                    firstLaunch = firstLaunch,
                    organizationName = cachedOrganizationName,
                    locationAddress = cachedLocationAddress,
                    context = context,
                )
            }
            return
        }
        scope.launch {
            val uri = CommerceStatsGoogleMapsOpener.resolveOpenUri(
                repository = repository,
                slug = businessSlug,
                firstLaunch = firstLaunch,
                organizationName = cachedOrganizationName,
                locationAddress = cachedLocationAddress,
                context = context,
            )
            if (!CommerceStatsGoogleMapsOpener.openUri(context, uri)) {
                Toast.makeText(
                    context,
                    "Fiche Google introuvable — vérifiez Mon établissement",
                    Toast.LENGTH_SHORT,
                ).show()
            }
        }
    }

    LaunchedEffect(slug) {
        vm.resetForBusinessSwitch(slug)
        vm.load(force = true)
        val businessSlug = slug?.trim().orEmpty()
        if (businessSlug.isEmpty()) {
            cachedSettingsPlaceId = null
            cachedOrganizationName = null
            cachedLocationAddress = null
            return@LaunchedEffect
        }
        val settings = runCatching { repository.businessSettings(businessSlug) }.getOrNull()
        cachedSettingsPlaceId = settings?.engagementRewards?.googleReview?.placeId?.trim()?.takeIf { it.isNotEmpty() }
        cachedOrganizationName = settings?.organizationName?.trim()?.takeIf { it.isNotEmpty() }
        cachedLocationAddress = settings?.locationAddress?.trim()?.takeIf { it.isNotEmpty() }
        val firstLaunch = FirstLaunchPreferences(context)
        CommerceStatsGoogleMapsOpener.prefetchOpenUri(
            repository = repository,
            slug = businessSlug,
            firstLaunch = firstLaunch,
            organizationName = cachedOrganizationName,
            locationAddress = cachedLocationAddress,
            context = context,
        )
    }

    var socialMissionsRefreshTick by remember { mutableIntStateOf(0) }
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) socialMissionsRefreshTick++
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    LaunchedEffect(slug, socialMissionsRefreshTick) {
        val s = slug?.trim().orEmpty()
        if (s.isEmpty()) {
            connectedSocialNetworkIds = emptySet()
            socialConnectSubtitle = "Instagram · TikTok · Facebook · X — missions & points"
            return@LaunchedEffect
        }
        runCatching {
            val json = repository.dashboardSocialMissions(s)
            val connected = mutableSetOf<String>()
            val labels = mutableListOf<String>()
            listOf(
                "instagram" to "IG",
                "tiktok" to "TikTok",
                "facebook" to "FB",
                "twitter" to "X",
            ).forEach { (key, tag) ->
                val node = json[key]?.jsonObject
                val enabled = when (val el = node?.get("enabled")) {
                    null -> false
                    else -> el.toString().contains("true", ignoreCase = true) || el.toString() == "1"
                }
                val user = node?.get("username")?.jsonPrimitive?.content.orEmpty().trim()
                if (enabled && user.isNotEmpty()) {
                    connected.add(key)
                    labels += "$tag @$user"
                }
            }
            connectedSocialNetworkIds = connected
            socialConnectSubtitle = if (labels.isEmpty()) {
                "Instagram · TikTok · Facebook · X — missions & points"
            } else {
                labels.joinToString(" · ")
            }
        }
    }

    val detailPresentation = remember(selectedMonthKey, hasProInsights, vm.monthSnapshots) {
        vm.presentationForMonth(selectedMonthKey, hasProInsights)
    }
    val notificationCampaigns = remember(selectedMonthKey, hasProInsights, vm.monthSnapshots) {
        vm.notificationCampaignsForMonth(selectedMonthKey, hasProInsights, context)
    }

    val scrollContent: @Composable () -> Unit = {
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(top = if (embeddedRoot) 4.dp else 0.dp)
                .padding(bottom = 96.dp),
        ) {
            if (vm.loading && vm.monthSnapshots.isEmpty()) {
                CircularProgressIndicator(Modifier.padding(MerchantDesignSystem.spacingMd))
            } else {
                vm.error?.let {
                    Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(16.dp))
                }

                CommerceStatsKpiCarousel(
                    pages = vm.pages(),
                    palette = palette,
                    panierFreqLocked = !hasProInsights,
                    onUnlockPro = onUnlockPro,
                    onMonthChanged = { selectedMonthKey = it },
                    onMembersTap = { onOpenMembers() },
                    onPanierTap = {
                        if (hasProInsights) showPanierRepereSheet = true
                        else onUnlockPro()
                    },
                    onGoogleReviewsTap = {
                        if (hasProInsights) openGoogleMapsReviews()
                        else onUnlockPro()
                    },
                )

                Spacer(Modifier.height(22.dp))

                CommerceStatsProUnlockOverlay(
                    locked = !hasProInsights,
                    onUnlock = onUnlockPro,
                    modifier = Modifier.padding(horizontal = 8.dp),
                ) {
                    Column {
                        CommerceStatsSectionHeader(
                            "Plus de données",
                            modifier = Modifier.padding(horizontal = 16.dp),
                        )
                        Spacer(Modifier.height(12.dp))
                        CommerceStatsCategoryListCard(
                            rows = detailPresentation.categoryRows,
                            palette = palette,
                            modifier = Modifier.padding(horizontal = 8.dp),
                            onViewGoogleReviews = { openGoogleMapsReviews() },
                            onRowTap = { id ->
                                if (id == "rewards" && hasProInsights) onAccounting()
                            },
                        )
                        if (notificationCampaigns.isNotEmpty()) {
                            Spacer(Modifier.height(16.dp))
                            Text(
                                "Notifications envoyées",
                                fontWeight = FontWeight.Bold,
                                fontSize = 16.sp,
                                modifier = Modifier.padding(horizontal = 16.dp),
                            )
                            Spacer(Modifier.height(12.dp))
                            CommerceStatsNotificationImpactCard(
                                campaigns = notificationCampaigns,
                                palette = palette,
                                modifier = Modifier.padding(horizontal = 8.dp),
                            )
                        }
                    }
                }

                Spacer(Modifier.height(32.dp))

                CommerceStatsProUnlockOverlay(
                    locked = !hasProInsights,
                    onUnlock = onUnlockPro,
                    modifier = Modifier.padding(horizontal = 8.dp),
                ) {
                    Column {
                        CommerceStatsSectionHeader(
                            "Engagement réseaux sociaux",
                            modifier = Modifier.padding(horizontal = 16.dp),
                        )
                        Spacer(Modifier.height(12.dp))
                        CommerceStatsCategoryListCard(
                            rows = detailPresentation.engagementRows,
                            palette = palette,
                            modifier = Modifier.padding(horizontal = 8.dp),
                        )
                        if (connectedSocialNetworkIds.size < 4) {
                            Spacer(Modifier.height(12.dp))
                            CommerceStatsConnectNetworksRow(
                                subtitle = socialConnectSubtitle,
                                connectedNetworkIds = connectedSocialNetworkIds,
                                onClick = onOpenSocial,
                                modifier = Modifier.padding(horizontal = 8.dp),
                            )
                        }
                    }
                }

                if (hasProInsights) {
                    Spacer(Modifier.height(24.dp))
                    Column(Modifier.padding(horizontal = 16.dp)) {
                        Text(
                            "Exports & historique",
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp,
                        )
                        Spacer(Modifier.height(12.dp))
                        androidx.compose.material3.OutlinedButton(
                            onClick = onStatsTransactions,
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text("Historique complet")
                        }
                        Spacer(Modifier.height(8.dp))
                        androidx.compose.material3.Button(onClick = onAccounting, modifier = Modifier.fillMaxWidth()) {
                            Text("Pack comptable")
                        }
                        Spacer(Modifier.height(8.dp))
                        androidx.compose.material3.OutlinedButton(onClick = onTraceability, modifier = Modifier.fillMaxWidth()) {
                            Text("Traçabilité & exports")
                        }
                    }
                }
            }
        }
    }

    MerchantStatsPanierRepereSheet(
        initialEuro = vm.baselinePanierRepereEuro,
        visible = showPanierRepereSheet,
        onDismiss = { showPanierRepereSheet = false },
        onSave = { value, clear -> vm.savePanierRepere(value, clear) },
    )

    if (embeddedRoot) {
        Box(Modifier.fillMaxSize()) {
            scrollContent()
        }
    } else {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("Statistiques") },
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Retour")
                        }
                    },
                )
            },
        ) { padding ->
            Column(Modifier.fillMaxSize().padding(padding)) {
                scrollContent()
            }
        }
    }
}
