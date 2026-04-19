package fr.myfidpass.ui.screens.commerce

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
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.dto.AdminBusinessRowDto
import fr.myfidpass.data.dto.AdminEventRowDto
import fr.myfidpass.data.repo.DashboardRepository

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminPlatformScreen(
    repository: DashboardRepository,
    onBack: () -> Unit,
) {
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var usersCount by remember { mutableStateOf<Int?>(null) }
    var businessesCount by remember { mutableStateOf<Int?>(null) }
    var subsCount by remember { mutableStateOf<Int?>(null) }
    var businesses by remember { mutableStateOf<List<AdminBusinessRowDto>>(emptyList()) }
    var events by remember { mutableStateOf<List<AdminEventRowDto>>(emptyList()) }
    var eventsError by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        loading = true
        error = null
        eventsError = null
        runCatching {
            val o = repository.adminOverview()
            usersCount = o.usersCount
            businessesCount = o.businessesCount
            subsCount = o.activeSubscriptionsCount
            businesses = repository.adminBusinesses(limit = 80).businesses
        }.onFailure { error = it.message }
        runCatching {
            events = repository.adminEvents(limit = 50).events
        }.onFailure { eventsError = it.message }
        loading = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Admin plateforme") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Retour")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp)
                .verticalScroll(rememberScrollState()),
        ) {
            if (loading) {
                CircularProgressIndicator(Modifier.padding(24.dp))
                return@Column
            }
            error?.let {
                Text(it, color = MaterialTheme.colorScheme.error)
                Spacer(Modifier.height(12.dp))
            }
            Text(
                "Utilisateurs : ${usersCount ?: "—"} · Commerces : ${businessesCount ?: "—"} · Abos actifs : ${subsCount ?: "—"}",
                style = MaterialTheme.typography.bodyMedium,
            )
            Spacer(Modifier.height(20.dp))
            Text("Événements admin (Stripe / système)", style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(8.dp))
            eventsError?.let {
                Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                Spacer(Modifier.height(8.dp))
            }
            if (events.isEmpty()) {
                Text("Aucun événement ou accès refusé.", style = MaterialTheme.typography.bodySmall)
            } else {
                events.forEach { ev ->
                    Card(
                        Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    ) {
                        Column(Modifier.padding(10.dp)) {
                            Text(
                                ev.eventType?.ifBlank { ev.id } ?: ev.id,
                                style = MaterialTheme.typography.labelLarge,
                            )
                            ev.createdAt?.let { Text(it, style = MaterialTheme.typography.bodySmall) }
                            ev.payloadJson?.take(120)?.let { Text(it, style = MaterialTheme.typography.bodySmall) }
                        }
                    }
                }
            }
            Spacer(Modifier.height(20.dp))
            Text("Commerces (extrait)", style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(8.dp))
            businesses.forEach { b ->
                Card(
                    Modifier
                        .fillMaxWidth()
                        .padding(vertical = 6.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                ) {
                    Column(Modifier.padding(12.dp)) {
                        Text(b.name?.ifBlank { b.slug } ?: b.slug, style = MaterialTheme.typography.titleSmall)
                        Text(
                            "${b.organizationName ?: ""} · ${b.ownerEmail ?: ""}",
                            style = MaterialTheme.typography.bodySmall,
                        )
                        Text(
                            "Membres : ${b.memberCount ?: "—"} · Statut : ${b.ownerSubscriptionStatus ?: "—"}",
                            style = MaterialTheme.typography.bodySmall,
                        )
                    }
                }
            }
            Spacer(Modifier.height(24.dp))
        }
    }
}
