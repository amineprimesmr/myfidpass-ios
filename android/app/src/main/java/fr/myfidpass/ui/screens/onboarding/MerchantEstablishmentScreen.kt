package fr.myfidpass.ui.screens.onboarding

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import fr.myfidpass.ui.theme.BackgroundLight
import fr.myfidpass.ui.theme.Primary
import fr.myfidpass.ui.viewmodel.MerchantOnboardingViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MerchantEstablishmentScreen(
    viewModel: MerchantOnboardingViewModel,
    showTopBarBack: Boolean,
    onBack: (() -> Unit)?,
    onContinue: (placeId: String?, description: String?, relax: Boolean) -> Unit,
    onAlreadyHaveAccount: () -> Unit,
) {
    Scaffold(
        containerColor = BackgroundLight,
        topBar = {
            if (showTopBarBack && onBack != null) {
                TopAppBar(
                    title = { },
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Retour")
                        }
                    },
                )
            }
        },
        bottomBar = {
            Column(Modifier.padding(20.dp)) {
                Button(
                    onClick = {
                        onContinue(
                            viewModel.selectedPlaceId,
                            viewModel.selectedDescription,
                            viewModel.relaxRequirement,
                        )
                    },
                    enabled = viewModel.canContinue,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("CONTINUER")
                }
                TextButton(onClick = onAlreadyHaveAccount, modifier = Modifier.fillMaxWidth()) {
                    Text("J'ai déjà un compte", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 20.dp),
        ) {
            Spacer(Modifier.height(16.dp))
            Text(
                text = "Comment s'appelle votre établissement ?",
                style = MaterialTheme.typography.titleLarge,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(20.dp))
            if (viewModel.selectedPlaceId == null && !viewModel.relaxRequirement) {
                OutlinedTextField(
                    value = viewModel.query,
                    onValueChange = { viewModel.onQueryChange(it) },
                    modifier = Modifier.fillMaxWidth(),
                    placeholder = { Text("Recherchez votre commerce") },
                    singleLine = true,
                )
            }
            if (viewModel.selectedPlaceId != null) {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { viewModel.clearSelection() },
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Text(
                            viewModel.selectedMainText ?: "",
                            style = MaterialTheme.typography.titleMedium,
                        )
                        viewModel.selectedSecondaryText?.let {
                            Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Spacer(Modifier.height(8.dp))
                        TextButton(onClick = { viewModel.clearSelection() }) {
                            Text("Modifier la recherche", color = Primary)
                        }
                    }
                }
            }
            if (viewModel.isSearching) {
                CircularProgressIndicator(Modifier.padding(16.dp))
            }
            viewModel.hint?.let {
                Text(
                    it,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
            if (viewModel.selectedPlaceId == null && viewModel.predictions.isNotEmpty()) {
                LazyColumn(
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = 360.dp),
                ) {
                    items(viewModel.predictions, key = { it.placeId }) { p ->
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { viewModel.selectPrediction(p) },
                        ) {
                            Column(Modifier.padding(14.dp)) {
                                Text(
                                    p.mainText?.takeIf { it.isNotBlank() } ?: p.description,
                                    style = MaterialTheme.typography.bodyLarge,
                                )
                                p.secondaryText?.takeIf { it.isNotBlank() }?.let { s ->
                                    Text(s, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
