package fr.myfidpass.ui.screens.settings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.services.sync.SyncService
import fr.myfidpass.ui.components.GroupedSettingsCard
import fr.myfidpass.ui.components.GroupedSettingsIconBox
import fr.myfidpass.ui.components.GroupedSettingsMetrics
import fr.myfidpass.ui.components.GroupedSettingsRowDivider
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

@Composable
fun SettingsLastSyncSection(
    syncService: SyncService,
    scope: CoroutineScope,
    businessSlug: String,
    modifier: Modifier = Modifier,
    showsSyncNowButton: Boolean = true,
    onSyncStarted: (() -> Unit)? = null,
) {
    val lastText = remember(syncService.lastSyncAtMillis, syncService.lastSyncError) {
        formatLastSync(syncService.lastSyncAtMillis)
    }
    var syncMetaText by remember(businessSlug) { mutableStateOf<String?>(null) }
    LaunchedEffect(businessSlug, syncService.lastSyncAtMillis) {
        val slug = businessSlug.trim()
        if (slug.isEmpty()) {
            syncMetaText = null
            return@LaunchedEffect
        }
        val meta = syncService.getSyncMeta(slug)
        syncMetaText = meta?.let { "${it.membersTotal} membres · ${it.transactionsTotal} opérations" }
    }
    GroupedSettingsCard(modifier) {
        Column(Modifier.fillMaxWidth()) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = GroupedSettingsMetrics.horizontalPadding, vertical = GroupedSettingsMetrics.rowVerticalPadding),
                verticalAlignment = Alignment.Top,
            ) {
                GroupedSettingsIconBox(Icons.Default.Sync)
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Row(
                        Modifier.fillMaxWidth(),
                        horizontalArrangement = androidx.compose.foundation.layout.Arrangement.SpaceBetween,
                    ) {
                        Text("Dernière synchro", fontWeight = FontWeight.Medium, fontSize = 16.sp)
                        Text(lastText, fontSize = 16.sp, color = Color(0xFF8E8E93))
                    }
                    syncMetaText?.let { meta ->
                        Spacer(Modifier.height(4.dp))
                        Text(meta, fontSize = 13.sp, color = Color(0xFF8E8E93))
                    }
                    syncService.lastSyncError?.takeIf { it.isNotEmpty() }?.let { err ->
                        Spacer(Modifier.height(4.dp))
                        Text(err, fontSize = 12.sp, color = Color(0xFFFF3B30))
                    }
                }
            }
            if (showsSyncNowButton) {
                GroupedSettingsRowDivider()
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable {
                            scope.launch {
                                val slug = businessSlug.trim()
                                if (slug.isNotEmpty()) {
                                    syncService.invalidateThrottle()
                                    syncService.syncIfNeeded(slug, force = true)
                                }
                                onSyncStarted?.invoke()
                            }
                        }
                        .padding(horizontal = GroupedSettingsMetrics.horizontalPadding, vertical = GroupedSettingsMetrics.rowVerticalPadding),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    GroupedSettingsIconBox(Icons.Default.Sync)
                    Spacer(Modifier.width(12.dp))
                    Text("Synchroniser maintenant", fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                }
            }
        }
    }
}
