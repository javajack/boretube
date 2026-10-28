package com.rakesh.boretube.agent.core

/**
 * Media-session model, shared by both MediaWatcher paths:
 *
 * - **listener**: MediaSessionManager.getActiveSessions with notification-listener
 *   access. Has title, artist and METADATA_KEY_DURATION.
 * - **dumpsys**: `dumpsys media_session` over self-ADB every 2 s. Has title,
 *   subtitle, state and position, but no duration.
 *
 * Positions follow Android's PlaybackState model: [MediaSample.positionMs] was
 * true at [MediaSample.updatedElapsed] (SystemClock.elapsedRealtime) and moves at
 * [MediaSample.speed] while playing. Pure Kotlin, JVM unit-tested.
 */
enum class PlayState {
    none, stopped, paused, playing, buffering, error, other;

    companion object {
        /** android.media.session.PlaybackState.STATE_* values. */
        fun fromAndroid(code: Int): PlayState = when (code) {
            0 -> none
            1 -> stopped
            2 -> paused
            3 -> playing
            4, 5 -> playing // fast-forwarding / rewinding: still "watching"
            6, 8 -> buffering // buffering / connecting
            7 -> error
            else -> other
        }

        fun fromDumpName(name: String): PlayState = when (name.uppercase()) {
            "NONE" -> none
            "STOPPED" -> stopped
            "PAUSED" -> paused
            "PLAYING", "FAST_FORWARDING", "REWINDING" -> playing
            "BUFFERING", "CONNECTING" -> buffering
            "ERROR" -> error
            else -> other
        }
    }
}

/** What is playing: one video. [key] identifies it (seeking never changes it). */
data class MediaTrack(
    val pkg: String,
    val title: String,
    val artist: String? = null,
    /** METADATA_KEY_DURATION, when readable and > 0. */
    val durationMs: Long? = null,
) {
    val key: String get() = "$pkg|$title|${artist.orEmpty()}"
}

/** One media session as read right now. [track] is null when the session has no title. */
data class MediaSample(
    val pkg: String,
    val track: MediaTrack?,
    val state: PlayState,
    val positionMs: Long = 0,
    val speed: Float = 1f,
    /** elapsedRealtime when [positionMs] was true. */
    val updatedElapsed: Long = 0,
    val active: Boolean = true,
) {
    /** Live position: `position + (now − updated) × speed` while playing; clamped to the duration. */
    fun livePositionMs(nowElapsed: Long): Long {
        val p = if (state == PlayState.playing && updatedElapsed > 0) {
            positionMs + ((nowElapsed - updatedElapsed).coerceAtLeast(0) * speed).toLong()
        } else positionMs
        val d = track?.durationMs
        return if (d != null && d > 0) p.coerceIn(0, d) else p.coerceAtLeast(0)
    }

    fun remainingMs(nowElapsed: Long): Long? =
        track?.durationMs?.takeIf { it > 0 }?.let { (it - livePositionMs(nowElapsed)).coerceAtLeast(0) }
}

/** How the agent reads media sessions: listener (with duration), dumpsys fallback, or not at all. */
enum class MediaSource { listener, dumpsys, none }

data class MediaSnapshot(val source: MediaSource, val sessions: List<MediaSample>, val readElapsed: Long = 0) {
    companion object {
        val NONE = MediaSnapshot(MediaSource.none, emptyList())

        /** Video apps whose sessions are followed for Shorts and "end after this one". */
        val VIDEO_PACKAGES = setOf(
            "org.smarttube.stable", "org.smarttube.beta",
            "com.liskovsoft.smarttubetv", "com.liskovsoft.smarttubetv.beta",
            "com.teamsmart.videomanager.tv",
            "com.google.android.youtube.tv", "com.google.android.youtube",
            "com.google.android.apps.youtube.kids", "com.google.android.youtube.tvkids",
        )

        /**
         * Kept closed during a Shorts/hopping cool-down: the video apps, plus
         * Netflix (not followed for Shorts: its browse trailers change title).
         */
        val COOLDOWN_PACKAGES = VIDEO_PACKAGES + setOf("com.netflix.ninja")
    }

    /**
     * The session to follow: the foreground app's (active first). With no known
     * foreground, the first active video-app session that is playing or buffering.
     */
    fun primary(foreground: String?): MediaSample? {
        if (foreground != null) {
            val mine = sessions.filter { it.pkg == foreground }
            return mine.firstOrNull { it.active } ?: mine.firstOrNull()
        }
        return sessions.firstOrNull {
            it.active && it.pkg in VIDEO_PACKAGES && (it.state == PlayState.playing || it.state == PlayState.buffering)
        }
    }

    fun forPackage(pkg: String): MediaSample? =
        sessions.filter { it.pkg == pkg }.let { s -> s.firstOrNull { it.active } ?: s.firstOrNull() }
}

/** `dumpsys media_session` parser (fallback path, verified on the Sony VU3 with SmartTube 32.68). */
object MediaDump {
    const val COMMAND = "dumpsys media_session"

    private val stateRe = Regex(
        "state=PlaybackState \\{state=([A-Z_]+)\\((\\d+)\\), position=(-?\\d+),.*?speed=(-?[\\d.]+), updated=(\\d+)",
    )

    fun parse(out: String, readElapsed: Long = 0): MediaSnapshot {
        val sessions = mutableListOf<MediaSample>()
        var pkg: String? = null
        var active = false
        var state = PlayState.none
        var position = 0L
        var speed = 1f
        var updated = 0L
        var desc: String? = null
        fun flush() {
            val p = pkg ?: return
            val track = desc?.let { trackFromDescription(p, it) }
            sessions += MediaSample(p, track, state, position, speed, updated, active)
            pkg = null; active = false; state = PlayState.none; position = 0; speed = 1f; updated = 0; desc = null
        }
        for (raw in out.lines()) {
            val line = raw.trim()
            when {
                line.startsWith("package=") -> {
                    flush()
                    pkg = line.removePrefix("package=").trim().takeIf { TvShell.isValidPackage(it) }
                }
                pkg == null -> {}
                line.startsWith("active=") -> active = line.removePrefix("active=").trim() == "true"
                line.startsWith("state=PlaybackState") -> stateRe.find(line)?.let { m ->
                    state = PlayState.fromAndroid(m.groupValues[2].toInt())
                    position = m.groupValues[3].toLong()
                    speed = m.groupValues[4].toFloatOrNull() ?: 1f
                    updated = m.groupValues[5].toLong()
                }
                line.startsWith("state=null") -> state = PlayState.none
                line.startsWith("metadata:") -> desc = line.substringAfter("description=", "").takeIf { it.isNotEmpty() }
                line.startsWith("Audio playback") || line.startsWith("Media session config") -> flush()
            }
        }
        flush()
        return MediaSnapshot(MediaSource.dumpsys, sessions, readElapsed)
    }

    /**
     * MediaDescription.toString() is "title, subtitle, description". The last part
     * is usually "null"; titles may contain ", " so the subtitle is taken after
     * the last separator. The key stays stable across samples either way.
     */
    fun trackFromDescription(pkg: String, desc: String): MediaTrack? {
        var d = desc.trim()
        if (d.endsWith(", null")) d = d.removeSuffix(", null")
        val i = d.lastIndexOf(", ")
        val (title, sub) = if (i >= 0) d.substring(0, i) to d.substring(i + 2) else d to null
        val t = title.trim().takeIf { it.isNotEmpty() && it != "null" } ?: return null
        return MediaTrack(pkg, t, sub?.trim()?.takeIf { it.isNotEmpty() && it != "null" }, null)
    }
}

/** A track as watched: [startPlayMs] is on the play clock (which only runs while playing). */
data class TrackRecord(
    val seq: Long,
    val track: MediaTrack,
    val startPlayMs: Long,
    val playedMs: Long,
    val finished: Boolean,
) {
    val endPlayMs: Long get() = startPlayMs + playedMs
}

/**
 * Follows one package's media session over time: detects track changes (title,
 * not position: seeking is not a new track) and keeps a **play clock** that only
 * advances while the session is PLAYING, so paused time never counts.
 */
class MediaTimeline(private val maxStepMs: Long = 10_000) {
    var pkg: String? = null
        private set
    var current: TrackRecord? = null
        private set
    /** Total played time since this timeline started following [pkg]. */
    var playClockMs: Long = 0
        private set
    private var lastSample: MediaSample? = null
    private var lastAt: Long? = null
    private var seq = 0L

    /** Feeds the followed session (null = none). Returns the finished track when the title changed. */
    fun update(sample: MediaSample?, nowElapsed: Long): TrackRecord? {
        if (sample == null || sample.pkg != pkg) {
            val done = finishCurrent()
            reset(sample?.pkg)
            if (sample == null) return done
        }
        // Advance the play clock by the time spent playing since the last update.
        val prev = lastSample
        val at = lastAt
        if (prev != null && at != null && prev.state == PlayState.playing) {
            val step = (nowElapsed - at).coerceIn(0, maxStepMs)
            playClockMs += step
            current?.let { current = it.copy(playedMs = it.playedMs + step) }
        }
        lastSample = sample
        lastAt = nowElapsed
        val t = sample.track ?: return null // between titles (NONE/BUFFERING without metadata): keep the current one
        val cur = current
        if (cur != null && cur.track.key == t.key) {
            if (t.durationMs != null && cur.track.durationMs != t.durationMs) current = cur.copy(track = t)
            return null
        }
        val done = finishCurrent()
        current = TrackRecord(++seq, t, playClockMs, 0, finished = false)
        return done
    }

    private fun finishCurrent(): TrackRecord? {
        val c = current ?: return null
        current = null
        return c.copy(finished = true)
    }

    private fun reset(newPkg: String?) {
        pkg = newPkg
        current = null
        playClockMs = 0
        lastSample = null
        lastAt = null
    }
}
