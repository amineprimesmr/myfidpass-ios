package fr.myfidpass.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import fr.myfidpass.ui.theme.MerchantDesignSystem

/**
 * Coque partagée Accueil / Campagnes / Commerce :
 * fond noir + barre overlay + panneau scroll arrondi (24dp haut).
 *
 * Le contenu [content] reste au même emplacement dans l'arbre Compose
 * (pas de Crossfade) pour ne pas remonter le NavHost lors du mode immersif Ma carte.
 */
@Composable
fun MerchantTabShell(
    topBar: @Composable () -> Unit,
    canvasColor: Color,
    modifier: Modifier = Modifier,
    topContentInset: Dp = Dp.Unspecified,
    /** Ma carte : masque barre noire + coins arrondis (aligné iOS). */
    immersiveContent: Boolean = false,
    content: @Composable (Modifier) -> Unit,
) {
    val resolvedTopInset = if (topContentInset != Dp.Unspecified) {
        topContentInset
    } else {
        SafeArea.merchantTopBarTotalInset()
    }
    val panelShape = if (immersiveContent) RectangleShape else MerchantDesignSystem.topRoundedPanelShape
    val shellBackground = if (immersiveContent) canvasColor else Color.Black

    Box(modifier.fillMaxSize().background(shellBackground)) {
        Column(
            Modifier
                .fillMaxSize()
                .padding(top = if (immersiveContent) 0.dp else resolvedTopInset),
        ) {
            Box(
                Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .clip(panelShape)
                    .background(canvasColor),
            ) {
                content(Modifier.fillMaxSize())
            }
        }
        if (!immersiveContent) {
            Box(Modifier.zIndex(1f)) {
                topBar()
            }
        }
    }
}
