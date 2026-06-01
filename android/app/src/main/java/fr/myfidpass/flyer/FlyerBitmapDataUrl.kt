package fr.myfidpass.flyer

import android.graphics.Bitmap
import android.util.Base64
import java.io.ByteArrayOutputStream

fun bitmapToPngDataUrl(bitmap: Bitmap, quality: Int = 92): String {
    val stream = ByteArrayOutputStream()
    bitmap.compress(Bitmap.CompressFormat.PNG, quality.coerceIn(50, 100), stream)
    val b64 = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
    return "data:image/png;base64,$b64"
}
