package fr.myfidpass.ui.components

import android.content.Context
import android.graphics.BitmapFactory
import android.util.Base64
import androidx.compose.foundation.Image
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import coil.compose.AsyncImage
import coil.request.ImageRequest

@Composable
fun WalletPreviewImage(
    model: String?,
    authToken: String?,
    context: Context,
    modifier: Modifier,
    contentScale: ContentScale,
) {
    val trimmed = model?.trim().orEmpty()
    if (trimmed.isEmpty()) return
    if (trimmed.startsWith("data:", ignoreCase = true)) {
        val bitmap = remember(trimmed) { decodeDataUrlToBitmap(trimmed) }
        if (bitmap != null) {
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = null,
                modifier = modifier,
                contentScale = contentScale,
            )
            return
        }
    }
    val request = ImageRequest.Builder(context)
        .data(trimmed)
        .crossfade(true)
        .apply {
            if (!authToken.isNullOrBlank() && trimmed.contains("/api/")) {
                addHeader("Authorization", "Bearer $authToken")
            }
        }
        .build()
    AsyncImage(
        model = request,
        contentDescription = null,
        modifier = modifier,
        contentScale = contentScale,
    )
}

private fun decodeDataUrlToBitmap(dataUrl: String): android.graphics.Bitmap? {
    val comma = dataUrl.indexOf(',')
    if (comma < 0) return null
    return runCatching {
        val bytes = Base64.decode(dataUrl.substring(comma + 1), Base64.DEFAULT)
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    }.getOrNull()
}
