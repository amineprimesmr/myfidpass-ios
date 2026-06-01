package fr.myfidpass.ui.screens.settings

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import fr.myfidpass.ui.screens.settings.export.ExportPeriodChoice

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExportPeriodDropdown(periodOrdinal: Int, onPeriodChange: (Int) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    val current = ExportPeriodChoice.entries.getOrElse(periodOrdinal) { ExportPeriodChoice.D30 }
    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
        OutlinedTextField(
            value = current.label,
            onValueChange = {},
            readOnly = true,
            label = { Text("Période") },
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) },
            modifier = Modifier
                .menuAnchor()
                .fillMaxWidth(),
        )
        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            ExportPeriodChoice.entries.forEachIndexed { idx, choice ->
                DropdownMenuItem(
                    text = { Text(choice.label) },
                    onClick = {
                        onPeriodChange(idx)
                        expanded = false
                    },
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MovementFilterDropdown(selectedOrdinal: Int, onChange: (Int) -> Unit, labels: List<String>) {
    var expanded by remember { mutableStateOf(false) }
    val label = labels.getOrElse(selectedOrdinal) { labels.first() }
    Column {
        ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
            OutlinedTextField(
                value = label,
                onValueChange = {},
                readOnly = true,
                label = { Text("Filtrer") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) },
                modifier = Modifier
                    .menuAnchor()
                    .fillMaxWidth(),
            )
            ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                labels.forEachIndexed { idx, item ->
                    DropdownMenuItem(
                        text = { Text(item) },
                        onClick = {
                            onChange(idx)
                            expanded = false
                        },
                    )
                }
            }
        }
    }
}
