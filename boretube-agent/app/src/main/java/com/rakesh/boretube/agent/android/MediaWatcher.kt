package com.rakesh.boretube.agent.android

import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import com.rakesh.boretube.agent.core.MediaDump
import com.rakesh.boretube.agent.core.MediaSample
import com.rakesh.boretube.agent.core.MediaSnapshot
import com.rakesh.boretube.agent.core.MediaSource
import com.rakesh.boretube.agent.core.MediaTrack
import com.rakesh.boretube.agent.core.PlayState
import com.rakesh.boretube.agent.core.SelfAdb

/**
 * Reads media sessions on its own `media` thread and keeps the latest
 * [MediaSnapshot] for the 1 s enforcement tick.
 *
 * - **listener** (preferred): with notification-listener access,
 *   MediaSessionManager.getActiveSessions + MediaController callbacks
 *   (title, artist, METADATA_KEY_DURATION, PlaybackState). Polled every 1 s too.
 * - **dumpsys** (fallback): `dumpsys media_session` over self-ADB every 2 s
 *   (title, state, position; no duration).
 */
class MediaWatcher(private val ctx: Context, private val shell: Shell) {
    private val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val msm = ctx.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
    private val component = ComponentName(ctx, MediaListenerService::class.java)
    private val thread = HandlerThread("media").apply { start() }
    private val handler = Handler(thread.looper)

    @Volatile var snapshot: MediaSnapshot = MediaSnapshot.NONE
        private set

    private var controllers: List<MediaController> = emptyList()
    private val callbacks = HashMap<MediaController, MediaController.Callback>()
    private var sessionsListener: MediaSessionManager.OnActiveSessionsChangedListener? = null
    private var lastDump = 0L
    private var lastAttachTry = -ATTACH_RETRY_MS
    @Volatile private var running = false

    fun listenerGranted(): Boolean = try {
        if (Build.VERSION.SDK_INT >= 27) nm.isNotificationListenerAccessGranted(component)
        else Settings.Secure.getString(ctx.contentResolver, "enabled_notification_listeners")
            ?.split(':')?.any { ComponentName.unflattenFromString(it) == component } == true
    } catch (_: Exception) {
        false
    }

    fun start() {
        running = true
        handler.post(loop)
    }

    fun stop() {
        running = false
        handler.post { detach() }
        thread.quitSafely()
    }

    private val loop = object : Runnable {
        override fun run() {
            if (!running) return
            try { poll() } catch (e: Throwable) { Log.w(TAG, "media poll failed", e) }
            handler.postDelayed(this, 1_000)
        }
    }

    private fun poll() {
        val now = SystemClock.elapsedRealtime()
        if (listenerGranted()) {
            if (sessionsListener == null && now - lastAttachTry >= ATTACH_RETRY_MS) { lastAttachTry = now; attach() }
            if (sessionsListener != null) { snapshot = fromControllers(now); return }
        } else if (sessionsListener != null) {
            detach()
        }
        if (shell.state != SelfAdb.ok) { snapshot = MediaSnapshot.NONE; return }
        if (now - lastDump < DUMP_PERIOD_MS) return
        lastDump = now
        snapshot = try {
            MediaDump.parse(shell.run(MediaDump.COMMAND).stdout, now)
        } catch (_: Exception) {
            MediaSnapshot.NONE
        }
    }

    private fun attach() {
        try {
            val l = MediaSessionManager.OnActiveSessionsChangedListener { list -> setControllers(list ?: emptyList()) }
            msm.addOnActiveSessionsChangedListener(l, component, handler)
            sessionsListener = l
            setControllers(msm.getActiveSessions(component))
        } catch (e: SecurityException) {
            Log.w(TAG, "listener access not usable: ${e.message}")
            detach()
        }
    }

    private fun detach() {
        sessionsListener?.let { try { msm.removeOnActiveSessionsChangedListener(it) } catch (_: Exception) {} }
        sessionsListener = null
        setControllers(emptyList())
    }

    private fun setControllers(list: List<MediaController>) {
        for ((c, cb) in callbacks) try { c.unregisterCallback(cb) } catch (_: Exception) {}
        callbacks.clear()
        controllers = list
        for (c in list) {
            val cb = object : MediaController.Callback() {
                override fun onMetadataChanged(metadata: MediaMetadata?) = refresh()
                override fun onPlaybackStateChanged(state: PlaybackState?) = refresh()
                override fun onSessionDestroyed() = refresh()
            }
            try { c.registerCallback(cb, handler); callbacks[c] = cb } catch (_: Exception) {}
        }
        refresh()
    }

    /** Callback path: publish a fresh snapshot right away (the tick picks it up within 1 s). */
    private fun refresh() {
        if (sessionsListener != null) snapshot = fromControllers(SystemClock.elapsedRealtime())
    }

    private fun fromControllers(now: Long): MediaSnapshot =
        MediaSnapshot(MediaSource.listener, controllers.mapNotNull { sample(it) }, now)

    private fun sample(c: MediaController): MediaSample? = try {
        val pkg = c.packageName
        val md = c.metadata
        val title = md?.getString(MediaMetadata.METADATA_KEY_TITLE)
            ?: md?.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
            ?: md?.description?.title?.toString()
        val artist = md?.getString(MediaMetadata.METADATA_KEY_ARTIST)
            ?: md?.description?.subtitle?.toString()
        val dur = md?.getLong(MediaMetadata.METADATA_KEY_DURATION)?.takeIf { it > 0 }
        val ps = c.playbackState
        val state = ps?.let { PlayState.fromAndroid(it.state) } ?: PlayState.none
        val track = title?.trim()?.takeIf { it.isNotEmpty() }?.let { MediaTrack(pkg, it, artist?.trim()?.takeIf { a -> a.isNotEmpty() }, dur) }
        MediaSample(
            pkg, track, state,
            positionMs = ps?.position ?: 0, speed = ps?.playbackSpeed ?: 1f,
            updatedElapsed = ps?.lastPositionUpdateTime ?: 0,
            active = true, // getActiveSessions only returns active sessions
        )
    } catch (_: Exception) {
        null
    }

    companion object {
        private const val TAG = "BoretubeMedia"
        const val DUMP_PERIOD_MS = 2_000L
        const val ATTACH_RETRY_MS = 30_000L
    }
}
