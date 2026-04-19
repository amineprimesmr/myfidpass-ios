package fr.myfidpass.ui.screens.commerce

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.dto.CategoryDto
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.util.toComposeColorOr
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CategoriesScreen(
    repository: DashboardRepository,
    snackbarHostState: SnackbarHostState,
    onBack: () -> Unit,
) {
    val slug = repository.currentSlug()
    val scope = rememberCoroutineScope()
    var loading by remember { mutableStateOf(true) }
    var categories by remember { mutableStateOf<List<CategoryDto>>(emptyList()) }
    var showAdd by remember { mutableStateOf(false) }
    var newName by remember { mutableStateOf("") }
    var newColor by remember { mutableStateOf("#2563EB") }

    fun reload() {
        if (slug == null) return
        scope.launch {
            loading = true
            runCatching { repository.businessCategories(slug).categories }
                .onSuccess { list -> categories = list }
            loading = false
        }
    }

    LaunchedEffect(slug) {
        if (slug == null) {
            loading = false
            return@LaunchedEffect
        }
        reload()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Catégories") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Retour")
                    }
                },
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = { showAdd = true }) {
                Icon(Icons.Default.Add, contentDescription = "Ajouter")
            }
        },
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            if (loading) {
                CircularProgressIndicator(Modifier.padding(24.dp))
            }
            LazyColumn(Modifier.padding(horizontal = 16.dp)) {
                items(categories, key = { it.id }) { c ->
                    Card(
                        Modifier
                            .fillMaxWidth()
                            .padding(vertical = 6.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    ) {
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Box(
                                Modifier
                                    .size(12.dp)
                                    .background(c.colorHex.toComposeColorOr(Color(0xFF2563EB))),
                            )
                            Text(
                                c.name,
                                Modifier
                                    .weight(1f)
                                    .padding(horizontal = 10.dp),
                                style = MaterialTheme.typography.titleMedium,
                            )
                            IconButton(
                                onClick = {
                                    if (slug == null) return@IconButton
                                    scope.launch {
                                        runCatching {
                                            repository.deleteCategory(slug, c.id)
                                            snackbarHostState.showSnackbar("Catégorie supprimée")
                                            reload()
                                        }.onFailure {
                                            snackbarHostState.showSnackbar(it.message ?: "Erreur")
                                        }
                                    }
                                },
                            ) {
                                Icon(Icons.Default.Delete, contentDescription = "Supprimer")
                            }
                        }
                    }
                }
            }
        }
    }

    if (showAdd) {
        AlertDialog(
            onDismissRequest = { showAdd = false },
            title = { Text("Nouvelle catégorie") },
            text = {
                Column {
                    OutlinedTextField(
                        value = newName,
                        onValueChange = { newName = it },
                        label = { Text("Nom") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(
                        value = newColor,
                        onValueChange = { newColor = it },
                        label = { Text("Couleur #RRGGBB") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        if (slug == null || newName.isBlank()) return@TextButton
                        scope.launch {
                            runCatching {
                                repository.createCategory(slug, newName.trim(), newColor.trim().takeIf { it.length == 7 })
                                snackbarHostState.showSnackbar("Créée")
                                newName = ""
                                showAdd = false
                                reload()
                            }.onFailure {
                                snackbarHostState.showSnackbar(it.message ?: "Erreur")
                            }
                        }
                    },
                ) { Text("Créer") }
            },
            dismissButton = {
                TextButton(onClick = { showAdd = false }) { Text("Annuler") }
            },
        )
    }
}
