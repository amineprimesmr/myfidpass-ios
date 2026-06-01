package fr.myfidpass.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class FlyerAiGenerateRequest(
    @SerialName("brand_name") val brandName: String,
    @SerialName("cuisine_or_concept") val cuisineOrConcept: String,
    @SerialName("accent_color_hex") val accentColorHex: String,
    @SerialName("secondary_color_hex") val secondaryColorHex: String? = null,
    @SerialName("extra_context") val extraContext: String? = null,
    @SerialName("palette_colors_hex") val paletteColorsHex: List<String> = emptyList(),
    @SerialName("logo_base64") val logoBase64: String? = null,
    @SerialName("style_reference_images_base64") val styleReferenceImagesBase64: List<String>? = null,
)

@Serializable
data class FlyerAiGenerateSyncResponse(
    @SerialName("image_base64") val imageBase64: String,
    @SerialName("revised_prompt") val revisedPrompt: String? = null,
    @SerialName("flyer_ai_generations_used") val flyerAiGenerationsUsed: Int? = null,
    @SerialName("flyer_ai_generations_remaining") val flyerAiGenerationsRemaining: Int? = null,
    @SerialName("flyer_ai_unlimited") val flyerAiUnlimited: Boolean? = null,
)

@Serializable
data class FlyerAiGenerateEnqueueResponse(
    @SerialName("job_id") val jobId: String,
    val status: String? = null,
)

@Serializable
data class FlyerAiJobStatusResponse(
    val status: String,
    @SerialName("job_id") val jobId: String? = null,
    val error: String? = null,
    @SerialName("image_base64") val imageBase64: String? = null,
    @SerialName("revised_prompt") val revisedPrompt: String? = null,
    @SerialName("flyer_ai_generations_used") val flyerAiGenerationsUsed: Int? = null,
    @SerialName("flyer_ai_generations_remaining") val flyerAiGenerationsRemaining: Int? = null,
    @SerialName("flyer_ai_unlimited") val flyerAiUnlimited: Boolean? = null,
    @SerialName("fidelity_page_background_saved") val fidelityPageBackgroundSaved: Boolean? = null,
    @SerialName("fidelity_page_background_error") val fidelityPageBackgroundError: String? = null,
)
