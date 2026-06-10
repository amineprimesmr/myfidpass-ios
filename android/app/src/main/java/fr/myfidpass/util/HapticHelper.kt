package fr.myfidpass.util

import android.content.Context
import android.view.View

/** Raccourcis haptiques (le son d'envoi de notification passe par `MerchantUXFeedback.playNotificationSent`). */
object HapticHelper {
    fun tabSwitch(view: View?) {
        MerchantUXFeedback.play(view = view, kind = MerchantUXFeedback.Kind.TAB_SWITCH)
    }

    fun tap(view: View? = null, context: Context? = null) {
        MerchantUXFeedback.play(context = context, view = view, kind = MerchantUXFeedback.Kind.TAP)
    }

    fun success(view: View? = null, context: Context? = null) {
        MerchantUXFeedback.play(context = context, view = view, kind = MerchantUXFeedback.Kind.SUCCESS)
    }

    fun error(view: View? = null, context: Context? = null) {
        MerchantUXFeedback.play(context = context, view = view, kind = MerchantUXFeedback.Kind.ERROR)
    }

    fun scan(view: View? = null, context: Context? = null) {
        MerchantUXFeedback.play(context = context, view = view, kind = MerchantUXFeedback.Kind.SCAN)
    }

    fun save(view: View? = null, context: Context? = null) {
        MerchantUXFeedback.play(context = context, view = view, kind = MerchantUXFeedback.Kind.SAVE)
    }

    fun confirm(view: View? = null, context: Context? = null) {
        MerchantUXFeedback.play(context = context, view = view, kind = MerchantUXFeedback.Kind.CONFIRM)
    }
}
