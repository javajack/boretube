package com.rakesh.boretube.agent.core

import kotlinx.serialization.Serializable

/** Rules doc `shorts` (optional; absent = off). */
@Serializable
data class ShortsRules(
    /** off | block | budget | report */
    val mode: String = "off",
    /** budget: Shorts allowed per day (local midnight reset). */
    val perDay: Int = 0,
) {
    companion object {
        val MODES = setOf("off", "block", "budget", "report")
    }
}

/** What one detector step saw. */
data class ShortsStep(
    /** The followed package is in a Shorts session right now. */
    val active: Boolean,
    /** The session started on this step. */
    val started: Boolean = false,
    /** Short tracks seen for the first time on this step (add to today's count). */
    val newShorts: Int = 0,
    /** Distinct titles in the window (for the journal). */
    val titles: List<String> = emptyList(),
)

/**
 * Shorts detection by rhythm. Nothing in SmartTube's media session marks a Short,
 * but Shorts change title every ~8–10 s while a normal video keeps one title
 * for minutes (verified on the VU3, docs/knowledge/youtube-shorts-and-smarttube.md).
 *
 * Rule, per followed video package, on the play clock (paused time never counts):
 * - a track is **short** when its known duration is ≤ [shortDurationMs] (counts
 *   right away, even while still playing or looping), or, with no known duration,
 *   while it has played < [maxTrackMs]. A known duration > [shortDurationMs] is
 *   never short.
 * - a **Shorts session** is ≥ [minTitles] distinct titles whose play time falls
 *   within the last [windowMs], every one of them short.
 * - tracks that played < [minPlayedMs] are ignored (titles flashing past).
 * Seeking keeps the title, so it is never a new track. One short-ish normal video
 * is one title and never triggers.
 */
class ShortsDetector(
    private val windowMs: Long = 120_000,
    private val maxTrackMs: Long = 90_000,
    private val minTitles: Int = 3,
    private val shortDurationMs: Long = 180_000,
    private val minPlayedMs: Long = 1_000,
    /** Steps (about 1 s each) with no media session before the run is dropped. */
    private val maxGapSteps: Int = 60,
) {
    private var pkg: String? = null
    private var gapSteps = 0
    private val finished = ArrayDeque<TrackRecord>()
    private val counted = HashSet<Long>()
    var active = false
        private set

    fun reset(newPkg: String? = null) {
        pkg = newPkg
        gapSteps = 0
        finished.clear()
        counted.clear()
        active = false
    }

    fun isShort(r: TrackRecord): Boolean {
        val d = r.track.durationMs
        if (d != null && d > 0) return d <= shortDurationMs
        return r.playedMs < maxTrackMs
    }

    /**
     * [followedPkg]: the package the timeline follows; [done]: the track the
     * timeline just finished (if any); [current] and [playClockMs] from the timeline.
     */
    fun step(followedPkg: String?, done: TrackRecord?, current: TrackRecord?, playClockMs: Long): ShortsStep {
        // SmartTube tears its media session down for ~4–5 s between Shorts
        // (verified on the VU3), so "no session" must not end the run: keep
        // following the last app until [maxGapSteps] steps pass with nothing.
        if (followedPkg == null) {
            if (++gapSteps > maxGapSteps) reset(null)
        } else {
            gapSteps = 0
            if (followedPkg != pkg) reset(followedPkg)
        }
        val followed = followedPkg ?: pkg
        if (followed == null || followed !in MediaSnapshot.VIDEO_PACKAGES) {
            active = false
            return ShortsStep(false)
        }
        if (done != null && done.track.pkg == followed && done.playedMs >= minPlayedMs) finished.addLast(done)
        val from = playClockMs - windowMs
        while (finished.isNotEmpty() && finished.first().endPlayMs < from) finished.removeFirst()
        val window = finished.toMutableList()
        if (current != null && current.playedMs >= minPlayedMs) window += current
        counted.retainAll(window.map { it.seq }.toSet())

        val distinct = window.map { it.track.key }.distinct()
        val now = distinct.size >= minTitles && window.all { isShort(it) }
        val started = now && !active
        active = now
        if (!now) return ShortsStep(false)
        val fresh = window.filter { it.seq !in counted }
        counted += fresh.map { it.seq }
        return ShortsStep(true, started, fresh.size, window.map { it.track.title }.distinct())
    }
}

/** Persisted "Shorts today" counter; resets at local midnight. */
@Serializable
data class ShortsCount(
    /** Local date, ISO (yyyy-MM-dd). */
    val day: String = "",
    val count: Int = 0,
    val lastDetectedAt: Long? = null,
) {
    fun forDay(today: String): ShortsCount = if (day == today) this else ShortsCount(today, 0, lastDetectedAt)

    fun add(today: String, n: Int, now: Long): ShortsCount {
        val d = forDay(today)
        return if (n <= 0) d else d.copy(count = d.count + n, lastDetectedAt = now)
    }

    /** budget: block once today's count is over [perDay]. */
    fun overBudget(today: String, perDay: Int): Boolean = forDay(today).count > perDay
}
