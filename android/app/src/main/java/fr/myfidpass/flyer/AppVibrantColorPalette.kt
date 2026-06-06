package fr.myfidpass.flyer

/** Palette unifiée — alignée iOS `AppVibrantColorPalette`. */
object AppVibrantColorPalette {
    val cardRowPresets: List<Pair<String, String>> = listOf(
        "Noir" to "000000", "Graphite" to "1C1C1E", "Anthracite" to "3A3A3C", "Gris" to "636366",
        "Gris moyen" to "8E8E93", "Gris perle" to "C7C7CC", "Gris clair" to "F5F5F7", "Blanc" to "FFFFFF",
        "Espresso" to "1A120B", "Brun cacao" to "3E2723", "Brun" to "4E342E", "Marron" to "5D4037",
        "Taupe foncé" to "6D4C41", "Brun clair" to "795548", "Taupe" to "8D6E63", "Grège" to "A1887F",
        "Grège clair" to "BCAAA4", "Beige rosé" to "D7CCC8", "Camel" to "A67B5B", "Doré beige" to "C9A66B",
        "Caramel" to "DDB892", "Sable" to "E8DCC8", "Crème" to "F0E6D8", "Ivoire" to "F5EBDD", "Blanc cassé" to "FAF3E8",
        "Bordeaux" to "4A0000", "Rouge sombre" to "7F0000", "Grenat" to "5C0011", "Rouge profond" to "B71C1C",
        "Rouge brique" to "C62828", "Rouge" to "D50000", "Rouge vif" to "E53935", "Rouge corail" to "F44336",
        "Rouge éclat" to "FF1744", "Magenta" to "FF0066", "Framboise claire" to "E91E63", "Rose" to "FF4081",
        "Rose pâle" to "FF80AB", "Rose bonbon" to "F48FB1", "Rose néon" to "FF00A8", "Rose blush" to "FCE4EC",
        "Terracotta" to "BF360C", "Rouge orangé" to "D84315", "Orange brûlé" to "FF3D00", "Orange profond" to "FF5722",
        "Corail" to "FF7043", "Pêche" to "FF8A65", "Feu" to "E65100", "Orange" to "FF6D00",
        "Orange clair" to "FF9100", "Ambre" to "FFAB00", "Ambre doré" to "FFB300", "Mandarine" to "FFA726",
        "Pêche claire" to "FFCC80", "Abricot" to "FFE0B2",
        "Moutarde" to "F57F17", "Or" to "F9A825", "Jaune doré" to "FBC02D", "Jaune soleil" to "FDD835",
        "Jaune miel" to "FFE082", "Jaune" to "FFEA00", "Jaune clair" to "FFF176", "Jaune pâle" to "FFF9C4",
        "Lime" to "C6FF00", "Vert citron" to "C0CA33", "Chartreuse" to "CDDC39", "Citron" to "CCFF00",
        "Vert forêt" to "1B5E20", "Vert sapin" to "33691E", "Vert pin" to "2E7D32", "Vert gazon" to "388E3C",
        "Vert mousse" to "558B2F", "Vert olive" to "689F38", "Olive foncé" to "827717", "Olive" to "9E9D24",
        "Vert" to "7CB342", "Vert pomme" to "8BC34A", "Vert lime" to "AEEA00", "Vert fluo" to "64DD17",
        "Vert vif" to "00C853", "Vert menthe" to "00E676", "Menthe néon" to "00FF9D", "Sauge" to "C5E1A5",
        "Vert pastel" to "A5D6A7",
        "Teal profond" to "004D40", "Teal" to "00695C", "Teal moyen" to "00796B", "Turquoise" to "00897B",
        "Sarcelle" to "009688", "Turquoise vif" to "00BFA5", "Teal clair" to "26A69A", "Turquoise pastel" to "4DB6AC",
        "Turquoise pâle" to "80CBC4", "Cyan profond" to "00ACC1", "Cyan" to "00BCD4", "Cyan néon" to "00E5FF",
        "Cyan clair" to "18FFFF", "Cyan pastel" to "4DD0E1", "Cyan brume" to "B2EBF2",
        "Bleu marine" to "0D47A1", "Bleu profond" to "1565C0", "Bleu nuit" to "0D3B66", "Bleu" to "1976D2",
        "Bleu royal" to "1E88E5", "Bleu ciel" to "2196F3", "Bleu vif" to "0091EA", "Azur" to "00B0FF",
        "Bleu clair" to "42A5F5", "Bleu pastel" to "64B5F6", "Bleu roi" to "2979FF", "Bleu indigo" to "304FFE",
        "Indigo" to "3D5AFE", "Bleu gris" to "7986CB", "Bleu brume" to "9FA8DA",
        "Indigo nuit" to "1A237E", "Indigo profond" to "283593", "Violet profond" to "311B92", "Violet royal" to "4527A0",
        "Violet" to "512DA8", "Violet vif" to "651FFF", "Violet clair" to "7C4DFF", "Prune" to "673AB7",
        "Pourpre" to "9C27B0", "Violet doux" to "BA68C8", "Violet néon" to "AA00FF", "Lilas clair" to "CE93D8",
        "Magenta profond" to "4A148C", "Violet intense" to "6A1B9A", "Mauve" to "7B1FA2", "Orchidée" to "8E24AA",
        "Lilas" to "AB47BC", "Framboise" to "C51162", "Fuchsia" to "D500F9", "Magenta clair" to "E040FB",
        "Lavande" to "EA80FC", "Lavande brume" to "F3E5F5",
    )

    val hex6: List<String> = cardRowPresets.map { it.second }

    private val flyerCarouselExcluded = setOf(
        "000000", "1C1C1E", "3A3A3C", "636366", "8E8E93", "C7C7CC", "F5F5F7", "FFFFFF",
        "F0E6D8", "F5EBDD", "FAF3E8", "FCE4EC", "FFF9C4", "FFE0B2", "B2EBF2", "F3E5F5",
    )

    val flyerCarouselHex6: List<String>
        get() = hex6
            .filter { it !in flyerCarouselExcluded }
            .sortedBy { flyerHueSortKey6(it) }

    fun normalizeHex(raw: String): String? {
        val t = raw.trim().removePrefix("#").uppercase()
        if (t.length != 6 || t.any { it !in '0'..'9' && it !in 'A'..'F' }) return null
        return "#$t"
    }

    fun containsHex6(raw: String): Boolean {
        val t = raw.trim().removePrefix("#").uppercase()
        return hex6.contains(t)
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
