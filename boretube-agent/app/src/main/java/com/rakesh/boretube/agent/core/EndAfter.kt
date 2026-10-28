package com.rakesh.boretube.agent.core

import kotlinx.serialization.Serializable

/** "End after this one", persisted so it survives agent restarts. Times are epoch ms. */
@Serializable
data class EndAfterState(
    val armed: Boolean = false,
    val startedAt: Long? = null,
    val capAt: Long? = null,
    val pkg: String? = null,
    val title: String? = null,
    /** [MediaTrack.key] of the video being followed. */
    val key: String? = null,
    val breakMin: Int = EndAfter.DEFAULT_BREAK_MIN,
    val durationMs: Long? = null,
) {
    fun toJson(): String = AgentJson.encodeToString(serializer(), this)

    companion object {
        fun parse(text: String?): EndAfterState =
            if (text.isNullOrBlank()) EndAfterState()
            else try { AgentJson.decodeFromString(serializer(), text) } catch (_: Exception) { EndAfterState() }
    }
}

/**
 * Follows the armed video and says when it is over:
 * - **nextVideo**: the title changed (autoplay or a new pick)
 * - **stopped**: STOPPED/ERROR, NONE for [noneDebounceMs], or the session gone for [goneDebounceMs]
 * - **ended**: position ≥ duration − [nearEndMs] (only when the duration is known)
 * - **cap**: the cap time passed
 * A pause is not an end; the cap covers a video left paused.
 */
class EndAfterWatcher(
    private val noneDebounceMs: Long = 3_000,
    private val goneDebounceMs: Long = 5_000,
    private val nearEndMs: Long = 2_000,
) {
    private var noneSince: Long? = null
    private var goneSince: Long? = null

    fun clear() { noneSince = null; goneSince = null }

    /** Returns the trigger reason, or null while the video is still on. */
    fun check(state: EndAfterState, sample: MediaSample?, nowElapsed: Long, nowWall: Long): String? {
        if (!state.armed) { clear(); return null }
        if (state.capAt != null && nowWall >= state.capAt) return "cap"
        if (sample == null) {
            noneSince = null
            val g = goneSince ?: nowElapsed.also { goneSince = it }
            return if (nowElapsed - g >= goneDebounceMs) "stopped" else null
        }
        goneSince = null
        val t = sample.track
        if (t != null && state.key != null && t.key != state.key) return "nextVideo"
        when (sample.state) {
            PlayState.stopped, PlayState.error -> return "stopped"
            PlayState.none -> {
                val n = noneSince ?: nowElapsed.also { noneSince = it }
                return if (nowElapsed - n >= noneDebounceMs) "stopped" else null
            }
            else -> noneSince = null
        }
        val d = t?.durationMs ?: state.durationMs
        if (d != null && d > nearEndMs && sample.livePositionMs(nowElapsed) >= d - nearEndMs) return "ended"
        return null
    }
}

object EndAfter {
    const val DEFAULT_CAP_MIN = 45
    const val DEFAULT_BREAK_MIN = 60

    /** Arms on [sample] (the foreground video). Returns the state, or an error message. */
    fun arm(sample: MediaSample?, nowWall: Long, capMin: Int?, breakMin: Int?): Pair<EndAfterState?, String> {
        val t = sample?.track ?: return null to "no foreground video to follow"
        if (sample.state == PlayState.stopped || sample.state == PlayState.error) return null to "nothing is playing"
        val cap = (capMin ?: DEFAULT_CAP_MIN).coerceIn(1, 24 * 60)
        val brk = (breakMin ?: DEFAULT_BREAK_MIN).coerceIn(1, 24 * 60)
        return EndAfterState(
            armed = true, startedAt = nowWall, capAt = nowWall + cap * 60_000L,
            pkg = t.pkg, title = t.title, key = t.key, breakMin = brk, durationMs = t.durationMs,
        ) to "break of $brk min after \"${t.title}\" (cap $cap min)"
    }
}
