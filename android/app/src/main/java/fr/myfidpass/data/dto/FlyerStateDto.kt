package fr.myfidpass.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.jsonObject

@Serializable
data class FlyerStateDto(
    val templateId: String = TEMPLATE_ID_FIXED,
    val headline: String = "SCANNEZ & GAGNEZ VOTRE CADEAU !",
    val ctaBanner: String = "SCANNER POUR JOUER",
    val ctaBannerBgColor: String = "#ec4899",
    val ctaTextColor: String = "#ffffff",
    val step1: String = "Scannez le QR code",
    val step2: String = "Ajoutez la carte au Wallet",
    val step3: String = "Cumulez points & avantages",
    val social1: String = "",
    @SerialName("socialUrl1") val socialUrl1: String = "",
    val social2: String = "",
    @SerialName("socialUrl2") val socialUrl2: String = "",
    val social3: String = "",
    @SerialName("socialUrl3") val socialUrl3: String = "",
    val colorPrimary: String = "#fbbf24",
    val colorSecondary: String = "#f97316",
    val colorAccent: String = "#ffffff",
    val colorBgTop: String = "#FEF3C7",
    val colorBgBottom: String = "#FED7AA",
    val wheelRenderMode: String = "png",
    val wheelColorOdd: String = "#fbbf24",
    val wheelColorEven: String = "#ffffff",
    val wheelSegmentOffsetDeg: Double = 0.0,
    val headlineFontId: String = "fraunces",
    val headlineTextColor: String = "#0f172a",
    val headlineStrokeColor: String = "#F8FAFC",
    val headlineGiftStrokeColor: String = "#be185d",
    val headlineStrokeWidth: Double = 18.0,
    val headlineLogoGapPct: Double = 4.0,
    val headlineLetterSpacing: Double = 0.0,
    val headlineSizePct: Double = 7.0,
    val flyerFooterTextScalePct: Double = 100.0,
    val flyerWheelLabelScalePct: Double = 100.0,
    val flyerBgOverlayPct: Double = 0.0,
    val flyerQrOutlineWidth: Double = 5.0,
    val flyerLogoCenterYFrac: Double = 0.092,
    val flyerLogoMaxWFrac: Double = 0.62,
    val flyerLogoMaxHFrac: Double = 0.15,
    val flyerLogoKeepSourceBackground: Boolean = false,
) {
    fun normalizeClamps(): FlyerStateDto = copy(
        templateId = TEMPLATE_ID_FIXED,
        wheelRenderMode = "png",
        headlineSizePct = headlineSizePct.coerceIn(4.0, 14.0),
        flyerLogoCenterYFrac = flyerLogoCenterYFrac.coerceIn(0.04, 0.22),
        flyerLogoMaxWFrac = flyerLogoMaxWFrac.coerceIn(0.28, 0.88),
        flyerLogoMaxHFrac = flyerLogoMaxHFrac.coerceIn(0.06, 0.36),
        flyerBgOverlayPct = flyerBgOverlayPct.coerceIn(0.0, 80.0),
        flyerQrOutlineWidth = flyerQrOutlineWidth.coerceIn(0.0, 12.0),
        headlineStrokeWidth = headlineStrokeWidth.coerceIn(0.0, 32.0),
    )

    val isCustomizedComparedToAppDefault: Boolean
        get() {
            val d = DEFAULT
            return headline != d.headline ||
                ctaBanner != d.ctaBanner ||
                colorPrimary != d.colorPrimary ||
                colorSecondary != d.colorSecondary ||
                wheelColorOdd != d.wheelColorOdd ||
                ctaBannerBgColor != d.ctaBannerBgColor
        }

    companion object {
        const val TEMPLATE_ID_FIXED = "noir-or-roue"
        val DEFAULT = FlyerStateDto()

        private val json = Json { ignoreUnknownKeys = true; isLenient = true }

        fun decodeFromJsonElement(element: JsonElement?): FlyerStateDto {
            if (element == null || element !is JsonObject || element.isEmpty()) return DEFAULT
            return runCatching { json.decodeFromJsonElement<FlyerStateDto>(element) }
                .getOrDefault(DEFAULT)
                .normalizeClamps()
        }
    }
}

sealed class FlyerRemoteImagePayload {
    data object LeaveUnchanged : FlyerRemoteImagePayload()
    data object Clear : FlyerRemoteImagePayload()
    data class DataUrl(val value: String) : FlyerRemoteImagePayload()
}
