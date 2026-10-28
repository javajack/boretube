package com.rakesh.boretube.agent.android

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import com.rakesh.boretube.agent.core.Card

/**
 * The explicit-style full-screen card ("TV time is over · back at 07:00") as a
 * TYPE_APPLICATION_OVERLAY window, FLAG_NOT_FOCUSABLE so it never traps the
 * remote. Shown for [SHOW_MS], then removed.
 */
class Overlay(private val ctx: Context) {
    private val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val main = Handler(Looper.getMainLooper())
    private var view: LinearLayout? = null
    private var title: TextView? = null
    private var sub: TextView? = null
    private val hide = Runnable { removeNow() }

    fun allowed(): Boolean = Settings.canDrawOverlays(ctx)

    fun show(card: Card) {
        if (!allowed()) return
        main.post {
            try {
                if (view == null) create()
                title?.text = card.message
                sub?.text = card.backAt?.let { "back at $it" } ?: card.sub ?: ""
                main.removeCallbacks(hide)
                main.postDelayed(hide, SHOW_MS)
            } catch (_: Exception) {
                view = null
            }
        }
    }

    private fun create() {
        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.rgb(16, 18, 24))
        }
        val t = TextView(ctx).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 44f)
            gravity = Gravity.CENTER
        }
        val s = TextView(ctx).apply {
            setTextColor(Color.rgb(170, 180, 200))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 28f)
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 0)
        }
        root.addView(t)
        root.addView(s)
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.OPAQUE,
        )
        wm.addView(root, lp)
        view = root
        title = t
        sub = s
    }

    private fun removeNow() {
        val v = view ?: return
        try { wm.removeView(v) } catch (_: Exception) {}
        view = null
    }

    fun dismiss() = main.post { main.removeCallbacks(hide); removeNow() }

    companion object {
        const val SHOW_MS = 8_000L
    }
}
