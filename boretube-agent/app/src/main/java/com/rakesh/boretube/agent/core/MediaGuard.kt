package com.rakesh.boretube.agent.core

import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

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
    /** off | block | budget | report | cooldown */
    val mode: String,
    val todayCount: Int,
    val lastDetectedAt: Long? = null,
    /** A Shorts session is on right now. */
    val active: Boolean = false,
    val perDay: Int? = null,
    /** 1.3.0+, mode cooldown: the configured minutes. */
    val cooldownMin: Int? = null,
    /** 1.3.0+: video apps are kept closed until this epoch ms (absent = no cool-down running). */
    val cooldownUntil: Long? = null,
)

/** A journal line the controller writes (op, target, before, after). */
data class MediaNote(val op: String, val target: String, val before: String, val after: String, val ok: Boolean = true)

data class MediaOutcome(
    val followed: MediaSample?,
    /** Close this Shorts / video app (force-stop + HOME), with the explicit card if any. */
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
    /** Persisted cool-down end (epoch ms), or null. */
    cooldownUntil: Long? = null,
    private val zone: ZoneId = ZoneId.systemDefault(),
) {
    @Volatile var shortsCount: ShortsCount = shortsCount
    @Volatile var endAfter: EndAfterState = endAfter
    /** Cool-down: every [MediaSnapshot.COOLDOWN_PACKAGES] app stays closed until then (epoch ms). */
    @Volatile var cooldownUntil: Long? = cooldownUntil
        private set
    /** Last cool-down close per package (elapsed ms): a failing close must not spam the journal. */
    private val cooldownClosedAt = HashMap<String, Long>()
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
        val explicit = rules.style == "explicit"
        var close: Decision.CloseApp? = null
        // A running cool-down ends when it expires, or when the parent switched cool-down off.
        cooldownUntil?.let { until ->
            // (A cool-down further away than the longest allowed means the wall clock jumped back.)
            if (nowWall >= until || sr.mode != "cooldown" || until - nowWall > MAX_COOLDOWN_AHEAD_MS) {
                notes += MediaNote(
                    "cooldown", "video apps", "until ${hhmm(until)}",
                    if (nowWall >= until) "ended" else "ended (shorts mode ${sr.mode})",
                )
                cooldownUntil = null
                cooldownClosedAt.clear()
            }
        }
        if (s.active) {
            shortsCount = shortsCount.add(today, s.newShorts, nowWall)
            val pkg = timeline.pkg!!
            if (s.started && sr.mode != "off") {
                notes += MediaNote(
                    "shorts", pkg, "detected",
                    "${s.kind}: ${s.titles.size} videos; today ${shortsCount.count}; mode ${sr.mode}" +
                        (if (sr.mode == "budget") " (${sr.perDay}/day)" else "") +
                        "; ${s.titles.take(5).joinToString(" | ")}",
                )
            }
            if (sr.mode == "cooldown" && canEnforce && cooldownUntil == null) {
                val min = sr.cooldownMinutes
                val until = nowWall + min * 60_000L
                cooldownUntil = until
                cooldownClosedAt[pkg] = nowElapsed
                val card = if (!explicit) null else Card(
                    COOLDOWN_TITLE, hhmm(until),
                    if (s.kind == "hopping") COOLDOWN_HOP_SUB else COOLDOWN_SHORTS_SUB, CardMood.asleep,
                )
                close = Decision.CloseApp(pkg, forceStop = true, reason = "shortsCooldown", card = card)
                notes += MediaNote("cooldown", pkg, s.kind, "closing; video apps closed for $min min, until ${hhmm(until)}")
                detector.reset(pkg)
            }
            val block = when (sr.mode) {
                "block" -> "shortsBlock"
                "budget" -> if (shortsCount.overBudget(today, sr.perDay)) "shortsBudget" else null
                else -> null
            }
            if (block != null && canEnforce) {
                val card = when {
                    !explicit -> null
                    s.kind == "hopping" && block == "shortsBlock" -> Card(HOP_TITLE, null, HOP_SUB, CardMood.calm)
                    s.kind == "hopping" -> Card(HOP_BUDGET_TITLE, null, HOP_SUB, CardMood.calm)
                    block == "shortsBlock" -> Card(BLOCK_TITLE, null, BLOCK_SUB, CardMood.calm)
                    else -> Card(BUDGET_TITLE, null, BLOCK_SUB, CardMood.calm)
                }
                close = Decision.CloseApp(pkg, forceStop = true, reason = block, card = card)
                notes += MediaNote("shorts", pkg, block, "closing; today ${shortsCount.count}" +
                    if (block == "shortsBudget") " > ${sr.perDay}/day" else "")
                // Start over: after the close, three new titles are needed again.
                detector.reset(pkg)
            }
        }

        // ── Cool-down: keep every video app closed ──
        val cu = cooldownUntil
        if (close == null && cu != null && canEnforce) {
            val target = foreground?.takeIf { it in MediaSnapshot.COOLDOWN_PACKAGES }
                ?: primary?.takeIf {
                    foreground == null && it.pkg in MediaSnapshot.COOLDOWN_PACKAGES &&
                        (it.state == PlayState.playing || it.state == PlayState.buffering)
                }?.pkg
            val last = target?.let { cooldownClosedAt[it] }
            if (target != null && (last == null || nowElapsed - last >= COOLDOWN_RECLOSE_MS)) {
                cooldownClosedAt[target] = nowElapsed
                val card = if (explicit) Card(COOLDOWN_AGAIN_TITLE, hhmm(cu), COOLDOWN_AGAIN_SUB, CardMood.asleep) else null
                close = Decision.CloseApp(target, forceStop = true, reason = "shortsCooldown", card = card)
                notes += MediaNote("cooldown", target, "opened during cool-down", "closing; back at ${hhmm(cu)}")
                if (target == timeline.pkg) detector.reset(target)
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

    /** Ends a running cool-down (the `restore` action). Returns whether one was running. */
    fun endCooldown(): Boolean {
        val was = cooldownUntil != null
        cooldownUntil = null
        cooldownClosedAt.clear()
        return was
    }

    private fun hhmm(epochMs: Long): String = HHMM.format(Instant.ofEpochMilli(epochMs).atZone(zone)).lowercase().replace(" ", "\u00A0")

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

    fun shortsDoc(rules: Rules, today: String, nowWall: Long = System.currentTimeMillis()): ShortsDoc {
        val sr = rules.shorts ?: ShortsRules()
        val c = shortsCount.forDay(today)
        return ShortsDoc(
            sr.mode, c.count, c.lastDetectedAt, detector.active, sr.perDay.takeIf { sr.mode == "budget" },
            cooldownMin = sr.cooldownMinutes.takeIf { sr.mode == "cooldown" },
            cooldownUntil = cooldownUntil?.takeIf { it > nowWall },
        )
    }

    companion object {
        const val BLOCK_TITLE = "Shorts aren't on in this house."
        const val BUDGET_TITLE = "That's all the Shorts for today."
        const val BLOCK_SUB = "Pick a full video instead."
        const val HOP_TITLE = "Lots of jumping between videos."
        const val HOP_BUDGET_TITLE = "That's enough video hopping for today."
        const val HOP_SUB = "Pick one video and watch it to the end."
        const val COOLDOWN_TITLE = "Time for a video break."
        const val COOLDOWN_HOP_SUB = "Lots of jumping between videos. Videos rest for a bit."
        const val COOLDOWN_SHORTS_SUB = "That was a lot of Shorts. Videos rest for a bit."
        const val COOLDOWN_AGAIN_TITLE = "Videos are still resting."
        const val COOLDOWN_AGAIN_SUB = "Try something else for now."
        /** A cool-down re-closes the same app at most this often. */
        const val COOLDOWN_RECLOSE_MS = 5_000L
        private const val MAX_COOLDOWN_AHEAD_MS = 121 * 60_000L
        private val HHMM: DateTimeFormatter = DateTimeFormatter.ofPattern("h:mm a", java.util.Locale.US)
    }
}
