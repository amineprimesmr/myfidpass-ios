package fr.myfidpass.util

import android.content.Context
import android.net.Uri
import android.util.Base64

fun readUriAsImageDataUrl(context: Context, uri: Uri, maxBytes: Int = 4 * 1024 * 1024): String? {
    return runCatching {
        context.contentResolver.openInputStream(uri)?.use { input ->
            val bytes = input.readBytes()
            if (bytes.size > maxBytes) error("Image trop lourde (max 4 Mo)")
            val mime = context.contentResolver.getType(uri) ?: "image/jpeg"
            val b64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
            "data:$mime;base64,$b64"
        }
    }.getOrNull()
}
