package fr.myfidpass.ui.screens.auth

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import fr.myfidpass.ui.theme.Primary
import fr.myfidpass.ui.viewmodel.EmailAuthPhase
import fr.myfidpass.ui.viewmodel.EmailAuthViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EmailAuthModalSheet(
    viewModel: EmailAuthViewModel,
    onDismiss: () -> Unit,
    onSuccess: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = {
            viewModel.resetForSheet()
            onDismiss()
        },
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .padding(horizontal = 24.dp)
                .padding(bottom = 32.dp)
                .verticalScroll(rememberScrollState()),
        ) {
            when (viewModel.phase) {
                EmailAuthPhase.Email -> {
                    Text(
                        "Continuer avec l'e-mail",
                        style = MaterialTheme.typography.headlineSmall,
                    )
                    Spacer(Modifier.height(12.dp))
                    Text(
                        "Inscrivez-vous ou connectez-vous avec votre e-mail. Mot de passe à l'étape suivante.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.height(20.dp))
                    OutlinedTextField(
                        value = viewModel.email,
                        onValueChange = { viewModel.email = it },
                        label = { Text("Adresse e-mail") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                    )
                    Spacer(Modifier.height(16.dp))
                    Button(
                        onClick = { viewModel.goToCredentials() },
                        enabled = viewModel.emailValid,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Continuer")
                    }
                }
                EmailAuthPhase.Credentials -> {
                    TextButton(onClick = { viewModel.backToEmail() }) { Text("← Changer l'e-mail") }
                    Spacer(Modifier.height(8.dp))
                    Text(
                        viewModel.email,
                        style = MaterialTheme.typography.titleMedium,
                        color = Primary,
                    )
                    Spacer(Modifier.height(16.dp))
                    if (viewModel.isNewUser) {
                        OutlinedTextField(
                            value = viewModel.displayName,
                            onValueChange = { viewModel.displayName = it },
                            label = { Text("Votre nom (optionnel)") },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                        )
                        Spacer(Modifier.height(12.dp))
                    }
                    OutlinedTextField(
                        value = viewModel.password,
                        onValueChange = { viewModel.password = it },
                        label = { Text(if (viewModel.isNewUser) "Mot de passe (12 caractères min.)" else "Mot de passe") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        visualTransformation = PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    )
                    viewModel.errorMessage?.let {
                        Spacer(Modifier.height(8.dp))
                        Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                    }
                    Spacer(Modifier.height(20.dp))
                    Button(
                        onClick = {
                            viewModel.submitCredentials {
                                viewModel.resetForSheet()
                                onSuccess()
                            }
                        },
                        enabled = !viewModel.loading && run {
                            if (viewModel.isNewUser) viewModel.password.length >= 12
                            else viewModel.password.isNotEmpty()
                        },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(
                            when {
                                viewModel.loading -> "Patientez…"
                                viewModel.isNewUser -> "Créer mon compte"
                                else -> "Continuer"
                            },
                        )
                    }
                }
            }
        }
    }
}
