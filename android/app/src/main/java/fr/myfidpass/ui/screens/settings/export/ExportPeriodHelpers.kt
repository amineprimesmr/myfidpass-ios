package fr.myfidpass.ui.screens.settings.export

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import fr.myfidpass.ui.screens.settings.ExportPeriodDropdown

enum class ExportPeriodChoice(val label: String) {
    ALL("Tout"),
    D7("7 jours"),
    D30("30 jours"),
    D90("90 jours"),
    D365("12 mois"),
    CUSTOM("Plage de dates"),
}

data class ExportPeriodParams(
    val days: Int? = null,
    val from: String? = null,
    val to: String? = null,
)

fun exportPeriodParams(
    periodOrdinal: Int,
    customFrom: String,
    customTo: String,
): ExportPeriodParams {
    return when (ExportPeriodChoice.entries.getOrElse(periodOrdinal) { ExportPeriodChoice.D30 }) {
        ExportPeriodChoice.ALL -> ExportPeriodParams()
        ExportPeriodChoice.D7 -> ExportPeriodParams(days = 7)
        ExportPeriodChoice.D30 -> ExportPeriodParams(days = 30)
        ExportPeriodChoice.D90 -> ExportPeriodParams(days = 90)
        ExportPeriodChoice.D365 -> ExportPeriodParams(days = 365)
        ExportPeriodChoice.CUSTOM -> ExportPeriodParams(
            from = customFrom.trim().ifEmpty { null },
            to = customTo.trim().ifEmpty { null },
        )
    }
}

@Composable
fun ExportPeriodPicker(
    periodOrdinal: Int,
    onPeriodChange: (Int) -> Unit,
    customFrom: String,
    onCustomFromChange: (String) -> Unit,
    customTo: String,
    onCustomToChange: (String) -> Unit,
) {
    ExportPeriodDropdown(periodOrdinal, onPeriodChange)
    if (ExportPeriodChoice.entries.getOrElse(periodOrdinal) { ExportPeriodChoice.D30 } == ExportPeriodChoice.CUSTOM) {
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = customFrom,
            onValueChange = onCustomFromChange,
            label = { Text("Du (yyyy-MM-dd)") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = customTo,
            onValueChange = onCustomToChange,
            label = { Text("Au (yyyy-MM-dd)") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
        )
    }
}

enum class TraceabilityMovementFilter(val label: String, val typesParam: String?) {
    ALL("Tous les mouvements", null),
    CREDITS("Crédits (points / €)", "points_add"),
    VISITS("Passages seuls", "visit"),
    REWARDS("Récompenses & réductions", "reward_redeem"),
    CORRECTIONS("Corrections caisse", "points_correction"),
    GAME("Jeux / tickets", "points_redeem_game_tickets"),
}
