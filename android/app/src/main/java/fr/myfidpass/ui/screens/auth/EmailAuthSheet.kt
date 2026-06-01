package fr.myfidpass.ui.screens.auth

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import fr.myfidpass.ui.viewmodel.EmailAuthViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EmailAuthModalSheet(
    viewModel: EmailAuthViewModel,
    signUpMode: Boolean,
    onDismiss: () -> Unit,
    onSuccess: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val fieldBg = Color(0xFFECECEE)

    ModalBottomSheet(
        onDismissRequest = {
            viewModel.resetForSheet(signUpMode = signUpMode)
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
            if (signUpMode && viewModel.hasPendingEstablishment()) {
                Text(
                    "Commerce sélectionné",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(12.dp))
            }

            OutlinedTextField(
                value = viewModel.email,
                onValueChange = {
                    viewModel.email = it
                    if (viewModel.errorMessage != null) viewModel.errorMessage = null
                },
                label = { Text(if (signUpMode) "E-mail" else "E-mail ou identifiant") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    keyboardType = if (signUpMode) KeyboardType.Email else KeyboardType.Email,
                ),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedContainerColor = fieldBg,
                    unfocusedContainerColor = fieldBg,
                ),
                shape = RoundedCornerShape(12.dp),
            )
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = viewModel.password,
                onValueChange = {
                    viewModel.password = it
                    if (viewModel.errorMessage != null) viewModel.errorMessage = null
                },
                label = {
                    Text(
                        if (signUpMode) "Mot de passe (12 caractères min.)" else "Mot de passe",
                    )
                },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedContainerColor = fieldBg,
                    unfocusedContainerColor = fieldBg,
                ),
                shape = RoundedCornerShape(12.dp),
            )
            viewModel.errorMessage?.let {
                Spacer(Modifier.height(8.dp))
                Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            }
            Spacer(Modifier.height(16.dp))
            Button(
                onClick = {
                    viewModel.submit {
                        viewModel.resetForSheet(signUpMode = signUpMode)
                        onSuccess()
                    }
                },
                enabled = viewModel.canSubmit,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(
                    when {
                        viewModel.loading -> "Patientez…"
                        signUpMode -> "Créer mon compte"
                        else -> "Se connecter"
                    },
                )
            }
        }
    }
}
