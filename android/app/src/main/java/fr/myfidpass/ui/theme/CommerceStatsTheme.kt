package fr.myfidpass.ui.theme

import androidx.compose.ui.graphics.Color

/** Palette stats Commerce — alignée `CommerceStatisticsTheme.swift`. */
data class CommerceStatsPalette(
    val background: Color = Color.Black,
    /** Aligné accueil / notifs (`FintechLightPalette.canvas`, `DashboardRevolutPalette` iOS). */
    val canvasEmbedded: Color = Color(0xFFF5F7FC),
    val card: Color = Color(0xFF1C1C1E),
    val cardElevated: Color = Color(0xFF2C2C2E),
    val secondaryLabel: Color = Color(0xFF8E8E93),
    val accentBlue: Color = Color(0xFF0066D9),
    val positive: Color = Color(0xFF30D158),
    val negative: Color = Color(0xFFFF453A),
    val kpiTrendGreen: Color = Color(0xFF2EAD6E),
    val chartLine: Color = Color(0xFF00FF85),
    val onTilePrimary: Color = Color.Black,
    val onTileSecondary: Color = Color(0xFF000000).copy(alpha = 0.62f),
    val pageTitle: Color = Color.Black,
    val tileSurface: Color = Color(0xFF2C2C2E).copy(alpha = 0.86f),
    val tileSurfaceLight: Color = Color.White.copy(alpha = 0.94f),
)

val CommerceStatsLightEmbedded = CommerceStatsPalette()
