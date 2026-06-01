package fr.myfidpass.ui.components

/**
 * Ratios et exports alignés sur iOS `ImageCropSpec` / backend PassKit.
 */
enum class ImageCropSpec(
    val aspectWidthOverHeight: Float,
    val exportWidth: Int,
    val exportHeight: Int,
    val title: String,
    val hint: String,
) {
    WALLET_STRIP_LOGO(
        aspectWidthOverHeight = 400f / 125f,
        exportWidth = 800,
        exportHeight = 250,
        title = "Logo bandeau",
        hint = "Logo en bandeau (face carte, comme Apple 160×50 pt, ratio 16:5). Départ en haut à gauche du cadre ; pincez pour zoomer et faites glisser pour placer l'image comme vous voulez.",
    ),
    WALLET_CARD_BACKGROUND(
        aspectWidthOverHeight = 750f / 246f,
        exportWidth = 1500,
        exportHeight = 492,
        title = "Image de fond",
        hint = "Image de fond strip (750×246 @2x). Départ en haut à gauche du cadre ; pincez et faites glisser pour ajuster.",
    ),
    STAMP_ICON(
        aspectWidthOverHeight = 1f,
        exportWidth = 512,
        exportHeight = 512,
        title = "Icône des tampons",
        hint = "Cadre carré pour l'icône dans chaque case tampon. Pincez pour cadrer le détail, puis validez.",
    ),
    FLYER_PROMO_LOGO(
        aspectWidthOverHeight = (2400f * 0.56f) / (3600f * 0.18f),
        exportWidth = 2000,
        exportHeight = ((2000f) / ((2400f * 0.56f) / (3600f * 0.18f))).toInt(),
        title = "Logo du flyer",
        hint = "",
    ),
    FLYER_CUSTOM_BACKGROUND(
        aspectWidthOverHeight = 2400f / 3600f,
        exportWidth = 2000,
        exportHeight = 3000,
        title = "Image de fond du flyer",
        hint = "",
    ),
}
