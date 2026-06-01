package fr.myfidpass.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import fr.myfidpass.data.dto.BusinessDto
import fr.myfidpass.data.local.SessionStore

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BusinessSwitcher(
    sessionStore: SessionStore,
    modifier: Modifier = Modifier,
    onSwitched: () -> Unit = {},
) {
    val businesses = sessionStore.businesses
    if (businesses.size <= 1) return

    val currentSlug = sessionStore.currentBusinessSlug
    val current = businesses.firstOrNull { it.slug == currentSlug } ?: businesses.first()
    var expanded by remember { mutableStateOf(false) }

    Row(modifier = modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
        ExposedDropdownMenuBox(
            expanded = expanded,
            onExpandedChange = { expanded = !expanded },
        ) {
            OutlinedTextField(
                value = current.name.ifBlank { current.slug },
                onValueChange = {},
                readOnly = true,
                label = { Text("Commerce") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) },
                modifier = Modifier.menuAnchor().fillMaxWidth(),
                singleLine = true,
            )
            ExposedDropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false },
            ) {
                businesses.forEach { b ->
                    DropdownMenuItem(
                        text = {
                            Text(
                                b.name.ifBlank { b.slug },
                                style = MaterialTheme.typography.bodyMedium,
                            )
                        },
                        onClick = {
                            sessionStore.switchBusiness(b.slug)
                            expanded = false
                            onSwitched()
                        },
                    )
                }
            }
        }
    }
}
