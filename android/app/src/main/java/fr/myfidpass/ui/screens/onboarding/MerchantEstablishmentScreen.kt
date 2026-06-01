package fr.myfidpass.ui.screens.onboarding

import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
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
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.myfidpass.ui.theme.Primary
import fr.myfidpass.ui.viewmodel.MerchantOnboardingViewModel

/** Espace sous la barre de progression Process (overlay parent). */
private val ProcessHeaderTopInset = 72.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MerchantEstablishmentScreen(
    viewModel: MerchantOnboardingViewModel,
    showTopBarBack: Boolean,
    onBack: (() -> Unit)?,
    onContinue: (placeId: String?, description: String?, relax: Boolean) -> Unit,
    onAlreadyHaveAccount: () -> Unit,
) {
    val integratedInProcess = !showTopBarBack

    Scaffold(
        containerColor = Color.White,
        topBar = {
            if (showTopBarBack && onBack != null) {
                IconButton(onClick = onBack, modifier = Modifier.padding(8.dp)) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Retour")
                }
            }
        },
        bottomBar = {
            Column(Modifier.padding(horizontal = 24.dp, vertical = 20.dp)) {
                Button(
                    onClick = {
                        onContinue(
                            viewModel.selectedPlaceId,
                            viewModel.selectedDescription,
                            viewModel.relaxRequirement,
                        )
                    },
                    enabled = viewModel.canContinue,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                    shape = RoundedCornerShape(999.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color.Black,
                        contentColor = Color.White,
                        disabledContainerColor = Color.Black.copy(alpha = 0.22f),
                        disabledContentColor = Color.White.copy(alpha = 0.72f),
                    ),
                ) {
                    Text("CONTINUER", fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
                }
                TextButton(onClick = onAlreadyHaveAccount, modifier = Modifier.fillMaxWidth()) {
                    Text("J'ai déjà un compte", color = Color.Black.copy(0.55f))
                }
            }
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(Color.White)
                .padding(horizontal = 28.dp),
        ) {
            Spacer(Modifier.height(if (integratedInProcess) ProcessHeaderTopInset else 16.dp))
            Text(
                text = "Quel est votre commerce ?",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF141518),
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(10.dp))
            Text(
                "Recherchez votre établissement pour démarrer.",
                fontSize = 15.sp,
                color = Color(0xFF73737A),
                textAlign = TextAlign.Center,
                lineHeight = 21.sp,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(24.dp))
            if (viewModel.selectedPlaceId == null && !viewModel.relaxRequirement) {
                OutlinedTextField(
                    value = viewModel.query,
                    onValueChange = { viewModel.onQueryChange(it) },
                    modifier = Modifier.fillMaxWidth(),
                    placeholder = { Text("Recherchez votre commerce…") },
                    singleLine = true,
                    shape = RoundedCornerShape(16.dp),
                )
            }
            if (viewModel.selectedPlaceId != null) {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { viewModel.clearSelection() },
                    colors = CardDefaults.cardColors(containerColor = Color(0xFFF8F8FA)),
                    shape = RoundedCornerShape(18.dp),
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Text(
                            viewModel.selectedMainText ?: "",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                        )
                        viewModel.selectedSecondaryText?.let {
                            Text(it, style = MaterialTheme.typography.bodyMedium, color = Color(0xFF64748B))
                        }
                        Spacer(Modifier.height(8.dp))
                        TextButton(onClick = { viewModel.clearSelection() }) {
                            Text("Modifier la recherche", color = Primary)
                        }
                    }
                }
            }
            if (viewModel.isSearching) {
                CircularProgressIndicator(Modifier.padding(16.dp).align(Alignment.CenterHorizontally))
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
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = 360.dp)
                        .padding(top = 12.dp),
                ) {
                    items(viewModel.predictions, key = { it.placeId }) { p ->
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { viewModel.selectPrediction(p) },
                            shape = RoundedCornerShape(14.dp),
                            colors = CardDefaults.cardColors(containerColor = Color(0xFFF8F8FA)),
                        ) {
                            Column(Modifier.padding(14.dp)) {
                                Text(
                                    p.mainText?.takeIf { it.isNotBlank() } ?: p.description,
                                    style = MaterialTheme.typography.bodyLarge,
                                )
                                p.secondaryText?.takeIf { it.isNotBlank() }?.let { s ->
                                    Text(s, style = MaterialTheme.typography.bodySmall, color = Color(0xFF64748B))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
