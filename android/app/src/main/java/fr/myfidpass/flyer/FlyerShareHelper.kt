package fr.myfidpass.flyer

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.webkit.WebView
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream

object FlyerShareHelper {

    fun shareWebViewCapture(context: Context, webView: WebView, underlay: Bitmap? = null) {
        val flyerBitmap = captureWebView(webView) ?: return
        val composite = if (underlay != null) {
            compositeBitmaps(underlay, flyerBitmap)
        } else {
            flyerBitmap
        }
        val file = writePng(context, composite) ?: return
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(intent, "Partager le flyer"))
    }

    private fun captureWebView(webView: WebView): Bitmap? = runCatching {
        val bmp = Bitmap.createBitmap(webView.width.coerceAtLeast(1), webView.height.coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        webView.draw(canvas)
        bmp
    }.getOrNull()

    private fun compositeBitmaps(background: Bitmap, foreground: Bitmap): Bitmap {
        val w = maxOf(background.width, foreground.width)
        val h = maxOf(background.height, foreground.height)
        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        canvas.drawBitmap(background, 0f, 0f, null)
        canvas.drawBitmap(foreground, 0f, 0f, null)
        return out
    }

    private fun writePng(context: Context, bitmap: Bitmap): File? = runCatching {
        val dir = File(context.cacheDir, "flyer_share")
        dir.mkdirs()
        val file = File(dir, "myfidpass_flyer_${System.currentTimeMillis()}.png")
        FileOutputStream(file).use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        file
    }.getOrNull()
}
