package fr.myfidpass.ui.screens.tabs

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.dto.isApiTrue
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.ui.components.PerimeterMapView
import fr.myfidpass.util.openInCustomTab
import kotlinx.coroutines.launch
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PerimeterSettingsScreen(
    repository: DashboardRepository,
    snackbar: SnackbarHostState,
    onBack: () -> Unit,
) {
    val slug = repository.currentSlug()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var loading by remember { mutableStateOf(true) }
    var saving by remember { mutableStateOf(false) }
    var lat by remember { mutableStateOf("") }
    var lng by remember { mutableStateOf("") }
    var address by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    var radius by remember { mutableFloatStateOf(100f) }
    var includeInPass by remember { mutableStateOf(false) }

    LaunchedEffect(slug) {
        if (slug == null) {
            loading = false
            return@LaunchedEffect
        }
        loading = true
        runCatching { repository.businessSettings(slug) }.onSuccess { s ->
            lat = s.locationLat?.let { String.format(Locale.US, "%.6f", it) }.orEmpty()
            lng = s.locationLng?.let { String.format(Locale.US, "%.6f", it) }.orEmpty()
            address = s.locationAddress.orEmpty()
            message = s.locationRelevantText.orEmpty()
            radius = (s.locationRadiusMeters ?: 100).coerceIn(25, 100).toFloat()
            includeInPass = s.walletPassIncludeLocations.isApiTrue()
        }
        loading = false
    }

    fun save() {
        if (slug == null) return
        scope.launch {
            saving = true
            runCatching {
                val patch = buildJsonObject {
                    lat.toDoubleOrNull()?.let { put("location_lat", it) }
                    lng.toDoubleOrNull()?.let { put("location_lng", it) }
                    put("location_address", address.trim())
                    put("location_relevant_text", message.trim())
                    put("location_radius_meters", radius.toInt())
                    put("wallet_pass_include_locations", if (includeInPass) 1 else 0)
                }
                repository.patchDashboardSettings(slug, patch)
            }.onSuccess {
                snackbar.showSnackbar("Périmètre enregistré")
                onBack()
            }.onFailure {
                snackbar.showSnackbar(it.message ?: "Erreur")
            }
            saving = false
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Périmètre") },
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
                .padding(padding),
        ) {
            if (loading) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                return@Column
            }
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(260.dp),
            ) {
                PerimeterMapView(
                    latitude = lat.toDoubleOrNull(),
                    longitude = lng.toDoubleOrNull(),
                    radiusMeters = radius.toInt(),
                    onMapClick = { la, lo ->
                        lat = String.format(Locale.US, "%.6f", la)
                        lng = String.format(Locale.US, "%.6f", lo)
                    },
                )
            }
            Column(
                Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
            ) {
                Text(
                    "Appuyez sur la carte pour placer le commerce. Rayon 25–100 m (Wallet).",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(12.dp))
                OutlinedTextField(lat, { lat = it }, label = { Text("Latitude") }, modifier = Modifier.fillMaxWidth())
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(lng, { lng = it }, label = { Text("Longitude") }, modifier = Modifier.fillMaxWidth())
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(address, { address = it }, label = { Text("Adresse") }, modifier = Modifier.fillMaxWidth())
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(message, { message = it }, label = { Text("Message périmètre") }, modifier = Modifier.fillMaxWidth(), minLines = 2)
                Spacer(Modifier.height(12.dp))
                Text("Rayon : ${radius.toInt()} m")
                Slider(value = radius, onValueChange = { radius = it }, valueRange = 25f..100f, steps = 2)
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text("Inclure dans le pass Wallet", modifier = Modifier.weight(1f))
                    Switch(checked = includeInPass, onCheckedChange = { includeInPass = it })
                }
                Spacer(Modifier.height(12.dp))
                val latD = lat.toDoubleOrNull()
                val lngD = lng.toDoubleOrNull()
                if (latD != null && lngD != null) {
                    Button(
                        onClick = { openInCustomTab(context, "https://www.google.com/maps?q=$latD,$lngD") },
                        modifier = Modifier.fillMaxWidth(),
                    ) { Text("Voir sur Google Maps") }
                    Spacer(Modifier.height(8.dp))
                }
                Button(onClick = { save() }, enabled = !saving && slug != null, modifier = Modifier.fillMaxWidth()) {
                    if (saving) CircularProgressIndicator() else Text("Enregistrer")
                }
            }
        }
    }
}
