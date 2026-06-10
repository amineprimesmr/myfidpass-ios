package fr.myfidpass.ui.screens.admin

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.dto.AdminBusinessRowDto
import fr.myfidpass.data.dto.AdminEventRowDto
import fr.myfidpass.data.dto.AdminOverviewResponse
import fr.myfidpass.data.dto.AdminUserRowDto
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.repo.DashboardRepository

@Composable
fun PlatformAdminRootScreen(
    repository: DashboardRepository,
    sessionStore: SessionStore,
    onOpenMerchantApp: () -> Unit,
) {
    var tab by remember { mutableIntStateOf(0) }
    var loading by remember { mutableStateOf(true) }
    var overview by remember { mutableStateOf<AdminOverviewResponse?>(null) }
    var users by remember { mutableStateOf<List<AdminUserRowDto>>(emptyList()) }
    var businesses by remember { mutableStateOf<List<AdminBusinessRowDto>>(emptyList()) }
    var events by remember { mutableStateOf<List<AdminEventRowDto>>(emptyList()) }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(tab) {
        loading = true
        error = null
        runCatching {
            if (tab == 0) overview = repository.adminOverview()
            if (tab == 1) users = repository.adminUsers(limit = 60).users
            if (tab == 2) businesses = repository.adminBusinesses(limit = 80).businesses
            if (tab == 3) events = repository.adminEvents(limit = 50).events
        }.onFailure { error = it.message }
        loading = false
    }

    Scaffold { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            Text(
                "Admin MyFidpass",
                style = MaterialTheme.typography.headlineSmall,
                modifier = Modifier.padding(16.dp),
            )
            Button(
                onClick = {
                    businesses.firstOrNull()?.slug?.let { sessionStore.switchBusiness(it) }
                    onOpenMerchantApp()
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
            ) { Text("Mode commerçant") }
            Spacer(Modifier.height(8.dp))
            TabRow(selectedTabIndex = tab) {
                Tab(selected = tab == 0, onClick = { tab = 0 }, text = { Text("Vue") })
                Tab(selected = tab == 1, onClick = { tab = 1 }, text = { Text("Comptes") })
                Tab(selected = tab == 2, onClick = { tab = 2 }, text = { Text("Commerces") })
                Tab(selected = tab == 3, onClick = { tab = 3 }, text = { Text("Events") })
            }
            Column(
                Modifier
                    .fillMaxSize()
                    .padding(16.dp)
                    .verticalScroll(rememberScrollState()),
            ) {
                if (loading) CircularProgressIndicator()
                error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                when (tab) {
                    0 -> {
                        val o = overview
                        Text("Utilisateurs : ${o?.usersCount ?: "—"}")
                        Text("Commerces : ${o?.businessesCount ?: "—"}")
                        Text("Abonnements actifs : ${o?.activeSubscriptionsCount ?: "—"}")
                        Text(
                            "Détail : ${o?.merchantOwnersCount ?: 0} proprio · ${o?.teamMemberAccountsCount ?: 0} équipe · ${o?.platformAdminAccountsCount ?: 0} admin · ${o?.orphanAccountsCount ?: 0} orphelins",
                        )
                    }
                    1 -> users.forEach { u ->
                        AdminCard("${u.email ?: u.id}${if (u.isAdmin == 1) " · admin" else ""}")
                    }
                    2 -> businesses.forEach { b ->
                        val email = b.ownerEmail?.trim().orEmpty().ifBlank { "E-mail non renseigné" }
                        val members = (b.memberCount ?: 0).coerceAtLeast(0)
                        val memberLabel = if (members == 1) "1 membre" else "$members membres"
                        AdminCard("${b.name ?: b.slug}\n$email · $memberLabel")
                    }
                    3 -> events.forEach { e ->
                        AdminCard("${e.eventType ?: "event"} · ${e.createdAt?.take(16) ?: ""}")
                    }
                }
            }
        }
    }
}

@Composable
private fun AdminCard(text: String) {
    Card(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
        Text(text, modifier = Modifier.padding(12.dp), style = MaterialTheme.typography.bodyMedium)
    }
}
