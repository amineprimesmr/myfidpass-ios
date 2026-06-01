package fr.myfidpass.ui.components

import android.annotation.SuppressLint
import android.os.Build
import android.view.ViewGroup
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.layout.Box
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import org.json.JSONObject

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun FlyerPreviewWebView(
    url: String,
    modifier: Modifier = Modifier,
    bootstrapBase64: String? = null,
    onWebViewReady: ((WebView) -> Unit)? = null,
) {
    val context = LocalContext.current
    val b64 = bootstrapBase64?.trim().orEmpty()
    var webView by remember { mutableStateOf<WebView?>(null) }
    var webViewError by remember { mutableStateOf<String?>(null) }

    DisposableEffect(Unit) {
        onDispose {
            webView?.let { view ->
                runCatching {
                    (view.parent as? ViewGroup)?.removeView(view)
                    view.stopLoading()
                    view.destroy()
                }
            }
            webView = null
        }
    }

    if (webViewError != null) {
        Box(modifier, contentAlignment = Alignment.Center) {
            Text(
                webViewError.orEmpty(),
                color = Color.White.copy(alpha = 0.75f),
            )
        }
        return
    }

    AndroidView(
        modifier = modifier,
        factory = { ctx ->
            runCatching {
                WebView(ctx).apply {
                    settings.javaScriptEnabled = true
                    settings.domStorageEnabled = true
                    settings.cacheMode = WebSettings.LOAD_DEFAULT
                    settings.loadsImagesAutomatically = true
                    settings.useWideViewPort = true
                    settings.loadWithOverviewMode = true
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        settings.mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
                    }
                    setBackgroundColor(0)
                    webViewClient = object : WebViewClient() {
                        override fun onPageFinished(view: WebView?, finishedUrl: String?) {
                            injectBootstrap(view, b64)
                        }
                    }
                    loadUrl(url)
                    webView = this
                    onWebViewReady?.invoke(this)
                }
            }.getOrElse { error ->
                webViewError = "Aperçu flyer indisponible sur cet appareil."
                android.util.Log.e("FlyerPreviewWebView", "WebView init failed", error)
                android.view.View(ctx)
            }
        },
        update = { view ->
            if (view !is WebView) return@AndroidView
            webView = view
            if (view.url != url) {
                view.loadUrl(url)
            } else {
                injectBootstrap(view, b64)
            }
            onWebViewReady?.invoke(view)
        },
    )
}

private fun injectBootstrap(view: WebView?, bootstrapB64: String) {
    if (view == null) return
    val safeB64 = bootstrapB64.trim()
    val js = if (safeB64.isEmpty()) {
        """
        (function(){
          window.__FIDPASS_FLYER_B64__ = '';
          if (typeof window.__FIDPASS_FLYER_APPLY__ === 'function') {
            window.__FIDPASS_FLYER_APPLY__();
          }
        })();
        """.trimIndent()
    } else {
        val quoted = JSONObject.quote(safeB64)
        """
        (function(){
          window.__FIDPASS_FLYER_B64__ = $quoted;
          if (typeof window.__FIDPASS_FLYER_APPLY__ === 'function') {
            window.__FIDPASS_FLYER_APPLY__();
          }
        })();
        """.trimIndent()
    }
    runCatching { view.evaluateJavascript(js, null) }
}
