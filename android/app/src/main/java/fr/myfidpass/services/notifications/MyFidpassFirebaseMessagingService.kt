package fr.myfidpass.services.notifications

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import fr.myfidpass.MyFidpassApplication
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/** Token FCM → `POST /api/device/register` — aligné iOS APNs. */
class MyFidpassFirebaseMessagingService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        val app = applicationContext as? MyFidpassApplication ?: return
        if (!app.container.sessionStore.isLoggedIn) return
        CoroutineScope(Dispatchers.IO).launch {
            runCatching {
                app.container.deviceRegistration.registerTokenNow(token)
            }.onFailure {
                Log.w(TAG, "device register failed: ${it.message}")
            }
        }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        val app = applicationContext as? MyFidpassApplication ?: return
        val data = message.data
        val action = data["myfidpass_action"]?.trim().orEmpty()

        if (action == "dashboard_sync") {
            CoroutineScope(Dispatchers.IO).launch {
                val slug = app.container.sessionStore.currentBusinessSlug?.trim().orEmpty()
                if (slug.isNotEmpty()) {
                    runCatching {
                        app.container.syncService.syncIfNeeded(slug, force = true)
                    }.onFailure {
                        Log.w(TAG, "dashboard sync from push failed: ${it.message}")
                    }
                }
            }
            return
        }

        val title = message.notification?.title
            ?: data["title"]
            ?: getString(fr.myfidpass.R.string.app_name)
        val body = message.notification?.body
            ?: data["body"]
            ?: data["message"]
            ?: return

        if (message.notification == null) {
            MerchantNotificationHelper.showAlert(
                context = applicationContext,
                title = title,
                body = body,
            )
        }
    }

    companion object {
        private const val TAG = "MyFidpassFCM"
    }
}
