package fr.myfidpass.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class PlacesAutocompleteResponse(
    val predictions: List<PlaceAutocompletePrediction> = emptyList(),
)

@Serializable
data class PlaceAutocompletePrediction(
    @SerialName("place_id") val placeId: String,
    val description: String,
    @SerialName("main_text") val mainText: String? = null,
    @SerialName("secondary_text") val secondaryText: String? = null,
)

@Serializable
data class PlacesPlaceDetailsResponse(
    @SerialName("place_id") val placeId: String,
    val name: String? = null,
    @SerialName("formatted_address") val formattedAddress: String? = null,
    @SerialName("google_maps_reviews_uri") val googleMapsReviewsUri: String? = null,
)
