package fr.myfidpass.ui.mycard

/** Clés `stamp_emoji` — aligné iOS `StampIconCatalog`. */
object StampIconCatalog {
    val selectableKeys: List<String> = listOf(
        "baguette",
        "burger",
        "cafe",
        "checkvert",
        "coiffeur",
        "croissant",
        "giftgold",
        "giftsilver",
        "kebab",
        "ongle",
        "pizza",
        "riz",
        "salade",
        "sourcil",
        "spa",
        "steak",
        "sushi",
    ).sorted()

    const val DEFAULT_KEY = "cafe"

    private val keyToEmoji: Map<String, String> = mapOf(
        "baguette" to "🥖",
        "burger" to "🍔",
        "cafe" to "☕",
        "iconcafe" to "☕",
        "checkvert" to "✅",
        "coiffeur" to "💈",
        "croissant" to "🥐",
        "giftgold" to "🎁",
        "giftsilver" to "🎀",
        "kebab" to "🌯",
        "ongle" to "💅",
        "pizza" to "🍕",
        "riz" to "🍚",
        "salade" to "🥗",
        "sourcil" to "👁",
        "spa" to "💆",
        "steak" to "🥩",
        "sushi" to "🍣",
        "darkburger" to "🍔",
    )

    fun normalizeKey(raw: String?): String {
        val trimmed = raw?.trim().orEmpty()
        if (trimmed.isEmpty()) return DEFAULT_KEY
        val lower = trimmed.lowercase()
        if (keyToEmoji.containsKey(lower)) return lower
        if (lower.startsWith("stamp") && lower.length > 5) {
            val stripped = lower.drop(5)
            if (keyToEmoji.containsKey(stripped)) return stripped
        }
        keyToEmoji.entries.firstOrNull { it.value == trimmed }?.key?.let { return it }
        return DEFAULT_KEY
    }

    fun emojiFor(key: String?): String = keyToEmoji[normalizeKey(key)] ?: "☕"

    fun isCatalogKey(raw: String?): Boolean {
        val trimmed = raw?.trim().orEmpty()
        if (trimmed.isEmpty()) return false
        val lower = trimmed.lowercase()
        if (keyToEmoji.containsKey(lower)) return true
        return keyToEmoji.values.any { it == trimmed }
    }

    fun isGiftKey(key: String): Boolean = key == "giftgold" || key == "giftsilver"
}
