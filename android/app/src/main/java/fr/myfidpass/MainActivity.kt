package fr.myfidpass

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import fr.myfidpass.ui.AppRoot
import fr.myfidpass.ui.theme.MyfidpassTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val app = application as MyFidpassApplication
        setContent {
            MyfidpassTheme(darkTheme = false) {
                Surface(Modifier.fillMaxSize()) {
                    AppRoot(app.container)
                }
            }
        }
    }
}
