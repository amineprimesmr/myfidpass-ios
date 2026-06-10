package fr.myfidpass

import android.app.Application
import android.os.Build
import android.webkit.WebView
import fr.myfidpass.di.AppContainer
import fr.myfidpass.services.notifications.MerchantNotificationHelper
import fr.myfidpass.util.MerchantUXFeedback
import org.osmdroid.config.Configuration

class MyFidpassApplication : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        MerchantUXFeedback.init(this)
        prepareWebViewStorage()
        Configuration.getInstance().userAgentValue = packageName
        container = AppContainer(this)
        MerchantNotificationHelper.ensureChannels(this)
    }

    private fun prepareWebViewStorage() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            runCatching { WebView.setDataDirectorySuffix("merchant") }
        }
    }
}
