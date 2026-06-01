package fr.myfidpass.flyer

import kotlin.math.pow

/** Paire thème roue + dégradé — aligné iOS `FlyerAIWheelPairColor`. */
object FlyerWheelPairColor {
    const val WHEEL_ALTERNATING_LIGHT_HEX = "#FFFFFF"

    fun evenHexFromAccent(raw: String): String {
        val hex6 = raw.trim().removePrefix("#")
        if (hex6.length != 6) return "#FEF3C7"
        val rv = hex6.substring(0, 2).toIntOrNull(16) ?: return "#FEF3C7"
        val gv = hex6.substring(2, 4).toIntOrNull(16) ?: return "#FEF3C7"
        val bv = hex6.substring(4, 6).toIntOrNull(16) ?: return "#FEF3C7"
        fun lighten(x: Int) = minOf(255, x + ((255 - x) * 0.62).toInt())
        return String.format("#%02X%02X%02X", lighten(rv), lighten(gv), lighten(bv))
    }

    fun contrastingOnAccentHex(raw: String): String {
        val hex6 = raw.trim().removePrefix("#")
        if (hex6.length != 6) return "#ffffff"
        val rv = hex6.substring(0, 2).toIntOrNull(16) ?: return "#ffffff"
        val gv = hex6.substring(2, 4).toIntOrNull(16) ?: return "#ffffff"
        val bv = hex6.substring(4, 6).toIntOrNull(16) ?: return "#ffffff"
        val r = rv / 255.0
        val g = gv / 255.0
        val b = bv / 255.0
        fun lin(c: Double) = if (c <= 0.03928) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)
        val luminance = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
        return if (luminance > 0.55) "#0f172a" else "#ffffff"
    }
}
