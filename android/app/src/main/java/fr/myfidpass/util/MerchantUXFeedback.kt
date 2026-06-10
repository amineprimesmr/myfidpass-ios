package fr.myfidpass.util

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View
import fr.myfidpass.R
import java.util.concurrent.atomic.AtomicLong

/** Haptiques partout ; son `soun2` uniquement à l’envoi d’une notification. */
object MerchantUXFeedback {
    enum class Kind {
        TAP,
        SELECTION,
        EMPHASIS,
        CONFIRM,
        TAB_SWITCH,
        SCAN,
        SAVE,
        SUCCESS,
        WARNING,
        ERROR,
    }

    private const val PREFS = "myfidpass_merchant_ux"
    private const val KEY_SOUND = "sound_enabled"
    private const val MIN_PLAY_MS = 55L

    @Volatile
    private var appContext: Context? = null

    @Volatile
    private var notificationPlayer: MediaPlayer? = null

    private val lastPlayAt = AtomicLong(0L)

    fun init(context: Context) {
        appContext = context.applicationContext
    }

    fun isSoundEnabled(context: Context): Boolean {
        val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_SOUND, true)
    }

    fun setSoundEnabled(context: Context, enabled: Boolean) {
        context.applicationContext
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_SOUND, enabled)
            .apply()
    }

    /** Haptique seule — pas de son. */
    fun play(context: Context? = null, view: View? = null, kind: Kind = Kind.TAP) {
        val ctx = context?.applicationContext ?: appContext
        if (ctx != null && appContext == null) appContext = ctx
        emitHaptic(view, kind)
    }

    /** Son signature quand une campagne / notification est envoyée. */
    fun playNotificationSent(context: Context? = null, view: View? = null) {
        val ctx = context?.applicationContext ?: appContext
        if (ctx != null && appContext == null) appContext = ctx
        view?.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
        playNotificationSound(ctx, 0.88f)
    }

    private fun ensureNotificationPlayer(ctx: Context) {
        if (notificationPlayer != null) return
        runCatching {
            MediaPlayer.create(ctx, R.raw.soun2)?.apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                isLooping = false
                notificationPlayer = this
            }
        }
    }

    private fun playNotificationSound(context: Context?, volume: Float) {
        val ctx = context ?: appContext ?: return
        if (!isSoundEnabled(ctx)) return
        val now = System.currentTimeMillis()
        if (now - lastPlayAt.get() < MIN_PLAY_MS) return
        lastPlayAt.set(now)
        ensureNotificationPlayer(ctx)
        val mp = notificationPlayer ?: return
        runCatching {
            mp.setVolume(volume, volume)
            if (mp.isPlaying) {
                mp.pause()
            }
            mp.seekTo(0)
            mp.start()
        }
    }

    private fun emitHaptic(view: View?, kind: Kind) {
        val target = view ?: return
        val constant = when (kind) {
            Kind.TAP, Kind.SELECTION -> HapticFeedbackConstants.KEYBOARD_TAP
            Kind.EMPHASIS, Kind.CONFIRM, Kind.SCAN -> HapticFeedbackConstants.CONTEXT_CLICK
            Kind.TAB_SWITCH -> HapticFeedbackConstants.CLOCK_TICK
            Kind.SAVE, Kind.SUCCESS -> HapticFeedbackConstants.CONFIRM
            Kind.WARNING -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                HapticFeedbackConstants.REJECT
            } else {
                HapticFeedbackConstants.LONG_PRESS
            }
            Kind.ERROR -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                HapticFeedbackConstants.REJECT
            } else {
                HapticFeedbackConstants.LONG_PRESS
            }
        }
        target.performHapticFeedback(constant)
    }
}
