package com.rakesh.boretube.agent.android

import android.content.Context
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.WindowManager
import com.rakesh.boretube.agent.core.Card

/**
 * The explicit-style full-screen card ([TvCardView]: Tubby + "TUBBY SAYS" +
 * headline) as a TYPE_APPLICATION_OVERLAY window, FLAG_NOT_FOCUSABLE so it
 * never traps the remote. Fades in over [FADE_IN_MS], stays [SHOW_MS], fades
 * out over [FADE_OUT_MS] and is removed: no view is kept while hidden.
 */
class Overlay(private val ctx: Context) {
    private val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val main = Handler(Looper.getMainLooper())
    private var view: TvCardView? = null
    /** Bumped on every show/hide so a stale fade-out never removes a re-shown card. */
    private var gen = 0
    private val hide = Runnable { fadeOut() }

    fun allowed(): Boolean = Settings.canDrawOverlays(ctx)

    fun show(card: Card) {
        if (!allowed()) return
        main.post {
            try {
                val v = view ?: create()
                gen++
                v.bind(card)
                v.animate().cancel()
                v.animate().alpha(1f).setDuration(FADE_IN_MS).withLayer().start()
                main.removeCallbacks(hide)
                main.postDelayed(hide, SHOW_MS)
            } catch (_: Exception) {
                removeNow()
            }
        }
    }

    private fun create(): TvCardView {
        val v = TvCardView(ctx).apply { alpha = 0f }
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            // Translucent so the fade shows what is underneath (HOME after a close).
            PixelFormat.TRANSLUCENT,
        )
        lp.title = "boretube card"
        wm.addView(v, lp)
        view = v
        return v
    }

    private fun fadeOut() {
        val v = view ?: return
        val g = ++gen
        v.animate().cancel()
        v.animate().alpha(0f).setDuration(FADE_OUT_MS).withLayer().withEndAction {
            if (gen == g) removeNow()
        }.start()
    }

    private fun removeNow() {
        val v = view ?: return
        view = null
        try { v.animate().cancel() } catch (_: Exception) {}
        try { wm.removeView(v) } catch (_: Exception) {}
    }

    /** Hides the card now (with the short fade-out). */
    fun dismiss() = main.post { main.removeCallbacks(hide); fadeOut() }

    companion object {
        const val SHOW_MS = 8_000L
        const val FADE_IN_MS = 320L
        const val FADE_OUT_MS = 200L
    }
}
