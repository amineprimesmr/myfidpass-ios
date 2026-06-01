package fr.myfidpass

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.ProcessLifecycleOwner
import fr.myfidpass.ui.AppRoot
import fr.myfidpass.ui.theme.MyfidpassTheme
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    var pendingOAuthUri by mutableStateOf<Uri?>(null)
        private set

    var pendingScanRequest by mutableStateOf(0)
        private set

    fun consumePendingScanRequest() {
        pendingScanRequest = 0
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        captureDeepLink(intent)
        val app = application as MyFidpassApplication
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        ProcessLifecycleOwner.get().lifecycle.addObserver(
            LifecycleEventObserver { _, event ->
                if (event == Lifecycle.Event.ON_START) {
                    scope.launch(Dispatchers.IO) {
                        runCatching { app.container.authRepository.refreshSessionOnForeground() }
                    }
                }
            },
        )
        setContent {
            MyfidpassTheme(darkTheme = false) {
                Surface(Modifier.fillMaxSize()) {
                    AppRoot(
                        container = app.container,
                        pendingOAuthUri = pendingOAuthUri,
                        onOAuthUriConsumed = { pendingOAuthUri = null },
                        pendingScanRequest = pendingScanRequest,
                        onScanRequestConsumed = { consumePendingScanRequest() },
                    )
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureDeepLink(intent)
    }

    private fun captureDeepLink(intent: Intent?) {
        val uri = intent?.data ?: return
        when {
            uri.scheme == "myfidpass" && uri.host == "auth" -> pendingOAuthUri = uri
            uri.scheme == "myfidpass" && uri.host == "scan" -> pendingScanRequest++
        }
    }
}
