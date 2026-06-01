package fr.myfidpass.ui.screens.commerce.flyer

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import fr.myfidpass.ui.viewmodel.ProgramFlyerEditorViewModel

@Composable
fun FlyerTitleEditPanel(vm: ProgramFlyerEditorViewModel) {
    Column {
        OutlinedTextField(
            value = vm.state.headline,
            onValueChange = { v -> vm.updateStringField { it.copy(headline = v) } },
            label = { Text("Titre principal") },
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = vm.state.ctaBanner,
            onValueChange = { v -> vm.updateStringField { it.copy(ctaBanner = v) } },
            label = { Text("Bandeau CTA") },
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = vm.state.step1,
            onValueChange = { v -> vm.updateStringField { it.copy(step1 = v) } },
            label = { Text("Étape 1") },
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = vm.state.step2,
            onValueChange = { v -> vm.updateStringField { it.copy(step2 = v) } },
            label = { Text("Étape 2") },
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = vm.state.step3,
            onValueChange = { v -> vm.updateStringField { it.copy(step3 = v) } },
            label = { Text("Étape 3") },
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
fun FlyerWheelEditPanel(vm: ProgramFlyerEditorViewModel) {
    Column {
        OutlinedTextField(
            value = vm.state.wheelColorOdd,
            onValueChange = { v -> vm.updateStringField { it.copy(wheelColorOdd = v) } },
            label = { Text("Couleur roue (impair)") },
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = vm.state.wheelColorEven,
            onValueChange = { v -> vm.updateStringField { it.copy(wheelColorEven = v) } },
            label = { Text("Couleur roue (pair)") },
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = vm.state.colorPrimary,
            onValueChange = { v -> vm.updateStringField { it.copy(colorPrimary = v) } },
            label = { Text("Couleur primaire") },
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = vm.state.ctaBannerBgColor,
            onValueChange = { v -> vm.updateStringField { it.copy(ctaBannerBgColor = v) } },
            label = { Text("Couleur pastille CTA") },
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
fun FlyerBackgroundEditPanel(
    vm: ProgramFlyerEditorViewModel,
    onPickBg: () -> Unit,
    onGenerateAi: () -> Unit,
) {
    Column {
        OutlinedTextField(
            value = vm.state.colorBgTop,
            onValueChange = { v -> vm.updateStringField { it.copy(colorBgTop = v) } },
            label = { Text("Dégradé haut") },
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = vm.state.colorBgBottom,
            onValueChange = { v -> vm.updateStringField { it.copy(colorBgBottom = v) } },
            label = { Text("Dégradé bas") },
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(10.dp))
        OutlinedButton(onClick = onPickBg, modifier = Modifier.fillMaxWidth()) {
            Text("Importer une photo de fond")
        }
        Spacer(Modifier.height(8.dp))
        OutlinedButton(onClick = onGenerateAi, modifier = Modifier.fillMaxWidth()) {
            Text("Régénérer le fond avec l'IA")
        }
        Spacer(Modifier.height(8.dp))
        OutlinedButton(onClick = { vm.useGradientBackground() }, modifier = Modifier.fillMaxWidth()) {
            Text("Utiliser le dégradé (sans photo)")
        }
        if (vm.pendingAiImageB64 != null) {
            Spacer(Modifier.height(8.dp))
            Button(
                onClick = { vm.validateGeneratedFlyer() },
                enabled = !vm.isSaving,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Appliquer le fond IA généré") }
        }
    }
}
