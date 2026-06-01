package fr.myfidpass.ui.theme

import androidx.compose.ui.graphics.Color

/** Palette accueil type Revolut — alignée `DashboardRevolutPalette` iOS (mode clair). */
data class DashboardFintechPalette(
    val canvas: Color = Color(0xFFF5F7FC),
    val card: Color = Color.White,
    val secondaryText: Color = Color(0xFF64748B),
    val onCanvasPrimary: Color = Color(0xFF0F172A),
    val transactionPillBg: Color = Color(0xFFE3E8EF),
    val transactionIconDisc: Color = Color(0xFFD1D5DB),
    val accentBlue: Color = Color(0xFF2563EB),
    val barButtonFill: Color = Color(0x1A000000),
)

val FintechLightPalette = DashboardFintechPalette()
