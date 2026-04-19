package fr.myfidpass.util

import androidx.compose.ui.graphics.Color

fun String?.toComposeColorOr(default: Color): Color {
    if (this.isNullOrBlank()) return default
    val s = trim().removePrefix("#").uppercase()
    if (s.length != 6) return default
    return try {
        val v = s.toLong(16)
        Color(0xFF000000L or v)
    } catch (_: NumberFormatException) {
        default
    }
}
