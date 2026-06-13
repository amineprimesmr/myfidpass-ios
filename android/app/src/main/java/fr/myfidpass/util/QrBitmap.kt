package fr.myfidpass.util

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import android.graphics.Bitmap
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter

fun qrCodeImageBitmap(data: String, size: Int = 512): ImageBitmap {
    val writer = QRCodeWriter()
    val matrix = writer.encode(data, BarcodeFormat.QR_CODE, size, size)
    val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    for (x in 0 until size) {
        for (y in 0 until size) {
            val color = if (matrix.get(x, y)) android.graphics.Color.BLACK else android.graphics.Color.WHITE
            bmp.setPixel(x, y, color)
        }
    }
    return bmp.asImageBitmap()
}

/** QR mémorisé — ne pas appeler [qrCodeImageBitmap] directement dans le corps d’un composant animé. */
@Composable
fun rememberQrCodeBitmap(data: String, size: Int): ImageBitmap {
    return remember(data, size) { qrCodeImageBitmap(data, size) }
}
