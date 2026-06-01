package fr.myfidpass.ui.components

import android.graphics.BitmapFactory
import android.util.Base64
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.foundation.Image
import fr.myfidpass.data.dto.FlyerStateDto

@Composable
fun FlyerNativeUnderlayStack(
    state: FlyerStateDto,
    customBgDataUrl: String?,
    modifier: Modifier = Modifier,
) {
    val top = parseHexColor(state.colorBgTop, Color(0xFFFEF3C7))
    val bottom = parseHexColor(state.colorBgBottom, Color(0xFFFED7AA))
    val overlayAlpha = (state.flyerBgOverlayPct / 100.0).coerceIn(0.0, 0.8).toFloat()
    val bitmap = remember(customBgDataUrl) { decodeDataUrlBitmap(customBgDataUrl) }

    Box(
        modifier.background(Brush.verticalGradient(listOf(top, bottom))),
    ) {
        bitmap?.let { bmp ->
            Image(
                bitmap = bmp.asImageBitmap(),
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        }
        if (overlayAlpha > 0f) {
            Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = overlayAlpha)))
        }
    }
}

private fun parseHexColor(raw: String, fallback: Color): Color = runCatching {
    val hex = raw.trim().removePrefix("#")
    when (hex.length) {
        6 -> Color(0xFF000000L or hex.toLong(16))
        8 -> Color(hex.toLong(16))
        else -> fallback
    }
}.getOrDefault(fallback)

private fun decodeDataUrlBitmap(dataUrl: String?): android.graphics.Bitmap? {
    val t = dataUrl?.trim().orEmpty()
    if (t.isEmpty()) return null
    val b64 = t.substringAfter(",", t)
    return runCatching {
        val bytes = Base64.decode(b64, Base64.DEFAULT)
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    }.getOrNull()
}
