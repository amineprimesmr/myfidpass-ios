package fr.myfidpass.ui.screens.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import fr.myfidpass.ui.theme.Primary

@Composable
fun WelcomeScreen(
    onLogin: () -> Unit,
    onSignUp: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = "MyFidpass",
            style = MaterialTheme.typography.displayLarge,
            color = Primary,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = "Fidélisez vos clients — tableau de bord, scan, carte et campagnes.",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Spacer(Modifier.height(40.dp))
        Button(
            onClick = onLogin,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Connexion")
        }
        Spacer(Modifier.height(12.dp))
        OutlinedButton(
            onClick = onSignUp,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Créer un compte")
        }
    }
}
