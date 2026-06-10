package fr.myfidpass.ui.screens.settings

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Link
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.dto.BusinessDto
import fr.myfidpass.data.dto.LoyaltyGroupBusinessLinkDto
import fr.myfidpass.data.dto.LoyaltyGroupCreateRequest
import fr.myfidpass.data.dto.LoyaltyGroupDetailResponse
import fr.myfidpass.data.dto.LoyaltyGroupLinkBusinessRequest
import fr.myfidpass.data.dto.LoyaltyGroupSummaryDto
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.network.MyfidpassApi
import fr.myfidpass.ui.components.GroupedSettingsCard
import fr.myfidpass.ui.components.GroupedSettingsMetrics
import fr.myfidpass.ui.components.GroupedSettingsNavigationRow
import fr.myfidpass.ui.components.GroupedSettingsRowDivider
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoyaltyNetworkSettingsScreen(
    api: MyfidpassApi,
    sessionStore: SessionStore,
    onBack: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var success by remember { mutableStateOf<String?>(null) }
    var groups by remember { mutableStateOf<List<LoyaltyGroupSummaryDto>>(emptyList()) }
    var detail by remember { mutableStateOf<LoyaltyGroupDetailResponse?>(null) }
    var businesses by remember { mutableStateOf(sessionStore.businesses) }
    var showCreate by remember { mutableStateOf(false) }
    var newName by remember { mutableStateOf("") }
    var confirmDelete by remember { mutableStateOf(false) }

    val owned = businesses.filter { !it.id.startsWith("pending-") }
    val unlinked = owned.filter { !it.isInLoyaltyNetwork }

    suspend fun refreshBusinesses() {
        runCatching {
            val me = api.me()
            businesses = me.businesses
            sessionStore.businesses = me.businesses
        }
    }

    suspend fun load() {
        loading = true
        error = null
        refreshBusinesses()
        runCatching {
            val list = api.loyaltyGroupsList().loyaltyGroups
            groups = list
            if (list.isNotEmpty()) {
                detail = api.loyaltyGroupDetail(list.first().id)
            } else {
                detail = null
            }
        }.onFailure { error = it.message }
        loading = false
    }

    LaunchedEffect(Unit) { load() }

    if (showCreate) {
        AlertDialog(
            onDismissRequest = { showCreate = false },
            title = { Text("Nouveau réseau") },
            text = {
                Column {
                    OutlinedTextField(
                        value = newName,
                        onValueChange = { newName = it },
                        label = { Text("Nom (ex. NBK)") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                    if (owned.size < 2) {
                        Spacer(Modifier.height(8.dp))
                        Text(
                            "Ajoutez au moins deux adresses pour créer un réseau.",
                            color = Color(0xFF8E8E93),
                        )
                    }
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        scope.launch {
                            runCatching {
                                api.loyaltyGroupsCreate(
                                    LoyaltyGroupCreateRequest(
                                        name = newName.trim(),
                                        businessIds = owned.map { it.id },
                                    ),
                                )
                                success = "Réseau créé."
                                newName = ""
                                showCreate = false
                                load()
                            }.onFailure { error = it.message }
                        }
                    },
                    enabled = newName.trim().length >= 2 && owned.size >= 2,
                ) { Text("Créer") }
            },
            dismissButton = {
                TextButton(onClick = { showCreate = false }) { Text("Annuler") }
            },
        )
    }

    if (confirmDelete && detail != null) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Supprimer ce réseau ?") },
            text = { Text("Les commerces redeviennent indépendants.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        val id = detail!!.loyaltyGroup.id
                        scope.launch {
                            runCatching {
                                api.loyaltyGroupDelete(id)
                                success = "Réseau supprimé."
                                confirmDelete = false
                                load()
                            }.onFailure { error = it.message }
                        }
                    },
                ) { Text("Supprimer") }
            },
            dismissButton = {
                TextButton(onClick = { confirmDelete = false }) { Text("Annuler") }
            },
        )
    }

    Scaffold(
        containerColor = GroupedSettingsMetrics.pageBackground,
        topBar = {
            TopAppBar(
                title = { Text("Réseau fidélité", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Retour")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = GroupedSettingsMetrics.pageBackground,
                ),
                modifier = Modifier.statusBarsPadding(),
            )
        },
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = GroupedSettingsMetrics.horizontalPadding)
                .navigationBarsPadding(),
        ) {
            GroupedSettingsCard {
                Text("Carte partagée", fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(6.dp))
                Text(
                    "Regroupez plusieurs adresses (ex. NBK Nord + Sud) : une carte, un solde, valable partout dans le réseau.",
                    color = Color(0xFF8E8E93),
                )
            }
            Spacer(Modifier.height(GroupedSettingsMetrics.interCardSpacing))

            success?.let {
                Text(it, color = Color(0xFF34C759))
                Spacer(Modifier.height(8.dp))
            }
            error?.let {
                Text(it, color = Color(0xFFFF3B30))
                Spacer(Modifier.height(8.dp))
            }

            if (loading && detail == null) {
                CircularProgressIndicator(modifier = Modifier.padding(24.dp))
            } else if (detail != null) {
                NetworkDetailCard(
                    detail = detail!!,
                    unlinked = unlinked,
                    onLink = { biz ->
                        scope.launch {
                            runCatching {
                                api.loyaltyGroupLinkBusiness(
                                    detail!!.loyaltyGroup.id,
                                    LoyaltyGroupLinkBusinessRequest(businessId = biz.id),
                                )
                                success = "${biz.name} ajouté."
                                load()
                            }.onFailure { error = it.message }
                        }
                    },
                    onUnlink = { biz ->
                        scope.launch {
                            runCatching {
                                api.loyaltyGroupUnlinkBusiness(detail!!.loyaltyGroup.id, biz.id)
                                success = "${biz.name} retiré."
                                load()
                            }.onFailure { error = it.message }
                        }
                    },
                    onDelete = { confirmDelete = true },
                )
            } else {
                GroupedSettingsCard {
                    Text("Aucun réseau actif", fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(8.dp))
                    if (owned.size >= 2) {
                        GroupedSettingsNavigationRow(
                            icon = Icons.Default.Link,
                            title = "Créer un réseau",
                            onClick = { showCreate = true },
                        )
                    } else {
                        Text("Ajoutez au moins deux adresses pour créer un réseau.", color = Color(0xFF8E8E93))
                    }
                }
            }
            Spacer(Modifier.height(100.dp))
        }
    }
}

@Composable
private fun NetworkDetailCard(
    detail: LoyaltyGroupDetailResponse,
    unlinked: List<BusinessDto>,
    onLink: (BusinessDto) -> Unit,
    onUnlink: (LoyaltyGroupBusinessLinkDto) -> Unit,
    onDelete: () -> Unit,
) {
    GroupedSettingsCard {
        Text(detail.loyaltyGroup.name, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        detail.businesses.forEachIndexed { index, biz ->
            if (index > 0) GroupedSettingsRowDivider()
            androidx.compose.foundation.layout.Row(
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(Modifier.weight(1f)) {
                    Text(biz.organizationName?.takeIf { it.isNotBlank() } ?: biz.name)
                    Text(biz.slug, color = Color(0xFF8E8E93))
                }
                if (detail.businesses.size > 1) {
                    TextButton(onClick = { onUnlink(biz) }) {
                        Text("Retirer", color = Color(0xFFFF3B30))
                    }
                }
            }
        }
        if (unlinked.isNotEmpty()) {
            GroupedSettingsRowDivider()
            Text("Ajouter une adresse", fontWeight = FontWeight.SemiBold)
            unlinked.forEach { biz ->
                GroupedSettingsNavigationRow(
                    icon = Icons.Default.Add,
                    title = biz.name,
                    onClick = { onLink(biz) },
                )
            }
        }
        GroupedSettingsRowDivider()
        TextButton(onClick = onDelete) {
            Text("Supprimer le réseau", color = Color(0xFFFF3B30))
        }
    }
}
