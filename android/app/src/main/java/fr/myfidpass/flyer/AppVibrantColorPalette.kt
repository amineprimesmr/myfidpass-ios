package fr.myfidpass.flyer

import kotlin.math.pow

/** Palette unifiée — alignée iOS `AppVibrantColorPalette`. */
object AppVibrantColorPalette {
    val hex6: List<String> = listOf(
        "000000", "F5F5F7", "FFFFFF",
        "FF0066", "FF1744", "FF3D00", "FF6D00", "FFAB00", "FFEA00", "CCFF00", "00FF9D", "00E5FF",
        "00B0FF", "3D5AFE", "651FFF", "D500F9", "FF00A8", "C51162", "D50000", "E65100", "F57F17",
        "7CB342", "00BFA5", "0091EA", "304FFE", "AA00FF",
    )

    private val flyerCarouselExcluded = setOf("000000", "F5F5F7", "FFFFFF")

    val flyerCarouselHex6: List<String>
        get() = hex6
            .filter { it !in flyerCarouselExcluded }
            .sortedBy { flyerHueSortKey6(it) }

    fun normalizeHex(raw: String): String? {
        val t = raw.trim().removePrefix("#").uppercase()
        if (t.length != 6 || t.any { it !in '0'..'9' && it !in 'A'..'F' }) return null
        return "#$t"
    }

    fun flyerHueSortKey6(raw: String): Double {
        val t = raw.trim().removePrefix("#").uppercase()
        if (t.length != 6) return 0.0
        val r = t.substring(0, 2).toIntOrNull(16) ?: return 0.0
        val g = t.substring(2, 4).toIntOrNull(16) ?: return 0.0
        val b = t.substring(4, 6).toIntOrNull(16) ?: return 0.0
        val rf = r / 255.0
        val gf = g / 255.0
        val bf = b / 255.0
        val max = maxOf(rf, gf, bf)
        val min = minOf(rf, gf, bf)
        val delta = max - min
        if (delta < 0.08) return 1.0 + max * 0.001
        val hue = when (max) {
            rf -> ((gf - bf) / delta).let { if (it < 0) it + 6 else it } / 6.0
            gf -> ((bf - rf) / delta + 2) / 6.0
            else -> ((rf - gf) / delta + 4) / 6.0
        }
        return hue.coerceIn(0.0, 1.0)
    }
}
