package fr.myfidpass

import android.app.Application
import android.os.Build
import android.webkit.WebView
import dagger.hilt.android.HiltAndroidApp
import fr.myfidpass.di.AppContainer
import fr.myfidpass.services.notifications.MerchantNotificationHelper
import fr.myfidpass.util.MerchantUXFeedback
import org.osmdroid.config.Configuration
import javax.inject.Inject

@HiltAndroidApp
class MyFidpassApplication : Application() {
    @Inject
    lateinit var container: AppContainer

    override fun onCreate() {
        super.onCreate()
        MerchantUXFeedback.init(this)
        prepareWebViewStorage()
        Configuration.getInstance().userAgentValue = packageName
        MerchantNotificationHelper.ensureChannels(this)
    }

    private fun prepareWebViewStorage() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            runCatching { WebView.setDataDirectorySuffix("merchant") }
        }
    }
}
