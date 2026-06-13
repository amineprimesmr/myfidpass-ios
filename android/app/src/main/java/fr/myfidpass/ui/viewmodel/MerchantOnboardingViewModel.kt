package fr.myfidpass.ui.viewmodel

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import fr.myfidpass.data.dto.PlaceAutocompletePrediction
import fr.myfidpass.data.repo.AuthRepository
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import retrofit2.HttpException
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject

@HiltViewModel
class MerchantOnboardingViewModel @Inject constructor(
    private val authRepository: AuthRepository,
) : ViewModel() {

    var query by mutableStateOf("")
        private set

    var predictions by mutableStateOf<List<PlaceAutocompletePrediction>>(emptyList())
        private set

    var selectedPlaceId by mutableStateOf<String?>(null)
        private set

    var selectedDescription by mutableStateOf<String?>(null)
        private set

    var selectedMainText by mutableStateOf<String?>(null)
        private set

    var selectedSecondaryText by mutableStateOf<String?>(null)
        private set

    var relaxRequirement by mutableStateOf(false)
        private set

    var isSearching by mutableStateOf(false)
        private set

    var hint by mutableStateOf<String?>(null)
        private set

    private var debounce: Job? = null

    fun onQueryChange(raw: String) {
        query = raw
        debounce?.cancel()
        val trimmed = raw.trim()
        if (trimmed.length < 2) {
            predictions = emptyList()
            if (selectedPlaceId == null) hint = null
            return
        }
        debounce = viewModelScope.launch {
            delay(400)
            search(trimmed)
        }
    }

    private suspend fun search(input: String) {
        isSearching = true
        hint = null
        relaxRequirement = false
        val result = authRepository.placesAutocomplete(input)
        result.fold(
            onSuccess = { list ->
                predictions = list
                hint = if (list.isEmpty()) {
                    "Aucun résultat. Essayez un autre libellé ou la ville."
                } else {
                    null
                }
            },
            onFailure = { e ->
                predictions = emptyList()
                if (e is HttpException && e.code() == 503) {
                    relaxRequirement = true
                    hint =
                        "Recherche indisponible. Vous pourrez configurer votre commerce après connexion (Paramètres)."
                } else {
                    hint = "Impossible de lancer la recherche. Vérifiez la connexion."
                }
            },
        )
        isSearching = false
    }

    fun selectPrediction(p: PlaceAutocompletePrediction) {
        val main = p.mainText?.trim().takeIf { !it.isNullOrEmpty() } ?: p.description
        val secondary = p.secondaryText?.trim()?.takeIf { it.isNotEmpty() }
        selectedPlaceId = p.placeId
        selectedDescription = p.description
        selectedMainText = main
        selectedSecondaryText = secondary
        predictions = emptyList()
        query = main
        hint = null
        relaxRequirement = false
    }

    fun clearSelection() {
        selectedPlaceId = null
        selectedDescription = null
        selectedMainText = null
        selectedSecondaryText = null
        query = ""
        predictions = emptyList()
        hint = null
    }

    /** Réutilisation de l’écran « choisir établissement » depuis l’accueil auth. */
    fun resetForNewFlow() {
        clearSelection()
        relaxRequirement = false
        isSearching = false
        debounce?.cancel()
    }

    val canContinue: Boolean
        get() = !selectedPlaceId.isNullOrBlank() || relaxRequirement
}
