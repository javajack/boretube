package com.rakesh.boretube.learn.ui

import android.os.SystemClock
import android.view.KeyEvent as AndroidKeyEvent
import androidx.compose.foundation.focusable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type

/** The remote, as the app sees it. Volume and everything else pass through. */
enum class RemoteKey { Left, Right, Up, Down, Ok, Back }

fun remoteKeyOf(code: Int): RemoteKey? = when (code) {
    AndroidKeyEvent.KEYCODE_DPAD_LEFT -> RemoteKey.Left
    AndroidKeyEvent.KEYCODE_DPAD_RIGHT -> RemoteKey.Right
    AndroidKeyEvent.KEYCODE_DPAD_UP -> RemoteKey.Up
    AndroidKeyEvent.KEYCODE_DPAD_DOWN -> RemoteKey.Down
    AndroidKeyEvent.KEYCODE_DPAD_CENTER, AndroidKeyEvent.KEYCODE_ENTER,
    AndroidKeyEvent.KEYCODE_NUMPAD_ENTER, AndroidKeyEvent.KEYCODE_BUTTON_A -> RemoteKey.Ok
    AndroidKeyEvent.KEYCODE_BACK, AndroidKeyEvent.KEYCODE_ESCAPE -> RemoteKey.Back
    else -> null
}

/**
 * Ignores OK for [graceMs] after [since] (a carried-over or mashed OK must not
 * answer the next screen) and ignores a held OK; arrows may repeat.
 */
class OkGrace(private val graceMs: Long = GRACE_MS) {
    fun accept(key: RemoteKey, repeat: Int, now: Long, since: Long): Boolean = when (key) {
        RemoteKey.Ok -> repeat == 0 && now - since >= graceMs
        RemoteKey.Back -> repeat == 0
        else -> true
    }

    companion object { const val GRACE_MS = 350L }
}

/** Uptime in ms for the OK grace and answer timing; tests drive it by hand. */
val LocalUptime = staticCompositionLocalOf<() -> Long> { { SystemClock.uptimeMillis() } }

/**
 * Makes this the screen's single key target: takes focus when it appears and
 * routes remote keys to [onKey] (return true when handled). [screenKey]
 * changing restarts the OK grace.
 */
fun Modifier.remote(screenKey: Any?, onKey: (RemoteKey) -> Boolean): Modifier = composed {
    val focus = remember { FocusRequester() }
    val uptime = LocalUptime.current
    val shownAt = remember(screenKey) { uptime() }
    val grace = remember { OkGrace() }
    LaunchedEffect(Unit) { focus.requestFocus() }
    this
        .focusRequester(focus)
        .onPreviewKeyEvent { e ->
            val key = remoteKeyOf(e.nativeKeyEvent.keyCode) ?: return@onPreviewKeyEvent false
            if (e.type != KeyEventType.KeyDown) return@onPreviewKeyEvent true
            if (!grace.accept(key, e.nativeKeyEvent.repeatCount, uptime(), shownAt)) return@onPreviewKeyEvent true
            onKey(key)
        }
        .focusable()
}
