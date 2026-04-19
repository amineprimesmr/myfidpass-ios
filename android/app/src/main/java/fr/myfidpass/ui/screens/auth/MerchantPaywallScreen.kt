package fr.myfidpass.ui.screens.auth

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
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import fr.myfidpass.util.openInCustomTab

/** Aligné sur `MerchantSubscriptionPaywallBlockingView` : accès bloqué sans abonnement / essai expiré. */
@Composable
fun MerchantPaywallScreen(
    userEmail: String?,
    onLogout: () -> Unit,
) {
    val context = LocalContext.current
    Column(
        Modifier
            .fillMaxSize()
            .padding(24.dp),
    ) {
        Text("Abonnement requis", style = MaterialTheme.typography.headlineSmall)
        Spacer(Modifier.height(12.dp))
        Text(
            "Votre essai est terminé ou aucun abonnement actif n’est détecté. Souscrivez sur myfidpass.fr pour continuer à utiliser l’app commerçant, comme sur iOS.",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        userEmail?.takeIf { it.isNotBlank() }?.let {
            Spacer(Modifier.height(16.dp))
            Text("Compte : $it", style = MaterialTheme.typography.bodyMedium)
        }
        Spacer(Modifier.height(28.dp))
        Button(
            onClick = {
                openInCustomTab(context, "https://www.myfidpass.fr/abonnement")
            },
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Voir les offres / payer l’abonnement") }
        Spacer(Modifier.height(12.dp))
        Button(
            onClick = {
                openInCustomTab(
                    context,
                    "https://buy.stripe.com/7sYcN53Z72N88et4Cr8Zq01?prefilled_promo_code=MYFID1EURO",
                )
            },
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Offre 1er mois (code MYFID1EURO)") }
        Spacer(Modifier.height(24.dp))
        OutlinedButton(
            onClick = onLogout,
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Changer de compte") }
    }
}
