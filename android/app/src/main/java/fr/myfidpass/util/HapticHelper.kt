package fr.myfidpass.util

import android.view.HapticFeedbackConstants
import android.view.View

object HapticHelper {
    fun tabSwitch(view: View?) {
        view?.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
    }

    fun success(view: View?) {
        view?.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
    }
}
