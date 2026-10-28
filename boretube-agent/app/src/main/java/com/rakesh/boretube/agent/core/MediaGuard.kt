package com.rakesh.boretube.agent.core

import kotlinx.serialization.Serializable

/** `status.media`: the followed media session, or absent. */
@Serializable
data class MediaDoc(
    val pkg: String,
    val title: String? = null,
    val artist: String? = null,
    /** none | stopped | paused | playing | buffering | error | other */
    val state: String,
    val positionMs: Long,
    val durationMs: Long? = null,
    val remainingMs: Long? = null,
    /** listener | dumpsys */
    val source: String,
)

/** `status.endAfter`. */
@Serializable
data class EndAfterDoc(
    val armed: Boolean,
    val startedAt: Long? = null,
    val capAt: Long? = null,
    val title: String? = null,
    val pkg: String? = null,
    val breakMin: Int? = null,
)

/** `status.shorts`. */
@Serializable
data class ShortsDoc(
    /** off | block | budget | report */
    val mode: String,
    val todayCount: Int,
    val lastDetectedAt: Long? = null,
    /** A Shorts session is on right now. */
    val active: Boolean = false,
    val perDay: Int? = null,
)

/** A journal line the controller writes (op, target, before, after). */
data class MediaNote(val op: String, val target: String, val before: String, val after: String, val ok: Boolean = true)

data class MediaOutcome(
    val followed: MediaSample?,
    /** Close this Shorts app (force-stop + HOME), with the explicit card if any. */
    val close: Decision.CloseApp? = null,
    /** End-after-this-one fired: start a break of [EndAfterState.breakMin]. */
    val endAfterFired: String? = null,
    val endAfterBreakMin: Int = EndAfter.DEFAULT_BREAK_MIN,
    val notes: List<MediaNote> = emptyList(),
)

/**
 * Media brain: timeline + Shorts detector + budget + end-after-this-one. Pure;
 * the controller feeds it a [MediaSnapshot] every tick and applies the outcome.
 * Not thread-safe: the controller calls it from the guard thread only.
 */
class MediaGuard(
    shortsCount: ShortsCount = ShortsCount(),
    endAfter: EndAfterState = EndAfterState(),
) {
    @Volatile var shortsCount: ShortsCount = shortsCount
    @Volatile var endAfter: EndAfterState = endAfter
    val timeline = MediaTimeline()
    val detector = ShortsDetector()
    private val watcher = EndAfterWatcher()
    @Volatile var source: MediaSource = MediaSource.none
        private set
    @Volatile var followed: MediaSample? = null
        private set

    fun step(
        snap: MediaSnapshot,
        foreground: String?,
        nowElapsed: Long,
        nowWall: Long,
        today: String,
        rules: Rules,
        canEnforce: Boolean,
    ): MediaOutcome {
        source = snap.source
        val notes = mutableListOf<MediaNote>()
        val primary = snap.primary(foreground)
        followed = primary
        shortsCount = shortsCount.forDay(today)

        // ── Shorts ──
        val done = timeline.update(primary, nowElapsed)
        val s = detector.step(timeline.pkg, done, timeline.current, timeline.playClockMs)
        val sr = rules.shorts ?: ShortsRules()
        var close: Decision.CloseApp? = null
        if (s.active) {
            shortsCount = shortsCount.add(today, s.newShorts, nowWall)
            val pkg = timeline.pkg!!
            if (s.started && sr.mode != "off") {
                notes += MediaNote(
                    "shorts", pkg, "detected",
                    "${s.titles.size} titles in 2 min; today ${shortsCount.count}; mode ${sr.mode}" +
                        (if (sr.mode == "budget") " (${sr.perDay}/day)" else "") +
                        "; ${s.titles.take(5).joinToString(" | ")}",
                )
            }
            val block = when (sr.mode) {
                "block" -> "shortsBlock"
                "budget" -> if (shortsCount.overBudget(today, sr.perDay)) "shortsBudget" else null
                else -> null
            }
            if (block != null && canEnforce) {
                val explicit = rules.style == "explicit"
                val card = when {
                    !explicit -> null
                    block == "shortsBlock" -> Card(BLOCK_TITLE, null, BLOCK_SUB)
                    else -> Card(BUDGET_TITLE, null, BLOCK_SUB)
                }
                close = Decision.CloseApp(pkg, forceStop = true, reason = block, card = card)
                notes += MediaNote("shorts", pkg, block, "closing; today ${shortsCount.count}" +
                    if (block == "shortsBudget") " > ${sr.perDay}/day" else "")
                // Start over: after the close, three new titles are needed again.
                detector.reset(pkg)
            }
        }

        // ── End after this one ──
        var fired: String? = null
        val ea = endAfter
        if (ea.armed) {
            val sample = ea.pkg?.let { snap.forPackage(it) }
            // Without any media source the session can't be judged "gone": only the cap applies.
            val judged = if (snap.source == MediaSource.none) null else sample
            val reason = if (snap.source == MediaSource.none) {
                if (ea.capAt != null && nowWall >= ea.capAt) "cap" else null
            } else watcher.check(ea, judged, nowElapsed, nowWall)
            if (reason != null) {
                fired = reason
                notes += MediaNote("endAfter", ea.pkg ?: "media", "\"${ea.title}\"", "$reason → break ${ea.breakMin} min")
                endAfter = EndAfterState()
                watcher.clear()
            }
        }
        return MediaOutcome(primary, close, fired, ea.breakMin, notes)
    }

    fun arm(snap: MediaSnapshot, foreground: String?, nowWall: Long, capMin: Int?, breakMin: Int?): ActionResult {
        val (st, detail) = EndAfter.arm(snap.primary(foreground), nowWall, capMin, breakMin)
        if (st == null) return ActionResult(false, detail)
        endAfter = st
        watcher.clear()
        return ActionResult(true, detail)
    }

    fun cancelEndAfter(): Boolean {
        val was = endAfter.armed
        endAfter = EndAfterState()
        watcher.clear()
        return was
    }

    fun mediaDoc(nowElapsed: Long): MediaDoc? {
        val f = followed ?: return null
        val t = f.track
        return MediaDoc(
            pkg = f.pkg, title = t?.title, artist = t?.artist, state = f.state.name,
            positionMs = f.livePositionMs(nowElapsed), durationMs = t?.durationMs,
            remainingMs = f.remainingMs(nowElapsed), source = source.name,
        )
    }

    fun endAfterDoc(): EndAfterDoc {
        val e = endAfter
        return if (!e.armed) EndAfterDoc(false)
        else EndAfterDoc(true, e.startedAt, e.capAt, e.title, e.pkg, e.breakMin)
    }

    fun shortsDoc(rules: Rules, today: String): ShortsDoc {
        val sr = rules.shorts ?: ShortsRules()
        val c = shortsCount.forDay(today)
        return ShortsDoc(sr.mode, c.count, c.lastDetectedAt, detector.active, sr.perDay.takeIf { sr.mode == "budget" })
    }

    companion object {
        const val BLOCK_TITLE = "Shorts aren't on in this house."
        const val BUDGET_TITLE = "That's all the Shorts for today."
        const val BLOCK_SUB = "Pick a full video instead."
    }
}
